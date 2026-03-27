---
name: dx-hub-init
description: Initialize a hub directory for multi-repo orchestration. Discovers sibling repos, merges configs, validates CLI compatibility. Use when setting up hub mode for the first time. Trigger on "init hub", "set up hub", "multi-repo setup".
argument-hint: "[path to hub directory (default: ../.hub)]"
---

You set up a `.hub/` directory that orchestrates work across multiple repos via dx-core hub mode.

## Flow

```dot
digraph hub_init {
    "Validate CLI" [shape=box];
    "CLI compatible?" [shape=diamond];
    "STOP: CLI incompatible" [shape=doublecircle];
    "Determine hub path" [shape=box];
    "Hub already exists?" [shape=diamond];
    "Confirm reinit" [shape=diamond];
    "STOP: User cancelled" [shape=doublecircle];
    "Discover repos" [shape=box];
    "Present repos" [shape=box];
    "User selects repos" [shape=diamond];
    "Build config" [shape=box];
    "Create hub structure" [shape=box];
    "Configure Claude Code settings" [shape=box];
    "Generate CLAUDE.md" [shape=box];
    "Offer workspace file" [shape=diamond];
    "Create .code-workspace" [shape=box];
    "Summary" [shape=doublecircle];

    "Validate CLI" -> "CLI compatible?";
    "CLI compatible?" -> "Determine hub path" [label="yes"];
    "CLI compatible?" -> "STOP: CLI incompatible" [label="no"];
    "Determine hub path" -> "Hub already exists?";
    "Hub already exists?" -> "Confirm reinit" [label="yes"];
    "Hub already exists?" -> "Discover repos" [label="no"];
    "Confirm reinit" -> "Discover repos" [label="yes, reinit"];
    "Confirm reinit" -> "STOP: User cancelled" [label="no"];
    "Discover repos" -> "Present repos";
    "Present repos" -> "User selects repos";
    "User selects repos" -> "Build config" [label="confirmed"];
    "User selects repos" -> "STOP: User cancelled" [label="none selected"];
    "Build config" -> "Create hub structure";
    "Create hub structure" -> "Configure Claude Code settings";
    "Configure Claude Code settings" -> "Generate CLAUDE.md";
    "Generate CLAUDE.md" -> "Offer workspace file";
    "Offer workspace file" -> "Create .code-workspace" [label="yes"];
    "Offer workspace file" -> "Summary" [label="no"];
    "Create .code-workspace" -> "Summary";
}
```

## Node Details

### Validate CLI

Run:
```bash
claude --version
claude -p --help 2>&1 | grep -q 'output-format'
```

Both must succeed. If `claude --version` fails, the CLI is not installed. If `output-format` is absent, the CLI version is too old to support hub dispatch (requires `--output-format` flag for machine-readable output).

Fail with clear message:
```
ERROR: Hub mode requires Claude Code CLI with --output-format support.
  - Install: https://docs.anthropic.com/en/docs/claude-code
  - Minimum version: one that supports `claude -p --output-format`
```

### CLI compatible?

- **yes** — both checks passed → proceed to "Determine hub path"
- **no** — either check failed → go to "STOP: CLI incompatible"

### STOP: CLI incompatible

Print the error message from "Validate CLI". STOP.

### Determine hub path

If the user provided an argument, use it as the hub path. Otherwise default to `../.hub` relative to the current working directory.

Resolve to an absolute path for all subsequent operations:
```bash
HUB_PATH=$(realpath "${ARGUMENT:-../.hub}")
```

Print: `Hub path: $HUB_PATH`

### Hub already exists?

Check if `$HUB_PATH/.ai/config.yaml` exists.

- **yes** — a hub config already exists → go to "Confirm reinit"
- **no** → proceed to "Discover repos"

### Confirm reinit

Print:
```
Hub already exists at $HUB_PATH
Reinitializing will overwrite config.yaml and CLAUDE.md (state/ and existing specs are preserved).
Continue? [y/N]
```

Wait for user input.

- **yes, reinit** → proceed to "Discover repos"
- **no** → go to "STOP: User cancelled"

### STOP: User cancelled

Print: `Hub init cancelled. Existing hub at $HUB_PATH is unchanged.` STOP.

### Discover repos

Scan sibling directories (parent of `$HUB_PATH`) for repos that contain `.ai/config.yaml` with a `scm:` key.

**Strategy 1 — filesystem scan:**
```bash
PARENT=$(dirname "$HUB_PATH")
for dir in "$PARENT"/*/; do
  cfg="$dir/.ai/config.yaml"
  if [ -f "$cfg" ] && grep -q '^scm:' "$cfg"; then
    echo "$dir"
  fi
done
```

For each candidate, read `.ai/config.yaml` and extract:
- `name` — the directory name (basename)
- `scm.project` — ADO project name (may be absent)
- `scm.base-branch` — default branch (may be absent, fallback `main`)

**Strategy 2 — fallback (no siblings found):**
If no siblings are discovered, ask the user:
```
No repos with dx config found in <parent>.
Enter repo paths manually (absolute or relative to hub, comma-separated), or press Enter to abort:
```
Parse the paths and load their configs the same way.

Exclude the hub directory itself from the list.

### Present repos

Display discovered repos as a numbered checklist:
```
Discovered repos with dx config:

  [1] repo-alpha        (branch: develop, project: MyProject)
  [2] repo-beta         (branch: main, project: MyProject)
  [3] repo-gamma        (branch: main, project: OtherProject)

Select repos to include in hub (e.g. 1,2 or all):
```

### User selects repos

Wait for user input.

- **confirmed** — user entered at least one selection → resolve the list and proceed to "Build config"
- **none selected** — user entered nothing, pressed Enter, or typed `0` → go to "STOP: User cancelled"

Accept `all` to include every discovered repo.

### Build config

Merge selected repos into a hub `config.yaml`:

```yaml
hub:
  enabled: true
  auto-dispatch: false
  dispatch-mode: sequential
  state-dir: state/
  state-ttl: 7d

repos:
  - name: <dir-name>
    path: ../<dir-name>
    base-branch: <scm.base-branch from repo config, default: main>
    ado-project: <scm.project from repo config, omit if absent>
```

One entry per selected repo. Paths are relative to the hub directory. No hardcoded org URLs, project names, or credentials.

### Create hub structure

Create the hub directory layout:
```bash
mkdir -p "$HUB_PATH/.ai/specs"
mkdir -p "$HUB_PATH/.ai/rules"
mkdir -p "$HUB_PATH/.claude/rules"
mkdir -p "$HUB_PATH/state"
```

Write `$HUB_PATH/.ai/config.yaml` with the content built in "Build config".

Write `$HUB_PATH/.gitignore`:
```
state/
.ai/specs/
```

**Install hub rules:**

Copy rule templates from the dx-hub plugin's `templates/rules/` directory to `$HUB_PATH/.claude/rules/`:

```bash
for tpl in ${CLAUDE_PLUGIN_DIR}/templates/rules/*.md.template; do
  dest="$HUB_PATH/.claude/rules/$(basename "$tpl" .template)"
  if [ ! -f "$dest" ]; then
    cp "$tpl" "$dest"
  fi
done
```

Strip the `.template` suffix. Do not overwrite existing files (user may have customized them).

Report: "Installed hub rules: <list of rule filenames>"

### Configure Claude Code settings

The hub directory needs Claude Code settings so that plugins and MCP servers are available when the user opens the hub in Claude Code. Read these from the first selected sibling repo — its `.claude/settings.json` was created by `/dx-init`.

**Step 1 — Read sibling settings:**

Pick the first selected repo. Read `<repo-path>/.claude/settings.json`. Extract:
- `extraKnownMarketplaces` — the marketplace source(s)
- `enabledPlugins` — which plugins are enabled
- `enabledMcpjsonServers` — which MCP servers are enabled (if present)

If the first repo has no `.claude/settings.json`, try the next selected repo. If none have it, warn:
```
WARNING: No sibling repo has .claude/settings.json — plugins won't be available in the hub.
Run /dx-init in at least one repo first, then re-run /dx-hub-init.
```
Skip this step (do not create settings files) and continue to "Generate CLAUDE.md".

**Step 2 — Write `.claude/settings.json`:**

Check if `$HUB_PATH/.claude/settings.json` already exists.
- **If it exists on reinit:** Read it and merge — add missing keys but do not overwrite existing values (user may have customized permissions, env, etc.).
- **If it does not exist:** Create it.

Write/merge the following structure:

```json
{
  "plansDirectory": ".ai/specs",
  "env": {
    "COPILOT_CUSTOM_INSTRUCTIONS_DIRS": ".claude/rules"
  },
  "attribution": {
    "commit": "",
    "pr": ""
  },
  "enabledMcpjsonServers": <copied from sibling, or ["ado"] as minimum>,
  "enabledPlugins": <copied from sibling>,
  "extraKnownMarketplaces": <copied from sibling>
}
```

Do NOT copy `permissions` from the sibling — the hub is an orchestrator directory, not a code repo. Let the user build up permissions naturally through Claude Code prompts.

**Step 3 — Write `.claude/settings.local.json`:**

Check if `$HUB_PATH/.claude/settings.local.json` already exists.
- **If it exists:** Do not overwrite. Report "Local secrets file validated".
- **If it does not exist:** Check if the sibling repo has `.claude/settings.local.json`. If yes, copy its `env` block (secrets like `AEM_INSTANCES`, API keys). If no, create a minimal placeholder:

```json
{
  "env": {}
}
```

Report: "Created `.claude/settings.local.json` — add credentials if needed for hub dispatch."

**Step 4 — Create `.mcp.json`:**

The hub needs project-level MCP servers so the user can read tickets, check PRs, and query docs directly from the hub directory. Read the sibling repo's `.mcp.json` and copy relevant servers.

1. Pick the first selected repo. Read `<repo-path>/.mcp.json`.
2. **If it exists:** Copy the full `mcpServers` object. The hub is an orchestration directory — it benefits from having all the same MCP servers (ADO for tickets/PRs, context7 for docs, Atlassian if configured).
3. **If no sibling has `.mcp.json`:** Warn and skip:
   ```
   WARNING: No sibling repo has .mcp.json — MCP tools (ADO, etc.) won't be available in the hub.
   Run /dx-init in at least one repo first, then re-run /dx-hub-init.
   ```

**If `$HUB_PATH/.mcp.json` already exists on reinit:** Read it and merge — add missing server entries but do not overwrite existing ones (user may have customized args, added servers).

Write `$HUB_PATH/.mcp.json`:
```json
{
  "mcpServers": <merged mcpServers from sibling>
}
```

Report: "Created `.mcp.json` — MCP servers: <list of server names>"

### Generate CLAUDE.md

Write `$HUB_PATH/CLAUDE.md`:

```markdown
# Hub — Multi-Repo Orchestrator

This is a hub directory — it contains no code. It orchestrates work
across multiple repos via dx-core hub mode.

## Repos

<!-- populated by dx-hub-init, do not edit manually -->
<list of repo names and paths from config>

## Commands

No build commands. This directory dispatches to repos.

## MCP Servers

ADO MCP is configured — use `mcp__ado__wit_get_work_item` and
`mcp__ado__wit_get_work_items_batch_by_ids` to read tickets directly.

## Specs & Progress

Check sibling repos for dx workflow output:
- Specs live in `<repo-path>/.ai/specs/<ticket-id>-<slug>/`
- See `.claude/rules/hub-orchestration.md` for the full spec directory convention

## Rules

- Never edit code files from this directory
- Use /dx-hub-status to check in-flight work
- Dispatch happens via hub-enabled dx-core skills
- Config lives in `.ai/config.yaml` — edit it to add/remove repos
- See `.claude/rules/` for detailed hub behavior rules
```

Replace the `<list of repo names and paths from config>` placeholder with the actual repo list formatted as:
```
- **repo-alpha** → `../repo-alpha` (branch: develop)
- **repo-beta** → `../repo-beta` (branch: main)
```

### Offer workspace file

Ask:
```
Create a VS Code workspace file at $HUB_PATH/hub.code-workspace?
This lets you open all repos side-by-side in VS Code. [y/N]
```

- **yes** → proceed to "Create .code-workspace"
- **no** → proceed to "Summary"

### Create .code-workspace

Write `$HUB_PATH/hub.code-workspace`:

```json
{
  "folders": [
    { "name": "hub", "path": "." },
    { "name": "<repo-name>", "path": "../<repo-name>" }
  ],
  "settings": {}
}
```

One folder entry per selected repo, plus the hub itself as the first entry. Use the repo directory name as the `name` field.

### Summary

Print:

```markdown
## Hub Initialized

**Location:** $HUB_PATH
**Repos:** <N> repos configured
**Dispatch mode:** sequential
**Workspace file:** <created at hub.code-workspace | not created>

### Files created:
- `.ai/config.yaml` — hub config with repo registry
- `.claude/settings.json` — marketplace, plugins, MCP servers (from sibling repo)
- `.claude/settings.local.json` — local env vars / secrets placeholder
- `.claude/rules/` — hub convention rules
- `.mcp.json` — MCP servers (ADO, context7, etc. from sibling repo)
- `CLAUDE.md` — hub instructions for Claude
- `state/` — runtime dispatch state (gitignored)
- `.gitignore` — ignores state and specs

### Plugins:
- **Marketplace:** <marketplace name from sibling>
- **Enabled:** <list of enabled plugins>
- **MCP servers:** <list of enabled MCP servers>

### Next steps:
- Open $HUB_PATH in Claude Code to use hub mode
- Run `/dx-hub-status` to verify connectivity
- Run `/dx-hub-dispatch` with a ticket ID to start coordinated work
```

## Examples

### Initialize hub with default path
```
/dx-hub-init
```
Scans `..` for sibling repos with dx config, prompts for selection, creates `../.hub/` with merged config, CLAUDE.md, and state directory.

### Initialize hub at a custom path
```
/dx-hub-init /workspace/my-hub
```
Same as above but creates the hub at the specified absolute path.

### Reinitialize an existing hub
```
/dx-hub-init
```
If `../.hub/.ai/config.yaml` already exists, prompts for confirmation before overwriting config and CLAUDE.md. State and existing specs are preserved.

## Troubleshooting

### "CLI incompatible" error
**Cause:** `claude --version` failed or `--output-format` flag is not available in the installed CLI version.
**Fix:** Update Claude Code CLI to the latest version. Hub dispatch relies on `claude -p --output-format json` for machine-readable subagent output.

### No repos discovered
**Cause:** Sibling directories either have no `.ai/config.yaml`, or their config does not contain a `scm:` key.
**Fix:** Run `/dx-init` in each repo first to generate the config. Then re-run `/dx-hub-init`. Alternatively, enter paths manually when prompted.

### Hub already exists — want to add a repo
**Cause:** Re-running init overwrites the full repo list.
**Fix:** Edit `.ai/config.yaml` directly to append a new entry under `repos:`. Follow the existing format (name, path, base-branch, ado-project).

### No plugins available in hub
**Cause:** No sibling repo had `.claude/settings.json` when hub-init ran, so marketplace and plugin settings were not copied.
**Fix:** Run `/dx-init` in at least one sibling repo first, then re-run `/dx-hub-init`. The init reads `extraKnownMarketplaces` and `enabledPlugins` from the first sibling's `.claude/settings.json`.

### Workspace file not opening all repos
**Cause:** Relative paths in `hub.code-workspace` are resolved from the hub directory. If repos moved, paths break.
**Fix:** Edit `hub.code-workspace` to update the `path` values, or re-run `/dx-hub-init` to regenerate it.

## Rules

- **No hardcoded values** — all org names, project names, branch names, and URLs come from `.ai/config.yaml` in each repo
- **Relative paths in config** — repo paths in `hub/config.yaml` are always relative to the hub directory (e.g., `../repo-name`)
- **Preserve state on reinit** — `state/` and `.ai/specs/` are never deleted during reinit
- **CLI check is mandatory** — never skip the CLI compatibility check; hub dispatch will silently fail without it
