'use strict';
// Playwright MCP --init-page script: sends HTTP Basic Auth to the sites listed
// in BASIC_AUTH_SITES ("name:url:user:pass,name2:url2:user2:pass2"), scoped to
// each site's origin, so the model never handles a password.
// user/pass may use %3A (:), %2C (,) and %25 (%) escapes. Only pass may contain
// ':' — Basic Auth splits user:pass at the first colon (RFC 7617), so a user
// with ':' can never authenticate. Never logs values.
// %0A/%0D (or a raw CR/LF) in a value skips the entry: the shell side
// (dx-common.sh curl-basic-auth) cannot carry one, and the two must agree.
// An unexpanded ADO macro ("$(BASIC_AUTH_SITES)", what ADO passes when the
// pipeline variable is not defined) counts as unset.
// .cjs (not .js): @playwright/mcp require()s this file, and a .js would be
// treated as ESM in projects whose package.json sets "type": "module".
// Loaded from the plugin (${CLAUDE_PLUGIN_ROOT}/data/lib), not the project.

function decode(s) {
  return s.includes('%') ? decodeURIComponent(s) : s;
}

function parseEntry(entry) {
  const first = entry.indexOf(':');
  const last = entry.lastIndexOf(':');
  if (first < 0 || last <= first) return null;
  const name = entry.slice(0, first);
  const pass = entry.slice(last + 1);
  const rest = entry.slice(first + 1, last);
  const mid = rest.lastIndexOf(':');
  if (!name || mid < 0) return null;
  const url = rest.slice(0, mid);
  const user = rest.slice(mid + 1);
  const u = new URL(url); // throws on invalid
  if (u.protocol !== 'http:' && u.protocol !== 'https:') return null;
  const du = decode(user);
  const dp = decode(pass);
  if (/[\r\n]/.test(du) || /[\r\n]/.test(dp)) return null;
  return { name, origin: u.origin, user: du, pass: dp };
}

function parseSites(raw) {
  const sites = [];
  const skipped = [];
  if (!raw || /^\$\([^)]*\)$/.test(raw.trim())) return { sites, skipped };
  raw.split(',').forEach((entry, i) => {
    let site = null;
    try { site = parseEntry(entry); } catch { /* malformed */ }
    if (site) sites.push(site); else skipped.push(i);
  });
  return { sites, skipped };
}

function headerFor(sites, url) {
  let origin;
  try { origin = new URL(url).origin; } catch { return null; }
  const s = sites.find((x) => x.origin === origin);
  return s ? 'Basic ' + Buffer.from(`${s.user}:${s.pass}`).toString('base64') : null;
}

const registered = new WeakSet();
let parsed = null; // env is fixed for the server's life: parse and warn once

async function initPage({ page }) {
  if (!parsed) {
    parsed = parseSites(process.env.BASIC_AUTH_SITES);
    for (const i of parsed.skipped) {
      console.error(`BASIC_AUTH_SITES: entry ${i} skipped (expected name:url:user:pass)`);
    }
  }
  const { sites } = parsed;
  if (!sites.length) return;
  const context = page.context();
  if (registered.has(context)) return; // script runs once per tab
  registered.add(context);
  // route.continue({headers}) makes Chromium carry the override across
  // redirects, leaking the login to whatever origin a listed site redirects to
  // (verified). So for a listed origin, fetch with the header and no redirect
  // following, then fulfill: the browser follows any redirect itself, as a
  // fresh request that carries no Authorization.
  await context.route(
    (url) => headerFor(sites, url.toString()) !== null,
    async (route) => {
      try {
        const req = route.request();
        const response = await route.fetch({
          headers: { ...req.headers(), authorization: headerFor(sites, req.url()) },
          maxRedirects: 0,
        });
        await route.fulfill({ response });
      } catch {
        // Never log the error: its call log can include request headers.
        await route.abort().catch(() => {});
      }
    }
  );
}

module.exports = { default: initPage, parseSites, headerFor };
