'use strict';

/**
 * Hermetic fixtures for the dx-scaffold suites.
 *
 * No network, no ambient git config: every repo gets GIT_CONFIG_GLOBAL=/dev/null,
 * its own user.name/user.email, and an unroutable http.proxy so that the
 * `git remote set-head origin --auto` probe inside detectGitEnv() fails instantly
 * instead of dialling out to a real ADO or GitHub host.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const GIT_ENV = {
  ...process.env,
  GIT_CONFIG_GLOBAL: '/dev/null',
  GIT_CONFIG_SYSTEM: '/dev/null',
  GIT_TERMINAL_PROMPT: '0',
  HOME: os.tmpdir(),
};

function git(cwd, ...args) {
  execFileSync('git', args, { cwd, env: GIT_ENV, stdio: 'pipe' });
}

/** Create an isolated temp directory, registered for cleanup by the caller. */
function tmpDir(prefix = 'dx-scaffold-test-') {
  return fs.mkdtempSync(path.join(os.tmpdir(), prefix));
}

function rm(dir) {
  fs.rmSync(dir, { recursive: true, force: true });
}

/**
 * Create a git repo at <root>/<name> with an optional origin remote and
 * remote-tracking branches. Returns the repo path.
 */
function makeRepo(root, name, { remote, remoteBranches = [] } = {}) {
  const repo = path.join(root, name);
  fs.mkdirSync(repo, { recursive: true });
  git(repo, 'init', '-q', '.');
  git(repo, 'config', 'user.email', 'test@example.com');
  git(repo, 'config', 'user.name', 'Test');
  // Unroutable proxy — keeps the set-head probe offline and instant.
  git(repo, 'config', 'http.proxy', 'http://127.0.0.1:1');
  git(repo, 'commit', '-q', '--allow-empty', '-m', 'init');
  if (remote) git(repo, 'remote', 'add', 'origin', remote);
  for (const branch of remoteBranches) {
    git(repo, 'update-ref', `refs/remotes/origin/${branch}`, 'HEAD');
  }
  return repo;
}

function write(repo, relPath, content = '') {
  const full = path.join(repo, relPath);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, content);
  return full;
}

function read(repo, relPath) {
  return fs.readFileSync(path.join(repo, relPath), 'utf8');
}

function exists(repo, relPath) {
  return fs.existsSync(path.join(repo, relPath));
}

const PLUGINS_DIR = path.resolve(__dirname, '..', '..', 'plugins');

module.exports = { tmpDir, rm, makeRepo, write, read, exists, PLUGINS_DIR };
