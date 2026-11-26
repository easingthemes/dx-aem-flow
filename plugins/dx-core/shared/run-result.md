# Run Result — how a flow skill records its run

Every skill a tool can start as a flow — the coordinators (`dx-agent-all`, `dx-bug-all`, `dx-post-merge`, `dx-prep`, `dx-pr-review`) and the skills they call or a tool starts on its own (`dx-req`, `dx-plan`, `dx-step-all`, `dx-step-verify`, `dx-pr-answer`, `dx-bug-fix`, `dx-dor`, `dx-estimate`, `dx-req-dod`, `dx-doc-gen`, `dx-qa-handoff`, dx-aem's `aem-demo-page`, dx-hub's `dx-hub-dispatch`) — records its run, so the tool that started it (a dashboard, a script, a hub) can always tell how it ended without parsing terminal text. Schema: `docs/reference/run-result.md` in the plugin repo.

A skill's SKILL.md says **when** (its start point, its steps, its exits with their status); this file says **how**. Skills link here instead of repeating it.

## Which helper path

| Skill's plugin | Run the helpers as |
|----------------|--------------------|
| dx-core | `bash "${CLAUDE_PLUGIN_ROOT}/data/lib/run-result.sh"`, `bash "${CLAUDE_PLUGIN_ROOT}/shared/update-progress.sh"` |
| dx-aem | `bash .ai/lib/run-result.sh`, `bash .ai/lib/update-progress.sh` — the project copies `/dx-init` / `/dx-upgrade` install (a dx-aem skill's `${CLAUDE_PLUGIN_ROOT}` is dx-aem's root) |
| dx-hub | `bash "${CLAUDE_SKILL_DIR}/scripts/dx-core-lib.sh" run-result.sh …` / `… update-progress.sh …` — finds dx-core beside dx-hub (a hub has no `.ai/lib/`) |

The examples below use the dx-core form.

## 1. Start

The first action once the id is known — before any long work:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/data/lib/run-result.sh" --start --skill <skill-name> --id <id> \
  [--progress-file <progress file name>] [--spec-dir <spec dir, if not .ai/specs/<id>-*/>]
```

It writes `.ai/run-results/<skill>-<id>.running.json`: `run_id` (the caller's `DX_RUN_ID`; for a manual run `<session id>.<n>`), `started_at`, `progress_file`, `spec_dir` (found as the one `.ai/specs/<id>-*/` when not passed). Pass `--progress-file` whenever the skill keeps one (step 2) — the SessionEnd hook reads it to name the step a run was interrupted in.

## 2. Steps — the progress file

A skill with more than one step keeps a progress table in its spec folder, written with the shared script:

```bash
DX_PROGRESS_FILE="<file>" DX_PROGRESS_TITLE="/<skill> Progress" DX_PROGRESS_LABEL="Step" \
  bash "${CLAUDE_PLUGIN_ROOT}/shared/update-progress.sh" "$SPEC_DIR" "<step>" "<status>" "[short note]"
```

- One row per step: `| Step | Status | Note | Updated |` — `Updated` is the UTC time the row was last written (filled in by the script).
- Status: `pending` → `in_progress` → `done` · `skipped` · `blocked` · `failed`.
- Mark a step `in_progress` **before** it starts, not after it finishes — an interrupted run is reported by its last `in_progress` row.
- A skipped step gets a `skipped` row with the reason; a retry updates the note (`retry 1`), never adds a row.
- A nested skill (step 5) is one row in the caller's file — `in_progress` before calling it, its outcome after. Rules for the file itself: `rules/task-progress.md`.
- No spec folder (`dx-pr-review`, `dx-pr-answer` work on a PR) → no progress file; leave `--progress-file` out.

## 3. End — exactly one final result on every exit

The last action of every exit path, after the final message:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/data/lib/run-result.sh" \
  --skill <skill-name> --id <id> --status <done|blocked|failed> --summary "<one line>" \
  [--next "<next command or step>"] [--verdict <verdict>] [--vote <vote cast>] \
  [--pr <PR url>] [--wiki <wiki url>] [--work-item <work item url>] \
  [--metric <key>=<value>]... [--mode <automation|interactive>] [--mode-reason <env|flag|args|no-ask|none>]
```

| `--status` | When | Say |
|------------|------|-----|
| `done` | The skill reached its normal end — including **nothing to do** (output already up to date, nothing changed) | `--summary` what was done, or that there was nothing to do |
| `blocked` | It stopped waiting for the user or another system: a gate failed, missing config or input, a deploy or another repo not ready, a question it must not guess | `--summary` what it waits for; `--next` the command to run once it is there |
| `failed` | An error ended it: tool or MCP failure, build failure after retries, nothing produced | `--summary` the error; `--metric fail_at=<step>` the failing step |

No exit path may end without this write — a STOP, an early return and an error branch each write one. A missing result means the run was interrupted (step 4).

It writes `.ai/run-results/<skill>-<id>.json` (latest run wins), removes the running marker, carries `run_id` / `started_at` over from it, adds `duration_s`, and appends the result to `history.jsonl` (step 6). Omit an option, or pass an empty value, when there is nothing to report — it becomes `null`.

- `--metric key=value` (repeatable) — the counts listed for your skill in `docs/reference/run-result.md` § Metrics. Pass only counts you already have; leave one out rather than guess. Integers become numbers, `true`/`false` booleans, anything else a short string.
- `--mode` / `--mode-reason` — whether this run was `automation` or `interactive`, and why. `env.dx_version` and `env.engine` are filled in by the helper.

## 4. Interrupted runs

When the session ends before the final write (Ctrl+C, terminal closed, crash, the model stopping early), dx-core's `SessionEnd` hook (`hooks/scripts/run-result-close.sh`) closes the session's running markers — those whose `run_id` is the session's `DX_RUN_ID`, or `<session id>.<n>` for a manual run. It writes `--status failed`, `metrics.interrupted: true`, `summary` `interrupted: <last in_progress step>` (`metrics.fail_at` the same step) when the progress file names one, and `next_action` the re-run command. It runs on Claude Code and Copilot CLI alike: Copilot reads the plugin's `hooks.json` too, and since v1.0.116 sends the same `session_id` / `cwd` input and sets `CLAUDE_PROJECT_DIR` (older Copilot sent `sessionId`; the hook takes either).

## 5. Nested skills

A skill called by another skill inherits the caller's `DX_RUN_ID` and writes its **own** marker and result — `<its skill>-<id>.json`, never the caller's file. So one `run_id` can appear in several files; a reader matches on **skill and** `run_id`. Never set `DX_RUN_ID` yourself: it belongs to the tool that started the outermost skill.

## 6. History

Every final write (including the hook's) appends the same object as one line to `.ai/run-results/history.jsonl` — `skill`, `id`, `run_id`, `status`, `duration_s`, `metrics` and the rest. `/dx-runs` summarizes it.

## Rules

- **Start once, end once** — `--start` once per run; never pass `--status` with it.
- **One line, no content** — `--summary` and `--next` are one short line each. Never put file contents, ticket text, diffs or secrets in them.
- **Links are URLs you already have** — never construct one you did not see.
- **Never fail the run because of it** — if a helper exits non-zero or is missing, print one warning line and finish normally.
- **Not in git** — `.ai/run-results/` is listed in the `.gitignore` entries `/dx-init` suggests.
