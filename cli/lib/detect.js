'use strict';

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

/**
 * Run a shell command silently, return stdout or fallback.
 */
function run(cmd, cwd, fallback = '', timeoutMs = 5000) {
  try {
    return execSync(cmd, { cwd, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: timeoutMs }).trim();
  } catch {
    return fallback;
  }
}

/**
 * Detect git remote, SCM provider, base branch, ADO org/project.
 * Port of detect-env.sh.
 */
function detectGitEnv(targetDir) {
  const remoteUrl = run('git remote get-url origin', targetDir);

  let scmProvider = 'unknown';
  if (remoteUrl.includes('visualstudio.com') || remoteUrl.includes('dev.azure.com')) {
    scmProvider = 'ado';
  } else if (remoteUrl.includes('github.com')) {
    scmProvider = 'github';
  }

  // Try auto-detecting base branch
  run('git remote set-head origin --auto', targetDir);
  let baseBranch = run(
    "git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'",
    targetDir
  );
  if (!baseBranch) {
    baseBranch = run(
      "git branch -r 2>/dev/null | grep -oE 'origin/(development|develop|main|master)$' | head -1 | sed 's|origin/||'",
      targetDir
    );
  }
  baseBranch = baseBranch || 'development';

  // ADO org + project extraction
  let adoOrg = '';
  let adoProject = '';
  if (scmProvider === 'ado') {
    if (remoteUrl.includes('visualstudio.com')) {
      const orgMatch = remoteUrl.match(/https:\/\/([^.]+)\.visualstudio\.com/);
      const projMatch = remoteUrl.match(/https:\/\/[^/]+\/([^/]+)\/_git\//);
      adoOrg = orgMatch ? orgMatch[1] : '';
      adoProject = projMatch ? projMatch[1] : '';
    } else if (remoteUrl.includes('dev.azure.com')) {
      const orgMatch = remoteUrl.match(/https:\/\/dev\.azure\.com\/([^/]+)\//);
      const projMatch = remoteUrl.match(/https:\/\/dev\.azure\.com\/[^/]+\/([^/]+)\/_git\//);
      adoOrg = orgMatch ? orgMatch[1] : '';
      adoProject = projMatch ? projMatch[1] : '';
    }
  }

  // Sibling repos
  const parentDir = path.dirname(targetDir);
  const siblings = [];
  if (fs.existsSync(parentDir)) {
    for (const entry of fs.readdirSync(parentDir)) {
      const full = path.join(parentDir, entry);
      if (full === targetDir) continue;
      if (fs.existsSync(path.join(full, '.git'))) {
        siblings.push(entry);
      }
    }
  }

  return { remoteUrl, scmProvider, baseBranch, adoOrg, adoProject, siblings };
}

/**
 * Detect project type and build commands by inspecting project files.
 */
function detectProject(targetDir) {
  const hasPom = fs.existsSync(path.join(targetDir, 'pom.xml'));
  const hasPkg = fs.existsSync(path.join(targetDir, 'package.json'));
  const hasCargo = fs.existsSync(path.join(targetDir, 'Cargo.toml'));
  const hasGo = fs.existsSync(path.join(targetDir, 'go.mod'));

  let projectType = 'unknown';
  let buildCommand = '';
  let deployCommand = '';
  let testCommand = '';
  let lintCommand = '';
  let frontendDir = '';
  let projectName = path.basename(targetDir);
  let projectPrefix = '';

  // Check for AEM markers
  const isAem = hasPom && (
    findFileRecursive(targetDir, 'jcr_root', 2) ||
    findFileRecursive(targetDir, 'ui.apps', 1) ||
    findFileRecursive(targetDir, 'ui.content', 1)
  );

  // Detect frontend directory
  if (fs.existsSync(path.join(targetDir, 'ui.frontend'))) {
    frontendDir = 'ui.frontend/';
  }

  if (isAem) {
    // Check for Java source (fullstack vs frontend-only)
    const hasJava = findFileRecursive(targetDir, 'core/src', 1) ||
      fs.existsSync(path.join(targetDir, 'core'));
    projectType = hasJava ? 'aem-fullstack' : 'aem-frontend';
    buildCommand = 'mvn clean install -PautoInstallPackage';
    deployCommand = 'mvn clean install -PautoInstallPackage -DskipTests';
    testCommand = 'mvn test';

    // Try to detect component prefix from apps dir
    const appsContent = findAppsDir(targetDir);
    if (appsContent) {
      projectPrefix = appsContent + '-';
    }
  } else if (hasPom) {
    projectType = 'java';
    buildCommand = 'mvn clean install';
    deployCommand = 'mvn clean install -DskipTests';
    testCommand = 'mvn test';
  } else if (hasPkg) {
    projectType = 'frontend';
    const pkg = readJsonSafe(path.join(targetDir, 'package.json'));
    projectName = pkg.name || projectName;
    buildCommand = pkg.scripts?.build ? 'npm run build' : '';
    testCommand = pkg.scripts?.test ? 'npm test' : '';
    lintCommand = pkg.scripts?.lint ? 'npm run lint' : '';
  } else if (hasCargo) {
    projectType = 'rust';
    buildCommand = 'cargo build';
    testCommand = 'cargo test';
  } else if (hasGo) {
    projectType = 'go';
    buildCommand = 'go build ./...';
    testCommand = 'go test ./...';
  }

  // Try pom.xml for project name
  if (hasPom && projectType !== 'frontend') {
    const pomName = extractPomValue(path.join(targetDir, 'pom.xml'), 'artifactId');
    if (pomName) projectName = pomName;
  }

  // Try package.json lint for AEM projects
  if (isAem && frontendDir) {
    const fePkg = readJsonSafe(path.join(targetDir, frontendDir, 'package.json'));
    if (fePkg.scripts?.lint) lintCommand = `cd ${frontendDir} && npm run lint`;
    if (fePkg.scripts?.lintcheck) lintCommand = `cd ${frontendDir} && npm run lintcheck`;
  }

  return {
    projectName,
    projectPrefix,
    projectType,
    buildCommand,
    deployCommand,
    testCommand,
    lintCommand,
    frontendDir,
    isAem: isAem || false,
  };
}

// --- Helpers ---

function findFileRecursive(dir, name, maxDepth) {
  if (maxDepth < 0) return false;
  try {
    for (const entry of fs.readdirSync(dir)) {
      if (entry === name) return true;
      if (entry.startsWith('.') || entry === 'node_modules' || entry === 'target') continue;
      const full = path.join(dir, entry);
      if (maxDepth > 0 && fs.statSync(full).isDirectory()) {
        if (findFileRecursive(full, name, maxDepth - 1)) return true;
      }
    }
  } catch { /* permission errors, etc. */ }
  return false;
}

function findAppsDir(targetDir) {
  // Look for jcr_root/apps/<brand>/components
  try {
    const candidates = [
      path.join(targetDir, 'ui.apps/src/main/content/jcr_root/apps'),
      path.join(targetDir, 'ui.content/src/main/content/jcr_root/apps'),
    ];
    for (const appsDir of candidates) {
      if (fs.existsSync(appsDir)) {
        const entries = fs.readdirSync(appsDir).filter(e => !e.startsWith('.') && e !== 'cq');
        if (entries.length > 0) return entries[0];
      }
    }
  } catch { /* ignore */ }
  return '';
}

function readJsonSafe(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return {};
  }
}

function extractPomValue(pomPath, tag) {
  try {
    const content = fs.readFileSync(pomPath, 'utf8');
    // Only match top-level (not inside <parent>)
    const parentEnd = content.indexOf('</parent>');
    const searchFrom = parentEnd > -1 ? content.slice(parentEnd) : content;
    const match = searchFrom.match(new RegExp(`<${tag}>([^<]+)</${tag}>`));
    return match ? match[1] : '';
  } catch {
    return '';
  }
}

module.exports = { detectGitEnv, detectProject };
