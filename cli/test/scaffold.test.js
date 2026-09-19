'use strict';

/**
 * cli/lib/scaffold.js — template substitution, file layout, overwrite rules.
 * Hermetic: writes into temp dirs and reads templates from the repo's own plugins/.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const { Scaffold } = require('../lib/scaffold');
const { tmpDir, rm, read, exists, PLUGINS_DIR } = require('./helpers');

const BASE_PLACEHOLDERS = {
  PROJECT_NAME: 'My Project',
  PROJECT_PREFIX: 'myproj',
  SCM_ORG: 'myorg',
  SCM_PROJECT: 'My ADO Project',
  SCM_REPO_ID: 'TODO-repo-guid',
  BASE_BRANCH: 'develop',
  BUILD_COMMAND: 'mvn clean install',
  DEPLOY_COMMAND: 'mvn clean install -DskipTests',
  TEST_COMMAND: 'mvn test',
  projectType: 'aem-fullstack',
};

function scaffold(target, { placeholders = {}, ...options } = {}) {
  const s = new Scaffold(target, PLUGINS_DIR, { quiet: true, ...options });
  s.setPlaceholders({ ...BASE_PLACEHOLDERS, ...placeholders });
  return s;
}

/** Every generated file except .ai/templates/, whose placeholders are filled at run time. */
function generatedFiles(root) {
  const out = [];
  (function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      const rel = path.relative(root, full);
      if (rel.startsWith(path.join('.ai', 'templates'))) continue;
      if (entry.isDirectory()) walk(full);
      else out.push(rel);
    }
  })(root);
  return out;
}

// --- Template substitution -------------------------------------------------

test('substitutes every init-time placeholder — no {{TOKEN}} survives', () => {
  const root = tmpDir();
  try {
    scaffold(root).run();
    const leftovers = [];
    for (const rel of generatedFiles(root)) {
      const content = fs.readFileSync(path.join(root, rel), 'utf8');
      const match = content.match(/\{\{[A-Z0-9_]+\}\}/);
      if (match) leftovers.push(`${rel}: ${match[0]}`);
    }
    assert.deepEqual(leftovers, []);
  } finally {
    rm(root);
  }
});

test('writes the detected values into .ai/config.yaml', () => {
  const root = tmpDir();
  try {
    scaffold(root).run();
    const config = read(root, '.ai/config.yaml');
    assert.match(config, /name: "My Project"/);
    assert.match(config, /base-branch: "develop"/);
    assert.match(config, /command: "mvn clean install"/);
  } finally {
    rm(root);
  }
});

test('derives project role from project type', () => {
  for (const [type, role] of [
    ['aem-fullstack', 'fullstack'],
    ['aem-frontend', 'frontend'],
    ['frontend', 'frontend'],
    ['java', 'backend'],
    ['rust', 'fullstack'], // unmapped types fall back
  ]) {
    const root = tmpDir();
    try {
      scaffold(root, { placeholders: { projectType: type } }).run();
      const config = read(root, '.ai/config.yaml');
      assert.match(config, new RegExp(`type: "${type}"`), `type for ${type}`);
      assert.match(config, new RegExp(`role: "${role}"`), `role for ${type}`);
    } finally {
      rm(root);
    }
  }
});

test('an explicit PROJECT_ROLE is not overwritten by the derived one', () => {
  const root = tmpDir();
  try {
    scaffold(root, { placeholders: { projectType: 'java', PROJECT_ROLE: 'config' } }).run();
    assert.match(read(root, '.ai/config.yaml'), /role: "config"/);
  } finally {
    rm(root);
  }
});

// --- .mcp.json -------------------------------------------------------------

test('registers the ADO MCP server with the detected org', () => {
  const root = tmpDir();
  try {
    scaffold(root, { placeholders: { scmProvider: 'ado' } }).run();
    const mcp = JSON.parse(read(root, '.mcp.json'));
    assert.deepEqual(mcp.mcpServers.ado.args, ['-y', '@azure-devops/mcp', 'myorg']);
    assert.ok(mcp.mcpServers.context7, 'context7 should always be registered');
  } finally {
    rm(root);
  }
});

test('omits the ADO MCP server when there is no ADO org to point it at', () => {
  const root = tmpDir();
  try {
    scaffold(root, { placeholders: { scmProvider: 'github', SCM_ORG: '' } }).run();
    const mcp = JSON.parse(read(root, '.mcp.json'));
    assert.equal(mcp.mcpServers.ado, undefined);
    assert.ok(mcp.mcpServers.context7);
  } finally {
    rm(root);
  }
});

// --- Layout ----------------------------------------------------------------

test('always generates the cross-tool agent files, with or without --copilot', () => {
  for (const copilot of [false, true]) {
    const root = tmpDir();
    try {
      scaffold(root, { copilot }).run();
      assert.ok(exists(root, 'AGENTS.md'), `AGENTS.md (copilot=${copilot})`);
      assert.ok(fs.readdirSync(path.join(root, '.github/agents')).length > 0,
        `.github/agents populated (copilot=${copilot})`);
      // Copilot-only extras follow the flag.
      assert.equal(exists(root, '.github/copilot-instructions.md'), copilot);
    } finally {
      rm(root);
    }
  }
});

test('--aem adds the project seed data, plain runs do not', () => {
  const withAem = tmpDir();
  const withoutAem = tmpDir();
  try {
    scaffold(withAem, { aem: true }).run();
    assert.ok(exists(withAem, '.ai/project/component-index.md'));
    assert.ok(exists(withAem, '.ai/project/file-patterns.yaml'));

    scaffold(withoutAem).run();
    assert.equal(exists(withoutAem, '.ai/project'), false);
  } finally {
    rm(withAem);
    rm(withoutAem);
  }
});

test('creates the core directory structure', () => {
  const root = tmpDir();
  try {
    scaffold(root).run();
    for (const dir of ['.ai/specs', '.ai/rules', '.ai/lib', '.claude/rules', '.claude/hooks']) {
      assert.ok(exists(root, dir), `missing ${dir}`);
    }
  } finally {
    rm(root);
  }
});

test('adds .ai entries to .gitignore without dropping existing ones', () => {
  const root = tmpDir();
  try {
    fs.writeFileSync(path.join(root, '.gitignore'), 'node_modules/\ntarget/\n');
    scaffold(root).run();
    const ignore = read(root, '.gitignore');
    assert.match(ignore, /node_modules\//);
    assert.match(ignore, /target\//);
    assert.match(ignore, /\.ai\//);
  } finally {
    rm(root);
  }
});

// --- Overwrite rules -------------------------------------------------------

test('leaves existing files alone and counts them as skipped', () => {
  const root = tmpDir();
  try {
    const first = scaffold(root);
    const firstStats = first.run();
    assert.ok(firstStats.installed > 0);

    fs.writeFileSync(path.join(root, '.ai/config.yaml'), 'hand-edited\n');
    const second = scaffold(root);
    const secondStats = second.run();

    assert.equal(read(root, '.ai/config.yaml'), 'hand-edited\n');
    assert.equal(secondStats.installed, 0, 'a second run should install nothing');
    assert.ok(secondStats.skipped > 0);
  } finally {
    rm(root);
  }
});

test('--force overwrites a hand-edited file', () => {
  const root = tmpDir();
  try {
    scaffold(root).run();
    fs.writeFileSync(path.join(root, '.ai/config.yaml'), 'hand-edited\n');
    scaffold(root, { force: true }).run();
    assert.match(read(root, '.ai/config.yaml'), /name: "My Project"/);
  } finally {
    rm(root);
  }
});

test('a missing template degrades to an empty file instead of throwing', () => {
  const root = tmpDir();
  const emptyPlugins = tmpDir();
  try {
    const s = new Scaffold(root, emptyPlugins, { quiet: true });
    s.setPlaceholders(BASE_PLACEHOLDERS);
    s.run();
    assert.equal(read(root, '.ai/config.yaml'), '');
  } finally {
    rm(root);
    rm(emptyPlugins);
  }
});
