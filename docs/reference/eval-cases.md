# Eval Case Contract: `claude plugin eval` cases

What a behavioural eval case in `plugins/<plugin>/evals/` must look like, for people and for tools that
generate cases (for example a dashboard that turns a past run into a case skeleton). The eval runner
checks graders with **strict** schemas when the case runs: an unknown key fails a billed run.
`plugins/dx-core/data/lib/eval-case-check.sh <dir>...` checks the same rules for free; CI runs it over
every `evals/` folder in this repo (`data/lib/tests/eval-case-check.test.sh`). Rules taken from
Claude Code v2.1.322 — re-check after an upstream change to `claude plugin eval`.

## Folder

```
evals/<case-name>/
├── prompt.md          # frontmatter = run options, body = the prompt
├── case.yaml          # optional: schema_version, name, context.* (e.g. scaffold_script)
├── graders/*.md       # one grader per file: frontmatter + optional body
└── resources/         # optional: fixtures, scaffold script
```

- A case needs a prompt: the `prompt.md` body, or `execution.prompt` in `case.yaml`. The blank
  `claude plugin eval init --bare` text (`TODO: describe what the agent should do`) is rejected.
- `case.yaml` needs `schema_version` (`"1.1"` today). A `context.scaffold_script` path must exist.
- At least one grader.

## Graders

Every grader has `type`, and may have `weight` (positive number, default 1) and `arm`
(`with-only` | `both`). Other keys per type — nothing else is accepted:

| `type` | Keys | Body |
|--------|------|------|
| `regex` | `target`, `pattern`, `flags` (JS flags `dgimsuvy`), `match` (`contains` \| `not_contains` \| `count:N`) | the pattern, when `pattern:` is not set |
| `file_exists` | `path` (glob, required), `exists` (`true` \| `false`) | note |
| `tool_used` | `tool` (required), `input_match`, `min`, `max` (non-negative integers) | note |
| `tool_order` | `before`, `after` (both required; a tool name or `{tool, input_match}`) | note |
| `llm` | `criteria`, `focus` | the rubric, when `criteria:` is not set |
| `baseline` | `baseline_file` (required), `criteria` | the rubric, when `criteria:` is not set |

`target` / `focus`: `last_message` (default), `trace`, `files` (paths created during the run — paths only),
`mock_calls`, or `{ source: file, path: <path> }` to grade a file's contents.

## Common mistakes the checker catches

| Wrong | Right |
|-------|-------|
| `type: regex` with `path:` / `must_match:` | `target: { source: file, path: <file> }` + `pattern:` (+ `match: not_contains` for "must not match") |
| `type: tool_used` with `expect: false` | `max: 0` |
| `type: exit_code`, `type: json` | not grader types — use `regex` on a file the case writes |
| `file_exists` for a file that existed before the run | it only sees files **created** during the run |

## For run-based seeds

A case built from a real dx run should grade what dx writes deterministically:
`file_exists` on `.ai/run-results/<skill>-*.json`; `regex` with `target: { source: file, path: … }` on
that file for `"status": "done"` or a verdict; `tool_used` with `tool: AskUserQuestion` and `max: 0` for
an autonomous run. Fixtures must be synthetic (this repo is public). Sanity-check every grader against
a known-bad run — see CLAUDE.md § Behavioral evals.
