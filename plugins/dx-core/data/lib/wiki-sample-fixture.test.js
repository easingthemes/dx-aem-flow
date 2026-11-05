'use strict';

// Integrity checks for fixtures/wiki-sample/ (TODO-258). Run with:
//   node --test plugins/dx-core/data/lib/wiki-sample-fixture.test.js
//
// The fixture is ground truth for a future wiki indexer/search. If it drifts
// (a page renamed but not in expected-map.json, a question pointing at a
// missing page), every recall number computed on it is wrong without anyone
// noticing. These tests keep the three files consistent with the wiki tree.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, 'fixtures', 'wiki-sample');
const WIKI = path.join(ROOT, 'wiki');
const readJson = (f) => JSON.parse(fs.readFileSync(path.join(ROOT, f), 'utf8'));

// Walk an ADO-wiki-git layout: <dir>/.order lists child pages; each page is
// <name>.md, and a page with children also has a <name>/ folder.
function walk(dir = WIKI, prefix = '') {
  const order = fs.readFileSync(path.join(dir, '.order'), 'utf8').split('\n').filter(Boolean);
  const pages = [];
  for (const name of order) {
    const id = prefix ? `${prefix}/${name}` : name;
    pages.push(id);
    const sub = path.join(dir, name);
    if (fs.existsSync(sub)) pages.push(...walk(sub, id));
  }
  return pages;
}

function allMarkdown(dir = WIKI, prefix = '') {
  const out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const id = prefix ? `${prefix}/${e.name}` : e.name;
    if (e.isDirectory()) out.push(...allMarkdown(path.join(dir, e.name), id));
    else if (e.name.endsWith('.md')) out.push(id.slice(0, -3));
  }
  return out;
}

const pages = walk();
const map = readJson('expected-map.json').pages;
const { questions } = readJson('questions.json');

test('every .order entry has a page file and every page file is ordered', () => {
  for (const id of pages) assert.ok(fs.existsSync(path.join(WIKI, `${id}.md`)), `missing ${id}.md`);
  assert.deepEqual([...allMarkdown()].sort(), [...pages].sort());
});

test('a child folder exists only for a page that has a .md file', () => {
  for (const id of pages) {
    const dir = path.join(WIKI, id);
    if (fs.existsSync(dir)) assert.ok(fs.existsSync(path.join(dir, '.order')), `${id}/ has no .order`);
  }
});

test('every page has a ## heading to chunk on', () => {
  for (const id of pages) {
    const md = fs.readFileSync(path.join(WIKI, `${id}.md`), 'utf8');
    // parent landing pages may be a single intro paragraph
    if (fs.existsSync(path.join(WIKI, id))) continue;
    assert.match(md, /^## /m, `${id} has no ## section`);
  }
});

test('expected-map covers exactly the pages in the tree', () => {
  assert.deepEqual(Object.keys(map).sort(), [...pages].sort());
});

test('expected-map tags use the allowed values', () => {
  const markets = ['mine', 'global', ...readJson('config.json').markets.others.map((m) => `other:${m.name}`)];
  for (const [id, t] of Object.entries(map)) {
    assert.ok(['ours', 'other-stack', 'general'].includes(t.platform), `${id} platform=${t.platform}`);
    assert.ok(markets.includes(t.market), `${id} market=${t.market}`);
  }
});

test('override pages really differ from what plain inheritance would give', () => {
  // Root pages inherit {general, global}; children inherit their parent.
  const overrides = Object.entries(map).filter(([, t]) => t.override);
  assert.ok(overrides.length >= 3, 'fixture must keep at least 3 override cases');
  for (const [id, t] of overrides) {
    const parent = id.includes('/') ? map[id.slice(0, id.lastIndexOf('/'))] : { platform: 'general', market: 'global' };
    assert.ok(t.platform !== parent.platform || t.market !== parent.market, `${id} is flagged override but matches its parent`);
  }
});

test('questions reference existing pages and distractors are out of scope', () => {
  const ids = new Set();
  for (const q of questions) {
    assert.ok(!ids.has(q.id), `duplicate ${q.id}`);
    ids.add(q.id);
    assert.ok(q.relevant.length > 0, `${q.id} has no relevant page`);
    for (const p of q.relevant) {
      assert.ok(map[p], `${q.id} relevant page ${p} not in map`);
      assert.notEqual(map[p].platform, 'other-stack', `${q.id} relevant page ${p} is other-stack`);
    }
    for (const p of q.must_not || []) {
      assert.ok(map[p], `${q.id} must_not page ${p} not in map`);
      assert.equal(map[p].platform, 'other-stack', `${q.id} must_not page ${p} should be other-stack`);
    }
  }
});

test('question set covers every hard case kind', () => {
  const kinds = new Set(questions.map((q) => q.kind));
  for (const k of ['keyword', 'synonym', 'language', 'cross-market']) assert.ok(kinds.has(k), `no ${k} question`);
  assert.ok(questions.length >= 15, 'keep at least 15 questions');
});
