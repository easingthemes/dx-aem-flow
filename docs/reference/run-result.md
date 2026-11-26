# Run Result File: `.ai/run-results/<skill>-<id>.json`

Written at the end of every run (including STOP and failure) by the coordinator skills `dx-agent-all`,
`dx-bug-all`, `dx-post-merge`, `dx-pr-review` and `dx-prep`, and by `dx-dor`, `dx-estimate`, `dx-req`, `dx-pr-answer`,
`dx-bug-fix`, `dx-plan`, `dx-step-all`, `dx-step-verify`, `dx-req-dod`, `dx-doc-gen`, `dx-qa-handoff`, dx-aem's
`aem-demo-page` and dx-hub's `dx-hub-dispatch`, through `plugins/dx-core/data/lib/run-result.sh`
(`aem-demo-page` runs the project's `.ai/lib/run-result.sh` copy, since a dx-aem skill's
`${CLAUDE_PLUGIN_ROOT}` is dx-aem's root; `dx-hub-dispatch` finds dx-core beside dx-hub through its
`scripts/dx-core-lib.sh`)
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
  "metrics": { "must_fix": 1, "questions": 2, "threads_posted": 3, "threads_failed": 0, "patches": 1 },
  "env": { "dx_version": "6.5.0", "engine": "copilot", "mode": "automation", "mode_reason": "args" },
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
| `run_id` | string \| null | The caller's id for this run: `--run-id`, else the `DX_RUN_ID` environment variable, else the running marker's. Without any of them (a skill run by hand), `<session id>.<n>` — see [Manual runs](#manual-runs-run_id-from-the-engine-session). `[A-Za-z0-9._:-]{1,64}`; anything else becomes `null` |
| `started_at` | string \| null | UTC ISO 8601 time of the run's `--start` (from the running marker); `null` when the run wrote no marker |
| `duration_s` | number \| null | Seconds from `started_at` to `finished_at`; `null` without `started_at` |
| `metrics` | object | Per-skill counts (below); `{}` when the skill passed none. Values are numbers, booleans or short strings |
| `env.dx_version` | string \| null | Version of the dx plugin that wrote the file |
| `env.engine` | string \| null | `--engine`, else `DX_ENGINE`, else `copilot` under Copilot CLI (`COPILOT_AGENT_SESSION_ID` set or `COPILOT_CLI=1`), else `claude` under Claude Code (`CLAUDECODE=1`). Always set on both engines; `null` only outside them (a plain script) |
| `env.mode` | string \| null | `automation` \| `interactive`, as the skill decided |
| `env.mode_reason` | string \| null | Why: `env` (`DX_PIPELINE_MODE`), `flag` (orchestration flag), `args` (`autonomous` / `autopilot` / `non-interactive`), `no-ask` (host has no way to ask), `none` |
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

## Manual runs: `run_id` from the engine session

A skill run by hand in a terminal has no `DX_RUN_ID`. `run-result.sh` then mints
`run_id` = `<session id>.<n>`:

- **session id** — the engine session's id, lowercased: `CLAUDE_CODE_SESSION_ID` on Claude Code,
  `COPILOT_AGENT_SESSION_ID` on Copilot CLI (the engine named by `env.engine`; `DX_SESSION_ID`
  overrides both). It is the same id the engine's hooks receive (`session_id` / `sessionId`), so a
  tool can link the run to its session transcript exactly. It must match `[a-z0-9_:-]{1,60}` — no
  `.` — or `run_id` stays `null`; a broken id is never written.
- **n** — the run's number within that session (1, 2, …), so two skills or two tickets in one
  session never share a `run_id`. Nested skills each get their own number. The counter lives in
  `.ai/run-results/.sessions/<session id>`; counters idle for 30 days are pruned at `SessionEnd`.

`--start` mints the id and the final write carries it over from the marker, so marker, result and
history line agree. A final write with no marker mints the next number. With `DX_RUN_ID` (or
`--run-id`) set nothing changes and no number is used.

To find the session of a run: the part of `run_id` before the first `.`. A `run_id` without `.`
came from a caller (`DX_RUN_ID`).

## Metrics

Each skill passes the counts it already has (`--metric key=value`); a count it does not know is left
out, never guessed. Keys are stable — a tool can rely on them per skill:

| Skill | Keys |
|-------|------|
| `dx-agent-all` | `steps_done`, `steps_total`, `fix_loops`, `build_attempts`, `fail_at` |
| `dx-bug-all` | `fix_attempts`, `fail_at` |
| `dx-post-merge` | `steps_done`, `steps_skipped`, `screenshots`, `fail_at` |
| `dx-prep` | `plan_steps`, `resolve_rounds`, `fail_at` |
| `dx-pr-review` | `must_fix`, `questions`, `threads_posted`, `threads_failed`, `patches` |
| `dx-pr-answer` | `replied`, `will_fix`, `disagree`, `needs_human`, `patches_applied`, `skipped` |
| `dx-dor` | `criteria_pass`, `criteria_total`, `mandatory_failed`, `comment_mode` |
| `dx-estimate` | `story_points`, `hours_total`, `open_questions`, `pages_affected` |
| `dx-req` | `dor_questions`, `fail_at` |
| `dx-bug-fix` | `fix_attempts`, `steps_done`, `steps_total`, `fail_at` |
| `dx-step-all` | `steps_done`, `steps_total`, `fix_attempts`, `heals`, `fail_at` |
| `dx-step-verify` | `compile`, `lint`, `test`, `secrets`, `arch` (`passed`/`failed`/`skipped`), `review_cycles`, `critical`, `important` |
| `dx-req-dod` | `criteria_pass`, `criteria_total`, `fixed`, `tasks_created`, `fail_at` |
| `dx-doc-gen` | `screenshots`, `posted`, `retro`, `fail_at` |
| `dx-qa-handoff` | `comment_mode` (`posted`/`update`/`unchanged`/`dry-run`), `qa_pages`, `screenshots`, `fail_at` |
| `aem-demo-page` | `env` (`qa`/`local`), `pages`, `pages_created`, `screenshots`, `screenshots_uploaded`, `fail_at` |
| `dx-plan` | `plan_steps`, `fail_at` |
| `dx-hub-dispatch` | `repos`, `started`, `pending`, `fail_at` |

`fail_at` is the first failed or blocked phase, node or step, as a short name. `interrupted: true`
(with `fail_at` the step that was in progress) is added by the SessionEnd hook, never by a skill.

## Progress file: `<spec dir>/<progress_file>`

Every skill with more than one step keeps a progress table in its spec dir (the marker's
`progress_file`), written by `shared/update-progress.sh`:

```markdown
# /dx-doc-gen Progress — #12345

| Step | Status | Note | Updated |
|---|---|---|---|
| Read sources | done | spec files | 2026-01-01T11:48:21Z |
| Generate wiki-page.md | in_progress | — | 2026-01-01T11:49:02Z |
```

One row per step, updated in place; `Status` is `pending`, `in_progress`, `done`, `skipped`,
`blocked` or `failed`; `Updated` is when the row was last written (UTC). A step is `in_progress`
before it starts, so the last `in_progress` row of an interrupted run is where it stopped. A nested
skill is one row in its caller's file. Files started before the `Updated` column existed keep three
columns. Per skill: `dev-all-progress.md` (`dx-agent-all`, `dx-step-all`), `bug-progress.md`,
`req-progress.md` (`dx-req`, `dx-prep`), `plan-progress.md`, `step-verify-progress.md`,
`dor-progress.md`, `estimate-progress.md`, `post-merge-progress.md`, `dod-progress.md`,
`doc-gen-progress.md`, `qa-handoff-progress.md`, `demo-page-progress.md`, and
`hub-dispatch-progress.md` (in the hub's `state/<id>/`). `dx-pr-review` and `dx-pr-answer` work on a
PR, have no spec dir and write none.

## Nested skills and `run_id`

`dx-agent-all`, `dx-bug-all`, `dx-prep`, `dx-estimate`, `dx-post-merge` and `dx-req-dod` run other skills that write their own results
(`dx-req`, `dx-plan`, `dx-step-all`, `dx-bug-fix`, `dx-step-verify`, `dx-dor`, `aem-demo-page`, `dx-doc-gen`, `dx-qa-handoff`, `dx-post-merge`) —
each in its own `<skill>-<id>.json`, never the caller's file. They inherit the caller's
`DX_RUN_ID`, so one run id can appear in several files: match on **skill and** `run_id`. Run by
hand (no `DX_RUN_ID`), each nested skill gets its own `<session id>.<n>`.

## Related files

- `.ai/run-results/dx-step-verify-<id>.checks.json` — the pre-review gate's summary from
  `pre-review-checks.sh --out`: `passed`, `phases[]` (`phase`, `name`, `status`, `blocking`),
  `secret_files[]` (paths only, never the matched text), `checked_at`.
- `.ai/pr-reviews/pr-<id>-findings.json` — review findings with ADO thread ids:
  `docs/reference/pr-review-findings.md`.

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
| `spec_dir` | string \| null | The spec dir: `--spec-dir`, else the one `.ai/specs/<id>-*/` that exists at start; `null` when there is none or several |

Other fields as in the result file. The file name does not match `<skill>-<id>.json`, so a reader that
globs only result files never sees it.

## History: `.ai/run-results/history.jsonl`

Each final write appends the result object, unchanged, as one line. It is the record of every run;
the per-id file only holds the latest. Once it passes `DX_RUN_HISTORY_MAX` lines (default 2000) it is
trimmed to the last `DX_RUN_HISTORY_KEEP` (default 1000). Readers should skip lines that do not parse.

## Interrupted runs: the SessionEnd hook

When the session ends before a skill's final write (Ctrl+C, terminal closed, crash), its running
marker stays. dx-core's `SessionEnd` hook (`hooks/scripts/run-result-close.sh`) closes the markers this
session owns: `run_id` equal to the session's `DX_RUN_ID`, or a manual run whose `run_id` part before
the first `.` equals the ending session's id (hook input `session_id` — Copilot CLI too since v1.0.116 —
or `sessionId` on older Copilot CLI; the project comes from `CLAUDE_PROJECT_DIR`, else the input's `cwd`). It writes the result
as `failed`, `summary` "interrupted: <step>" — the last `in_progress` row of the marker's progress file,
also in `metrics.fail_at` — or "interrupted: the session ended before the skill wrote its result" when
there is no such row, `next_action` the re-run command, `metrics.interrupted: true`, keeping the
marker's `run_id`. Markers of other sessions and
markers with no run id are left alone, because another session in the same repo may still own them. A crash that skips
`SessionEnd` still leaves the marker; readers treat an old marker with no result as interrupted.

## Reading the history: `/dx-runs`

`/dx-runs [--days N] [--skill <name>] [--json]` (script: `plugins/dx-core/data/lib/run-history.sh`)
summarizes `history.jsonl` and the running markers per skill: runs, done / blocked / failed, success
rate, median `duration_s`, most common `metrics.fail_at` of unfinished runs, and running vs stale
markers (`--stale-hours`, default 6). `--json` prints one object for tools.
