# Hub Dispatch Protocol

Reference document for coordinator skills that orchestrate work across multiple repositories from a hub workspace.

## When This Applies

Hub mode lets a single `.hub/` directory act as an orchestration point for multi-repo workflows. Instead of manually switching to each repo, coordinator skills dispatch sub-invocations via `cd <repo-path> && claude -p` and collect structured results.

This document defines how to detect hub mode, resolve target repos, build dispatch commands, collect results, and persist state. It is the local alternative to pipeline delegation (see `repo-discovery.md`).

## Decision Tree (Per Skill)

Before executing any cross-repo work item, evaluate in order:

```
Is DX_PIPELINE_MODE=true?
  → yes: delegate via ADO pipeline (see repo-discovery.md — stop here)

Is hub.enabled=true AND cwd ends with .hub/?
  → yes: dispatch via cd <path> && claude -p (this document)

Is cross-repo scope detected?
  → yes: print "switch to {repo.name} at {repo.path}" (manual handoff)

Otherwise:
  → execute locally (standard behavior)
```

The hub check comes after pipeline mode and before manual handoff. A hub workspace replaces the manual switching step — it does not replace pipeline automation.

## Hub Detection

Two conditions must BOTH be true for hub mode to be active:

```bash
HUB_ENABLED=$(grep -A1 '^hub:' .ai/config.yaml | grep 'enabled:' | grep -o 'true' || echo "false")
IS_HUB_DIR=$(basename "$(pwd)" | grep -q '\.hub$' && echo "true" || echo "false")
```

Hub mode is active when `HUB_ENABLED=true` AND `IS_HUB_DIR=true`.

The directory check prevents skills from accidentally dispatching when run inside a child repo (even if its own config has hub settings). Only the `.hub/` directory itself triggers hub dispatch.

## 1. Repo Resolution

### Config Source

Target repos are listed under `repos:` in `.ai/config.yaml`:

```yaml
hub:
  enabled: true
  auto-dispatch: false
  dispatch-mode: sequential
  state-ttl: 7d

repos:
  - name: Repo-A
    path: ../repo-a
    capabilities: [fe]
  - name: Repo-B
    path: ../repo-b
    capabilities: [be]
  - name: Repo-C
    path: /absolute/path/to/repo-c
    capabilities: [fe, be]
```

### Matching Logic

Match repos from the cross-repo scope section of the spec file against the `repos:` list:

1. **Name match** — compare repo names case-insensitively
2. **Capabilities match** — use the role-to-capabilities table below

If both `role` and `capabilities` are present in the scope spec, `capabilities` takes precedence over `role`.

### Role-to-Capabilities Mapping

| Role | Capabilities |
|------|-------------|
| `backend` | `[be]` |
| `frontend` | `[fe]` |
| `fullstack` | `[fe, be]` |

A repo matches a role if its `capabilities` list contains at least one matching capability. A `fullstack` role matches any repo that has `fe` OR `be`.

### No Match Warning

If no repo entry matches a required scope target, print a warning and skip that target — do not abort the entire dispatch:

```
⚠ No repo entry found for "Unknown-Repo". Add it to repos: in .ai/config.yaml.
```

### Path Resolution

Paths in `repos[].path` may be absolute or relative:

- **Absolute paths** — used as-is
- **Relative paths** — resolved against the `.hub/` directory parent (one level up from cwd)

Example: if cwd is `/projects/project-x/.hub` and path is `../repo-a`, the resolved path is `/projects/project-x/repo-a`.

## 2. Command Builder

Build the dispatch invocation for each target repo:

```bash
cd "<resolved-repo-path>" && \
claude -p "<skill-invocation>" \
  --output-format json \
  --allowedTools "Bash,Read,Edit,Write,Glob,Grep" \
  --permission-mode bypassPermissions
```

### Parameter Notes

| Parameter | Value | Reason |
|-----------|-------|--------|
| `cd <path> &&` | resolved absolute path | sets working directory before launching Claude — the CLI has no `--cwd` flag |
| `--output-format json` | always | structured result collection |
| `--allowedTools` | skill-dependent | minimum required for the skill |
| `--permission-mode bypassPermissions` | always | non-interactive session, no prompts. Valid modes: `acceptEdits`, `bypassPermissions`, `default`, `dontAsk`, `plan`, `auto` |

The `<skill-invocation>` string is exactly what the user would type in an interactive session, e.g. `/dx-step-all 12345` or `/dx-bug-all BUG-99`.

### Allowed Tools

Default tool set covers most skills: `Bash,Read,Edit,Write,Glob,Grep`. Extend for skills that require MCP tools — but keep the list minimal. Do not include tools the dispatched skill does not need.

## 3. Result Collection

### JSON Output Contract

`claude -p --output-format json` produces one JSON object per session:

```json
{
  "session_id": "sess_abc123",
  "result": "Completed implementation. 3 files modified.",
  "cost_usd": 0.12,
  "duration_ms": 45200,
  "is_error": false
}
```

If the session ended with an unhandled error, `is_error` is `true` and `result` contains the error message or last output.

### Exit States

| State | Condition | Action |
|-------|-----------|--------|
| **Success** | exit 0, `is_error: false` | write result, continue |
| **Failure** | exit non-0, or `is_error: true` | write result with error, continue to next repo |
| **Timeout** | process exceeds timeout | kill process, write timeout result, continue |

Default timeout: **30 minutes** per repo. Override via `hub.dispatch-timeout` in config (value in minutes).

**No automatic retries.** Partial success is kept — completed repos are not rolled back if a later repo fails. Report all outcomes at the end.

## 4. State Persistence

State files live under `.hub/state/` relative to the hub workspace. They survive across sessions so a failed dispatch can be resumed or inspected.

### Per-Repo Result

Written after each repo completes (success, failure, or timeout):

```
.hub/state/<ticket-id>/results/<repo-name>.json
```

```json
{
  "repo": "Repo-A",
  "path": "/projects/project-x/repo-a",
  "status": "success",
  "session_id": "sess_abc123",
  "result": "Completed implementation. 3 files modified.",
  "cost_usd": 0.12,
  "duration_ms": 45200,
  "dispatched_at": "2026-01-15T10:30:00Z",
  "completed_at": "2026-01-15T10:30:45Z"
}
```

Status values: `success`, `failure`, `timeout`, `skipped`.

### Dispatch Metadata

Written once at the start of dispatch, updated at completion:

```
.hub/state/<ticket-id>/dispatch.json
```

```json
{
  "ticket_id": "12345",
  "skill": "dx-step-all",
  "dispatch_mode": "sequential",
  "repos": ["Repo-A", "Repo-B"],
  "started_at": "2026-01-15T10:30:00Z",
  "completed_at": "2026-01-15T10:31:30Z",
  "status": "partial",
  "summary": "2/2 repos completed. 1 success, 1 failure."
}
```

Dispatch status values: `running`, `complete`, `partial` (some repos failed), `aborted`.

### Active Index

Rebuilt from all result files after each dispatch completes:

```
.hub/state/active.json
```

```json
{
  "updated_at": "2026-01-15T10:31:30Z",
  "dispatches": [
    {
      "ticket_id": "12345",
      "status": "partial",
      "repos": {
        "Repo-A": "success",
        "Repo-B": "failure"
      }
    }
  ]
}
```

The active index is a convenience summary — it is always derived from result files, never the source of truth.

### State Lifecycle

```
1. Write dispatch.json (status: running)
2. For each repo:
   a. Dispatch claude -p
   b. Collect result
   c. Write results/<repo-name>.json
3. Update dispatch.json (status: complete/partial)
4. Rebuild active.json from all result files
```

### Cleanup

Entries older than `hub.state-ttl` (default: `7d`) may be removed on next dispatch. TTL is measured from `dispatch.json:completed_at`. Running dispatches (`status: running`) are never removed by cleanup.

## 5. Dispatch Modes

Controlled by `hub.dispatch-mode` in config (or overridable per-invocation):

| Mode | Behavior |
|------|----------|
| `sequential` | One repo at a time, in `repos:` config order. Default. |
| `parallel` | All repos dispatched simultaneously. Results collected as they complete. |
| `auto` | Deferred to v2 — not implemented. |

**Sequential** is the default and recommended for most workflows. It produces cleaner output and avoids write conflicts if repos share any artifact paths.

**Parallel** is appropriate when repos are fully independent and speed matters. All `claude -p` processes run concurrently; collect results with a process group or background job pattern.

## 6. Auto-Dispatch vs Confirmation

Controlled by `hub.auto-dispatch` in config:

### `hub.auto-dispatch: false` (default)

Show the dispatch plan and ask for confirmation before executing:

```
Hub dispatch plan for ticket 12345:
  Mode: sequential
  Repos: Repo-A → Repo-B
  Skill: /dx-step-all 12345

Proceed? [y/N]
```

If the user declines, print the manual commands they can run:
```
To dispatch manually:
  cd /projects/project-x/repo-a && claude -p "/dx-step-all 12345" --output-format json --permission-mode bypassPermissions
  cd /projects/project-x/repo-b && claude -p "/dx-step-all 12345" --output-format json --permission-mode bypassPermissions
```

### `hub.auto-dispatch: true`

Dispatch immediately without confirmation. Log the plan before executing:

```
Hub dispatch: ticket 12345 → Repo-A, Repo-B (sequential)
```

## Config Reference

All hub settings live under `hub:` in `.ai/config.yaml`:

| Key | Default | Description |
|-----|---------|-------------|
| `hub.enabled` | `false` | Enable hub mode for this workspace |
| `hub.auto-dispatch` | `false` | Skip confirmation prompt |
| `hub.dispatch-mode` | `sequential` | `sequential` or `parallel` |
| `hub.dispatch-timeout` | `30` | Per-repo timeout in minutes |
| `hub.state-ttl` | `7d` | How long to keep completed state entries |

The `repos:` list is a top-level key (not nested under `hub:`):

| Key | Required | Description |
|-----|----------|-------------|
| `repos[].name` | yes | Display name, used for state file names |
| `repos[].path` | yes | Absolute or relative path to repo root |
| `repos[].capabilities` | no | List of capability tags: `fe`, `be` |
