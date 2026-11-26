---
name: dx-hub-status
description: "Show hub dispatch status — which repos are running, done, blocked or failed. Use for 'hub status', 'what's running'."
argument-hint: "[ticket-id (optional)] [--json] | --clean"
allowed-tools: ["Read", "Glob", "Grep", "Write", "Bash"]
---

You display the status of hub dispatches across all configured repos.

**Before anything else**, read `.ai/config.yaml`. If `hub.enabled` is not `true`, STOP with:

```
Hub mode is not enabled. Run `/dx-hub-init` first.
```

## 1. Parse Arguments

- No argument → show all active dispatches (summary table)
- `<ticket-id>` → detailed view for that one ticket
- `--clean` → remove state entries older than `hub.state-ttl`, report count
- `--json` (alone or with `<ticket-id>`) → machine-readable output for tools: see **JSON mode** below, then STOP

Read from config:
- `hub.state-ttl` — retention period for clean mode (default: `7d`)
- `repos[]` — list of repos with paths (for reading spec dirs in detailed view)

## JSON mode (`--json`)

Print the status files as **one JSON array** and nothing else — no table, no prose before or after, so a tool can parse stdout:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/status-json.sh" state [<ticket-id>]
```

(`${CLAUDE_SKILL_DIR}` is this skill's directory; on a host that does not substitute it, run `scripts/status-json.sh` from this skill's folder.) Each element is a `state/<id>/status.json` object as `/dx-hub-dispatch` wrote it — `ticket`, `title`, `type`, `skill`, `engine`, `started`, `repos` (`<repo>: pending | running | done | blocked | failed`; `pending` = a `--no-launch` dispatch not yet started), `sessions` (`<repo>: <session id>`, for the `copilot` engine and `--no-launch`) and, with `--no-launch`, `launch` (`<repo>: {cwd, command}`). An unreadable file becomes `{"ticket": "<dir>", "error": "unreadable status.json"}`. No dispatches → `[]` (not the "No active dispatches" message). STOP after printing.

## 2. Load Status Files

Glob `state/*/status.json` to find all dispatch state files.

If no files found, print: `No active dispatches found. Run /dx-hub-dispatch to start one.` and STOP.

## 3. Display

### All dispatches (no argument)

Print a summary table:

```
Hub Dispatch Status
───────────────────────────────────────────────────
┌──────────┬─────────────────────────┬──────────────┬──────────┐
│ Ticket   │ Title                   │ Repo         │ Status   │
├──────────┼─────────────────────────┼──────────────┼──────────┤
│ 2471234  │ Add user profile page   │ repo-fe      │ done     │
│          │                         │ repo-be      │ running  │
│ 2471189  │ Fix auth timeout        │ repo-be      │ blocked  │
└──────────┴─────────────────────────┴──────────────┴──────────┘

Legend: done ✓  running ⟳  pending ·  blocked ⚠  failed ✗
```

For multi-repo dispatches, show ticket and title only on the first row.

### Single ticket (`<ticket-id>` argument)

Find `state/<ticket-id>/status.json`. If not found, print: `No dispatch found for ticket <ticket-id>.` and STOP.

Read the status file and print:

```markdown
## Dispatch: <ticket-id> — <title>

**Type:** <type>
**Skill:** <skill>
**Started:** <started timestamp>

### Repo Status

| Repo | Status |
|------|--------|
| <repo-a> | done |
| <repo-b> | running |
```

**If any repo is `blocked`**, add:
```
⚠ <repo-name> is blocked — switch to its terminal to investigate.
```

**If any repo is `done`**, optionally check for spec files in that repo:
```bash
ls <repo-path>/.ai/specs/<ticket-id>-*/
```
Report which pipeline artifacts exist (raw-story.md, explain.md, implement.md, pr.md) as a quick progress indicator.

### Cross-repo context

Print:
```
Context file: state/<ticket-id>/context.md
```

### Clean mode (`--clean`)

1. Parse `hub.state-ttl` — support `7d`, `30d`, `24h` formats. Convert to seconds.
2. Check each `state/<dir>/status.json`:
   - Read `started` timestamp
   - If age exceeds TTL AND no repo is `running`, delete the directory with one `rm -rf state/<ticket-id>` per directory, the ticket id written out literally — never `state` or `state/` itself, no shell variable, loop or `$(...)` as the target (Claude Code v2.1.281+ stops on those for a permission prompt even in bypass mode, which stalls a pipeline run)
   - Never clean dispatches where any repo is still `running`
3. Print summary:

```
Hub State Cleaned
─────────────────
Removed: <N> dispatch dir(s) older than <hub.state-ttl>
Retained: <M> dispatch dir(s)
```

## Examples

### Check overall hub progress
```
/dx-hub-status
```
Shows summary table of all dispatches with per-repo status.

### Inspect a specific ticket
```
/dx-hub-status 2471234
```
Shows detailed view with repo statuses. For completed repos, shows which spec files exist.

### Status for a tool
```
/dx-hub-status --json
```
Prints `[{"ticket": "2471234", "repos": {...}, "sessions": {...}, ...}]` — one array, nothing else.

### Clean up old state
```
/dx-hub-status --clean
```
Removes dispatch state directories older than `hub.state-ttl` (default 7 days).

## Troubleshooting

### "No active dispatches found"
**Cause:** No `status.json` files in `state/`.
**Fix:** Run `/dx-hub-dispatch <ticket-id>` to start a dispatch.

### Status shows "running" but terminal is idle
**Cause:** The repo's Claude session finished but did not update `status.json` (prompt instruction was not followed).
**Fix:** Manually edit `state/<ticket-id>/status.json` to set the correct status, or check the repo's spec directory for completion indicators.

## Rules

- **Read config first** — always check `hub.enabled` before doing anything else
- **Never hardcode paths** — state dir is always `state/` relative to hub CWD
- **Respect running dispatches** — never clean entries where any repo is `running`
- **Generic examples only** — no client org names, project names, or real repo names
