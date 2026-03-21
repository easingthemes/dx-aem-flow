---
name: dx-upgrade
description: Upgrade consumer project to latest plugin versions — runs dx-doctor, then fixes stale files, installs missing files, and reports what needs manual action. Use after upgrading plugins.
argument-hint: "[dx|aem|auto|all]"
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You upgrade a consumer project's dx workflow files to match the latest installed plugin versions. You diagnose first (dx-doctor), then fix issues with smart handling of user-customized files.

## Tool Usage Rules

- **File existence:** Use `Glob` — never `[ -f ]`, `test -f`, or Bash test commands
- **File content reads:** Use `Read` — never `cat` or `head` in Bash
- **File writes:** Use `Write` — never `echo >` or `cat <<EOF` in Bash
- **Content comparison:** Read both files with `Read`, compare in-context — never shell `diff`
- **Bash is ONLY for:** `chmod +x` on scripts, `bash` to run install scripts (steps 3e), and `git` commands
- **Parallel operations:** Call multiple `Read`/`Write`/`Glob` tools in parallel when independent — do not serialize into one Bash command with `&&`/`||`

## 0. Run dx-doctor

Run the full `/dx-doctor` flow inline with the same scope argument the user passed. Collect all issues into three categories:

| Category | Description | Examples |
|----------|-------------|---------|
| **Auto-fix** | Plugin-owned files that can be updated without asking | Stale utility scripts, stale seed data, stale universal rules, missing template-generated files |
| **Needs confirmation** | Files the user may have intentionally customized | Stale shared rules (`.ai/rules/*`), stale AEM convention rules |
| **Manual action** | Issues that cannot be auto-fixed | Missing gitignore entries, missing config sections, broken branch references |

If dx-doctor reports zero issues:
```
✓ All checks passed. Nothing to upgrade.
```
STOP.

## 1. Present Fix Plan

Before applying any fixes, present a summary table for each category:

```markdown
## Upgrade Plan

### Auto-fix (no confirmation needed)
| File | Issue | Fix |
|------|-------|-----|
| .ai/lib/audit.sh | stale | Update from plugin |
| .ai/project/component-index.md | stale | Update from plugin data |
| .github/agents/ | 4 new, 2 stale | Install new + update stale from templates |

### Needs confirmation
| File | Issue | Action |
|------|-------|--------|
| .ai/rules/pr-answer.md | stale | Show diff, ask |
| .claude/rules/be-components.md | stale | Show diff, ask |

### Manual action required
| Issue | Suggested Fix |
|-------|--------------|
| .ai/run-context/ not in .gitignore | Add to .gitignore manually |
| Missing project seed data | Run /aem-init or /aem-refresh |
```

Ask: **Proceed with auto-fixes?** (the confirmation items will be handled one-by-one next)

If the user declines, STOP.

## 2. Resolve Plugin Directories

Find each plugin root directory (same method as dx-doctor):

- **dx plugin:** Glob for `**/skills/dx-doctor/SKILL.md`, navigate up 3 levels
- **aem plugin:** Glob for `**/skills/aem-init/SKILL.md`, navigate up 3 levels
- **auto plugin:** Glob for `**/skills/auto-init/SKILL.md`, navigate up 3 levels

## 3. Apply Auto-fixes

These are plugin-owned files — update without asking.

### 3a. Utility Scripts

For each stale or missing script:

| Installed | Plugin Source | Post-copy |
|-----------|-------------|-----------|
| `.ai/lib/audit.sh` | `<dx-plugin>/data/lib/audit.sh` | `chmod +x` |
| `.ai/lib/dx-common.sh` | `<dx-plugin>/data/lib/dx-common.sh` | `chmod +x` |
| `.ai/lib/pre-review-checks.sh` | `<dx-plugin>/data/lib/pre-review-checks.sh` | `chmod +x` |
| `.ai/lib/plan-metadata.sh` | `<dx-plugin>/data/lib/plan-metadata.sh` | `chmod +x` |
| `.ai/lib/gather-context.sh` | `<dx-plugin>/data/lib/gather-context.sh` | `chmod +x` |
| `.ai/lib/ensure-feature-branch.sh` | `<dx-plugin>/data/lib/ensure-feature-branch.sh` | `chmod +x` |
| `.ai/lib/queue-pipeline.sh` | `<dx-plugin>/data/lib/queue-pipeline.sh` | `chmod +x` |
| `.claude/hooks/stop-guard.sh` | `<dx-plugin>/data/hooks/stop-guard.sh` | `chmod +x` |

Read the plugin source file, Write to the installed location.

**Comment-only differences:** If dx-doctor reported the script as `✓ up to date (project-specific examples)` — meaning the only differences are in comment lines where the project uses real infrastructure names (e.g., `kai-dedupe`) instead of the plugin's generic placeholders (e.g., `myai-dedupe`) — do NOT overwrite. The project-specific names are intentional and correct. Only update scripts that have functional code changes.

### 3ab. Output Templates

For each stale or missing output template in `.ai/templates/`:

For each subdirectory (`spec/`, `wiki/`, `ado-comments/`):
1. Create `.ai/templates/<subdir>/` if missing
2. For each `*.template` file in `<dx-plugin>/data/templates/<subdir>/`:
   - Read the plugin source file, Write to `.ai/templates/<subdir>/<name>`

These are plugin-owned format definition files — always update without asking.

### 3b. Universal Rules

| Installed | Plugin Source |
|-----------|-------------|
| `.claude/rules/reuse-first.md` | `<dx-plugin>/templates/rules/universal-reuse-first.md.template` |

Read template, Write to installed location.

### 3c. Seed Data Refresh (if `.ai/project/` exists and `aem.docs-repo` is configured)

Seed data files in `.ai/project/` are project-specific — they are NOT copied from a plugin directory. To refresh them, use `/aem-refresh` which pulls from the docs repo or a local path.

Report: `ℹ Seed data refresh is handled by /aem-refresh, not dx-upgrade.`

### 3c-ii. Config Migration

Check `dx.version` in `.ai/config.yaml`:
- If missing or older than current plugin version:
  1. Read the migration script from `<dx-plugin>/skills/dx-sync/scripts/migrate-config.sh`
  2. List pending migrations between current version and plugin version
  3. For each pending migration, describe what will change and apply it (auto-fix — structural migrations don't need confirmation)
  4. Update `dx.version` to current plugin version
  5. Report: `✓ Config migrated from <old-version> → <new-version>`
- If already current: `✓ Config version up to date (<version>)`

**Migration script location:** `<dx-plugin>/skills/dx-sync/scripts/migrate-config.sh` — this is the same script used by `/dx-sync`. Running `/dx-upgrade` on a single repo applies the same migrations that `/dx-sync` would apply across all consumers.

### 3d. AEM Rule Files (if aem plugin configured)

| Installed | Plugin Source |
|-----------|-------------|
| `.claude/rules/audit.md` | `<aem-plugin>/templates/rules/audit.md.template` |
| `.claude/rules/qa-basic-auth.md` | `<aem-plugin>/templates/rules/qa-basic-auth.md.template` |

### 3e. Copilot Agents and Skills

If `.github/agents/` exists (Copilot was enabled):

**Agents:** Run the agent install script:
```bash
bash <dx-plugin>/skills/dx-init/scripts/install-copilot-agents.sh --force <dx-plugin>
```
The `--force` flag overwrites stale agents with latest templates.

### 3f. Template-Generated Files

For missing (not stale) template-generated files:

| Missing File | Plugin Source | Action |
|-------------|-------------|--------|
| `.ai/README.md` | `<dx-plugin>/templates/README.md.template` | Read template, fill `{{PROJECT_NAME}}` from config, Write |
| `agent.index.md` | `<dx-plugin>/templates/agent.index.md.template` | Read template, fill `{{PROJECT_NAME}}` from config, Write |
| `.ai/me.md` | — | Create with the demo template (same as dx-init step 5e) |

### 3g. Settings

If `.claude/settings.json` is missing or lacks `attribution`:
- If file missing: Write `{"attribution": {"commit": "", "pr": ""}}`
- If file exists but no attribution: Read, add `attribution` key, Write back (preserve other settings)

### 3g-ii. Local Secrets File

Check `.claude/settings.local.json`:
- **If missing:** Create with empty env vars (same as dx-init step 5i). Report "Created `.claude/settings.local.json`".
- **If exists:** Parse and merge any new env var keys that the upgraded plugin now requires (empty string value). Do NOT overwrite existing values. Base vars: `QA_BASIC_AUTH_USER`, `QA_BASIC_AUTH_PASS`, `QA_BASIC_AUTH_FALLBACK_USER`, `QA_BASIC_AUTH_FALLBACK_PASS`, `AXE_API_KEY`. If project has `aem:` section in config, also add: `AEM_INSTANCES` (with default value `local:http://localhost:4502:admin:admin,qa:https://qa-author.example.com:USER:PASS`). Report count of new keys added (or "up to date").

### 3h. MCP Configuration (ADO only)

If `.mcp.json` org mismatch was detected:
- Read `.mcp.json`, update the org in the `ado` server args, Write back

If `.mcp.json` is missing and `scm.provider` is `ado`:
- Create with ADO MCP entry using `scm.org` from config

## 4. Handle Customized Files (needs confirmation)

For each file flagged as "needs confirmation" — these are files the user may have intentionally edited:

### 4a. Shared Rules (`.ai/rules/*.md`)

For each stale shared rule:
1. Read the installed file
2. Read the plugin template (`<dx-plugin>/templates/rules/<name>.md.template`)
3. Present a summary: "This file differs from the latest plugin template."
4. Ask:
   - **(A) Update to latest template** — overwrites with plugin template
   - **(B) Keep current version** — no changes
   - **(C) Show diff** — display both versions, then ask A or B

If the file has AEM sections appended (for `pr-review.md` and `pr-answer.md`):
- When updating, preserve the AEM section — replace only the dx template portion (everything before the first `## AEM` or `## Sling` heading)
- Explain this to the user: "The AEM section will be preserved. Only the dx portion is being updated."

### 4b. AEM Convention Rules (`.claude/rules/`)

For each stale AEM rule (be-*.md, fe-*.md, naming.md, accessibility.md):
1. Read installed and template
2. Ask same A/B/C as above

### 4c. Automation Policy (if applicable)

If `.ai/automation/policy/pipeline-policy.yaml` is flagged:
1. Read installed and plugin source
2. Ask same A/B/C — this file may have user-tuned rate limits or capability gates

### 4d. Automation Profile Awareness

When upgrading automation files, read `automationProfile` from `.ai/automation/infra.json` (if it exists). Adapt checks:

- **consumer** (or legacy `pr-only` / `pr-delegation`): Do NOT flag missing Lambda handlers, agent step directories, or AWS resource scripts as issues. These are hub-only files and are intentionally absent. DO check that consumer has a `webhooks.pr-answer` entry in infra.json (added in v2.10) — if missing, add it as a manual action: "Run `/auto-webhooks` to create repo-scoped PR Answer hook."
- **full-hub (or missing profile field):** Check all automation files as before.

### 4e. Webhook Migration (v2.10+)

If `.ai/automation/infra.json` exists and has `webhooks.pr-answer` WITHOUT a `filter` field containing `repository`:
- Report as manual action: "PR Answer hook may be project-scoped (legacy). Run `/auto-webhooks` to create a repo-scoped hook filtered to this repo + base branch."

This applies to both hub and consumer profiles — all repos should have their own repo-scoped PR Answer hook.

## 5. Report Manual Actions

List all issues that cannot be auto-fixed. These require the user to take action:

```markdown
### Manual Actions Required

1. **Add to .gitignore:** `.ai/run-context/`
2. **Run /aem-init:** project seed data is missing
3. **Run /auto-init:** .ai/automation/infra.json not found
4. **Verify branch:** scm.base-branch 'develop' not found in remotes — check .ai/config.yaml
5. **Check build config:** build.command uses 'mvn' but pom.xml not found
```

For missing config sections, always suggest running the appropriate init skill — dx-upgrade does not create config sections (that requires interactive user input from the init flow).

## 6. Summary Report

```markdown
## Upgrade Complete

| Action | Count |
|--------|-------|
| Files updated | 5 |
| Files created | 1 |
| Files skipped (kept by user) | 1 |
| Manual actions remaining | 2 |

### Updated
- .ai/lib/audit.sh ← from plugin
- .claude/hooks/stop-guard.sh ← from plugin
- .ai/project/component-index.md ← from plugin data
- .ai/project/markets.md ← from plugin data
- .claude/rules/be-components.md ← from plugin template

### Created
- .ai/me.md ← demo template

### Kept (user's version)
- .ai/rules/pr-review.md

### Manual Actions Required
1. Add `.ai/run-context/` to .gitignore
2. Verify `scm.base-branch` in .ai/config.yaml

→ Run /dx-doctor to verify
```

## Examples

1. `/dx-upgrade all` — Runs dx-doctor across all plugins, finds 3 stale utility scripts and 2 missing Copilot agents. Presents the fix plan, auto-updates plugin-owned files, shows diffs for 1 customized rule file (user chooses "Keep"), and lists 1 manual action (missing gitignore entry).

2. `/dx-upgrade dx` — Scopes the upgrade to only the dx-core plugin. Updates `audit.sh` and `stop-guard.sh` from plugin data, installs 4 new Copilot skill templates, and reports "Suggest re-run: `/dx-doctor` to verify."

3. `/dx-upgrade aem` — Scopes to the dx-aem plugin. Updates stale AEM convention rules in `.claude/rules/`, preserves user-customized `pr-review.md` AEM section, and reports seed data refresh should be done via `/aem-refresh`.

## Copilot CLI Plugin Update

Copilot CLI's `/plugin marketplace update` may fail for local marketplaces with "Failed to fetch git marketplace". To update plugins in Copilot CLI, uninstall and reinstall:

```bash
/plugin uninstall dx-core
/plugin uninstall dx-aem
/plugin install dx-core@dx-aem-ai-flow
/plugin install dx-aem@dx-aem-ai-flow
```

This picks up the latest version from the local marketplace source.

## Troubleshooting

- **"All checks passed. Nothing to upgrade."**
  **Cause:** All project files match the latest plugin versions.
  **Fix:** No action needed. This is the desired state after a successful upgrade.

- **Customized rule file shows unexpected diff**
  **Cause:** Both the plugin template and the user have made changes to the same file.
  **Fix:** Choose option (C) "Show diff" to see both versions side by side, then decide to keep your version or replace with the template. You can also choose to write the template as `.template` and manually merge.

- **"Missing config section" reported as manual action**
  **Cause:** A newer plugin version introduced a config section (e.g., `aem:` or `automation:`) that doesn't exist in your `.ai/config.yaml`.
  **Fix:** Run the appropriate init skill (`/aem-init`, `/auto-init`) to interactively add the missing config section.

## Rules

- **Doctor first** — always run dx-doctor before applying any fixes
- **Confirm before overwriting customized files** — auto-fix plugin-owned files; ask for user-editable files
- **Never touch config values** — update file structure and template content, never change user-entered config values in config.yaml
- **Never touch me.md content** — only create if missing (use demo template)
- **Preserve AEM sections** — when updating shared rules that have AEM sections appended, keep the AEM portion intact
- **Preserve user data in infra.json/repos.json** — never overwrite these automation config files
- **Report everything** — show what was changed, what was skipped, and what needs manual action
- **Suggest re-run** — always end with "Run `/dx-doctor` to verify"
- **Gitignore is sacred** — never auto-modify .gitignore; list needed entries as manual actions
- **Template-driven** — always Read source files from plugin directories; never hardcode file content
- **chmod +x** — always set executable permission on shell scripts after copying
