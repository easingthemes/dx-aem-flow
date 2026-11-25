# Run Result File: `.ai/run-results/<skill>-<id>.json`

Written at the end of every run (including STOP and failure) by the coordinator skills `dx-agent-all`,
`dx-bug-all`, `dx-pr-review` and `dx-prep`, through `plugins/dx-core/data/lib/run-result.sh`
(procedure: `plugins/dx-core/shared/run-result.md`). Meant for tools that start a skill and need its
outcome — a local dashboard, a script, a hub — without parsing terminal output.

- One file per skill and id; a new run overwrites it (latest wins).
- While a run is going, a **running marker** `<skill>-<id>.running.json` sits next to it (below). The final write removes it.
- Every final write is also appended as one line to `history.jsonl` (below).
- Local only: `.ai/run-results/` belongs in `.gitignore`.
- A running marker left after the session ended — or no file at all — means the run was interrupted before its end.

## Schema (version 1)

```json
{
  "schema": 1,
  "skill": "dx-pr-review",
  "id": "12345",
  "status": "done",
  "verdict": "approved-with-suggestions",
  "vote": "ApprovedWithSuggestions",
  "next_action": "none",
  "links": {
    "pr": "https://dev.azure.com/my-org/my-project/_git/my-repo/pullrequest/12345",
    "wiki": null,
    "work_item": null
  },
  "summary": "Posted 3 threads, voted ApprovedWithSuggestions",
  "run_id": "3f1c2b9e-0000-4000-8000-000000000000",
  "started_at": "2026-01-01T11:48:20Z",
  "duration_s": 700,
  "finished_at": "2026-01-01T12:00:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `schema` | number | Always `1` for this shape. A breaking change bumps it |
| `skill` | string | Skill name without plugin prefix (`dx-agent-all`, `dx-bug-all`, `dx-pr-review`, `dx-prep`) |
| `id` | string | Work item id, Jira key, or PR id — always a string |
| `status` | string | `done` \| `blocked` \| `failed` — see below |
| `verdict` | string \| null | The skill's own verdict, when it has one (review verdict, DoR/plan-validation result) |
| `vote` | string \| null | ADO vote cast by this run (`Approved`, `ApprovedWithSuggestions`, `NoVote`, …); `null` when no vote was cast |
| `next_action` | string \| null | One line: the next command or step for a human |
| `links.pr` | string \| null | PR created or reviewed |
| `links.wiki` | string \| null | Wiki page published |
| `links.work_item` | string \| null | Work item the run worked on |
| `summary` | string \| null | One line, no file contents |
| `run_id` | string \| null | The caller's id for this run: `--run-id`, else the `DX_RUN_ID` environment variable, else the running marker's. `[A-Za-z0-9._:-]{1,64}`; anything else becomes `null` |
| `started_at` | string \| null | UTC ISO 8601 time of the run's `--start` (from the running marker); `null` when the run wrote no marker |
| `duration_s` | number \| null | Seconds from `started_at` to `finished_at`; `null` without `started_at` |
| `finished_at` | string | UTC ISO 8601 time the file was written |

### `status`

| Value | Meaning |
|-------|---------|
| `done` | The skill reached its normal end. Optional parts may have been skipped — `summary` says which |
| `blocked` | Stopped for a human: a gate failed, a question it must not guess, input missing |
| `failed` | An error ended the run |

All string values are single-line; control characters are replaced by spaces. Readers should ignore
fields they do not know, so new optional fields can be added within schema 1.

## Correlating a run with its caller: `DX_RUN_ID`

A tool that starts a skill sets `DX_RUN_ID` in the skill's environment (a session id, a uuid — any
`[A-Za-z0-9._:-]{1,64}` value). It lands in the running marker, the result file and the history line,
so the caller finds *its* run without matching by time. `/dx-hub-dispatch` sets it to each repo
terminal's session id on the `copilot` engine.

## Running marker: `.ai/run-results/<skill>-<id>.running.json`

Written by `run-result.sh --start` when a coordinator skill has parsed its id, before any long work.
Removed by the final write. A newer `--start` for the same skill and id overwrites it.

```json
{
  "schema": 1,
  "skill": "dx-agent-all",
  "id": "12345",
  "status": "running",
  "run_id": "3f1c2b9e-0000-4000-8000-000000000000",
  "started_at": "2026-01-01T11:48:20Z",
  "progress_file": "dev-all-progress.md",
  "spec_dir": null
}
```

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Always `running` |
| `progress_file` | string \| null | File name of the progress table this skill writes in its spec dir (`dev-all-progress.md`, `bug-progress.md`, `req-progress.md`); `null` when it writes none (`dx-pr-review`) |
| `spec_dir` | string \| null | The spec dir, when the skill already knows it at start; otherwise find it as `.ai/specs/<id>-*/` |

Other fields as in the result file. The file name does not match `<skill>-<id>.json`, so a reader that
globs only result files never sees it.

## History: `.ai/run-results/history.jsonl`

Each final write appends the result object, unchanged, as one line. It is the record of every run;
the per-id file only holds the latest. Once it passes `DX_RUN_HISTORY_MAX` lines (default 2000) it is
trimmed to the last `DX_RUN_HISTORY_KEEP` (default 1000). Readers should skip lines that do not parse.
