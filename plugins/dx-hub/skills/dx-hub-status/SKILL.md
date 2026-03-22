---
name: dx-hub-status
description: Show status of hub dispatches — in-flight work, completed results, and PRs across all repos. Use to check multi-repo progress. Trigger on "hub status", "dispatch status", "what's running".
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
- `--clean` → remove state entries older than `hub.state-ttl`, rebuild index, report count

Read from config:
- `hub.state-dir` — directory for dispatch state (default: `state/`)
- `hub.state-ttl` — retention period for clean mode (default: `7d`)

## 2. Load State Index

Read `<state-dir>/active.json`.

If the file is missing or empty, rebuild it:

1. Glob `<state-dir>/*/dispatch.json` — one file per ticket
2. For each ticket dir, read `dispatch.json` and any `results/*.json` files
3. Build the index structure (see below) and write it to `<state-dir>/active.json`

### active.json structure

```json
{
  "updated": "<ISO timestamp>",
  "dispatches": [
    {
      "ticket": "<ticket-id>",
      "skill": "<skill-name>",
      "dispatched-at": "<ISO timestamp>",
      "repos": [
        {
          "name": "<repo-name>",
          "status": "done|running|failed|pending",
          "pr": "<PR number or null>",
          "pr-url": "<PR URL or null>",
          "cost": "<cost string or null>",
          "duration": "<duration string or null>",
          "session-id": "<session-id or null>",
          "summary": "<one-line summary or null>",
          "error": "<error message or null>"
        }
      ]
    }
  ]
}
```

Derive `status` for each repo from the result file if present, otherwise `running` if the dispatch was recent, `pending` if not yet started.

## 3. Display

### All dispatches (no argument)

Print a summary table. Use Unicode box-drawing characters:

```
Hub Dispatch Status
───────────────────────────────────────────────────────────────────
┌──────────┬──────────────┬───────────────┬───────────┬────────┬──────────┐
│ Ticket   │ Skill        │ Repo          │ Status    │ PR     │ Cost     │
├──────────┼──────────────┼───────────────┼───────────┼────────┼──────────┤
│ 2471234  │ /dx-agent-all│ repo-alpha    │ done      │ #38001 │ $0.42    │
│          │              │ repo-beta     │ running   │ —      │ —        │
│ 2471189  │ /dx-plan     │ repo-gamma    │ failed    │ —      │ $0.11    │
└──────────┴──────────────┴───────────────┴───────────┴────────┴──────────┘

Legend: done ✓  running ⟳  failed ✗  pending ·
```

- For multi-repo dispatches, show the ticket and skill only on the first row; subsequent rows for the same dispatch use blank cells.
- PR column shows `#<number>` if available, `—` otherwise.
- Cost column shows `—` if still running.
- If `active.json` has no entries, print: `No active dispatches found. Run a hub-enabled skill to start one.`

### Single ticket (`<ticket-id>` argument)

Find the matching dispatch entry. If not found, print: `No dispatch found for ticket <ticket-id>.` and STOP.

Print detailed markdown:

```markdown
## Dispatch: <ticket-id> — <skill>

**Dispatched:** <dispatched-at>
**Repos:** <N> total (<done> done, <running> running, <failed> failed)

### <repo-name>

| Field    | Value            |
|----------|------------------|
| Status   | done             |
| PR       | #38001 (<pr-url>)|
| Duration | 4m 12s           |
| Cost     | $0.42            |
| Session  | <session-id>     |

**Summary:** <summary text>

---
```

Repeat the per-repo table for each repo. For failed repos, add:

```markdown
**Error:** <error message>

**Suggestion:** Check the repo's `.ai/specs/<ticket-slug>/` for partial output. Re-run `/dx-agent-all <ticket-id>` in that repo directly to resume.
```

### Clean mode (`--clean`)

1. Parse `hub.state-ttl` — support `7d`, `30d`, `24h` formats. Convert to seconds.
2. Check each subdirectory in `<state-dir>/`:
   - Read `dispatch.json` and check `dispatched-at`
   - If age exceeds TTL, delete the directory with `rm -rf`
3. Rebuild `active.json` from remaining dispatch dirs (same logic as step 2).
4. Print summary:

```
Hub State Cleaned
─────────────────
Removed: <N> dispatch dir(s) older than <hub.state-ttl>
Retained: <M> dispatch dir(s)
Index rebuilt: state/active.json
```

## Examples

### Check overall hub progress
```
/dx-hub-status
```
Reads `state/active.json` and prints the summary table with all in-flight and completed dispatches.

### Inspect a specific ticket
```
/dx-hub-status 2471234
```
Shows per-repo details for ticket 2471234 — session IDs, durations, costs, PR links, and any error messages with fix suggestions.

### Clean up old state
```
/dx-hub-status --clean
```
Removes dispatch state directories older than `hub.state-ttl` (default 7 days) and rebuilds the index.

## Troubleshooting

### "No active dispatches found"
**Cause:** `state/active.json` is empty or missing, and no `dispatch.json` files exist in `state/`.
**Fix:** Dispatches are created when a hub-enabled skill runs. Run `/dx-agent-all <ticket-id>` from the hub directory to start one.

### State shows "running" but dispatch finished
**Cause:** The result file was not written (dispatch failed silently) or `active.json` is stale.
**Fix:** Run `/dx-hub-status --clean` to rebuild the index. Check the individual `state/<ticket>/` directory for partial result files.

### PR column is blank for a completed dispatch
**Cause:** The repo session finished but did not create a PR (e.g., `/dx-plan` was used instead of `/dx-agent-all`), or the result file did not include a PR number.
**Fix:** This is expected for plan-only dispatches. Check `state/<ticket>/results/<repo>.json` for the full output.

### Cost shows "—" for a finished dispatch
**Cause:** The session result did not include cost metadata (older CLI version or interrupted session).
**Fix:** Cost reporting requires `claude -p --output-format json`. Ensure the CLI is up to date.

## Rules

- **Read config first** — always check `hub.enabled` before doing anything else
- **Never hardcode paths** — state dir always comes from `hub.state-dir` in config
- **Rebuild index on miss** — if `active.json` is absent, reconstruct from disk rather than failing
- **Generic examples only** — no client org names, project names, or real repo names in output or skill text
- **Respect TTL format** — parse `7d`, `30d`, `24h` correctly; do not assume a fixed unit
