'use strict';

/**
 * cli/lib/detect.js — git/SCM detection and project-type detection.
 * Hermetic: temp repos only, no network (see helpers.js).
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const { detectGitEnv, detectProject } = require('../lib/detect');
const { tmpDir, rm, makeRepo, write, PLUGINS_DIR } = require('./helpers');

// --- detectGitEnv ----------------------------------------------------------

test('detects an ADO visualstudio.com remote, org and project', () => {
  const root = tmpDir();
  try {
    const repo = makeRepo(root, 'app', {
      remote: 'https://myorg.visualstudio.com/MyProject/_git/MyRepo',
      remoteBranches: ['develop'],
    });
    const env = detectGitEnv(repo);
    assert.equal(env.scmProvider, 'ado');
    assert.equal(env.adoOrg, 'myorg');
    assert.equal(env.adoProject, 'MyProject');
    assert.equal(env.baseBranch, 'develop');
  } finally {
    rm(root);
  }
});

test('detects an ADO dev.azure.com remote, org and project', () => {
  const root = tmpDir();
  try {
    const repo = makeRepo(root, 'app', {
      remote: 'https://dev.azure.com/myorg/MyProject/_git/MyRepo',
      remoteBranches: ['main'],
    });
    const env = detectGitEnv(repo);
    assert.equal(env.scmProvider, 'ado');
    assert.equal(env.adoOrg, 'myorg');
    assert.equal(env.adoProject, 'MyProject');
  } finally {
    rm(root);
  }
});

test('reports a GitHub remote as github and extracts no ADO org', () => {
  // github is detected only so the caller can warn — no skill supports it.
  const root = tmpDir();
  try {
    const repo = makeRepo(root, 'app', {
      remote: 'https://github.com/owner/repo.git',
      remoteBranches: ['main'],
    });
    const env = detectGitEnv(repo);
    assert.equal(env.scmProvider, 'github');
    assert.equal(env.adoOrg, '');
    assert.equal(env.adoProject, '');
  } finally {
    rm(root);
  }
});

test('reports an unrecognised remote host as unknown', () => {
  const root = tmpDir();
  try {
    const repo = makeRepo(root, 'app', { remote: 'https://git.example.com/owner/repo.git' });
    assert.equal(detectGitEnv(repo).scmProvider, 'unknown');
  } finally {
    rm(root);
  }
});

test('falls back to "development" when no base branch can be found', () => {
  const root = tmpDir();
  try {
    const repo = makeRepo(root, 'app', { remote: 'https://dev.azure.com/o/p/_git/r' });
    assert.equal(detectGitEnv(repo).baseBranch, 'development');
  } finally {
    rm(root);
  }
});

test('prefers a known base branch name over an unrelated remote branch', () => {
  const root = tmpDir();
  try {
    const repo = makeRepo(root, 'app', {
      remote: 'https://dev.azure.com/o/p/_git/r',
      remoteBranches: ['feature/x', 'development'],
    });
    assert.equal(detectGitEnv(repo).baseBranch, 'development');
  } finally {
    rm(root);
  }
});

test('lists sibling git repos but never the repo itself', () => {
  const root = tmpDir();
  try {
    const repo = makeRepo(root, 'app', { remote: 'https://dev.azure.com/o/p/_git/r' });
    makeRepo(root, 'backend');
    makeRepo(root, 'config');
    require('fs').mkdirSync(require('path').join(root, 'not-a-repo'));

    const siblings = detectGitEnv(repo).siblings.sort();
    assert.deepEqual(siblings, ['backend', 'config']);
  } finally {
    rm(root);
  }
});

test('survives a directory that is not a git repo at all', () => {
  const root = tmpDir();
  try {
    const env = detectGitEnv(root);
    assert.equal(env.remoteUrl, '');
    assert.equal(env.scmProvider, 'unknown');
    assert.equal(env.baseBranch, 'development');
  } finally {
    rm(root);
  }
});

// --- detectProject ---------------------------------------------------------

test('detects a node frontend project and reads its scripts', () => {
  const root = tmpDir();
  try {
    write(root, 'package.json', JSON.stringify({
      name: 'my-frontend',
      scripts: { build: 'vite build', test: 'vitest', lint: 'eslint .' },
    }));
    const p = detectProject(root);
    assert.equal(p.projectType, 'frontend');
    assert.equal(p.projectName, 'my-frontend');
    assert.equal(p.buildCommand, 'npm run build');
    assert.equal(p.testCommand, 'npm test');
    assert.equal(p.lintCommand, 'npm run lint');
    assert.equal(p.isAem, false);
  } finally {
    rm(root);
  }
});

test('leaves build/test/lint empty when package.json declares no such scripts', () => {
  const root = tmpDir();
  try {
    write(root, 'package.json', JSON.stringify({ name: 'bare', scripts: {} }));
    const p = detectProject(root);
    assert.equal(p.buildCommand, '');
    assert.equal(p.testCommand, '');
    assert.equal(p.lintCommand, '');
  } finally {
    rm(root);
  }
});

test('detects a plain maven project', () => {
  const root = tmpDir();
  try {
    write(root, 'pom.xml', '<project><artifactId>my-service</artifactId></project>');
    const p = detectProject(root);
    assert.equal(p.projectType, 'java');
    assert.equal(p.projectName, 'my-service');
    assert.equal(p.buildCommand, 'mvn clean install');
  } finally {
    rm(root);
  }
});

test('reads the top-level artifactId, not the one inside <parent>', () => {
  const root = tmpDir();
  try {
    write(root, 'pom.xml', [
      '<project>',
      '  <parent><artifactId>parent-pom</artifactId></parent>',
      '  <artifactId>child-module</artifactId>',
      '</project>',
    ].join('\n'));
    assert.equal(detectProject(root).projectName, 'child-module');
  } finally {
    rm(root);
  }
});

test('detects an AEM fullstack project from jcr_root plus core/', () => {
  const root = tmpDir();
  try {
    write(root, 'pom.xml', '<project><artifactId>my-aem</artifactId></project>');
    write(root, 'ui.apps/src/main/content/jcr_root/apps/mybrand/components/.keep');
    write(root, 'core/src/main/java/.keep');
    const p = detectProject(root);
    assert.equal(p.isAem, true);
    assert.equal(p.projectType, 'aem-fullstack');
    assert.equal(p.projectPrefix, 'mybrand-');
    assert.match(p.buildCommand, /autoInstallPackage/);
    assert.match(p.deployCommand, /-DskipTests/);
  } finally {
    rm(root);
  }
});

test('detects an AEM frontend-only project and picks up its lint script', () => {
  const root = tmpDir();
  try {
    write(root, 'pom.xml', '<project><artifactId>my-aem-fe</artifactId></project>');
    write(root, 'ui.apps/src/main/content/jcr_root/apps/mybrand/components/.keep');
    write(root, 'ui.frontend/package.json', JSON.stringify({ scripts: { lint: 'eslint src' } }));
    const p = detectProject(root);
    assert.equal(p.projectType, 'aem-frontend');
    assert.equal(p.frontendDir, 'ui.frontend/');
    assert.equal(p.lintCommand, 'cd ui.frontend/ && npm run lint');
  } finally {
    rm(root);
  }
});

test('prefers lintcheck over lint for AEM frontends', () => {
  const root = tmpDir();
  try {
    write(root, 'pom.xml', '<project><artifactId>a</artifactId></project>');
    write(root, 'ui.apps/src/main/content/jcr_root/apps/b/.keep');
    write(root, 'ui.frontend/package.json', JSON.stringify({
      scripts: { lint: 'eslint src', lintcheck: 'npm run lint -- --max-warnings 0' },
    }));
    assert.equal(detectProject(root).lintCommand, 'cd ui.frontend/ && npm run lintcheck');
  } finally {
    rm(root);
  }
});

test('detects rust and go projects', () => {
  const rust = tmpDir();
  const go = tmpDir();
  try {
    write(rust, 'Cargo.toml', '[package]\nname = "x"\n');
    assert.equal(detectProject(rust).projectType, 'rust');
    write(go, 'go.mod', 'module example.com/x\n');
    assert.equal(detectProject(go).projectType, 'go');
  } finally {
    rm(rust);
    rm(go);
  }
});

test('falls back to unknown and the directory name for an empty project', () => {
  const root = tmpDir();
  try {
    const p = detectProject(root);
    assert.equal(p.projectType, 'unknown');
    assert.equal(p.projectName, require('path').basename(root));
    assert.equal(p.buildCommand, '');
  } finally {
    rm(root);
  }
});

test('tolerates malformed package.json instead of throwing', () => {
  const root = tmpDir();
  try {
    write(root, 'package.json', '{not json');
    const p = detectProject(root);
    assert.equal(p.projectType, 'frontend');
    assert.equal(p.projectName, require('path').basename(root));
  } finally {
    rm(root);
  }
});

test('the plugins directory the suites scaffold from exists', () => {
  assert.ok(require('fs').existsSync(PLUGINS_DIR), `missing ${PLUGINS_DIR}`);
});
