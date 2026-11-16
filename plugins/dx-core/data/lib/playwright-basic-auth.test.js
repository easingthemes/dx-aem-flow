'use strict';
// Unit tests (always run) + opt-in browser e2e (DX_BROWSER_TESTS=1).
const test = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { parseSites, headerFor } = require('./playwright-basic-auth.js');

const b64 = (s) => 'Basic ' + Buffer.from(s).toString('base64');

test('parseSites returns [] for undefined and empty', () => {
  assert.deepStrictEqual(parseSites(undefined), { sites: [], skipped: [] });
  assert.deepStrictEqual(parseSites(''), { sites: [], skipped: [] });
});

test('parseSites splits name/url/user/pass with ports in url', () => {
  const r = parseSites('qa:https://qa.example.com:8443:u:p');
  assert.deepStrictEqual(r.sites, [
    { name: 'qa', origin: 'https://qa.example.com:8443', user: 'u', pass: 'p' },
  ]);
  assert.deepStrictEqual(r.skipped, []);
});

test('parseSites decodes escapes', () => {
  const r = parseSites('qa:https://qa.example.com:a%3Ab:x%2Cy%25z');
  assert.strictEqual(r.sites[0].user, 'a:b');
  assert.strictEqual(r.sites[0].pass, 'x,y%z');
  const plain = parseSites('qa:https://qa.example.com:user:p@ss/w#rd"$');
  assert.strictEqual(plain.sites[0].pass, 'p@ss/w#rd"$');
});

test('parseSites skips malformed entries', () => {
  const r = parseSites('bad,qa:https://qa.example.com:u:p,x:notaurl:u:p');
  assert.strictEqual(r.sites.length, 1);
  assert.deepStrictEqual(r.skipped, [0, 2]);
});

test('headerFor normalises origin', () => {
  const { sites } = parseSites('qa:https://QA.example.com:443/content/:u:p');
  assert.strictEqual(headerFor(sites, 'https://qa.example.com/a?b'), b64('u:p'));
  assert.strictEqual(headerFor(sites, 'http://qa.example.com/'), null);
  assert.strictEqual(headerFor(sites, 'https://other.example.com/'), null);
});

test('headerFor picks per-site credentials', () => {
  const { sites } = parseSites('a:https://a.example.com:ua:pa,b:https://b.example.com:ub:pb');
  assert.strictEqual(headerFor(sites, 'https://a.example.com/x'), b64('ua:pa'));
  assert.strictEqual(headerFor(sites, 'https://b.example.com/x'), b64('ub:pb'));
});

// ---------------------------------------------------------------- e2e

const E2E = process.env.DX_BROWSER_TESTS === '1';
const SCRIPT = path.join(__dirname, 'playwright-basic-auth.js');

function listen(server) {
  return new Promise((res) => server.listen(0, '127.0.0.1', () => res(server.address().port)));
}

// Server requiring a login; records every authorization header seen.
function authServer(user, pass, title, extra) {
  const seen = [];
  const hits = { n: 0 };
  const want = b64(`${user}:${pass}`);
  const server = http.createServer((q, r) => {
    if (extra && extra(q, r)) return;
    hits.n++;
    const h = q.headers.authorization;
    if (h) seen.push(h);
    if (h !== want) {
      r.writeHead(401, { 'WWW-Authenticate': 'Basic realm="t"' });
      return r.end('denied');
    }
    r.writeHead(200, { 'content-type': 'text/html' });
    r.end(`<title>${title}</title><h1>${title}</h1>`);
  });
  return { server, seen, hits };
}

// Minimal stdio MCP client around the Playwright MCP server.
async function withMcp(env, fn) {
  const p = spawn(
    'npx',
    ['-y', '@playwright/mcp@0.0.83', '--headless', '--isolated', '--init-page', SCRIPT],
    { env: { ...process.env, BASIC_AUTH_SITES: '', ...env }, stdio: ['pipe', 'pipe', 'pipe'], detached: true }
  );
  let buf = '';
  let stderr = '';
  p.stderr.on('data', (d) => { stderr += d; });
  let id = 0;
  const pending = {};
  p.stdout.on('data', (d) => {
    buf += d;
    let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, i);
      buf = buf.slice(i + 1);
      try {
        const m = JSON.parse(line);
        if (pending[m.id]) { pending[m.id](m); delete pending[m.id]; }
      } catch { /* not JSON */ }
    }
  });
  const rpc = (method, params) =>
    new Promise((res, rej) => {
      const i = ++id;
      const t = setTimeout(() => rej(new Error(`rpc ${method} timed out`)), 90000);
      pending[i] = (m) => { clearTimeout(t); res(m); };
      p.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: i, method, params }) + '\n');
    });
  try {
    await rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 't', version: '1' } });
    p.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');
    const navigate = async (url) => {
      const r = await rpc('tools/call', { name: 'browser_navigate', arguments: { url } });
      return (r.result?.content || []).map((c) => c.text || '').join('\n') + (r.error ? JSON.stringify(r.error) : '');
    };
    return await fn(navigate, () => stderr);
  } finally {
    try { process.kill(-p.pid, 'SIGKILL'); } catch { /* gone */ }
  }
}

test('e2e (opt-in browser tests)', { skip: !E2E && 'set DX_BROWSER_TESTS=1', timeout: 600000 }, async (t) => {
  const A = authServer('ua', 'pa:x', 'A OK', (q, r) => {
    if (q.url === '/redirect') {
      r.writeHead(302, { Location: `http://127.0.0.1:${portC}/` });
      r.end();
      return true;
    }
  });
  const B = authServer('ub', 'pb', 'B OK');
  const C = authServer('uc', 'pc', 'C OK');
  const portA = await listen(A.server);
  const portB = await listen(B.server);
  var portC = await listen(C.server); // eslint-disable-line no-var
  const urlA = `http://127.0.0.1:${portA}`;
  const urlB = `http://127.0.0.1:${portB}`;
  const urlC = `http://127.0.0.1:${portC}`;
  const sites = `a:${urlA}/content:ua:pa%3Ax,b:${urlB}:ub:pb`;
  t.after(() => { A.server.close(); B.server.close(); C.server.close(); });

  await t.test('e2e: two sites get their own credentials', async () => {
    await withMcp({ BASIC_AUTH_SITES: sites }, async (nav) => {
      assert.match(await nav(`${urlA}/`), /Page Title: A OK/);
      assert.match(await nav(`${urlB}/`), /Page Title: B OK/);
    });
  });

  await t.test('e2e: unlisted origin gets no header', async () => {
    C.seen.length = 0;
    await withMcp({ BASIC_AUTH_SITES: sites }, async (nav) => {
      const out = await nav(`${urlC}/`);
      assert.doesNotMatch(out, /Page Title: C OK/);
    });
    assert.deepStrictEqual(C.seen, []);
  });

  await t.test('e2e: redirect to unlisted origin carries no header', async () => {
    C.seen.length = 0;
    C.hits.n = 0;
    await withMcp({ BASIC_AUTH_SITES: sites }, async (nav) => {
      await nav(`${urlA}/redirect`);
    });
    assert.ok(C.hits.n > 0, 'redirect target was actually requested');
    assert.deepStrictEqual(C.seen, []);
  });

  await t.test('e2e: unset env is a no-op', async () => {
    A.seen.length = 0;
    await withMcp({ BASIC_AUTH_SITES: '' }, async (nav) => {
      const out = await nav(`${urlA}/`);
      assert.doesNotMatch(out, /Page Title: A OK/);
      assert.doesNotMatch(out, /Failed to load init page/);
    });
    assert.deepStrictEqual(A.seen, []);
  });

  await t.test('e2e: fetch failure aborts promptly and leaks nothing', async () => {
    const closed = await new Promise((res) => {
      const s = http.createServer();
      s.listen(0, '127.0.0.1', () => { const p = s.address().port; s.close(() => res(p)); });
    });
    const dead = `http://127.0.0.1:${closed}`;
    const start = Date.now();
    await withMcp({ BASIC_AUTH_SITES: `d:${dead}:ud:secret%3Apw` }, async (nav, getStderr) => {
      const out = await nav(`${dead}/`);
      assert.doesNotMatch(out, /Page Title: /);
      const all = out + getStderr();
      for (const needle of ['secret:pw', 'secret%3Apw', Buffer.from('ud:secret:pw').toString('base64')]) {
        assert.ok(!all.includes(needle), 'credential leaked');
      }
    });
    assert.ok(Date.now() - start < 25000, 'navigation failed fast (no 30s hang)');
  });

  await t.test('e2e: password not in tool result', async () => {
    await withMcp({ BASIC_AUTH_SITES: sites }, async (nav) => {
      const out = await nav(`${urlA}/`);
      assert.ok(!out.includes('pa:x') && !out.includes('pa%3Ax'));
      assert.ok(!out.includes(Buffer.from('ua:pa:x').toString('base64')));
    });
  });
});
