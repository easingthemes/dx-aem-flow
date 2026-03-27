---
name: dx-hub-status
description: Show status of hub dispatches — which repos are running, done, blocked, or failed. Use to check multi-repo progress. Trigger on "hub status", "dispatch status", "what's running".
argument-hint: "[ticket-id (optional) | --clean]"
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

Read from config:
- `hub.state-ttl` — retention period for clean mode (default: `7d`)
- `repos[]` — list of repos with paths (for reading spec dirs in detailed view)

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

Legend: done ✓  running ⟳  blocked ⚠  failed ✗
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
   - If age exceeds TTL AND no repo is `running`, delete the directory with `rm -rf`
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
