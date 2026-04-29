'use strict';

const fs = require('fs');
const path = require('path');

/**
 * Core scaffolding engine.
 * Reads templates from plugin directories and writes to target project.
 */
class Scaffold {
  constructor(targetDir, pluginsDir, options = {}) {
    this.targetDir = targetDir;
    this.pluginsDir = pluginsDir;
    this.dxPlugin = path.join(pluginsDir, 'dx-core');
    this.aemPlugin = path.join(pluginsDir, 'dx-aem');
    this.autoPlugin = path.join(pluginsDir, 'dx-automation');
    this.options = options; // { aem, copilot, force, quiet }
    this.stats = { installed: 0, skipped: 0 };
    this.placeholders = {};
  }

  /**
   * Set placeholder values for template substitution.
   * Also derives projectRole from projectType if not explicitly set.
   */
  setPlaceholders(values) {
    this.placeholders = { ...this.placeholders, ...values };

    // Defaults for pipeline automation preferences in config.yaml
    if (this.placeholders.AUTO_COMMIT === undefined) {
      this.placeholders.AUTO_COMMIT = false;
    }
    if (this.placeholders.AUTO_PR === undefined) {
      this.placeholders.AUTO_PR = false;
    }

    // Derive projectRole from projectType if not explicitly provided
    if (!this.placeholders.projectRole && this.placeholders.projectType) {
      const typeToRole = {
        'aem-fullstack': 'fullstack',
        'aem-frontend': 'frontend',
        'frontend': 'frontend',
        'java': 'backend',
      };
      this.placeholders.projectRole = typeToRole[this.placeholders.projectType] || 'fullstack';
    }

    // Default REPOS_TABLE placeholder for non-interactive CLI context
    if (!this.placeholders.REPOS_TABLE) {
      this.placeholders.REPOS_TABLE = '| Repo | Role | Platform | Base Branch |\n|---|---|---|---|\n| <!-- TODO: Fill in your repo table from config.yaml repos: section --> |';
    }
  }

  /**
   * Run full scaffolding — replicates dx-init + aem-init output.
   */
  run() {
    this.createDirectories();
    this.installConfig();
    this.installReadme();
    this.installAgentIndex();
    this.installMe();
    this.installMcpJson();
    this.installClaudeSettings();
    this.installLocalSettings();
    this.installLibScripts();
    this.installHooks();
    this.installOutputTemplates();
    this.installDxRules();
    this.installUniversalRules();
    this.installDocs();
    this.updateGitignore();

    if (this.options.aem) {
      this.installAemRules();
      this.installAemInstructions();
      this.installAemConfigSection();
      this.installAemProjectSeedData();
    }

    // Always generate agents and AGENTS.md — consumed by Copilot CLI,
    // VS Code Chat, Codex CLI, Windsurf, and the Copilot coding agent.
    this.installCopilotAgents();
    this.installAgentsMd();

    if (this.options.copilot) {
      this.installCopilotInstructions();
    }

    return this.stats;
  }

  // --- Directory creation ---

  createDirectories() {
    const dirs = [
      '.ai/specs', '.ai/rules', '.ai/research', '.ai/lib', '.ai/docs',
      '.ai/templates/spec', '.ai/templates/wiki', '.ai/templates/ado-comments',
      '.ai/pr-reviews',
      '.claude/rules', '.claude/hooks',
    ];
    if (this.options.aem) {
      dirs.push('.ai/project');
    }
    // Always create .github/agents/ — consumed by multiple AI agents
    dirs.push('.github/agents');
    if (this.options.copilot) {
      dirs.push('.github/instructions');
    }
    for (const dir of dirs) {
      this.mkdirp(dir);
    }
    this.log('created directory structure');
  }

  // --- Core dx-init files ---

  installConfig() {
    const src = path.join(this.dxPlugin, 'templates', 'config.yaml.template');
    const content = this.readTemplate(src);
    this.writeFile('.ai/config.yaml', content);
  }

  installReadme() {
    const src = path.join(this.dxPlugin, 'templates', 'README.md.template');
    const content = this.readTemplate(src);
    this.writeFile('.ai/README.md', content);
  }

  installAgentIndex() {
    const src = path.join(this.dxPlugin, 'templates', 'INDEX.md.template');
    const content = this.readTemplate(src);
    this.writeFile('agent.index.md', content);
  }

  installMe() {
    const content = `# Communication Style

## Tone
- Professional, concise
- Direct — lead with the answer

## Language
- English

## PR Comments
- Brief, actionable
- No praise filler

## Preferences
- Prefer code examples over explanations
- Skip obvious context
`;
    this.writeFile('.ai/me.md', content);
  }

  installMcpJson() {
    const adoOrg = this.placeholders.SCM_ORG || 'YOUR_ADO_ORG';
    const content = {
      mcpServers: {
        context7: {
          type: 'stdio',
          command: 'npx',
          args: ['-y', '@upstash/context7-mcp@latest'],
        },
      },
    };
    // Only add ADO MCP if ADO is the SCM provider
    if (this.placeholders.scmProvider === 'ado' || this.placeholders.SCM_ORG) {
      content.mcpServers.ado = {
        type: 'stdio',
        command: 'npx',
        args: ['-y', '@azure-devops/mcp', adoOrg],
      };
    }
    this.writeFile('.mcp.json', JSON.stringify(content, null, 2) + '\n');
  }

  installClaudeSettings() {
    const content = {
      permissions: {
        allow: [
          'Bash(git *)',
          'Bash(npm *)',
          'Bash(npx *)',
        ],
      },
    };
    this.writeFile('.claude/settings.json', JSON.stringify(content, null, 2) + '\n');
  }

  installLocalSettings() {
    const filePath = '.claude/settings.local.json';
    const target = path.join(this.targetDir, filePath);
    if (fs.existsSync(target)) {
      // Merge missing keys into existing file
      const existing = JSON.parse(fs.readFileSync(target, 'utf8'));
      if (!existing.env) existing.env = {};
      let added = false;
      for (const key of this.getRequiredEnvVars()) {
        if (!(key in existing.env)) {
          existing.env[key] = '';
          added = true;
        }
      }
      if (added) {
        this.writeFile(filePath, JSON.stringify(existing, null, 2) + '\n');
      }
      return;
    }
    const env = {};
    for (const key of this.getRequiredEnvVars()) {
      env[key] = '';
    }
    this.writeFile(filePath, JSON.stringify({ env }, null, 2) + '\n');
  }

  getRequiredEnvVars() {
    const vars = [
      'QA_BASIC_AUTH_USER',
      'QA_BASIC_AUTH_PASS',
      'QA_BASIC_AUTH_FALLBACK_USER',
      'QA_BASIC_AUTH_FALLBACK_PASS',
      'AXE_API_KEY',
    ];
    // Add AEM vars if aem mode is enabled
    if (this.options.aem) {
      vars.push('AEM_INSTANCES');
    }
    return vars;
  }

  // --- Lib scripts ---

  installLibScripts() {
    const libDir = path.join(this.dxPlugin, 'data', 'lib');
    if (!fs.existsSync(libDir)) return;
    for (const file of fs.readdirSync(libDir)) {
      // .sh helpers + .js helpers; exclude tests and fixtures (dev-only artifacts).
      if (!/\.(sh|js)$/.test(file)) continue;
      if (file.endsWith('.test.js')) continue;
      this.copyFile(path.join(libDir, file), `.ai/lib/${file}`, { executable: true });
    }
  }

  // --- Hooks ---

  installHooks() {
    const hooksSrc = path.join(this.dxPlugin, 'data', 'hooks', 'stop-guard.sh');
    if (fs.existsSync(hooksSrc)) {
      this.copyFile(hooksSrc, '.claude/hooks/stop-guard.sh', { executable: true });
    }
  }

  // --- Output templates ---

  installOutputTemplates() {
    const templatesDir = path.join(this.dxPlugin, 'data', 'templates');
    if (!fs.existsSync(templatesDir)) return;
    for (const subdir of ['spec', 'wiki', 'ado-comments']) {
      const srcDir = path.join(templatesDir, subdir);
      if (!fs.existsSync(srcDir)) continue;
      for (const file of fs.readdirSync(srcDir)) {
        if (!file.endsWith('.template')) continue;
        this.copyFile(path.join(srcDir, file), `.ai/templates/${subdir}/${file}`);
      }
    }
  }

  // --- dx rules (non-universal) → .ai/rules/ ---

  installDxRules() {
    const rulesDir = path.join(this.dxPlugin, 'templates', 'rules');
    if (!fs.existsSync(rulesDir)) return;
    for (const file of fs.readdirSync(rulesDir)) {
      if (!file.endsWith('.template')) continue;
      if (file.startsWith('universal-')) continue; // handled separately
      const name = file.replace('.template', '');
      this.copyFile(path.join(rulesDir, file), `.ai/rules/${name}`);
    }
  }

  // --- Universal rules → .claude/rules/ ---

  installUniversalRules() {
    const rulesDir = path.join(this.dxPlugin, 'templates', 'rules');
    if (!fs.existsSync(rulesDir)) return;
    for (const file of fs.readdirSync(rulesDir)) {
      if (!file.startsWith('universal-') || !file.endsWith('.template')) continue;
      const name = file.replace('universal-', '').replace('.template', '');
      this.copyFile(path.join(rulesDir, file), `.claude/rules/${name}`);
    }
  }

  // --- Docs ---

  installDocs() {
    const docsDir = path.join(this.dxPlugin, 'templates', 'docs');
    if (!fs.existsSync(docsDir)) return;
    for (const file of fs.readdirSync(docsDir)) {
      if (!file.endsWith('.template')) continue;
      const name = file.replace('.template', '');
      this.copyFile(path.join(docsDir, file), `.ai/docs/${name}`);
    }
  }

  // --- .gitignore updates ---

  updateGitignore() {
    const gitignorePath = path.join(this.targetDir, '.gitignore');
    const entries = ['.ai/specs/', '.ai/research/', '.ai/pr-reviews/', '.ai/me.md'];
    let content = '';
    if (fs.existsSync(gitignorePath)) {
      content = fs.readFileSync(gitignorePath, 'utf8');
    }
    const missing = entries.filter(e => !content.includes(e));
    if (missing.length > 0) {
      const block = '\n# dx-scaffold — AI workflow (gitignored)\n' + missing.join('\n') + '\n';
      fs.writeFileSync(gitignorePath, content + block);
      this.log(`updated .gitignore (+${missing.length} entries)`);
    }
  }

  // =============================================================
  //  AEM-specific files (--aem)
  // =============================================================

  installAemRules() {
    const rulesDir = path.join(this.aemPlugin, 'templates', 'rules');
    if (!fs.existsSync(rulesDir)) return;

    const role = this.placeholders.projectRole || 'fullstack';
    const skipDirs = {
      frontend: ['be'],
      backend: ['fe'],
      config: ['be', 'fe'],
      fullstack: [],
    };
    const dirsToSkip = skipDirs[role] || [];

    // Handle templates at root level (backward compat)
    for (const file of fs.readdirSync(rulesDir)) {
      const fullPath = path.join(rulesDir, file);
      if (fs.statSync(fullPath).isFile() && file.endsWith('.md.template')) {
        const name = file.replace('.template', '');
        this.copyFile(fullPath, `.claude/rules/${name}`);
      }
    }

    // Recurse shared/, be/, fe/ subdirectories
    const subdirs = ['shared', 'be', 'fe'];
    for (const subdir of subdirs) {
      if (dirsToSkip.includes(subdir)) continue;
      const subdirPath = path.join(rulesDir, subdir);
      if (!fs.existsSync(subdirPath)) continue;
      for (const file of fs.readdirSync(subdirPath)) {
        if (!file.endsWith('.md.template')) continue;
        const name = file.replace('.template', '');
        this.copyFile(path.join(subdirPath, file), `.claude/rules/${name}`);
      }
    }
  }

  installAemInstructions() {
    const instrDir = path.join(this.aemPlugin, 'templates', 'instructions');
    if (!fs.existsSync(instrDir)) return;

    const projectType = this.placeholders.projectType || 'aem-fullstack';

    for (const file of fs.readdirSync(instrDir)) {
      if (!file.endsWith('.template')) continue;
      const name = file.replace('.template', '');

      // Filter backend instructions for frontend-only projects
      if (projectType === 'aem-frontend' && name.startsWith('be.')) continue;

      this.copyFile(path.join(instrDir, file), `.github/instructions/${name}`);
    }
  }

  installAemConfigSection() {
    const configPath = path.join(this.targetDir, '.ai', 'config.yaml');
    if (!fs.existsSync(configPath)) return;

    const projectName = this.placeholders.PROJECT_NAME || 'my-project';
    const brand = (this.placeholders.projectPrefix || 'mybrand-').replace(/-$/, '');

    const aemSection = `
# AEM Configuration — generated by dx-scaffold
# Update URLs, paths, and credentials to match your environment.
aem:
  component-path: "/apps/${brand}/components/content"
  component-prefix: "${this.placeholders.projectPrefix || 'bat-'}"
  component-group: "${capitalize(brand)}"
  resource-type-pattern: "${brand}/components/content/{name}"
  frontend-dir: "${this.placeholders.frontendDir || 'ui.frontend/'}"
  dam-path: "/content/dam/${brand}-assets/"
  author-url: "http://localhost:4502"
  author-url-qa: "https://TODO-qa-author-url.example.com"
  publish-url: "http://localhost:4503"
  publish-url-qa: "https://TODO-qa-publish-url.example.com"
  demo-parent-path: "/content/${brand}/us/en/demo"
  brands:
    - ${brand}
  active-markets:
    - ${brand}-us
  # qa-basic-auth:
  #   username: "TODO"
  #   password: "TODO"
`;

    let content = fs.readFileSync(configPath, 'utf8');
    content += aemSection;
    fs.writeFileSync(configPath, content);
    this.log('appended AEM config section to .ai/config.yaml');
  }

  installAemProjectSeedData() {
    const projectDir = path.join(this.targetDir, '.ai', 'project');
    this.mkdirp('.ai/project');

    const brand = (this.placeholders.projectPrefix || 'mybrand-').replace(/-$/, '');
    const projectName = this.placeholders.PROJECT_NAME || 'My-Project';

    // component-index.md — placeholder
    this.writeFile('.ai/project/component-index.md', `# Component Index — ${projectName}

Auto-generated component lookup table. Run \`/aem-init\` with Claude Code to populate from your AEM project, or manually add components below.

| Component | Title | Resource Type | Group |
|-----------|-------|---------------|-------|
| example-hero | Example Hero | ${brand}/components/content/example-hero | ${capitalize(brand)} |

> **Tip:** Populate this by scanning \`**/jcr_root/apps/*/components/*/.content.xml\` files in your project.
`);

    // file-patterns.yaml — default patterns
    this.writeFile('.ai/project/file-patterns.yaml', `# File Patterns — ${projectName}
# Maps component names to source file locations.
# Used by /aem-component and /dx-ticket-analyze to find all files for a component.

legacy:
  backend:
    htl: "ui.apps/src/main/content/jcr_root/apps/${brand}/components/content/{name}/{name}.html"
    dialog: "ui.apps/src/main/content/jcr_root/apps/${brand}/components/content/{name}/_cq_dialog/.content.xml"
    component-def: "ui.apps/src/main/content/jcr_root/apps/${brand}/components/content/{name}/.content.xml"
    sling-model: "core/src/main/java/**/models/{Name}Model.java"
    exporter: "core/src/main/java/**/models/{Name}ComponentExporter.java"
  frontend:
    js: "ui.frontend/src/core/components/{name}/*.js"
    scss: "ui.frontend/src/core/themes/components/_{name}.scss"
    brand-js: "ui.frontend/src/brand/components/{name}/*.js"
    brand-scss: "ui.frontend/src/brand/themes/components/_{name}.scss"
    hbs: "ui.frontend/src/core/components/{name}/*.hbs"
`);

    // content-paths.yaml — default content structure
    this.writeFile('.ai/project/content-paths.yaml', `# Content Paths — ${projectName}
# AEM content tree structure for page lookups.

content-root: "/content/${brand}/{country}/{language}"
xf-root: "/content/experience-fragments/${brand}/{country}/{language}"
author-url-pattern: "{author-url}/editor.html{pagePath}.html"
search-tool: "mcp__plugin_dx-aem_AEM__searchContent"

language-defaults:
  us: en
  gb: en
  de: de
  fr: fr
  ca: en
`);

    // architecture.md — placeholder
    this.writeFile('.ai/project/architecture.md', `# Architecture — ${projectName}

## Platform
TODO: Describe your AEM platform architecture here.

## Rendering Pipeline
TODO: Describe how components render (server-side HTL, client-side JS, hybrid).

## Module Structure
TODO: List the Maven modules and their roles.

## Key Patterns
TODO: Document component patterns, base classes, configuration approaches.
`);

    // features.md — placeholder
    this.writeFile('.ai/project/features.md', `# Features — ${projectName}

TODO: Document key platform features (auth, commerce, search, analytics, etc.)
Each feature should include: what it does, which components are involved, key config.
`);
  }

  // =============================================================
  //  Copilot files (--copilot)
  // =============================================================

  installCopilotAgents() {
    // dx-core agents
    this.copyCopilotAgents(this.dxPlugin);
    // dx-aem agents (if AEM mode)
    if (this.options.aem) {
      this.copyCopilotAgents(this.aemPlugin);
    }
  }

  copyCopilotAgents(pluginDir) {
    const agentsDir = path.join(pluginDir, 'templates', 'agents');
    if (!fs.existsSync(agentsDir)) return;
    for (const file of fs.readdirSync(agentsDir)) {
      if (!file.endsWith('.agent.md.template')) continue;
      const target = file.replace('.template', ''); // DxFoo.agent.md.template → DxFoo.agent.md
      this.copyFile(path.join(agentsDir, file), `.github/agents/${target}`);
    }
  }

  installCopilotInstructions() {
    const src = path.join(this.dxPlugin, 'templates', 'copilot-instructions.md.template');
    if (fs.existsSync(src)) {
      const content = this.readTemplate(src);
      this.writeFile('.github/copilot-instructions.md', content);
    }

    // Also copy github README template if it exists
    const readmeSrc = path.join(this.dxPlugin, 'templates', 'github-readme.md.template');
    if (fs.existsSync(readmeSrc)) {
      const content = this.readTemplate(readmeSrc);
      this.writeFile('.github/README.md', content);
    }
  }

  // =============================================================
  //  AGENTS.md — cross-agent discovery file
  // =============================================================

  /**
   * Generate AGENTS.md at project root.
   * Read by Codex CLI (primary instruction file), Windsurf (always-on),
   * and the Copilot coding agent. Lists all available agents with
   * invocation syntax.
   */
  installAgentsMd() {
    const agentsDir = path.join(this.targetDir, '.github', 'agents');
    if (!fs.existsSync(agentsDir)) return;

    const agents = [];
    for (const file of fs.readdirSync(agentsDir).sort()) {
      if (!file.endsWith('.agent.md')) continue;
      const name = file.replace('.agent.md', '');
      const content = fs.readFileSync(path.join(agentsDir, file), 'utf8');
      const desc = this.extractFrontmatterField(content, 'description') || '';
      const shortDesc = desc.length > 80 ? desc.slice(0, 77) + '...' : desc;
      agents.push({ name, desc: shortDesc });
    }

    if (agents.length === 0) return;

    // Group agents by prefix
    const dxAgents = agents.filter(a => a.name.startsWith('Dx'));
    const aemAgents = agents.filter(a => a.name.startsWith('AEM'));
    const otherAgents = agents.filter(a => !a.name.startsWith('Dx') && !a.name.startsWith('AEM'));

    let md = `# Agents

Available AI agents for this project. Invoke with \`@AgentName\` in Copilot CLI, VS Code Chat, or as subagents in Claude Code.

`;

    const writeTable = (title, list) => {
      if (list.length === 0) return '';
      let table = `## ${title}\n\n| Agent | Description | Invoke |\n|-------|-------------|--------|\n`;
      for (const a of list) {
        table += `| ${a.name} | ${a.desc} | \`@${a.name}\` |\n`;
      }
      return table + '\n';
    };

    md += writeTable('Development Workflow', dxAgents);
    md += writeTable('AEM', aemAgents);
    md += writeTable('Other', otherAgents);

    this.writeFile('AGENTS.md', md.trimEnd() + '\n');
  }

  /**
   * Extract a field value from YAML frontmatter in a markdown file.
   */
  extractFrontmatterField(content, field) {
    const match = content.match(new RegExp(`^${field}:\\s*(.+)$`, 'm'));
    if (!match) return null;
    return match[1].replace(/^["']|["']$/g, '').trim();
  }

  // =============================================================
  //  Utilities
  // =============================================================

  /**
   * Read a template file and substitute placeholders.
   */
  readTemplate(filePath) {
    if (!fs.existsSync(filePath)) {
      this.log(`WARNING: template not found: ${filePath}`);
      return '';
    }
    let content = fs.readFileSync(filePath, 'utf8');
    for (const [key, value] of Object.entries(this.placeholders)) {
      const replacement = value === undefined || value === null ? '' : String(value);
      content = content.replace(new RegExp(`\\{\\{${key}\\}\\}`, 'g'), replacement);
    }
    return content;
  }

  /**
   * Copy a file from absolute src to relative dst (within targetDir).
   * Skips if file already exists (unless --force).
   */
  copyFile(src, relDst, options = {}) {
    const dst = path.join(this.targetDir, relDst);
    if (!fs.existsSync(src)) {
      this.log(`WARNING: source not found: ${src}`);
      return;
    }
    if (fs.existsSync(dst) && !this.options.force) {
      this.stats.skipped++;
      this.log(`skipped ${relDst} (already exists)`);
      return;
    }
    const dir = path.dirname(dst);
    fs.mkdirSync(dir, { recursive: true });
    fs.copyFileSync(src, dst);
    if (options.executable) {
      fs.chmodSync(dst, 0o755);
    }
    this.stats.installed++;
    this.log(`installed ${relDst}`);
  }

  /**
   * Write content to a relative path within targetDir.
   * Skips if file already exists (unless --force).
   */
  writeFile(relPath, content) {
    const dst = path.join(this.targetDir, relPath);
    if (fs.existsSync(dst) && !this.options.force) {
      this.stats.skipped++;
      this.log(`skipped ${relPath} (already exists)`);
      return;
    }
    const dir = path.dirname(dst);
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(dst, content);
    this.stats.installed++;
    this.log(`installed ${relPath}`);
  }

  /**
   * Create directory relative to targetDir.
   */
  mkdirp(relPath) {
    fs.mkdirSync(path.join(this.targetDir, relPath), { recursive: true });
  }

  log(msg) {
    if (!this.options.quiet) {
      console.log(`  ${msg}`);
    }
  }
}

function capitalize(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

module.exports = { Scaffold };
