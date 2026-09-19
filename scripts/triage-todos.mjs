#!/usr/bin/env node
// triage-todos.mjs — Group open TODOs by consumer blast radius.
//
// Reads docs/todo/TODO.md, follows each open row to its detail section, and
// classifies it from the paths named in that section's `Scope:` line — the same
// A/B split scripts/check-tier.sh applies to a diff, applied here to planned work.
//
// WHAT THIS IS NOT: a decision. It reads prose written by humans, so it is a
// first pass that needs a human eye. Known misfiles at the time of writing: #113
// and #57 land in A because their Scope names docs, but both end up editing
// shipped plugin content. Treat the output as a worklist to review, never as a
// label to apply unread.
//
// Usage:
//   node scripts/triage-todos.mjs           # grouped worklist
//   node scripts/triage-todos.mjs --gaps    # only the rows that cannot be classified
//   node scripts/triage-todos.mjs --json    # machine-readable

import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const TODO_DIR = join(ROOT, 'docs/todo');

const args = new Set(process.argv.slice(2));
const ONLY_GAPS = args.has('--gaps');
const AS_JSON = args.has('--json');

// Must match GitHub's heading-anchor algorithm, not a generic slugifier: GitHub
// DROPS punctuation rather than replacing it, so `validate-skills.sh` anchors as
// "validate-skillssh", not "validate-skills-sh". Getting this wrong silently reports
// every row whose heading contains a backtick or a dot as "no Scope:" — it scored 79
// false gaps before this was fixed.
//
// GitHub also does NOT collapse runs of spaces: "a — b" anchors as "a--b", because
// the em-dash is dropped and each surrounding space becomes its own hyphen. Collapse
// them and every heading with a dash reads as a gap.
const slug = (s) =>
  s.trim().toLowerCase()
    .replace(/[^\p{L}\p{N} _-]/gu, '')
    .replace(/[ _]/g, '-');

// Every `## Heading` in every detail file -> that section's Scope line.
const scopes = new Map();
for (const file of readdirSync(TODO_DIR).filter((f) => /^todo-.*\.md$/.test(f))) {
  let key = null;
  let scope = '';
  for (const line of readFileSync(join(TODO_DIR, file), 'utf8').split('\n')) {
    if (line.startsWith('## ')) {
      if (key) scopes.set(key, scope);
      key = slug(line.slice(3));
      scope = '';
    } else if (key && line.startsWith('**Scope:**')) {
      scope += ' ' + line;
    }
  }
  if (key) scopes.set(key, scope);
}

// Same path rule as scripts/check-tier.sh. Kept in sync by hand; if they drift, the
// script is the authority for a diff and this is only ever advisory.
const SHIPS = /plugins\/[^/\s`]*\/(skills|agents|rules|templates|data|hooks)\/|SKILL\.md|plugin\.json|marketplace\.json|\.mcp\.json|config\.yaml\.template/;
const INERT = /(^|\/)(__tests__|tests|evals)\/|\.test\.(js|sh)$|run-tests\.sh$/;
// Work that cannot be verified without a live external system, whatever it edits.
const EXTERNAL = /\b(ado|aem|copilot|figma|jira|pipeline|lambda|consumer project|live probe|interactive session)\b/i;

const OPEN = /^(open|ready|actionable|reopened|pending|ongoing|decision needed)/i;

const rows = [];
const gaps = [];
const ROW = /^\|\s*(\d+)\s*\|\s*(.+?)\s*\|\s*(\w+)\s*\|\s*(.+?)\s*\|\s*([\d-]+)\s*\|\s*(.*?)\s*\|\s*$/;

for (const line of readFileSync(join(TODO_DIR, 'TODO.md'), 'utf8').split('\n')) {
  const m = ROW.exec(line);
  if (!m) continue;
  const [, n, title, prio, statusRaw, , detail] = m;
  const status = statusRaw.replace(/\*|~/g, '').trim();
  if (!OPEN.test(status)) continue;

  const link = /\]\(todo-[^)#]*#([a-z0-9-]+)\)/.exec(detail);
  const scope = link ? (scopes.get(link[1]) ?? '') : '';
  const item = { n: Number(n), title, priority: prio, status };

  if (!scope.trim()) {
    gaps.push({ ...item, reason: link ? 'detail section has no Scope: line' : 'row links to no detail section' });
    continue;
  }

  const paths = (scope.match(/`[^`]+`/g) ?? []).join(' ');
  const shipsPath = SHIPS.test(paths) && !paths.split(/\s+/).every((p) => INERT.test(p));
  const external = EXTERNAL.test(title + ' ' + detail);

  item.tier = external ? 'C' : shipsPath ? 'B' : 'A';
  rows.push(item);
}

if (AS_JSON) {
  console.log(JSON.stringify({ classified: rows, unclassifiable: gaps }, null, 2));
  process.exit(0);
}

const LABELS = {
  A: 'Tier A — inert. Safe to hand to an outside contributor.',
  B: 'Tier B — edits shipped plugin content. Needs a real consumer project.',
  C: 'Tier C — needs a live ADO / AEM / Copilot CLI / Figma / pipeline.',
};

if (!ONLY_GAPS) {
  for (const tier of ['A', 'B', 'C']) {
    const group = rows.filter((r) => r.tier === tier).sort((a, b) => a.n - b.n);
    console.log(`\n### ${LABELS[tier]}  (${group.length})`);
    for (const r of group) {
      console.log(`  #${String(r.n).padStart(3)} [${r.priority.padStart(6)}] ${r.title.slice(0, 74)}`);
    }
  }
}

console.log(`\n### Cannot be classified — no usable Scope:  (${gaps.length})`);
for (const g of gaps.sort((a, b) => a.n - b.n)) {
  console.log(`  #${String(g.n).padStart(3)} [${g.priority.padStart(6)}] ${g.title.slice(0, 56)} — ${g.reason}`);
}

const total = rows.length + gaps.length;
console.log(`\n${rows.length} of ${total} open items classified; ${gaps.length} need a Scope: line first.`);
console.log('Backfilling those is Tier A work and unblocks the rest — CONTRIBUTING.md § 9.');
console.log('\nThis is a first pass over prose, not a verdict. Review before labelling.');
