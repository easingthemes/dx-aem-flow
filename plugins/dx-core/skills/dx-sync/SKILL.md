---
name: dx-sync
description: Sync plugin updates to consumer repos — runs sync-consumers.sh with selected repos and options. Use when you say "sync plugins", "update consumers", "push to all repos".
argument-hint: "[--dry-run] [--parallel] [--skip-hub] [repo1 repo2 ...] — repos: hub, backend, brand-b"
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You sync plugin updates from the dx-aem-ai-flow source to consumer AEM repos using the `sync-consumers.sh` script.

## 1. Locate Sync Script

The sync script lives in this skill's scripts directory:

```bash
SYNC_SCRIPT="${CLAUDE_SKILL_DIR}/scripts/sync-consumers.sh"
```

If it doesn't exist, try the repo root fallback:
```bash
SYNC_SCRIPT="$(git rev-parse --show-toplevel)/internal/sync-consumers.sh"
```

If neither exists, STOP: "sync-consumers.sh not found. This skill requires the dx-aem-ai-flow source repo."

## 2. Show Consumer Repo Table

Present the available repos and their capabilities:

```markdown
| Repo | Path | Base Branch | Work Branch | FE | BE |
|------|------|-------------|-------------|:--:|:--:|
| hub | Brand-A-Project | development | feature/ai-sync | Yes | No |
| backend | AEM-Backend | develop | feature/ai-sync | Yes | Yes |
| brand-b | Brand-B-Project | development | feature/ai-sync | Yes | No |
```

> The hub repo is always included automatically. Sibling repos come from the `repos:` section in `.ai/config.yaml`.

## 3. Parse Arguments

From `$ARGUMENTS`, extract:
- **Flags:** `--dry-run`, `--parallel`, `--no-git`, `--no-pr`, `--skip-hub`
- **Repos:** Repo names from `.ai/config.yaml` `repos:` section
- If no repos specified, defaults to all configured repos

If no arguments at all, ask: "Sync all repos? Or specify which ones (e.g., `hub brand-b`). Add `--dry-run` to preview."

## 4. Run Sync

```bash
bash "$SYNC_SCRIPT" $ARGUMENTS
```

The script handles:
1. Merge `origin/<base-branch>` into work branch
2. Copy utility scripts to `.ai/lib/`
3. Copy output templates to `.ai/templates/`
4. Generate Copilot agents (with dual tool names for Copilot CLI + VS Code Chat)
5. Config migration (runs versioned migrations on the consumer's `.ai/config.yaml`; updates `dx.version` to match the plugin version)
6. Sync Claude rules (`.claude/rules/`)
7. Sync AI rules (`.ai/rules/`)
8. Sync instructions (`.github/instructions/`)
9. Sync VS Code MCP config (`.vscode/mcp.json` — mirrors ADO/Atlassian from root `.mcp.json`)
10. Sync VS Code Chat settings (`.vscode/settings.json` — `chat.instructionsFilesLocations`, `chat.agentSkillsLocations`)
11. Cleanup (remove rules not applicable to repo capabilities)
12. Commit and push
13. Create/update PR

## 5. Report Results

After the script completes, present:

```markdown
## Sync Complete

| Repo | Status | PR |
|------|--------|-----|
| hub | synced | PR #<id> |
| backend | synced | PR #<id> |
| brand-b | synced | PR #<id> |
```

If `--dry-run` was used, note: "Dry run — no changes were made."

## Rules

- **Never run without user confirmation** — always show the repo table and confirm before syncing
- **Use --no-pr when needed** — pass `--no-pr` to skip PR creation for specific runs
- **Dry-run first on uncertainty** — if unsure about scope, suggest `--dry-run` first
- **Read script output** — the script reports per-step status; relay any errors to the user
- **This skill only runs from the Hub repo** (the repo containing `dx-aem-ai-flow/`) since it hosts the plugin source
