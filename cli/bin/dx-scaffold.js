#!/usr/bin/env node
'use strict';

const path = require('path');
const fs = require('fs');
const { detectGitEnv, detectProject } = require('../lib/detect');
const { Scaffold } = require('../lib/scaffold');

// --- Parse CLI arguments ---
const args = process.argv.slice(2);
const flags = {
  aem: args.includes('--aem'),
  copilot: args.includes('--copilot'),
  all: args.includes('--all'),
  force: args.includes('--force'),
  help: args.includes('--help') || args.includes('-h'),
  quiet: args.includes('--quiet') || args.includes('-q'),
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
// CLI is at: dx-aem-ai-flow/dx/cli/bin/dx-scaffold.js
// Plugins:   dx-aem-ai-flow/dx/plugins/
const pluginsDir = path.resolve(__dirname, '..', '..', 'plugins');

if (flags.help) {
  console.log(`
dx-scaffold — Standalone scaffolding for dx-aem-ai-flow plugin ecosystem

Creates the same project structure as /dx-init + /aem-init Claude Code skills,
configured with auto-detected or default values. No Claude Code required.

Usage:
  dx-scaffold [target-dir] [flags]

Flags:
  --aem        Include AEM-specific files (rules, instructions, seed data)
  --copilot    Include GitHub Copilot agents and skills
  --all        Enable all features (--aem + --copilot)
  --force      Overwrite existing files (default: skip)
  --quiet, -q  Suppress per-file output
  --help, -h   Show this help

Examples:
  # Scaffold in current directory (base dx workflow only)
  node dx-scaffold.js

  # Scaffold AEM project with Copilot support
  node dx-scaffold.js --all

  # Scaffold into a specific directory
  node dx-scaffold.js /path/to/my-project --aem

Output Structure:
  .ai/config.yaml         Project configuration (SCM, build, AEM)
  .ai/project.yaml        Detected project profile
  .ai/README.md           Workflow quick reference
  .ai/rules/              Shared AI behavior rules
  .ai/docs/               Documentation (10 files)
  .ai/lib/                Utility shell scripts
  .ai/templates/          Output templates for skills
  .claude/rules/          Auto-loaded coding conventions
  .claude/hooks/          Lifecycle hooks
  .mcp.json               MCP server configuration
  agent.index.md          Machine-readable doc map

  With --aem:
  .ai/project/            AEM knowledge base (component index, patterns)
  .claude/rules/          + AEM coding conventions
  .github/instructions/   + AEM instruction docs

  With --copilot:
  .github/agents/         Copilot agent definitions
  .github/skills/         Copilot skill templates
  .github/copilot-instructions.md

After scaffolding, edit .ai/config.yaml to set your actual values.
`);
  process.exit(0);
}

// --- Validate ---
if (!fs.existsSync(pluginsDir)) {
  console.error(`ERROR: Plugin directory not found: ${pluginsDir}`);
  console.error('This tool must be run from within the dx-aem-ai-flow repository.');
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
if (flags.copilot) {
  console.log('  5. Review .github/agents/ and .github/skills/ for your Copilot setup');
}
console.log('');
