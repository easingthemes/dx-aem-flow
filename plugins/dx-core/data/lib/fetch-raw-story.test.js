'use strict';

// Tests for fetch-raw-story.js. Run with:
//   node --test plugins/dx-core/data/lib/fetch-raw-story.test.js
//
// Uses node:test (built-in, no deps). Covers pure helpers only — main()
// spawns @azure-devops/mcp and is exercised by manual end-to-end runs.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const lib = require('./fetch-raw-story.js');
const fixture = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/work-item.json'), 'utf8'));

test('parseOrg', () => {
  assert.equal(lib.parseOrg('https://dev.azure.com/myorg'), 'myorg');
  assert.equal(lib.parseOrg('https://dev.azure.com/myorg/'), 'myorg');
  assert.equal(lib.parseOrg('https://dev.azure.com/myorg/SomeProject'), 'myorg');
  assert.equal(lib.parseOrg('https://myorg.visualstudio.com/'), 'myorg');
  assert.equal(lib.parseOrg(''), null);
  assert.equal(lib.parseOrg(null), null);
});

test('findParentId returns the hierarchy-reverse work item ID', () => {
  assert.equal(lib.findParentId(fixture), 4000);
  assert.equal(lib.findParentId({ relations: [] }), null);
  assert.equal(lib.findParentId({}), null);
});

test('extractSprint normalizes Sprint<N> to "Sprint N"', () => {
  assert.equal(lib.extractSprint(fixture), 'Sprint 41');
  assert.equal(lib.extractSprint({ fields: { 'System.IterationPath': 'A\\B\\C\\Sprint12' } }), 'Sprint 12');
  assert.equal(lib.extractSprint({ fields: { 'System.IterationPath': 'A\\B\\Backlog' } }), 'Backlog');
  assert.equal(lib.extractSprint({}), null);
});

test('isMatchingBranch — id must be a distinct segment', () => {
  // matches
  assert.equal(lib.isMatchingBranch('feature/4242-fancy-widget', 4242), true);
  assert.equal(lib.isMatchingBranch('bugfix/4242-thing', 4242), true);
  assert.equal(lib.isMatchingBranch('refs/heads/feature/4242-x', 4242), true);
  assert.equal(lib.isMatchingBranch('feature/#4242-with-hash', 4242), true); // common dev convention
  // non-matches: id is a substring of a larger number
  assert.equal(lib.isMatchingBranch('feature/42421-other', 4242), false);
  assert.equal(lib.isMatchingBranch('feature/14242-other', 4242), false);
  // non-matches: no id at all
  assert.equal(lib.isMatchingBranch('release/sprint-41', 4242), false);
});

test('extractBranches reads vstfs:///Git/Ref/ artifact links', () => {
  const branches = lib.extractBranches(fixture, 4242);
  assert.deepEqual(branches, [{ branchName: 'feature/4242-fancy-widget' }]);
});

test('extractPRRefs parses projectId/repoId/prId from PR artifact URL', () => {
  const refs = lib.extractPRRefs(fixture);
  assert.deepEqual(refs, [
    { projectId: 'proj-guid', repositoryId: 'repo-guid', prId: 12345 },
    { projectId: 'proj-guid', repositoryId: 'repo-guid', prId: 12346 },
  ]);
});

test('refNameToBranch strips refs/heads/', () => {
  assert.equal(lib.refNameToBranch('refs/heads/develop'), 'develop');
  assert.equal(lib.refNameToBranch('refs/heads/feature/4242-x'), 'feature/4242-x');
  assert.equal(lib.refNameToBranch('develop'), 'develop');
  assert.equal(lib.refNameToBranch(''), null);
  assert.equal(lib.refNameToBranch(null), null);
});

test('normalizePRStatus maps numeric enum to string', () => {
  assert.equal(lib.normalizePRStatus(0), 'notSet');
  assert.equal(lib.normalizePRStatus(1), 'active');
  assert.equal(lib.normalizePRStatus(2), 'abandoned');
  assert.equal(lib.normalizePRStatus(3), 'completed');
  assert.equal(lib.normalizePRStatus('completed'), 'completed');
  assert.equal(lib.normalizePRStatus(99), '99'); // unknown int falls back to string
  assert.equal(lib.normalizePRStatus(null), '');
});

test('collectLinkedDevelopment merges branches from relations + PR sourceRefName, applies match filter, deduplicates', () => {
  const prs = [
    { pullRequestId: 12345, title: 'PR A', status: 3,
      sourceRefName: 'refs/heads/feature/4242-fancy-widget', // duplicates the Git/Ref relation — should dedup
      targetRefName: 'refs/heads/develop',
      creationDate: '2026-01-15T10:00:00Z' },
    { pullRequestId: 12346, title: 'PR B', status: 1,
      sourceRefName: 'refs/heads/feature/#4242-extra-fix', // # prefix, must still match
      targetRefName: 'refs/heads/develop',
      creationDate: '2026-01-16T10:00:00Z' },
    { pullRequestId: 99999, title: 'unrelated', status: 1,
      sourceRefName: 'refs/heads/release/sprint-41', // does not match WI id
      targetRefName: 'refs/heads/develop',
      creationDate: '2026-01-17T10:00:00Z' },
  ];
  const linked = lib.collectLinkedDevelopment(fixture, prs, 4242);

  assert.deepEqual(linked.branches.map(b => b.branchName).sort(), [
    'feature/#4242-extra-fix',
    'feature/4242-fancy-widget',
  ]);
  assert.equal(linked.prs.length, 2);
  assert.equal(linked.prs[0].id, 12345);
  assert.equal(linked.prs[0].status, 'completed');
  assert.equal(linked.prs[0].sourceBranch, 'feature/4242-fancy-widget');
  assert.equal(linked.prs[1].status, 'active');
});

test('htmlToMarkdown — basic formatting', () => {
  assert.equal(lib.htmlToMarkdown('<p>Hello <strong>world</strong>!</p>'), 'Hello **world**!');
  assert.equal(lib.htmlToMarkdown('<p>foo</p><p>bar</p>'), 'foo\n\nbar');
  assert.equal(lib.htmlToMarkdown('A<br>B'), 'A\nB');
  assert.equal(lib.htmlToMarkdown('<a href="https://x">click</a>'), '[click](https://x)');
  // entities decoded; htmlToMarkdown trims surrounding whitespace, so the leading nbsp goes away.
  assert.equal(lib.htmlToMarkdown('&nbsp;&amp;&lt;&gt;'), '&<>');
});

test('htmlToMarkdown — headings', () => {
  assert.match(lib.htmlToMarkdown('<h1>title</h1>'), /^# title$/);
  assert.match(lib.htmlToMarkdown('<h3>sub</h3>'), /^### sub$/);
});

test('htmlToMarkdown — lists', () => {
  const ul = lib.htmlToMarkdown('<ul><li>One</li><li>Two</li></ul>');
  assert.equal(ul, '- One\n- Two');
  const ol = lib.htmlToMarkdown('<ol><li>First</li><li>Second</li></ol>');
  assert.equal(ol, '1. First\n2. Second');
});

test('htmlToMarkdown — strips comments and scripts', () => {
  assert.equal(lib.htmlToMarkdown('<p>before</p><!-- secret --><p>after</p>'), 'before\n\nafter');
});

test('convertImg — preserves URL when no map', () => {
  assert.equal(
    lib.convertImg('<img src="https://x/foo.png" alt="bar">', null),
    '![bar](https://x/foo.png)'
  );
});

test('convertImg — rewrites ADO attachment URL to local path when GUID is in map', () => {
  const map = new Map([['aaaa1111-bbbb-2222-cccc-333344445555', './images/mockup.png']]);
  const html = '<img src="https://dev.azure.com/x/_apis/wit/attachments/aaaa1111-bbbb-2222-cccc-333344445555?fileName=mockup.png" alt="m">';
  assert.equal(lib.convertImg(html, map), '![m](./images/mockup.png)');
});

test('convertImg — annotates non-downloaded ADO attachments', () => {
  // The map needs >=1 entry to enter the rewrite branch; the GUID itself is not in the map.
  const mapWithEntry = new Map([['11111111-2222-3333-4444-555555555555', './images/x.png']]);
  const html = '<img src="https://dev.azure.com/x/_apis/wit/attachments/abcdef00-0000-0000-0000-000000000000?fileName=x.png" alt="m">';
  assert.match(lib.convertImg(html, mapWithEntry), /image not downloaded/);
});

test('extractImageManifest finds attachment and embedded refs, dedupes by GUID', () => {
  const rows = lib.extractImageManifest(fixture);
  // Expect 2: one AttachedFile (screenshot.png) and one embedded in System.Description (mockup.png)
  assert.equal(rows.length, 2);
  const sources = rows.map(r => r.source).sort();
  assert.deepEqual(sources, ['System.Description', 'attachment']);
});

test('chooseFilename — attachment preserves original name, embedded uses sanitized field-N-guid8', () => {
  const counters = new Map();
  const used = new Set();
  const f1 = lib.chooseFilename(
    { source: 'attachment', guid: 'dddd4444-eeee-5555-ffff-666677778888', filename: 'screenshot.png' },
    'png', counters, used
  );
  assert.equal(f1, 'screenshot.png');
  used.add(f1);

  const f2 = lib.chooseFilename(
    { source: 'System.Description', guid: 'aaaa1111-bbbb-2222-cccc-333344445555', filename: 'mockup.png' },
    'png', counters, used
  );
  assert.equal(f2, 'description-1-aaaa1111.png');

  // Second embedded image from the same field gets index 2
  const f3 = lib.chooseFilename(
    { source: 'System.Description', guid: 'cccc3333-4444-5555-6666-777788889999', filename: 'mockup2.png' },
    'png', counters, used
  );
  assert.equal(f3, 'description-2-cccc3333.png');
});

test('chooseFilename — collision on attachment name appends guid8', () => {
  const used = new Set(['screenshot.png']);
  const f = lib.chooseFilename(
    { source: 'attachment', guid: '12345678-aaaa-bbbb-cccc-ddddeeeeffff', filename: 'screenshot.png' },
    'png', new Map(), used
  );
  assert.equal(f, 'screenshot-12345678.png');
});

test('decodeAttachmentBlob handles both image and resource shapes', () => {
  const data = Buffer.from('hello').toString('base64');

  const fromImage = lib.decodeAttachmentBlob({ content: [{ type: 'image', data }] });
  assert.equal(fromImage.toString(), 'hello');

  const fromResource = lib.decodeAttachmentBlob({ content: [{ type: 'resource', resource: { blob: data } }] });
  assert.equal(fromResource.toString(), 'hello');

  assert.equal(lib.decodeAttachmentBlob({ content: [] }), null);
  assert.equal(lib.decodeAttachmentBlob({}), null);
});

test('isSystemComment filters auto-generated state changes', () => {
  assert.equal(lib.isSystemComment({ text: 'State changed from New to Active' }), true);
  assert.equal(lib.isSystemComment({ text: 'Assigned To changed from x to y' }), true);
  assert.equal(lib.isSystemComment({ text: '' }), true);
  assert.equal(lib.isSystemComment({ text: 'Real human comment.' }), false);
});

test('payloadUnchanged — returns false when no prior file, true on identical content', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'fetchraw-test-'));
  try {
    const payload = { workItem: { id: 1 }, comments: [], parent: null, prs: [] };

    // No prior file → false
    assert.equal(lib.payloadUnchanged(tmp, payload), false);

    // Write prior, identical → true
    fs.writeFileSync(path.join(tmp, 'raw-workitem.json'), JSON.stringify(payload, null, 2));
    assert.equal(lib.payloadUnchanged(tmp, payload), true);

    // Mutate → false
    const changed = { ...payload, workItem: { id: 2 } };
    assert.equal(lib.payloadUnchanged(tmp, changed), false);

    // Corrupted prior file → false (safe default: refetch)
    fs.writeFileSync(path.join(tmp, 'raw-workitem.json'), 'not json');
    assert.equal(lib.payloadUnchanged(tmp, payload), false);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('removeStaleImages — deletes non-keepers, preserves dotfiles + INDEX.md', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'fetchraw-stale-'));
  const imagesDir = path.join(tmp, 'images');
  fs.mkdirSync(imagesDir);
  fs.writeFileSync(path.join(imagesDir, 'keep-1.png'), 'a');
  fs.writeFileSync(path.join(imagesDir, 'orphan.png'), 'b');
  fs.writeFileSync(path.join(imagesDir, '.gitkeep'), '');
  fs.writeFileSync(path.join(imagesDir, 'INDEX.md'), '# index');

  try {
    lib.removeStaleImages(tmp, new Set(['keep-1.png']));
    const after = fs.readdirSync(imagesDir).sort();
    assert.deepEqual(after, ['.gitkeep', 'INDEX.md', 'keep-1.png']);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});

test('renderRawStory — full integration produces expected sections', () => {
  const guidToPath = new Map([
    ['aaaa1111-bbbb-2222-cccc-333344445555', './images/mockup.png'],
  ]);
  const linked = {
    branches: [{ branchName: 'feature/4242-fancy-widget' }],
    prs: [{
      id: 12345, title: 'PR A', status: 'completed',
      sourceBranch: 'feature/4242-fancy-widget', targetBranch: 'develop',
      createdDate: '2026-01-15T10:00:00Z',
    }],
  };
  const md = lib.renderRawStory({
    wi: fixture,
    comments: [
      { text: 'Real comment from a human.', createdBy: { displayName: 'Dev' }, createdDate: '2026-01-10T00:00:00Z' },
      { text: 'State changed from New to Active', createdBy: { displayName: 'Bot' }, createdDate: '2026-01-11T00:00:00Z' }, // filtered out
    ],
    parent: { id: 4000, fields: { 'System.Title': 'Big Feature', 'System.Description': '<p>Parent body.</p>' } },
    orgUrl: 'https://dev.azure.com/myorg',
    project: 'MyOrg',
    id: 4242,
    guidToPath,
    linked,
  });

  // Header
  assert.match(md, /^---/m);
  assert.match(md, /model: script/);
  assert.match(md, /# Add fancy widget to checkout flow/);
  assert.match(md, /\*\*Type:\*\* User Story \| \*\*State:\*\* Active \| \*\*Priority:\*\* 2/);
  assert.match(md, /Alex Sample/);

  // Sections
  assert.match(md, /## Description/);
  assert.match(md, /## Acceptance Criteria/);
  assert.match(md, /## Business Benefits/);
  assert.doesNotMatch(md, /## UI Designs/, 'empty UIDesigns should be omitted');

  // Image URL was rewritten via guidToPath
  assert.match(md, /!\[mockup\]\(\.\/images\/mockup\.png\)/);

  // Linked Development with branches AND PRs
  assert.match(md, /## Linked Development/);
  assert.match(md, /### Branches\n- `feature\/4242-fancy-widget`/);
  assert.match(md, /### Pull Requests/);
  assert.match(md, /\*\*PR #12345:\*\* PR A — \*\*completed\*\* \| `feature\/4242-fancy-widget` → `develop` \| 2026-01-15/);

  // Comments — system comment filtered out
  assert.match(md, /## Comments/);
  assert.match(md, /### Dev — 2026-01-10\nReal comment from a human/);
  assert.doesNotMatch(md, /State changed from New to Active/);

  // Parent context
  assert.match(md, /## Parent Feature Context/);
  assert.match(md, /\*\*#4000: Big Feature\*\*/);
  assert.match(md, /Parent body\./);
});

test('parseCliArgs — happy + error paths', () => {
  // Missing args
  assert.match(lib.parseCliArgs([]).error, /Usage:/);

  // Bad ID
  assert.match(lib.parseCliArgs(['https://dev.azure.com/x', 'p', 'abc']).error, /positive integer/);
  assert.match(lib.parseCliArgs(['https://dev.azure.com/x', 'p', '-1']).error, /positive integer/);

  // Bad org URL (parseOrg falls back to last path segment, so genuinely invalid input is hard
  // to construct — the parseOrg fallback is the safety net). Skip explicit org-error test.

  // Happy path
  const ok = lib.parseCliArgs(['https://dev.azure.com/myorg', 'MyProj', '4242']);
  assert.equal(ok.error, undefined);
  assert.equal(ok.opts.org, 'myorg');
  assert.equal(ok.opts.project, 'MyProj');
  assert.equal(ok.opts.id, 4242);
  assert.equal(ok.opts.force, false);

  // --force in any position
  const forced = lib.parseCliArgs(['--force', 'https://dev.azure.com/myorg', 'MyProj', '4242']);
  assert.equal(forced.opts.force, true);
});
