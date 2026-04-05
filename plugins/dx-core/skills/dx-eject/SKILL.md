---
name: dx-eject
description: Eject all plugin assets into the consumer repo — copies skills, agents, rules, templates, shared files, hooks, and MCP config so the project works without plugins installed. Use when a team wants to own all dx files locally instead of depending on plugins.
argument-hint: "[dx|aem|auto|all]"
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You eject (copy) all plugin assets into the consumer project so it can operate independently without any dx plugins installed. This is a **one-way, irreversible operation** — after ejecting, the project owns all files and plugin updates no longer propagate automatically.

## Tool Usage Rules

- **File existence:** Use `Glob` — never `[ -f ]`, `test -f`, or Bash test commands
- **File content reads:** Use `Read` — never `cat` or `head` in Bash
- **File writes:** Use `Write` or `Edit` — never `echo >` in Bash
- **Bash is ONLY for:** running `eject.sh`, `chmod +x`, `git` commands, and install scripts
- **Parallel operations:** Call multiple `Read`/`Write`/`Glob` tools in parallel when independent

## 0. Pre-flight Checks

### 0a. Verify dx is initialized

Check that `.ai/config.yaml` exists (use Glob). If not:
```
✗ FATAL: .ai/config.yaml not found. Run /dx-init first before ejecting.
```
STOP.

### 0b. Resolve Plugin Directories

Find each installed plugin root:

- **dx plugin:** Glob for `**/skills/dx-doctor/SKILL.md`, navigate up 3 levels
- **aem plugin:** Glob for `**/skills/aem-init/SKILL.md`, navigate up 3 levels
- **auto plugin:** Glob for `**/skills/auto-init/SKILL.md`, navigate up 3 levels

Parse the argument to determine scope:
- `dx` — eject dx-core only
- `aem` — eject dx-aem only
- `auto` — eject dx-automation only
- `all` or no argument — eject all detected plugins

If a requested plugin is not found, report: `⚠ <plugin> plugin not detected. Skipping.`

### 0c. Warn the User

Present this warning and **wait for explicit confirmation**:

```markdown
## ⚠ Eject Warning

This will copy ALL assets from the following plugins into your repo:
- dx-core (skills, agents, rules, shared files, data, templates)
- dx-aem (skills, agents, shared files, templates)
- dx-automation (skills, rules, data files, templates)

### What happens:
1. **Claude Code skills** → `.claude/skills/` (shadows plugin skills — Claude Code loads local over plugin)
2. **Claude Code agents** → `.claude/agents/` (local agent definitions)
3. **Copilot agents** → `.github/agents/`
4. **Plugin originals** → `.ai/ejected/` (rules, shared, data, templates, hooks, manifests)
6. **Hooks config** → merged into `.claude/hooks.json`

### After ejecting:
- You can uninstall the plugins (`/plugin uninstall dx-core`, etc.)
- All skills and agents work from local files
- You are responsible for maintaining and updating these files
- `/dx-upgrade` and `/dx-doctor` will no longer work (they depend on plugin directories)
- To get plugin updates, you must manually diff and merge

**This cannot be undone. Proceed?** (yes/no)
```

If the user says no, STOP.

## 1. Run the Eject Script

The eject script copies all plugin files into the project. Run it from the project root:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/eject.sh <dx-plugin> [<aem-plugin>] [<auto-plugin>]
```

Pass only the plugin directories that are in scope (based on the user's argument).

The script creates this structure:

```
.claude/
├── skills/           # All plugin skills (Claude Code local overrides)
│   ├── dx-req/SKILL.md
│   ├── dx-plan/SKILL.md
│   ├── aem-component/SKILL.md
│   ├── auto-deploy/SKILL.md
│   └── ...
├── agents/           # All plugin agents (Claude Code local)
│   ├── dx-pr-reviewer.md
│   ├── dx-code-reviewer.md
│   ├── aem-inspector.md
│   └── ...
└── hooks/            # Hooks (already installed by dx-init)

.github/
└── agents/           # Copilot agents
    ├── DxCodeReview.agent.md
    └── ...

.ai/ejected/          # Plugin source-of-truth archive
├── plugin-rules/     # Plugin default rules (read-only reference)
├── shared/           # Shared reference docs (ado-config.md, git-rules.md, etc.)
├── data/             # Plugin data originals organized by plugin name
│   ├── dx-core/  # lib/, templates/, hooks/
│   ├── dx-aem/             # (if applicable)
│   └── dx-automation/      # agents/lib/, pipelines/, lambda/, eval/
├── templates/        # All plugin templates organized by plugin name
│   ├── dx-core/  # rules/, skills/, agents/, docs/, instructions/
│   ├── dx-aem/             # rules/, agents/, instructions/
│   └── dx-automation/      # rules/
├── hooks/            # Plugin hooks.json files
│   └── dx-core/hooks.json
└── manifests/        # Plugin version snapshots
    ├── dx-core.json
    ├── dx-aem.json
    └── dx-automation.json
```

## 2. Merge Hooks Configuration

After the script runs, merge plugin hooks into the project's `.claude/hooks.json`.

Read `.ai/ejected/hooks/dx-core/hooks.json` (if it exists). This contains the Stop hook that runs `stop-guard.sh`.

Check if `.claude/hooks.json` already exists:
- **If it exists:** Read it, check if the Stop hook is already present. If not, merge the hook entry.
- **If it doesn't exist:** Create it with the hook from the plugin.

**Important:** The hook command references `$CLAUDE_PROJECT_DIR/.claude/hooks/stop-guard.sh` — this path is already correct for an ejected project since `stop-guard.sh` was installed by dx-init to `.claude/hooks/`.

## 3. Merge MCP Configuration

Read the project's existing `.mcp.json`.

For each ejected plugin that has MCP servers:
- **dx-core:** Empty mcpServers (ADO MCP configured separately) — no merge needed
- **dx-aem:** Has `AEM` (HTTP) and `chrome-devtools-mcp` (stdio) servers
- **dx-automation:** No .mcp.json

Check if the AEM MCP entries already exist in `.mcp.json`. If not, merge them. If they already exist (because dx-init/aem-init already configured them), skip.

## 4. Update Shared File References in Skills

Some ejected skills reference files via plugin-relative paths (e.g., `shared/git-rules.md`, `shared/ado-config.md`). After ejecting, these files live at `.ai/ejected/shared/`.

**Claude Code handles this automatically** — skills in `.claude/skills/` are loaded as local overrides, and shared files are resolved relative to the skill's plugin origin. Since the plugin will be uninstalled, we need to update any skill that reads shared files.

Scan all ejected skills in `.claude/skills/*/SKILL.md` for references to paths like:
- `shared/` → replace with `.ai/ejected/shared/`
- `<plugin-dir>/shared/` → replace with `.ai/ejected/shared/`

Use `Read` to check each skill file, and `Edit` to update references if found.

Similarly, scan ejected agents in `.claude/agents/*.md` for shared file references and update them.

## 5. Update .gitignore

Check if `.gitignore` contains `.ai/ejected/`. If not, add it to the "AI workflow" section:

```
# AI workflow (ejected plugin assets)
.ai/ejected/
```

Wait — `.ai/ejected/` should actually be **committed** since it's the source of truth for the project post-eject. Do NOT add it to .gitignore.

Check that these paths are NOT in .gitignore (they need to be committed):
- `.claude/skills/`
- `.claude/agents/`
- `.github/agents/`
- `.ai/ejected/`

If any are gitignored, report as a manual action: "Remove `<path>` from .gitignore — these ejected files must be committed."

## 6. Create Eject Manifest

Write `.ai/ejected/EJECT.md` with metadata about the ejection:

```markdown
# Ejected Plugin Assets

**Ejected on:** <current date>
**Plugins ejected:**

| Plugin | Version | Skills | Agents |
|--------|---------|--------|--------|
| dx-core | 2.19.0 | 45 | 5 |
| dx-aem | 2.19.0 | 10 | 5 |
| dx-automation | 2.19.0 | 11 | 0 |

## Post-Eject Notes

- All skills now load from `.claude/skills/` (Claude Code)
- All agents now load from `.claude/agents/` (Claude Code) and `.github/agents/` (Copilot)
- Plugin originals are archived in `.ai/ejected/` for reference
- To update: manually diff against newer plugin versions and merge changes
- `/dx-doctor` and `/dx-upgrade` are no longer functional (they require plugin directories)
- The ejected `/dx-doctor` skill can be adapted to check local files instead

## File Ownership

| Directory | Owner | Purpose |
|-----------|-------|---------|
| `.claude/skills/` | Project | Claude Code skills (edit freely) |
| `.claude/agents/` | Project | Claude Code agents (edit freely) |
| `.github/agents/` | Project | Copilot agents (regenerate from templates if needed) |
| `.ai/ejected/` | Archive | Plugin originals — reference only, do not edit |
| `.ai/rules/` | Project | Shared rules (already project-owned) |
| `.claude/rules/` | Project | Convention rules (already project-owned) |
| `.ai/lib/` | Project | Utility scripts (already project-owned) |
| `.ai/templates/` | Project | Output templates (already project-owned) |
```

Read each ejected plugin manifest from `.ai/ejected/manifests/` to get the version numbers.

## 7. Summary Report

```markdown
## Eject Complete

### Ejected
| Category | Count | Location |
|----------|-------|----------|
| Claude Code skills | 66 | .claude/skills/ |
| Claude Code agents | 10 | .claude/agents/ |
| Copilot agents | 24 | .github/agents/ |
| Plugin rules | 5 | .ai/ejected/plugin-rules/ |
| Shared files | 8 | .ai/ejected/shared/ |
| Data files | N | .ai/ejected/data/ |
| Templates | N | .ai/ejected/templates/ |
| Manifests | 3 | .ai/ejected/manifests/ |

### Next Steps
1. **Verify skills work:** Run `/dx-help "test"` to confirm local skills load
2. **Uninstall plugins:** `/plugin uninstall dx-core`, `/plugin uninstall dx-aem`, `/plugin uninstall dx-automation`
3. **Commit ejected files:** `git add .claude/skills/ .claude/agents/ .github/ .ai/ejected/ && git commit -m "Eject dx plugins into local repo"`
4. **Update CLAUDE.md:** Note that this project uses ejected (local) skills, not plugins

### Manual Actions
<list any .gitignore issues, missing MCP config, or path reference updates that couldn't be automated>

### What No Longer Works
- `/dx-upgrade` — no plugin directories to pull updates from
- `/dx-doctor` — plugin directory checks will fail
- Plugin auto-updates on `/plugin install` — files are now local

### What Still Works
- All `/dx-*`, `/aem-*`, `/auto-*` skills — loaded from `.claude/skills/`
- All Copilot skills and agents — loaded from `.github/`
- `.ai/config.yaml`, `.ai/rules/`, `.claude/rules/` — unchanged
- `.ai/lib/`, `.ai/templates/` — unchanged
```

## Examples

1. `/dx-eject all` — Ejects all 3 plugins. Copies all skills, agents, templates, and data files. Creates `.ai/ejected/` archive. Reports 3 manifests saved for version tracking.

2. `/dx-eject dx` — Ejects only dx-core. Copies dx skills and agents. AEM and automation plugins remain as plugins.

3. `/dx-eject aem` — Ejects only dx-aem. Copies AEM skills and agents. dx-core stays as a plugin (AEM skills depend on dx skills, which still load from the plugin).

## Troubleshooting

- **"Skills not loading after eject"**
  **Cause:** Plugin is still installed and takes priority, or `.claude/skills/` is gitignored.
  **Fix:** Uninstall the plugin first, then verify `.claude/skills/` is not in `.gitignore`.

- **"Shared file not found" errors in skills**
  **Cause:** Skills reference `shared/` paths that are now at `.ai/ejected/shared/`.
  **Fix:** Step 4 should have updated these references. If missed, manually update the skill's file path references.

- **"dx-doctor fails after eject"**
  **Cause:** Expected — dx-doctor looks for plugin directories which no longer exist.
  **Fix:** Edit `.claude/skills/dx-doctor/SKILL.md` to check `.ai/ejected/` instead of plugin directories. Or remove the dx-doctor skill if not needed.

- **"Want to go back to plugins"**
  **Cause:** Ejecting is one-way, but you can reverse it manually.
  **Fix:** Delete `.claude/skills/`, `.claude/agents/`, `.ai/ejected/`. Reinstall plugins with `/plugin install`. Run `/dx-upgrade all`.

## Rules

- **Confirm before ejecting** — always show the warning and wait for explicit yes
- **Archive everything** — copy plugin originals to `.ai/ejected/` even if already installed elsewhere
- **Never modify .ai/config.yaml** — eject copies files, it doesn't change configuration
- **Never modify .ai/rules/ or .claude/rules/** — these are already project-owned and installed
- **Never modify .ai/lib/ or .ai/templates/** — these are already installed by dx-init
- **Track versions** — save plugin manifests so the team knows what version they ejected from
- **One-way operation** — make this clear to the user; there's no "un-eject"
