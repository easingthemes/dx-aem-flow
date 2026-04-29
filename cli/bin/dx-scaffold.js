#!/usr/bin/env node
'use strict';

const path = require('path');
const fs = require('fs');
const { detectGitEnv, detectProject } = require('../lib/detect');
const { Scaffold } = require('../lib/scaffold');

function parseOptionalBooleanFlag(args, name) {
  const enable = `--${name}`;
  const disable = `--no-${name}`;

  if (args.includes(disable)) return false;

  const exact = args.indexOf(enable);
  if (exact !== -1) {
    const next = args[exact + 1];
    // Support: --flag true|false (space-separated)
    if (next === 'true') return true;
    if (next === 'false') return false;
    return true;
  }

  // Support: --flag=true|false
  const withEquals = args.find(a => a.startsWith(`${enable}=`));
  if (withEquals) {
    const raw = withEquals.slice(enable.length + 1).toLowerCase();
    if (['true', '1', 'yes', 'on'].includes(raw)) return true;
    if (['false', '0', 'no', 'off'].includes(raw)) return false;
  }

  return undefined;
}

// --- Parse CLI arguments ---
const args = process.argv.slice(2);
const flags = {
  aem: args.includes('--aem'),
  copilot: args.includes('--copilot'),
  all: args.includes('--all'),
  force: args.includes('--force'),
  help: args.includes('--help') || args.includes('-h'),
  quiet: args.includes('--quiet') || args.includes('-q'),
  autoCommit: parseOptionalBooleanFlag(args, 'auto-commit'),
  autoPr: parseOptionalBooleanFlag(args, 'auto-pr'),
};

// --all enables everything
if (flags.all) {
  flags.aem = true;
  flags.copilot = true;
}

// Target directory: first non-flag argument, or CWD
const targetDir = path.resolve(
  args.find(a => !a.startsWith('-')) || process.cwd()
);

// Resolve plugins directory relative to this CLI tool
// CLI is at: dx-aem-flow/dx/cli/bin/dx-scaffold.js
// Plugins:   dx-aem-flow/dx/plugins/
const pluginsDir = path.resolve(__dirname, '..', '..', 'plugins');

if (flags.help) {
  console.log(`
dx-scaffold — Bootstrap project config for any AI coding agent

Creates the same project structure as /dx-init + /aem-init skills.
Works with Claude Code, Copilot CLI, Codex CLI, VS Code Chat, and others.

Usage:
  dx-scaffold [target-dir] [flags]

Flags:
  --aem        Include AEM-specific files (rules, instructions, seed data)
  --copilot    Include extra Copilot files (copilot-instructions.md, README)
  --all        Enable all features (--aem + --copilot)
  --auto-commit[=true|false]
               Set preferences.auto-commit in generated config.yaml
               (also supports --no-auto-commit)
  --auto-pr[=true|false]
               Set preferences.auto-pr in generated config.yaml
               (also supports --no-auto-pr)
  --force      Overwrite existing files (default: skip)
  --quiet, -q  Suppress per-file output
  --help, -h   Show this help

Examples:
  # Scaffold in current directory (base workflow + agents)
  node dx-scaffold.js

  # Full scaffold for AEM project
  node dx-scaffold.js --all

  # Scaffold into a specific directory
  node dx-scaffold.js /path/to/my-project --aem

  # Scaffold with pipeline preferences
  node dx-scaffold.js /path/to/my-project --auto-commit=true --auto-pr=false

Output (always generated):
  .ai/config.yaml         Project configuration (SCM, build, AEM)
  .ai/rules/              Shared AI behavior rules
  .ai/lib/                Utility shell scripts
  .ai/templates/          Output templates for skills
  .claude/rules/          Auto-loaded coding conventions
  .claude/hooks/          Lifecycle hooks
  .mcp.json               MCP server configuration
  .github/agents/         Agent definitions (Copilot CLI, VS Code Chat, Codex)
  AGENTS.md               Agent discovery file (Codex CLI, Windsurf, coding agent)
  agent.index.md          Machine-readable doc map

  With --aem:
  .ai/project/            AEM knowledge base (component index, patterns)
  .claude/rules/          + AEM coding conventions
  .github/instructions/   + AEM instruction docs

  With --copilot:
  .github/copilot-instructions.md   Copilot master instructions
  .github/README.md                 GitHub AI config overview

After scaffolding, edit .ai/config.yaml to set your actual values.
`);
  process.exit(0);
}

// --- Validate ---
if (!fs.existsSync(pluginsDir)) {
  console.error(`ERROR: Plugin directory not found: ${pluginsDir}`);
  console.error('This tool must be run from within the dx-aem-flow repository.');
  process.exit(1);
}

if (!fs.existsSync(targetDir)) {
  console.error(`ERROR: Target directory does not exist: ${targetDir}`);
  process.exit(1);
}

// --- Detect environment ---
console.log(`\ndx-scaffold v1.0.0`);
console.log(`Target: ${targetDir}`);
console.log(`Plugins: ${pluginsDir}\n`);

console.log('Detecting environment...');
const gitEnv = detectGitEnv(targetDir);
const projectEnv = detectProject(targetDir);

console.log(`  SCM: ${gitEnv.scmProvider}${gitEnv.adoOrg ? ` (${gitEnv.adoOrg})` : ''}`);
console.log(`  Base branch: ${gitEnv.baseBranch}`);
console.log(`  Project type: ${projectEnv.projectType}`);
console.log(`  Project name: ${projectEnv.projectName}`);
if (projectEnv.isAem) console.log(`  AEM detected: yes`);
if (gitEnv.siblings.length > 0) console.log(`  Sibling repos: ${gitEnv.siblings.join(', ')}`);
console.log('');

// Auto-enable AEM if detected
if (projectEnv.isAem && !flags.aem) {
  console.log('  AEM project detected — auto-enabling --aem');
  flags.aem = true;
}

// --- Build placeholders ---
const placeholders = {
  PROJECT_NAME: projectEnv.projectName,
  PROJECT_PREFIX: projectEnv.projectPrefix,
  SCM_ORG: gitEnv.adoOrg || 'YOUR_ADO_ORG',
  SCM_PROJECT: gitEnv.adoProject || 'YOUR_ADO_PROJECT',
  SCM_REPO_ID: 'TODO-repo-guid',
  BASE_BRANCH: gitEnv.baseBranch,
  BUILD_COMMAND: projectEnv.buildCommand || 'TODO',
  DEPLOY_COMMAND: projectEnv.deployCommand || projectEnv.buildCommand || 'TODO',
  TEST_COMMAND: projectEnv.testCommand || 'TODO',
  // Pass through for internal use
  projectType: projectEnv.projectType,
  projectPrefix: projectEnv.projectPrefix,
  frontendDir: projectEnv.frontendDir,
  scmProvider: gitEnv.scmProvider,
};

if (flags.autoCommit !== undefined) {
  placeholders.AUTO_COMMIT = flags.autoCommit;
}
if (flags.autoPr !== undefined) {
  placeholders.AUTO_PR = flags.autoPr;
}

// --- Scaffold ---
console.log('Scaffolding files...');
const scaffold = new Scaffold(targetDir, pluginsDir, {
  aem: flags.aem,
  copilot: flags.copilot,
  force: flags.force,
  quiet: flags.quiet,
});
scaffold.setPlaceholders(placeholders);
const stats = scaffold.run();

// --- Summary ---
console.log(`\nDone! ${stats.installed} files installed, ${stats.skipped} skipped.`);
console.log('');
console.log('Next steps:');
console.log('  1. Edit .ai/config.yaml — set your actual SCM org, build commands, URLs');
if (flags.aem) {
  console.log('  2. Edit .ai/config.yaml aem: section — set author/publish URLs, credentials');
  console.log('  3. Populate .ai/project/component-index.md with your components');
  console.log('  4. Fill in .ai/project/architecture.md and features.md');
}
console.log('');
console.log('Works with:');
console.log('  Claude Code   — /plugin install, then /dx-init to refine config interactively');
console.log('  Copilot CLI   — /plugin install, then /dx-init (same plugins, same skills)');
console.log('  VS Code Chat  — agents auto-discovered from .github/agents/');
console.log('  Codex CLI     — reads AGENTS.md and .github/agents/ for project context');
console.log('  Windsurf      — reads AGENTS.md as always-on instructions');
console.log('  Others        — .claude/rules/ and .mcp.json provide conventions + MCP tools');
console.log('');
