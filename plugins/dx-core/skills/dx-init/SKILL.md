---
name: dx-init
description: Set up the dx workflow for a new project. Detects your environment, asks a few questions, and generates .ai/config.yaml plus supporting files. Run this first before using any other dx skill.
argument-hint: "(no arguments — interactive)"
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You configure the dx workflow for the current project by detecting the environment, asking the user a few key questions, and generating `.ai/config.yaml`.

## Re-run Validation Protocol

**CRITICAL: When dx-init is re-run on a project that is already set up, EVERY step MUST execute. NEVER stop early.** If the user chooses "Keep as-is" for config, skip to step 5 and continue through ALL remaining steps (5→6→7→8→9→10→11). Each step validates existing files against plugin data:

| File Category | Re-run Behavior |
|---|---|
| **Config** (config.yaml) | Ask: keep / modify / regenerate |
| **Utility scripts** (audit.sh, stop-guard.sh) | Compare against plugin version → update silently if changed |
| **Template-generated** (README.md, agent.index.md) | Compare against latest template → update if template is newer |
| **Docs** (.ai/docs/) | Removed — plugin docs are public at https://easingthemes.github.io/dx-aem-flow/ |
| **Rule files** (.ai/rules/, .claude/rules/) | Compare against template → if only template changed: update. If user customized: report diff, ask user |
| **User-owned** (me.md) | Never touch — always skip |
| **MCP config** (.mcp.json) | Validate configured values match current project config |

The scaffold script handles utility and rule validation automatically. Template-generated files are validated inline by each step.

## 1. Check Existing Config

Check if `.ai/config.yaml` exists at the project root (use Glob tool).

- **If it exists:** Read and display the current config, then ask: "Config already exists. **(A) Keep as-is**, **(B) Modify**, or **(C) Start fresh**?"
  - If **A**: Say "Config kept. Validating all project files..." — then check if `.ai/config.yaml` has a `preferences:` section with both `auto-commit` and `auto-pr` keys. **If either key is missing:** run **Step 4** (Preferences) to ask the user, then append the `preferences:` section to the existing config.yaml. After that, **CONTINUE to step 5** to validate all generated files, scripts, rules, and templates. **DO NOT stop or exit.** The re-run must validate everything.
  - If **B**: Load existing values as defaults, go to step 2
  - If **C**: Go to step 2 with no defaults
- **If it doesn't exist:** Say "No dx config found. Let's set up your project." Go to step 2.

## 2. Detect Environment

Auto-detect as much as possible before asking the user.

### 2a. Project Type

Use Read tool to check project files (no Bash needed). Check in this order:

| Check | Result |
|-------|--------|
| `pom.xml` with `uber-jar` or AEM dependency | AEM full-stack (Java + Maven) |
| `pom.xml` with `content-package-maven-plugin`, no Java | AEM frontend module (Maven-based) |
| `package.json` + AEM indicators (`aem-clientlib-generator`, `clientlib.config.js`) | AEM frontend module (npm-based) |
| `package.json` + framework (next, nuxt, angular, vue, react) | Frontend standalone |
| `pom.xml` (generic Java/Maven) | Java/Maven project |
| `package.json` (generic) | Node.js project |
| `Cargo.toml` | Rust project |
| `go.mod` | Go project |
| `*.csproj` / `*.sln` (use Glob) | .NET project |

Use Glob to check file existence and Read to inspect contents. No Bash needed for this step.

### 2b. Build Commands

Detect from the project files (use Read tool):

| Source | Build | Test | Lint |
|--------|-------|------|------|
| `pom.xml` | `mvn clean install` | `mvn test` | — |
| `package.json` scripts | `npm run build` | `npm test` | `npm run lint` |
| `Makefile` | `make build` | `make test` | `make lint` |
| `Cargo.toml` | `cargo build` | `cargo test` | `cargo clippy` |
| `go.mod` | `go build ./...` | `go test ./...` | `golangci-lint run` |

Use the first matching entry. Read `package.json` scripts for exact command names (might be `build:prod`, `test:unit`, `lint:fix`, etc.).

### 2c. SCM, Base Branch, ADO Details & Sibling Repos

Run the detection script — this consolidates all git and filesystem detection into a single command:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/detect-env.sh
```

Output is JSON:
```json
{
  "remote_url": "https://dev.azure.com/org/project/_git/repo",
  "scm_provider": "ado",
  "base_branch": "develop",
  "ado_org": "myorg",
  "ado_project": "myproject",
  "sibling_repos": ["sibling-a", "sibling-b"]
}
```

- `scm_provider`: `"ado"` → Azure DevOps, `"github"` → GitHub, `"unknown"` → ask the user
- If the remote URL points to a Bitbucket or Atlassian instance, or if the user selects `jira` when asked: set provider to `jira`
- `base_branch`: `"unknown"` → ask the user
- `ado_org` / `ado_project`: empty if not ADO or extraction failed → ask the user
- `sibling_repos`: if non-empty, ask: "Found these sibling repos: <list>. Are any of these related to this project? (comma-separated numbers, or 'none')"
  - For each selected sibling, store `name`, `path` (default: `../<sibling-name>`), and `role`:
    ```yaml
    repos:
      - name: <sibling-name>
        path: ../<sibling-name>
        role: <role>
    ```

### 2d. Project Name & Prefix

- **Name** — from `pom.xml` artifactId, `package.json` name, or directory name (use Read tool)
- **Prefix** — from component naming patterns found in source (e.g., Java package prefix, CSS class prefix)

## 3. Confirm with User

Present detected values and ask to confirm or correct:

```markdown
## Detected Configuration

| Property | Value |
|----------|-------|
| Project Name | <name> |
| Project Type | <type> |
| Build | `<command>` |
| Test | `<command>` |
| Lint | `<command or "none detected">` |
| SCM | <ADO / GitHub / Bitbucket> |
| Tracker | <ADO / Jira> |
| Organization | <org> |
| Project | <project> |
| Base Branch | <branch> |

**Correct?** Type "yes" or tell me what to change.
```

## 4. Preferences

Ask two separate questions:

**Question 1:**
> **Auto-commit after successful builds?** When enabled, the pipeline automatically commits after build + code review pass.
> 1. **No** — manual commits only (default)
> 2. **Yes** — auto-commit after successful build + review

**Question 2:**
> **Auto-PR after successful pipeline?** When enabled, a PR is automatically created after all phases pass.
> 1. **No** — manual PR creation only (default)
> 2. **Yes** — auto-PR

Map the answers to booleans and carry them into step 5b:
- Question 1: `1 => false`, `2 => true` (store as `AUTO_COMMIT`)
- Question 2: `1 => false`, `2 => true` (store as `AUTO_PR`)

## 5. Generate Files

### 5a. Scaffold directories and static files

Run the scaffold script — this creates all directories and validates/installs static files:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/scaffold.sh
```

This creates:
- `.ai/specs`, `.ai/rules`, `.ai/research`, `.ai/lib`, `.ai/templates`
- `.claude/rules`, `.claude/hooks`
- Copies utility scripts to `.ai/lib/` (audit.sh, dx-common.sh, pre-review-checks.sh, plan-metadata.sh, gather-context.sh, parse-wi-images.sh, ensure-feature-branch.sh, queue-pipeline.sh) with chmod +x
- Copies `stop-guard.sh` to `.claude/hooks/` with chmod +x
- Copies output templates to `.ai/templates/` (spec/, wiki/, ado-comments/)
- Copies shared rule templates to `.ai/rules/`
- Copies universal rule templates to `.claude/rules/`

**On re-run:** The script validates existing files against plugin data:
- **Utility scripts** (.ai/lib/*.sh, stop-guard.sh): updated silently if plugin version changed
- **Rule files**: if file differs from template, reported as `REVIEW` — read the diff and ask the user whether to update or keep their version
- **Missing files**: installed normally

Review the script output. For any `REVIEW` items, read both the existing file and the plugin template, show the user what changed, and ask whether to update.

### 5b. Write .ai/config.yaml

Read `templates/config.yaml.template` from the plugin directory (use Read tool). Fill in the detected/confirmed values by replacing all `{{PLACEHOLDER}}` tokens. Write the result to `.ai/config.yaml` (use Write tool).

Ensure the user preferences from step 4 are persisted in `.ai/config.yaml` under:

```yaml
preferences:
  auto-commit: <true|false>
  auto-pr: <true|false>
```

Populate template placeholders `{{AUTO_COMMIT}}` and `{{AUTO_PR}}` from the step 4 answers.

**Re-run with "Keep as-is" (case A):** If step 1 chose A and step 4 ran only to backfill missing preferences, do NOT regenerate the full config.yaml. Instead, read the existing `.ai/config.yaml` and append the `preferences:` section at the end (before any commented-out sections). Use the Edit tool — do not overwrite the entire file.

If the user selected sibling repos in step 2c, write them under `repos:` (uncommented) with `name`, `path` (default: `../<name>`), and `role` fields. `/aem-init` will later enrich these entries with `platform`, `ado-project`, and `base-branch` fields. If no siblings were selected, leave the `repos:` section commented out as in the template.

#### If tracker provider = jira

Ask the user for:
1. **Jira URL** — the Jira instance URL (e.g., `https://jira.example.com`)
2. **Jira Project Key** — the project key (e.g., `PROJ`)
3. **Jira Deployment** — `server` or `cloud`
4. **Confluence URL** — the Confluence instance URL (often `{base}/wiki`)
5. **Confluence Space Key** — the space key for documentation

Append these sections to `.ai/config.yaml`:

```yaml
tracker:
  provider: jira

jira:
  url: <user input>
  deployment: <server or cloud>
  project-key: <user input>
  child-issue-type: Sub-task
  custom-fields:
    acceptance-criteria: ''
    story-points: story_points

confluence:
  url: <user input>
  space-key: <user input>
  doc-root: ''
  pr-review-root: ''
```

Print: "Add `JIRA_PERSONAL_TOKEN` and `CONFLUENCE_PERSONAL_TOKEN` to your `.claude/settings.local.json` env block or shell profile."

### 5c. (Removed — .ai/README.md and agent-index.md no longer generated)

Plugin documentation is public at https://easingthemes.github.io/dx-aem-flow/ — no need to copy docs into each consumer project.

### 5d-bis. Generate AGENTS.md

Generate `AGENTS.md` at the project root for Copilot CLI agent discovery. This file lists all available agents with descriptions and invocation syntax.

**If `AGENTS.md` already exists:** Read it. Check if any installed agents are missing from the table (compare against `.github/agents/` directory). If missing agents found, append them. If up to date, skip.

**If `AGENTS.md` does not exist:** Scan `.github/agents/*.agent.md` files (use Glob). For each file, extract `name` and `description` from the YAML frontmatter. Generate a markdown file with categorized agent tables:

```markdown
# Agents

Available AI agents for this project. Invoke with `@AgentName` in Copilot CLI or as subagents in Claude Code.

| Agent | Description | Invoke |
|-------|-------------|--------|
| <name> | <first 80 chars of description> | `@<name>` |
```

Group agents by prefix: `Dx*` agents under "Development Workflow", `AEM*` agents under "AEM". Write to `AGENTS.md` at project root using Write tool.

### 5e. Create .ai/me.md

Create `.ai/me.md` with a demo template if it does not already exist (use Glob to check, Write tool to create). This file describes the developer's personal communication style — used by `dx-pr-answer` to match tone and persona in PR replies.

If `.ai/me.md` already exists → skip, report "already exists".

Content to write:

```markdown
# About Me

## Tone & Personality
<Describe your default communication style — e.g., casual and direct, or formal and thorough>

## Language
<Your preferred language, sentence length, vocabulary style>

## Communication Patterns
<How you structure replies — bullets vs prose, emoji usage, greetings>

## Context
<Your role, seniority, team context — helps calibrate technical depth>
```

### 5f. Add .ai/ to .gitignore (if needed)

Read `.gitignore` (use Read tool) and check if it already handles `.ai/` or `.ai/specs/`. If not, suggest adding:

```
# dx workflow
.ai/specs/
.ai/run-context/
.ai/research/
.ai/me.md
```

Do NOT auto-modify `.gitignore` — ask the user first.

### 5g. Configure ADO MCP Server

If `scm.provider` is `ado` and an ADO organization was detected/confirmed:

1. **Check if `.mcp.json` exists** at the project root (use Glob tool).

2. **If it exists:** Read it and check if an ADO MCP server is already configured (any entry in `mcpServers` whose `args` array contains `@azure-devops/mcp`).
   - **If ADO MCP already configured:** Validate the org name in `args` matches the current `scm.org`. If it differs, ask the user: "ADO MCP org is `<old>` but config says `<new>`. **(A) Update**, **(B) Keep**." Report "ADO MCP validated" or "ADO MCP updated".
   - **If ADO MCP not configured:** Read the existing JSON, add the `ado` entry to `mcpServers`, write back (use Write tool). Report "Added ADO MCP server to existing .mcp.json".

3. **If `.mcp.json` does not exist:** Create it with just the ADO MCP server (use Write tool).

The ADO MCP server entry (use the confirmed `scm.org` value — just the org name, not the full URL):

```json
{
  "mcpServers": {
    "ado": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@azure-devops/mcp", "<ado_org>"]
    }
  }
}
```

Where `<ado_org>` is the organization name extracted from `scm.org` (e.g., if `scm.org` is `https://myorg.visualstudio.com/`, use `myorg`; if `scm.org` is already just `myorg`, use it as-is).

**If SCM is not ADO** (GitHub or other): Skip this step entirely.

### 5g-bis. Configure Atlassian MCP Server

If `tracker.provider` is `jira`:

1. Check if `.mcp.json` exists at the project root.
2. If it exists, check if an `atlassian` entry already exists in `mcpServers`.
   - If exists: validate URLs match config. Report "Atlassian MCP validated".
   - If not: add the entry. Report "Added Atlassian MCP server".
3. If `.mcp.json` does not exist: create it.

The Atlassian MCP server entry:
```json
{
  "mcpServers": {
    "atlassian": {
      "command": "uvx",
      "args": ["mcp-atlassian"],
      "env": {
        "JIRA_URL": "<jira.url from config>",
        "JIRA_PERSONAL_TOKEN": "${JIRA_PERSONAL_TOKEN}",
        "CONFLUENCE_URL": "<confluence.url from config>",
        "CONFLUENCE_PERSONAL_TOKEN": "${CONFLUENCE_PERSONAL_TOKEN}",
        "TOOLSETS": "jira_issues,jira_comments,jira_transitions,jira_projects,jira_agile,jira_fields,jira_links,confluence_pages,confluence_comments,confluence_labels"
      }
    }
  }
}
```

**If both ADO code repos AND Jira tracker are used:** Both `ado` and `atlassian` entries should exist in `.mcp.json`. Do NOT remove the ADO entry when adding Atlassian.

### 5g-ter. Generate VS Code MCP Config

VS Code Chat reads MCP servers from `.vscode/mcp.json` — it does NOT read the root `.mcp.json`. The format also differs: VS Code uses `"servers"` (not `"mcpServers"`).

After generating/updating `.mcp.json` in steps 5g/5g-bis, mirror the same servers to `.vscode/mcp.json`:

1. **Check if `.vscode/mcp.json` exists** (use Glob tool).
2. **If it exists:** Read it. For each server in the root `.mcp.json`, check if a matching entry exists under `"servers"`. Add any missing entries. Do NOT remove existing VS Code-only entries (e.g., Playwright, BrowserMCP).
3. **If it does not exist:** Create it.

Convert the format: root `.mcp.json` uses `"mcpServers": {}`, VS Code uses `"servers": {}`. The server entries themselves are identical.

Example — if root `.mcp.json` has:
```json
{ "mcpServers": { "ado": { "type": "stdio", "command": "npx", "args": ["-y", "@azure-devops/mcp", "<org>"] } } }
```

Then `.vscode/mcp.json` should have:
```json
{ "servers": { "ado": { "type": "stdio", "command": "npx", "args": ["-y", "@azure-devops/mcp", "<org>"] } } }
```

Same for Atlassian if present. Report "VS Code MCP config synced" or "Created .vscode/mcp.json".

### 5g-quater. Configure VS Code Chat Settings

VS Code Chat needs explicit settings to discover project instructions and plugin skills. After syncing MCP config (step 5g-ter), ensure `.vscode/settings.json` has the required Chat settings.

1. **Check if `.vscode/settings.json` exists** (use Glob tool).
2. **If it exists:** Read it. Check if `chat.instructionsFilesLocations` and `chat.agentSkillsLocations` are present. Add any missing keys — do NOT overwrite existing settings.
3. **If it does not exist:** Create it with the settings below.

Required settings:
```json
{
  "chat.instructionsFilesLocations": {
    ".claude/rules": true,
    ".github/instructions": true
  },
  "chat.agentSkillsLocations": {
    ".claude/skills": true
  },
  "chat.subagents.allowInvocationsFromSubagents": true
}
```

When merging into an existing file, preserve all existing keys (formatOnSave, editor settings, etc.) — only add the Chat-specific keys if missing.

Report "VS Code Chat settings configured" or "VS Code Chat settings already present".

### 5h. Ensure Attribution Settings

Check if `.claude/settings.json` exists (use Glob tool).

1. **If it exists:** Read it and check if `"attribution"` key is present at the top level.
   - **If attribution exists:** Report "Attribution settings validated" — no changes needed.
   - **If attribution is missing:** Parse the existing JSON, add the `attribution` object, write back (use Write tool). Report "Added attribution settings to `.claude/settings.json`".

2. **If `.claude/settings.json` does not exist:** Read the template from `templates/claude-code/settings.json.template` (use Read tool). Merge with attribution settings and write to `.claude/settings.json` (use Write tool).

The resulting file should include attribution (disables Claude's default co-author footer) and dx defaults:

```json
{
  "plansDirectory": ".ai/specs",
  "attribution": {
    "commit": "",
    "pr": ""
  },
  "permissions": {
    "allow": [
      "Read",
      "Glob",
      "Grep",
      "Bash(npm run *)",
      "Bash(git *)"
    ]
  }
}
```

When adding to an existing file, merge new keys into the existing JSON object — do not overwrite existing settings (permissions, hooks, etc.).

### 5i. Create Local Secrets File

Check if `.claude/settings.local.json` exists (use Glob tool).

1. **If it exists:** Read it and verify it has an `"env"` key. Report "Local secrets file validated" — do not overwrite user values.

2. **If it does not exist:** Create `.claude/settings.local.json` with placeholder env vars. This file is auto-gitignored by Claude Code and stores per-project secrets as environment variables.

```json
{
  "env": {
    "QA_BASIC_AUTH_USER": "",
    "QA_BASIC_AUTH_PASS": "",
    "QA_BASIC_AUTH_FALLBACK_USER": "",
    "QA_BASIC_AUTH_FALLBACK_PASS": "",
    "AXE_API_KEY": ""
  }
}
```

If `tracker.provider` is `jira`, also include Jira/Confluence tokens in the placeholder env vars:

```json
{
  "env": {
    "JIRA_PERSONAL_TOKEN": "",
    "CONFLUENCE_PERSONAL_TOKEN": ""
  }
}
```

Report: "Created `.claude/settings.local.json` — add your credentials before using QA/accessibility skills."

Print env var guidance:
```
Environment variables can be set in two ways (either works for Claude Code):
  1. Shell profile (~/.bashrc or ~/.zshrc) — required for Copilot CLI compatibility
  2. .claude/settings.local.json "env" block — Claude Code only, per-project

Recommendation: use shell exports for machine-wide vars, settings.local.json for project-specific secrets.
```

> **Note:** AEM-specific env vars (`AEM_INSTANCES`) are added by `/aem-init` if the project is AEM.

**On re-run:** If the file exists, check for missing env var keys from the template above. If new keys were added by a plugin update, merge them in (empty string value) without overwriting existing values.

## 6. Detect Project Profile

Run `dx-adapt` detection inline — **Phases 1–3 only**. This detects the project type, extracts build commands and AEM values, confirms with the user, and saves the profile into `.ai/config.yaml`.

Since the `project:` section in `.ai/config.yaml` does not exist yet at this point, skip adapt's Phase 0 existence check entirely — go directly to Phase 1 (detect).

Run adapt Phases 1–3:
- **Phase 1** — detect project type and extract build commands, source roots, AEM values
- **Phase 2** — confirm detected values with the user (one confirmation table)
- **Phase 3** — save detected profile into `.ai/config.yaml`

**Stop here** — do NOT run Phase 4 (value substitution) or Phase 5 (report) yet. Those run in step 8 after AEM setup.

## 7. AEM Setup (conditional)

After the profile is saved to `.ai/config.yaml`, check the detected project type:

**If project type is `aem-fullstack` or `aem-frontend`:**

1. Check if the aem plugin is available — use Glob to search for `plugins/dx-aem/skills/aem-init/SKILL.md` or `skills/aem-init/SKILL.md` relative to the aem plugin location. Also check if aem skill files are accessible from the plugin system.

2. **If aem plugin is available:**
   - Print: "AEM project detected. Running AEM setup..."
   - Run the `/aem-init` flow inline, executing these steps from aem-init:
     - **Step 1** (Check Prerequisites) — `.ai/config.yaml` exists (already confirmed). If `aem:` section exists, ask whether to keep/modify/regenerate as normal.
     - **Step 2** (Detect AEM Structure) — find component paths, module structure, frontend structure, brands
     - **Step 3** (Ask AEM URL) — author URL, QA URL
     - **Step 4** (Confirm) — present detected AEM values
     - **Step 5** (Append to Config) — add `aem:` section to `.ai/config.yaml`
     - **Step 6** (Generate Component Index) — optional scan
     - **Step 7** (Extend Shared Rules) — append AEM/Sling patterns to `.ai/rules/pr-review.md` and `.ai/rules/pr-answer.md`
     - **Step 8c** (Copy rule templates) — install AEM convention rules to `.claude/rules/` (and `.github/instructions/` if Copilot enabled in step 9)
     - **Step 8g** (Report) — show what was installed
   - **Skip these aem-init steps** (handled by dx-init step 9 instead):
     - Step 8a (Copilot question) — dx-init asks this in step 9
     - Step 8b (mkdir for Copilot) — handled in step 9
     - Step 8e (AEM Copilot agents) — installed in step 9
     - Step 8f (copilot-instructions.md update) — handled in step 9
   - Set `COPILOT_ENABLED=false` for step 8c — dx-init handles Copilot output in step 9 instead. If the user enables Copilot in step 9, rule templates are also copied to `.github/instructions/`.
   - **Skip aem-init step 9** (Confirm) — the dx-init step 10 shows a combined summary.

3. **If aem plugin is NOT available:**
   - Print: "AEM project detected but the aem plugin is not installed. Install it and run `/aem-init` to get AEM coding conventions."
   - Continue to step 8.

**If project type is NOT `aem-fullstack` or `aem-frontend`:**

Skip this step entirely.

## 8. Finalize Rules

**DO NOT SKIP THIS STEP.** This must run after Step 7 (AEM setup) and before Step 9 (Copilot). It filters rules by project type and verifies project-specific values were applied.

### 8a. Filter rules by project type

Read `project.type` from `.ai/config.yaml`, then:

| Project Type | Action |
|---|---|
| `aem-fullstack` | Keep all rules. No deletions. |
| `aem-frontend` | Delete all `be-*.md` files from `.claude/rules/` (keep `fe-*.md`, `accessibility.md`, `naming.md`) |
| `frontend` | Delete all `be-*.md` and `fe-clientlibs.md` from `.claude/rules/` (keep `accessibility.md`, `naming.md`) |
| `java` | Delete all `fe-*.md` files from `.claude/rules/` (keep `be-*.md`, `accessibility.md`, `naming.md`) |

Use Glob to list `.claude/rules/be-*.md` and `.claude/rules/fe-*.md`, then delete the ones that don't apply. If no files match the deletion criteria, report "no rules to filter".

### 8b. Verify project values in rules

Read each `.claude/rules/*.md` file that was written in Step 7. Verify that project-specific values from `.ai/config.yaml` are present (not generic placeholders). Check for:

- Java package name (should match `aem.java-package` from config.yaml `aem:` section)
- Component path (should match `aem.component-path` from config.yaml `aem:` section)
- Component group (should match `aem.component-group` from config.yaml `aem:` section)

If any file still contains generic examples (`myproject`, `<prefix>`, `<package>`) instead of real values, substitute them with values from `.ai/config.yaml` (`aem:`, `toolchain:`, and `project:` sections).

### 8c. Report

Print a summary:

```markdown
### Rules Finalized
- **Kept:** <list of .claude/rules/ files kept>
- **Deleted:** <list deleted, or "none">
- **Values verified:** <count> files checked, <count> substitutions made (or "all correct")
```

### 8d. Install cross-repo coordination rule (if multi-repo)

Read `.ai/config.yaml`. If the `repos:` section does not exist or is empty → **skip this step entirely** and move to Step 9.

If a `repos:` section exists with at least one entry:

1. Read `plugins/dx-core/templates/rules/cross-repo.md.template` (use Read tool).
2. Build `{{REPOS_TABLE}}` from config:
   - First row: current repo — name from `project.name`, role from `project.role`, platform from `aem.platform` (if set, otherwise "—"), base branch from `scm.base-branch`
   - Remaining rows: each entry in `repos:` section — name, role, platform (if set, otherwise "—"), base-branch (if set, otherwise "—")

   Format:
   ```markdown
   | Repo | Role | Platform | Base Branch |
   |---|---|---|---|
   | {project.name} (this repo) | {project.role} | {aem.platform or —} | {scm.base-branch} |
   | {repos[0].name} | {repos[0].role} | {repos[0].platform or —} | {repos[0].base-branch or —} |
   | ... | ... | ... | ... |
   ```

3. Replace `{{REPOS_TABLE}}` in the template content with the generated table.
4. Apply smart-update logic (same as Step 8c in aem-init):
   - If `.claude/rules/cross-repo.md` exists and is identical to the generated content → skip, report "cross-repo.md up to date"
   - If `.claude/rules/cross-repo.md` exists but differs, AND user has not customized it (differs from template in the same way) → update silently, report "cross-repo.md updated"
   - If `.claude/rules/cross-repo.md` exists and user has customized it → show diff, ask: **(A) Keep yours**, **(B) Use updated version**, **(C) Merge manually**
5. Write the result to `.claude/rules/cross-repo.md` (use Write tool).

## 9. Copilot Support (optional)

Ask:
> **Support GitHub Copilot?** When enabled, Copilot agent definitions and instructions are generated alongside Claude Code for developers using Copilot Chat across supported development environments (VS Code, JetBrains IDEs...).
> 1. **No** — Claude Code only (default)
> 2. **Yes** — generate `.github/agents/` and `copilot-instructions.md`

If **No**, skip to step 10.

If **Yes**:

### 9a. Install dx agent templates

Run the Copilot agent install script — this batch-copies all dx agent templates in a single command:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/install-copilot-agents.sh
```

This copies all `*.agent.md.template` files from the dx plugin's `templates/agents/` to `.github/agents/` (stripping `.template` suffix), applies post-copy transforms (editFiles→edit, chrome-devtools→chrome-devtools-mcp, allowed-tools injection). Files that already exist are skipped. Review the script output to report what was installed vs skipped.

### 9a-bis. Set COPILOT_CUSTOM_INSTRUCTIONS_DIRS

Read `.claude/settings.json`. If no `env.COPILOT_CUSTOM_INSTRUCTIONS_DIRS` exists, add it:

```json
{
  "env": {
    "COPILOT_CUSTOM_INSTRUCTIONS_DIRS": ".claude/rules"
  }
}
```

This tells Copilot CLI (v1.0.6+) to read rules from `.claude/rules/` directly — the same location Claude Code uses. No `.github/instructions/` copies needed. Rules with dual frontmatter (`paths:` for Claude Code, `applyTo:` for Copilot CLI) work in both tools from a single source.

### 9b. Install AEM agent templates (if AEM was set up in step 7)

If step 7 ran aem-init successfully, also install AEM Copilot agents:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/install-copilot-agents.sh "$AEM_PLUGIN_DIR"
```

Where `$AEM_PLUGIN_DIR` is the path to the aem plugin root (resolve from the aem skill files found in step 7). This installs AEM agent templates (`AEMBefore.agent.md`, `AEMAfter.agent.md`, etc.) to `.github/agents/`.

> **Note:** `.github/instructions/` copies are no longer needed. Copilot CLI reads rules directly from `.claude/rules/` via `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` env var (set in step 9a-bis). If the directory exists from a previous install, leave it — Copilot reads both locations.

### 9c. Generate copilot-instructions.md

Read `templates/copilot-instructions.md.template` from the plugin directory (use Read tool). Replace `{{PROJECT_NAME}}` with the confirmed project name. Write to `.github/copilot-instructions.md` (use Write tool).

If it already exists, ask: **(A) Keep existing**, **(B) Replace**, **(C) Write as `.template`** (user can diff manually).

### 9d. Append AEM agents to copilot-instructions.md (if AEM was set up)

If step 7 ran aem-init and `.github/copilot-instructions.md` exists, append the AEM agents section:

```markdown

## AEM Agents

| Agent | Purpose | Invoke |
|-------|---------|--------|
| AEMBefore | Pre-development baseline snapshot | `@AEMBefore <component>` |
| AEMAfter | Post-deployment verification | `@AEMAfter <component>` |
| AEMSnapshot | Component inspection | `@AEMSnapshot <component>` |
| AEMDemo | Dialog screenshot + authoring guide | `@AEMDemo <component>` |
| AEMComponent | Find pages using a component | `@AEMComponent <component>` |
| AEMVerify | Bug verification on AEM | `@AEMVerify <component>` |
```

Check if the section already exists before appending (idempotent).

### 9e. Generate .github/README.md

Read `templates/github-readme.md.template` from the plugin directory (use Read tool). Replace `{{PROJECT_NAME}}`. Write to `.github/README.md` (use Write tool).

If it already exists, ask same as 9c.

### 9f. Append Copilot section to agent.index.md

Read `agent.index.md`. If it does not already contain `## Copilot Agents`, append before the `## Not Agent Files` line:

```markdown

## Copilot Agents

| Path | What | Committed |
|------|------|-----------|
| `.github/agents/` | VS Code Copilot agent definitions | Yes |
| `.github/instructions/` | Copilot path-scoped instruction files | Yes |

### Agents (orchestrators)

| Agent | Purpose |
|-------|---------|
| `@DxPlanExecutor` | Execute plan steps |
| `@DxCodeReview` | Full code review |
| `@DxReqAll` | Full requirements workflow |
| `@DxStepAll` | Full execution loop |
| `@DxBugAll` | Full bug fix workflow |
| `@DxAgentAll` | End-to-end pipeline |
| `@DxPRReview` | PR review |
| `@DxPRAnswer` | Answer PR comments |
| `@DxPRFix` | Fix PR review issues |
| `@DxCommit` | Commit + PR |
| `@DxTicket` | Ticket research |
| `@DxComponent` | Component lookup |
| `@DxHelp` | Workflow Q&A |
| `@DxDebug` | Debug failures |
```

If AEM was set up in step 7, also append the AEM agents to the same table.

### 9g. Report

```markdown
### Copilot Files
**dx Agents:** <N> written to `.github/agents/`, <N> skipped
<If AEM:> **AEM Agents:** <N> written to `.github/agents/`, <N> skipped
**Instructions:** `.github/copilot-instructions.md` <written|skipped>
```

### 9h. Generate AGENTS.md at repo root

Create `AGENTS.md` at the project root for Copilot CLI agent discovery. This file lists all available agents with invocation syntax.

Use Glob to find all `.github/agents/*.md` files. For each, read the frontmatter `description` field. Build a markdown table:

```markdown
# Agents

Available agents for this project. Use `@AgentName` to invoke in Copilot CLI.

| Agent | Description |
|-------|-------------|
```

Populate the table dynamically from the discovered agent files. The agent name is the filename without `.agent.md` suffix.

If `AGENTS.md` already exists, compare and update silently if content has changed.

### 9i. Install hooks for Copilot CLI

Deploy plugin hooks to `.github/hooks/` so Copilot CLI gets the same safety and convenience hooks as Claude Code.

```bash
mkdir -p .github/hooks
```

Copy `templates/hooks/branch-guard-hooks.json.template` to `.github/hooks/hooks.json`.

The template includes:
- **PreToolUse** — branch guard (prevents commits on main/master/develop)
- **SessionStart** — config validation + next-step suggestions
- **PostToolUse Edit** — validates plugin file edits

If `.github/hooks/hooks.json` already exists, merge new hooks into the existing file — do not overwrite hooks that are already present. Match by event type + matcher to detect duplicates.

## 10. Confirm

After writing, display:

```markdown
## dx Initialized

**Project:** <name> (<project type from config.yaml>)
**Config:** `.ai/config.yaml` (project config + build commands + module structure)
**Rules:** `.ai/rules/` (<N> shared rules installed)
**Attribution:** `.claude/settings.json` — commit/PR attribution disabled
**Secrets:** `.claude/settings.local.json` — local env vars for QA auth, API keys (gitignored)
<If ADO:> **MCP:** `.mcp.json` — ADO MCP server configured (org: `<ado_org>`)
<If Jira:> **Tracker:** Jira (project: `<project-key>`, deployment: `<server|cloud>`)
<If Jira:> **Wiki:** Confluence (space: `<space-key>`)
<If Jira:> **MCP:** `.mcp.json` — Atlassian MCP server configured

<If AEM:>
**AEM:** configured (component path: `<path>`, prefix: `<prefix>`)
**AEM Rules:** `.claude/rules/` (<N> AEM convention rules installed)

### Build Commands
| Command | Value |
|---------|-------|
| Full build | `<build.full>` |
| Test | `<build.test>` |
| Lint | `<build.lint or "—">` |

### Directory Structure
```
agent.index.md         ← AI setup entry point (all paths, all agents)
.ai/
├── config.yaml        ← project configuration + build commands + module structure
├── README.md          ← workflow quick reference
├── me.md              ← personal tone/style for PR replies (gitignored)
├── rules/             ← shared rules (dx skills + automation agents)
├── specs/             ← generated spec documents
└── research/          ← saved research results
```

<If Copilot enabled:>
```
.github/
├── copilot-instructions.md  ← Copilot master instructions
├── README.md                ← Copilot config overview
├── agents/                  ← Copilot agent definitions (orchestrators)
│   ├── DxCodeReview.agent.md
│   ├── DxPlanExecutor.agent.md
│   ├── DxReqAll.agent.md
│   ├── DxStepAll.agent.md
│   ├── DxBugAll.agent.md
│   ├── DxAgentAll.agent.md
│   ├── DxPRReview.agent.md
│   ├── DxPRAnswer.agent.md
│   ├── DxPRFix.agent.md
│   ├── DxCommit.agent.md
│   ├── DxTicket.agent.md
│   ├── DxComponent.agent.md
│   ├── DxHelp.agent.md
│   ├── DxDebug.agent.md
<If AEM + Copilot:>
│   ├── AEMBefore.agent.md
│   ├── AEMAfter.agent.md
│   ├── AEMSnapshot.agent.md
│   ├── AEMDemo.agent.md
│   ├── AEMComponent.agent.md
│   └── AEMVerify.agent.md
```

> **Quality scales with context:** The dx plugins provide workflow orchestration and convention templates. Your project provides context — `config.yaml`, `.claude/rules/` customizations. Extend the installed rule templates with project-specific patterns (brand naming, component variants, accessibility guards). The richer your project context, the better AI output quality.

### Next Steps
<If ADO:> - Start working: `/dx-req <ADO work item ID>`
<If Jira:> - Start working: `/dx-req <Jira issue key, e.g. PROJ-123>`
- Full pipeline: `/dx-agent-all <ID>`
- Re-detect project profile: `/dx-adapt` (re-run anytime if structure changes)
<If AEM:>
- AEM component lookup: `/aem-component <name>`
- AEM baseline snapshot: `/aem-snapshot <name>`
<If Copilot enabled:>
- VS Code Copilot agents: `@DxCodeReview`, `@DxReqAll`, `@DxAgentAll`, etc.
<If AEM + Copilot:>
- AEM Copilot: `@AEMBefore`, `@AEMAfter`, `@AEMSnapshot`, etc.
```

## 11. Offer AI Automation

Ask:

> **Set up AI automation?** Deploys ten autonomous agents (DoR checker, DoD checker, DoD fixer, PR reviewer, PR answerer, BugFix agent, QA agent, DevAgent, DOCAgent, Estimation) as ADO pipelines triggered by AWS Lambda webhooks. Requires the `automation` plugin installed plus AWS CLI and Azure CLI configured.
>
> 1. **Yes** — scaffold now (run `/auto-init` inline)
> 2. **Skip** — set up later with `/auto-init`

If **Yes**: run the full `auto-init` flow inline (Phases 0–3). Then append the automation section to `agent.index.md` — read the file, and if it does not already contain `## CI/CD Pipeline Agents`, insert before `## Not Agent Files`:

```markdown

## CI/CD Pipeline Agents

| Path | What | Committed |
|------|------|-----------|
| `.ai/automation/` | CI/CD automation — pipeline agents, Lambda handlers, eval framework | Yes |

| Agent | Trigger |
|-------|---------|
| DoR (Definition of Ready) | Tag work item |
| DoD (Definition of Done) | Tag work item |
| PR Review | PR created/updated |
| PR Answer | Comment on your PR |
| BugFix | Tag bug ticket |
| QA | Tag work item |
| DevAgent | Tag work item |
| DOCAgent | Tag work item |
```

If **Skip**: note in the Next Steps block:
```
- `/auto-init` — Add autonomous AI agents (DoR, PR review, PR answer) running via ADO + Lambda
```

## Examples

1. `/dx-init` — First run on a new repo. Detects Maven + Node 10 + AEM project structure, asks about ADO project and base branch, generates `.ai/config.yaml` with build commands, SCM settings, and branch conventions. Scaffolds `.claude/rules/` from plugin templates and offers to run `/aem-init`.

2. `/dx-init` (re-run on existing project) — Detects that `.ai/config.yaml` already exists. Validates each section against current project state, finds that `build.frontend` command was missing, and adds it. Updates `.claude/rules/` files that have new template versions while preserving user customizations.

3. `/dx-init` (non-AEM project) — Detects a React + TypeScript project with `npm run build` and `npm test`. Skips AEM-specific detection, generates config with frontend-only build commands, and scaffolds JavaScript/TypeScript convention rules.

## Troubleshooting

- **"`.ai/config.yaml` already exists — overwrite?"**
  **Cause:** You ran `/dx-init` on a project that was already initialized.
  **Fix:** Choose "validate and update" to keep existing config and only fix outdated values. Choose "overwrite" only if the config is corrupted or you want a fresh start.

- **Build commands not detected correctly**
  **Cause:** The project uses a non-standard build tool or the build scripts are in an unusual location.
  **Fix:** Answer "no" when asked to confirm detected commands, then provide the correct commands manually. They will be saved to `.ai/config.yaml` under `build:`.

- **AEM detection triggers but project is not AEM**
  **Cause:** The project has a `pom.xml` or `ui.frontend/` directory that resembles AEM structure.
  **Fix:** When asked "Is this an AEM project?", answer "no" to skip AEM-specific configuration. You can always run `/aem-init` later if needed.

## Rules

- **Interactive — use AskUserQuestion** — Every question, confirmation, or choice in this skill MUST use the `AskUserQuestion` tool to pause and wait for the user's response. Never proceed past a question without receiving the user's answer first. Present numbered options in the question text, then STOP and wait. Do not batch multiple questions into one message — ask one, wait for the answer, then continue.
- **Detect first, ask second** — auto-detect everything possible, then confirm
- **Minimal questions** — don't ask what you can detect
- **Never overwrite config** — if `.ai/config.yaml` exists, ask before replacing
- **Validate on re-run** — every step executes on re-run; validate existing files against plugin data, smart-update what's outdated, ask when in doubt
- **No project-specific data** — no brand lists, market tables, component indexes (those belong in project-specific extensions like an AEM plugin)
- **Templates are the source of truth** — always Read template files from `templates/` directory, never hardcode file contents
- **Gitignore is sacred** — suggest changes, never auto-modify
- **Prefer Read/Write/Glob tools over Bash** — use Bash only for the consolidated scripts (`detect-env.sh`, `scaffold.sh`, `install-copilot-agents.sh`); use Read tool for templates, Write tool for output files, Glob tool for existence checks
- **AEM auto-chain** — when AEM is detected, run aem-init inline between adapt Phase 3 and Phase 4 so that AEM rules are installed before value substitution runs
