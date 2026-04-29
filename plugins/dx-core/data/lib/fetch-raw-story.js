#!/usr/bin/env node
// fetch-raw-story.js — Fetch ADO work item + comments via @azure-devops/mcp,
// convert HTML to markdown, and write raw-story.md WITHOUT routing the
// work-item JSON through an LLM context.
//
// Why this exists:
//   The dx-req Phase 1 flow used to call wit_get_work_item / wit_list_work_item_comments
//   from the LLM, which forced the entire payload (often 50-200kB of HTML) into
//   model context just to be re-emitted as markdown. This script bypasses the
//   model: it spawns @azure-devops/mcp directly, talks JSON-RPC over stdio,
//   and renders raw-story.md from disk. The skill afterwards only Reads the
//   produced markdown — typically a tenth of the original payload.
//
// Auth:
//   @azure-devops/mcp uses interactive OAuth by default (browser flow) and
//   caches the token via MSAL on disk. When Claude Code's MCP session has
//   already cached a token, this script reuses it — no second prompt. No az
//   CLI needed; no PAT.
//
// Scope (v1):
//   - Tools called: wit_get_work_item (main + parent if hierarchy-reverse exists),
//     wit_list_work_item_comments.
//   - Linked branches are extracted from artifact relations directly (no extra MCP call).
//   - PR detail (git_get_pull_request) and image fetching (wit_get_work_item_attachment)
//     are out of scope — the calling skill handles those after this script runs.
//
// Usage:
//   node .ai/lib/fetch-raw-story.js <org-url> <project> <work-item-id> [<spec-dir>]
//
// If <spec-dir> is omitted, the script derives it from the fetched title via
// `bash .ai/lib/dx-common.sh slugify <id> "<title>"` and creates
// `.ai/specs/<id>-<slug>/` under the current working directory. The chosen
// spec dir is printed on the last line of stdout as `SPEC_DIR=<path>` so the
// caller can capture it.
//
// Outputs (under <spec-dir>):
//   - raw-workitem.json  full ADO response (debug / re-run cache)
//   - raw-story.md       structured markdown — same shape produced by dx-req Phase 1
//   - .sprint            extracted sprint name (e.g. "Sprint 41")

'use strict';

const { spawn, execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// CLI entry point lives at the bottom of the file (inside a `require.main`
// guard so the module is safe to import for unit tests). `class McpClient`
// is in TDZ until its declaration line executes, so the entry must run
// after the script body has finished evaluating.

async function main(opts) {
  const { org, orgUrl, project, id, force } = opts;
  let specDir = opts.specDirArg;
  // Pre-seed short-circuit: hub mode (`/dx-hub-dispatch`) writes raw-story.md
  // without raw-workitem.json. Don't refetch in that case — the hub is the
  // source of truth. Only works when specDir was passed explicitly; auto-derived
  // paths require the title from a fetch.
  if (specDir) {
    const rawStoryPath = path.join(specDir, 'raw-story.md');
    const rawJsonPath = path.join(specDir, 'raw-workitem.json');
    if (fs.existsSync(rawStoryPath) && !fs.existsSync(rawJsonPath)) {
      console.log(`PRESEEDED: ${rawStoryPath} exists without raw-workitem.json — skipping fetch`);
      console.log(`SPEC_DIR=${specDir}`);
      return;
    }
  }

  const client = new McpClient(['npx', '-y', '@azure-devops/mcp', org]);
  await client.start();

  const wi = await client.callTool('wit_get_work_item', { project, id, expand: 'all' });
  const commentsRaw = await client.callTool('wit_list_work_item_comments', { project, workItemId: id });
  const comments = Array.isArray(commentsRaw) ? commentsRaw : (commentsRaw && commentsRaw.comments) || [];

  let parent = null;
  const parentId = findParentId(wi);
  if (parentId) {
    try {
      parent = await client.callTool('wit_get_work_item', { project, id: parentId });
    } catch (e) {
      console.error(`fetch-raw-story: parent #${parentId} fetch failed (${e.message}) — continuing without parent context`);
    }
  }

  // Pull request detail. ADO does NOT consistently emit vstfs:///Git/Ref/
  // relations for linked branches — most orgs only get vstfs:///Git/PullRequestId/
  // links. Fetching each PR gives us authoritative branch info via sourceRefName.
  const prs = await fetchPRs(client, extractPRRefs(wi));

  if (!specDir) {
    const title = (wi && wi.fields && wi.fields['System.Title']) || '';
    if (!title) {
      console.error('ERROR: work item has no title; cannot derive spec dir. Pass <spec-dir> explicitly.');
      await client.stop();
      process.exit(1);
    }
    specDir = path.join('.ai', 'specs', deriveSlug(id, title));
  }
  fs.mkdirSync(specDir, { recursive: true });
  fs.mkdirSync(path.join(specDir, 'images'), { recursive: true });

  // Idempotency: compare current fetched payload against the prior
  // raw-workitem.json. If unchanged, skip image refetch + file rewrites.
  const newPayload = { workItem: wi, comments, parent, prs };
  if (!force && payloadUnchanged(specDir, newPayload)) {
    await client.stop();
    console.log(`SKIPPED: ${path.join(specDir, 'raw-story.md')} already up to date`);
    console.log(`SPEC_DIR=${specDir}`);
    return;
  }

  // Image fetch + INDEX.md happens BEFORE renderRawStory so the GUID→path map
  // can rewrite embedded <img src="..."> URLs in the HTML→markdown pass.
  const guidToPath = await fetchImages(client, wi, specDir, project);

  await client.stop();

  fs.writeFileSync(
    path.join(specDir, 'raw-workitem.json'),
    JSON.stringify(newPayload, null, 2)
  );

  const sprint = extractSprint(wi);
  if (sprint) fs.writeFileSync(path.join(specDir, '.sprint'), sprint + '\n');

  const linked = collectLinkedDevelopment(wi, prs, id);
  const md = renderRawStory({ wi, comments, parent, orgUrl, project, id, guidToPath, linked });
  fs.writeFileSync(path.join(specDir, 'raw-story.md'), md);

  console.log(
    `fetch-raw-story: wrote ${path.join(specDir, 'raw-story.md')} ` +
    `(${md.length} bytes, ${comments.length} comments, ${linked.branches.length} matching branches, ` +
    `${linked.prs.length} matching PRs, ${guidToPath.size} images` +
    (parent ? `, parent #${parent.id}` : '') + ')'
  );
  // Last line — parseable by the calling skill: `SPEC_DIR=$(node fetch-raw-story.js ... | tail -1 | cut -d= -f2)`
  console.log(`SPEC_DIR=${specDir}`);
}

// Shell out to the project's slugify helper so we don't duplicate slug logic
// here. Falls back to a minimal in-process implementation if the helper is
// missing (e.g. running outside an initialized project).
function deriveSlug(id, title) {
  const helper = path.join('.ai', 'lib', 'dx-common.sh');
  if (fs.existsSync(helper)) {
    try {
      const out = execFileSync('bash', [helper, 'slugify', String(id), title], { encoding: 'utf8' });
      const trimmed = out.trim();
      if (trimmed) return trimmed;
    } catch (e) {
      console.error(`fetch-raw-story: slugify helper failed (${e.message}); using fallback`);
    }
  }
  // Fallback: 4-word kebab-case slug, no stop-word filtering.
  const slug = title
    .toLowerCase()
    .replace(/\[[^\]]*\]/g, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .split(/\s+/)
    .slice(0, 4)
    .join('-');
  return `${id}-${slug}`;
}

// ------------------------------------------------------------------
// MCP stdio JSON-RPC client (line-delimited)
// ------------------------------------------------------------------

class McpClient {
  constructor(cmd) {
    this.cmd = cmd;
    this.proc = null;
    this.buffer = '';
    this.nextId = 1;
    this.pending = new Map();
  }

  async start() {
    const [bin, ...args] = this.cmd;
    this.proc = spawn(bin, args, { stdio: ['pipe', 'pipe', 'pipe'], env: process.env });
    this.proc.stdout.setEncoding('utf8');
    this.proc.stdout.on('data', chunk => this._onData(chunk));
    this.proc.stderr.setEncoding('utf8');
    this.proc.stderr.on('data', d => process.stderr.write(`[ado-mcp] ${d}`));
    this.proc.on('error', err => this._failAll(err));
    this.proc.on('exit', code => {
      if (this.pending.size) this._failAll(new Error(`MCP process exited with code ${code} before answering`));
    });

    await this._send('initialize', {
      protocolVersion: '2025-03-26',
      capabilities: { tools: {} },
      clientInfo: { name: 'dx-fetch-raw-story', version: '1.0.0' },
    });
    this._sendNotification('notifications/initialized', {});
  }

  stop() {
    return new Promise(resolve => {
      if (!this.proc || this.proc.killed) return resolve();
      this.proc.once('close', () => resolve());
      try { this.proc.stdin.end(); } catch (_) {}
      const timer = setTimeout(() => { try { this.proc.kill(); } catch (_) {} resolve(); }, 5000);
      timer.unref();
    });
  }

  async callTool(name, args) {
    const result = await this._send('tools/call', { name, arguments: args });
    if (result && result.isError) {
      const msg = (result.content || []).map(c => c.text || '').join(' ').trim();
      throw new Error(`tool ${name} returned error: ${msg || JSON.stringify(result)}`);
    }
    const content = (result && result.content) || [];
    const text = content.find(c => c.type === 'text');
    if (!text) return result;
    try { return JSON.parse(text.text); } catch (_) { return text.text; }
  }

  _onData(chunk) {
    this.buffer += chunk;
    let idx;
    while ((idx = this.buffer.indexOf('\n')) !== -1) {
      const line = this.buffer.slice(0, idx).trim();
      this.buffer = this.buffer.slice(idx + 1);
      if (!line) continue;
      let msg;
      try { msg = JSON.parse(line); } catch (_) { continue; }
      if (msg.id != null && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        if (msg.error) reject(new Error(`MCP error ${msg.error.code}: ${msg.error.message}`));
        else resolve(msg.result);
      }
    }
  }

  _send(method, params) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.proc.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
    });
  }

  _sendNotification(method, params) {
    this.proc.stdin.write(JSON.stringify({ jsonrpc: '2.0', method, params }) + '\n');
  }

  _failAll(err) {
    for (const { reject } of this.pending.values()) reject(err);
    this.pending.clear();
  }
}

// ------------------------------------------------------------------
// ADO field helpers
// ------------------------------------------------------------------

function parseOrg(url) {
  if (!url) return null;
  const u = url.replace(/\/+$/, '');
  let m = u.match(/dev\.azure\.com\/([^\/]+)/);
  if (m) return m[1];
  m = u.match(/https?:\/\/([^.]+)\.visualstudio\.com/);
  if (m) return m[1];
  return u.split('/').filter(Boolean).pop() || null;
}

// Idempotency: prior raw-workitem.json is the source of truth for "what we
// fetched last time". Compare via deterministic JSON serialization. Returns
// false if no prior file exists or if its parse/compare fails — the safe
// default is to refetch.
function payloadUnchanged(specDir, newPayload) {
  const priorPath = path.join(specDir, 'raw-workitem.json');
  if (!fs.existsSync(priorPath)) return false;
  let prior;
  try { prior = JSON.parse(fs.readFileSync(priorPath, 'utf8')); } catch { return false; }
  return JSON.stringify(prior) === JSON.stringify(newPayload);
}

function findParentId(wi) {
  for (const r of (wi && wi.relations) || []) {
    if (r.rel !== 'System.LinkTypes.Hierarchy-Reverse') continue;
    const m = (r.url || '').match(/\/workItems\/(\d+)/);
    if (m) return Number(m[1]);
  }
  return null;
}

function extractSprint(wi) {
  const ip = wi && wi.fields && wi.fields['System.IterationPath'];
  if (!ip) return null;
  const last = ip.split('\\').pop().split('/').pop();
  const m = last.match(/^Sprint(\d+)$/);
  return m ? `Sprint ${m[1]}` : last;
}

function isMatchingBranch(name, id) {
  // Separators include `#` because devs commonly write `feature/#<id>-<slug>`.
  return new RegExp(`(?:^|[\\/_#-])${id}(?:[\\/_-]|$)`).test(name);
}

// ADO returns PR status as either a numeric enum or a string. Normalize to
// the same lowercase strings ADO's REST docs use.
const PR_STATUS_BY_INT = { 0: 'notSet', 1: 'active', 2: 'abandoned', 3: 'completed' };
function normalizePRStatus(status) {
  if (typeof status === 'number') return PR_STATUS_BY_INT[status] || String(status);
  if (typeof status === 'string') return status;
  return '';
}

function extractBranches(wi, id) {
  const out = [];
  for (const r of (wi && wi.relations) || []) {
    if (r.rel !== 'ArtifactLink') continue;
    const url = r.url || '';
    if (!url.startsWith('vstfs:///Git/Ref/')) continue;
    const decoded = decodeURIComponent(url);
    const m = decoded.match(/\/GB(.+)$/);
    if (!m) continue;
    const branchName = m[1];
    if (isMatchingBranch(branchName, id)) out.push({ branchName });
  }
  return out;
}

// Extract <projectId, repositoryId, prId> tuples from
// vstfs:///Git/PullRequestId/<projectGuid>/<repoGuid>/<prId> artifact relations.
// URL components are URL-encoded — `%2f` separates the IDs. Cross-project links
// are common (a story in project A can link a PR in project B), so we keep the
// embedded projectId rather than reusing the WI's project name.
function extractPRRefs(wi) {
  const out = [];
  const seen = new Set();
  for (const r of (wi && wi.relations) || []) {
    if (r.rel !== 'ArtifactLink') continue;
    const url = r.url || '';
    if (!url.startsWith('vstfs:///Git/PullRequestId/')) continue;
    const tail = url.slice('vstfs:///Git/PullRequestId/'.length);
    const parts = decodeURIComponent(tail).split('/');
    if (parts.length < 3) continue;
    const [projectId, repositoryId, prIdStr] = parts;
    const prId = Number(prIdStr);
    if (!Number.isInteger(prId)) continue;
    if (seen.has(prId)) continue;
    seen.add(prId);
    out.push({ projectId, repositoryId, prId });
  }
  return out;
}

async function fetchPRs(client, refs) {
  const out = [];
  for (const { projectId, repositoryId, prId } of refs) {
    try {
      // The MCP `project` arg accepts either name or GUID — using the GUID
      // from the artifact URL means we don't have to resolve cross-project.
      const pr = await client.callTool('repo_get_pull_request_by_id', {
        project: projectId,
        pullRequestId: prId,
        repositoryId,
      });
      if (pr && Object.keys(pr).length) out.push(pr);
      else console.error(`fetch-raw-story: PR #${prId} returned empty payload — skipping`);
    } catch (e) {
      console.error(`fetch-raw-story: PR #${prId} fetch failed (${e.message}) — continuing without`);
    }
  }
  return out;
}

// Strip refs/heads/ from a fully-qualified ref name. Returns null for non-branch refs.
function refNameToBranch(refName) {
  if (typeof refName !== 'string') return null;
  if (refName.startsWith('refs/heads/')) return refName.slice('refs/heads/'.length);
  return refName || null;
}

// Combine branches from Git/Ref artifact links AND PR sourceRefName, applying
// the WI-ID matching rule. PRs are filtered the same way (their branch must match).
function collectLinkedDevelopment(wi, prs, id) {
  const branchNames = new Set();
  for (const b of extractBranches(wi, id)) branchNames.add(b.branchName);

  const matchingPRs = [];
  for (const pr of prs) {
    const sourceBranch = refNameToBranch(pr && pr.sourceRefName);
    if (!sourceBranch || !isMatchingBranch(sourceBranch, id)) continue;
    matchingPRs.push({
      id: pr.pullRequestId || pr.id,
      title: pr.title || '',
      status: normalizePRStatus(pr.status),
      sourceBranch,
      targetBranch: refNameToBranch(pr.targetRefName) || '',
      createdDate: pr.creationDate || pr.createdDate || '',
    });
    branchNames.add(sourceBranch);
  }
  return {
    branches: Array.from(branchNames).sort().map(branchName => ({ branchName })),
    prs: matchingPRs.sort((a, b) => Number(a.id) - Number(b.id)),
  };
}

function isSystemComment(c) {
  const text = String((c && c.text) || '');
  if (!text.trim()) return true;
  if (/^State changed from /i.test(text)) return true;
  if (/^Assigned To changed from /i.test(text)) return true;
  return false;
}

// ------------------------------------------------------------------
// HTML to Markdown — rules from references/html-conversion.md
// ------------------------------------------------------------------

function htmlToMarkdown(html, guidToPath) {
  if (!html) return '';
  let s = String(html).replace(/\r\n/g, '\n');

  s = s.replace(/<!--[\s\S]*?-->/g, '');
  s = s.replace(/<table[^>]*>([\s\S]*?)<\/table>/gi, (_, body) => convertTable(body));
  s = s.replace(/<br\s*\/?>/gi, '\n');
  s = s.replace(/<\/?(?:b|strong)>/gi, '**');
  s = s.replace(/<\/?(?:i|em)>/gi, '*');
  s = s.replace(/<a [^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/gi, (_, href, t) => `[${stripTags(t).trim()}](${href})`);
  s = s.replace(/<img\b[^>]*?>/gi, m => convertImg(m, guidToPath));

  for (let i = 1; i <= 6; i++) {
    const re = new RegExp(`<h${i}\\b[^>]*>([\\s\\S]*?)</h${i}>`, 'gi');
    s = s.replace(re, (_, body) => `\n\n${'#'.repeat(i)} ${stripTags(body).trim()}\n\n`);
  }

  s = s.replace(/<ol[^>]*>([\s\S]*?)<\/ol>/gi, (_, body) => convertList(body, 'ol'));
  s = s.replace(/<ul[^>]*>([\s\S]*?)<\/ul>/gi, (_, body) => convertList(body, 'ul'));

  s = s.replace(/<span[^>]*data-vss-mention[^>]*>([\s\S]*?)<\/span>/gi, '$1');
  s = s.replace(/<\/(?:p|div)>/gi, '\n\n');
  s = s.replace(/<(?:p|div)[^>]*>/gi, '');
  s = s.replace(/<[^>]+>/g, '');

  s = decodeEntities(s);
  s = s.replace(/[ \t]+\n/g, '\n');
  s = s.replace(/\n{3,}/g, '\n\n');

  return s.trim();
}

function convertImg(tag, guidToPath) {
  const src = (tag.match(/src="([^"]+)"/i) || [, ''])[1];
  const alt = (tag.match(/alt="([^"]*)"/i) || [, 'image'])[1];
  // ADO inline image URL → rewrite to local path if we downloaded it.
  if (guidToPath && guidToPath.size) {
    const m = src.match(/_apis\/wit\/attachments\/([0-9a-fA-F-]{36})/);
    if (m) {
      const local = guidToPath.get(m[1].toLowerCase());
      if (local) return `![${alt}](${local})`;
      return `![${alt}](${src}) <!-- image not downloaded -->`;
    }
  }
  return `![${alt}](${src})`;
}

function convertList(body, type) {
  const items = [];
  body.replace(/<li[^>]*>([\s\S]*?)<\/li>/gi, (_, item) => {
    items.push(stripTags(item).replace(/\s+/g, ' ').trim());
  });
  if (!items.length) return '';
  const fmt = type === 'ol'
    ? items.map((t, i) => `${i + 1}. ${t}`)
    : items.map(t => `- ${t}`);
  return '\n' + fmt.join('\n') + '\n';
}

function convertTable(body) {
  const rows = [];
  body.replace(/<tr[^>]*>([\s\S]*?)<\/tr>/gi, (_, row) => {
    const cells = [];
    row.replace(/<(?:td|th)[^>]*>([\s\S]*?)<\/(?:td|th)>/gi, (_, c) => {
      cells.push(stripTags(c).replace(/\s+/g, ' ').trim());
    });
    if (cells.length) rows.push(cells);
  });
  if (!rows.length) return '';
  const head = rows[0];
  const sep = head.map(() => '---');
  const fmt = r => `| ${r.join(' | ')} |`;
  return ['', fmt(head), fmt(sep), ...rows.slice(1).map(fmt), ''].join('\n');
}

function stripTags(s) { return String(s).replace(/<[^>]+>/g, ''); }

function decodeEntities(s) {
  return s
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)));
}

// ------------------------------------------------------------------
// Image fetch — extracts ADO attachments + embedded HTML <img> refs,
// downloads each via wit_get_work_item_attachment, applies size + MIME
// filters, names files per the policy in dx-req SKILL.md step 8, and
// writes images/INDEX.md. Returns a Map<lowercase-guid, "./images/<file>">.
// ------------------------------------------------------------------

const IMAGE_MAX_BYTES = 5 * 1024 * 1024; // 5 MB
const IMAGE_EXTS = new Set(['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp']);
const MIME_BY_EXT = {
  png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg',
  gif: 'image/gif', webp: 'image/webp', svg: 'image/svg+xml', bmp: 'image/bmp',
};

async function fetchImages(client, wi, specDir, project) {
  const map = new Map();
  const rows = extractImageManifest(wi);
  if (!rows.length) {
    removeStaleImages(specDir, new Set());
    writeImageIndex(specDir, []);
    return map;
  }

  const fieldCounters = new Map(); // sanitized field name → next index (1-based)
  const usedFilenames = new Set();
  const indexRows = [];
  const skipped = [];

  for (const row of rows) {
    const ext = (row.filename.split('.').pop() || '').toLowerCase();
    if (!IMAGE_EXTS.has(ext)) {
      skipped.push({ ...row, reason: `non-image extension .${ext}` });
      continue;
    }
    if (row.size > 0 && row.size > IMAGE_MAX_BYTES) {
      skipped.push({ ...row, reason: `>${IMAGE_MAX_BYTES} bytes pre-fetch` });
      continue;
    }

    let result;
    try {
      result = await client.callTool('wit_get_work_item_attachment', {
        project,
        attachmentId: row.guid,
        fileName: row.filename,
      });
    } catch (e) {
      console.error(`fetch-raw-story: image ${row.guid} fetch failed (${e.message})`);
      skipped.push({ ...row, reason: `fetch error: ${e.message}` });
      continue;
    }

    const buf = decodeAttachmentBlob(result);
    if (!buf) {
      skipped.push({ ...row, reason: 'no decodable blob in MCP response' });
      continue;
    }
    if (buf.length > IMAGE_MAX_BYTES) {
      skipped.push({ ...row, reason: `>${IMAGE_MAX_BYTES} bytes post-fetch` });
      continue;
    }

    const target = chooseFilename(row, ext, fieldCounters, usedFilenames);
    usedFilenames.add(target);
    fs.writeFileSync(path.join(specDir, 'images', target), buf);

    const localPath = `./images/${target}`;
    map.set(row.guid.toLowerCase(), localPath);
    indexRows.push({
      file: target,
      source: row.source,
      size: buf.length,
      mime: MIME_BY_EXT[ext] || 'application/octet-stream',
    });
  }

  removeStaleImages(specDir, usedFilenames);
  writeImageIndex(specDir, indexRows, skipped);
  return map;
}

// On re-runs (e.g. an attachment was removed from the WI), files left over
// from the previous run would otherwise stay in images/ forever. Delete any
// non-whitelisted file not in the new manifest. Hidden dotfiles (.gitkeep)
// and INDEX.md are preserved.
function removeStaleImages(specDir, keepFilenames) {
  const dir = path.join(specDir, 'images');
  let entries;
  try { entries = fs.readdirSync(dir); } catch { return; }
  for (const name of entries) {
    if (name.startsWith('.')) continue;
    if (name === 'INDEX.md') continue;
    if (keepFilenames.has(name)) continue;
    try { fs.unlinkSync(path.join(dir, name)); }
    catch (e) { console.error(`fetch-raw-story: failed to remove stale image ${name} (${e.message})`); }
  }
}

function extractImageManifest(wi) {
  const out = [];
  const seen = new Set();

  // 1) AttachedFile relations
  for (const r of (wi && wi.relations) || []) {
    if (r.rel !== 'AttachedFile') continue;
    const m = (r.url || '').match(/attachments\/([0-9a-fA-F-]{36})/);
    if (!m) continue;
    const guid = m[1];
    if (seen.has(guid)) continue;
    seen.add(guid);
    out.push({
      source: 'attachment',
      guid,
      filename: (r.attributes && r.attributes.name) || 'image.bin',
      size: (r.attributes && r.attributes.resourceSize) || 0,
    });
  }

  // 2) Embedded <img> in HTML fields (per multilineFieldsFormat)
  const fmt = (wi && wi.multilineFieldsFormat) || {};
  const fields = (wi && wi.fields) || {};
  for (const [name, format] of Object.entries(fmt)) {
    if (format !== 'html') continue;
    const html = fields[name];
    if (typeof html !== 'string') continue;
    const re = /_apis\/wit\/attachments\/([0-9a-fA-F-]{36})[?&]fileName=([^"'&<> ]+)/g;
    let m;
    while ((m = re.exec(html))) {
      const guid = m[1];
      if (seen.has(guid)) continue;
      seen.add(guid);
      out.push({ source: name, guid, filename: decodeURIComponent(m[2]), size: -1 });
    }
  }
  return out;
}

// MCP attachment responses come back wrapped in `content`. Different MCP
// implementations use slightly different shapes — tolerate all the common ones.
function decodeAttachmentBlob(result) {
  const content = (result && result.content) || [];
  for (const c of content) {
    // Direct image content
    if (c.type === 'image' && typeof c.data === 'string') {
      return Buffer.from(c.data, 'base64');
    }
    // Resource wrapper: { type: 'resource', resource: { blob, mimeType, uri } }
    if (c.type === 'resource' && c.resource && typeof c.resource.blob === 'string') {
      return Buffer.from(c.resource.blob, 'base64');
    }
  }
  return null;
}

function chooseFilename(row, ext, fieldCounters, usedFilenames) {
  const guid8 = row.guid.replace(/-/g, '').slice(0, 8).toLowerCase();
  if (row.source === 'attachment') {
    const base = row.filename;
    if (!usedFilenames.has(base)) return base;
    const dot = base.lastIndexOf('.');
    const stem = dot >= 0 ? base.slice(0, dot) : base;
    const e = dot >= 0 ? base.slice(dot) : '';
    return `${stem}-${guid8}${e}`;
  }
  // embedded — sanitize field name
  const sanitized = row.source
    .replace(/^System\./, '')
    .replace(/^Microsoft\.VSTS\.Common\./, '')
    .replace(/^Microsoft\.VSTS\./, '')
    .replace(/^Custom\./, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  const next = (fieldCounters.get(sanitized) || 0) + 1;
  fieldCounters.set(sanitized, next);
  return `${sanitized}-${next}-${guid8}.${ext}`;
}

function writeImageIndex(specDir, rows, skipped = []) {
  const lines = [];
  lines.push(`# Images — ${rows.length} downloaded${skipped.length ? `, ${skipped.length} skipped` : ''}`);
  lines.push('');
  if (rows.length) {
    lines.push('| File | Source | Size | Type |');
    lines.push('| --- | --- | ---: | --- |');
    for (const r of rows) {
      lines.push(`| \`${r.file}\` | ${r.source} | ${r.size} | ${r.mime} |`);
    }
  } else {
    lines.push('_No images downloaded._');
  }
  if (skipped.length) {
    lines.push('');
    lines.push('## Skipped');
    for (const s of skipped) {
      lines.push(`- \`${s.filename}\` (guid \`${s.guid.slice(0, 8)}\`, source ${s.source}) — ${s.reason}`);
    }
  }
  fs.writeFileSync(path.join(specDir, 'images', 'INDEX.md'), lines.join('\n') + '\n');
}

// ------------------------------------------------------------------
// raw-story.md renderer
// ------------------------------------------------------------------

function renderRawStory({ wi, comments, parent, orgUrl, project, id, guidToPath, linked }) {
  const f = (wi && wi.fields) || {};
  const title = f['System.Title'] || '';
  const type = f['System.WorkItemType'] || '';
  const state = f['System.State'] || '';
  const priority = f['Microsoft.VSTS.Common.Priority'] != null ? String(f['Microsoft.VSTS.Common.Priority']) : '';
  const assignedRaw = f['System.AssignedTo'];
  const assigned = (assignedRaw && (assignedRaw.displayName || assignedRaw)) || 'Unassigned';
  const area = f['System.AreaPath'] || '';
  const iter = f['System.IterationPath'] || '';
  const tags = f['System.Tags'] || 'None';
  const desc = htmlToMarkdown(f['System.Description'] || '', guidToPath);
  const ac = htmlToMarkdown(f['Microsoft.VSTS.Common.AcceptanceCriteria'] || '', guidToPath);
  const benefits = htmlToMarkdown(f['Custom.BusinessBenefits'] || '', guidToPath);
  const designs = htmlToMarkdown(f['Custom.UIDesigns'] || '', guidToPath);

  const orgBase = orgUrl.replace(/\/+$/, '');
  const adoLink = `${orgBase}/${encodeURIComponent(project)}/_workitems/edit/${id}`;

  const out = [];
  out.push('---');
  out.push('provenance:');
  out.push('  agent: dx-req');
  out.push('  model: script');
  out.push(`  created: ${new Date().toISOString()}`);
  out.push('  confidence: high');
  out.push('  verified: false');
  out.push('---');
  out.push(`# ${title}`);
  out.push('');
  out.push(`**ADO:** [#${id}](${adoLink})`);
  out.push('');
  out.push(`**Type:** ${type} | **State:** ${state}${priority ? ` | **Priority:** ${priority}` : ''}`);
  out.push(`**Assigned To:** ${typeof assigned === 'string' ? assigned : (assigned.displayName || 'Unassigned')}`);
  out.push(`**Area Path:** ${area}`);
  out.push(`**Iteration Path:** ${iter}`);
  out.push(`**Tags:** ${tags}`);
  out.push('');
  out.push('---');

  if (desc)     pushSection(out, 'Description', desc);
  if (ac)       pushSection(out, 'Acceptance Criteria', ac);
  if (benefits) pushSection(out, 'Business Benefits', benefits);
  if (designs)  pushSection(out, 'UI Designs', designs);

  const branches = (linked && linked.branches) || extractBranches(wi, id);
  const prs = (linked && linked.prs) || [];
  if (branches.length || prs.length) {
    out.push('');
    out.push('---');
    out.push('');
    out.push('## Linked Development');
    if (branches.length) {
      out.push('### Branches');
      for (const b of branches) out.push(`- \`${b.branchName}\``);
    }
    if (prs.length) {
      if (branches.length) out.push('');
      out.push('### Pull Requests');
      for (const pr of prs) {
        const date = pr.createdDate ? pr.createdDate.split('T')[0] : '';
        out.push(
          `- **PR #${pr.id}:** ${pr.title} — **${pr.status}**` +
          ` | \`${pr.sourceBranch}\` → \`${pr.targetBranch}\`` +
          (date ? ` | ${date}` : '')
        );
      }
    }
  }

  const humanComments = (comments || []).filter(c => !isSystemComment(c));
  if (humanComments.length) {
    out.push('');
    out.push('---');
    out.push('');
    out.push('## Comments');
    for (const c of humanComments) {
      const author = (c.createdBy && (c.createdBy.displayName || c.createdBy.uniqueName)) || 'Unknown';
      const date = c.createdDate ? c.createdDate.split('T')[0] : '';
      out.push('');
      out.push(`### ${author}${date ? ` — ${date}` : ''}`);
      out.push(htmlToMarkdown(c.text, guidToPath));
    }
  }

  // Images section — table of contents pointing into images.md (model writes
  // that file in step 8e). Helps later phases discover images without
  // re-scanning the body.
  if (guidToPath && guidToPath.size) {
    out.push('');
    out.push('---');
    out.push('');
    out.push('## Images');
    out.push('<!-- Inline image references already appear in Description / AC / other HTML fields above. Structured descriptions live in ../images.md (written by Phase 1, vision pass). -->');
    for (const [, p] of guidToPath) {
      out.push(`- \`${p}\``);
    }
  }

  if (parent) {
    const pf = parent.fields || {};
    const pdesc = htmlToMarkdown(pf['System.Description'] || '', guidToPath);
    out.push('');
    out.push('---');
    out.push('');
    out.push('## Parent Feature Context');
    out.push(`**#${parent.id}: ${pf['System.Title'] || ''}**`);
    if (pdesc) {
      out.push('');
      out.push(pdesc);
    }
  }

  return out.join('\n').replace(/\n{3,}/g, '\n\n').trimEnd() + '\n';
}

function pushSection(out, heading, body) {
  out.push('');
  out.push(`## ${heading}`);
  out.push(body);
}

function parseCliArgs(argv) {
  const force = argv.includes('--force');
  const positional = argv.filter(a => !a.startsWith('--'));
  if (positional.length < 3) {
    return { error: 'Usage: fetch-raw-story.js [--force] <org-url> <project> <work-item-id> [<spec-dir>]' };
  }
  const [orgUrl, project, idStr, specDirArg] = positional;
  const id = Number(idStr);
  if (!Number.isInteger(id) || id <= 0) {
    return { error: 'ERROR: work-item-id must be a positive integer' };
  }
  const org = parseOrg(orgUrl);
  if (!org) {
    return { error: `ERROR: cannot extract org name from "${orgUrl}". Expected https://<org>.visualstudio.com/ or https://dev.azure.com/<org>/` };
  }
  return { opts: { org, orgUrl, project, id, specDirArg, force } };
}

if (require.main === module) {
  const parsed = parseCliArgs(process.argv.slice(2));
  if (parsed.error) {
    console.error(parsed.error);
    process.exit(2);
  }
  main(parsed.opts).catch(err => {
    console.error(`fetch-raw-story: ${err.message}`);
    process.exit(1);
  });
}

module.exports = {
  main,
  parseCliArgs,
  parseOrg,
  findParentId,
  extractSprint,
  isMatchingBranch,
  extractBranches,
  extractPRRefs,
  refNameToBranch,
  normalizePRStatus,
  collectLinkedDevelopment,
  isSystemComment,
  htmlToMarkdown,
  convertImg,
  decodeAttachmentBlob,
  chooseFilename,
  extractImageManifest,
  payloadUnchanged,
  removeStaleImages,
  renderRawStory,
};
