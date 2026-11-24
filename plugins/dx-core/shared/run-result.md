# Run Result — one JSON file per coordinator run

Coordinator skills (`dx-agent-all`, `dx-bug-all`, `dx-pr-review`, `dx-prep`) write a small result file at the
end of **every** run — success, STOP, or failure — so the tool that started the run (a dashboard, a script, a
hub) can show the outcome without parsing terminal text. Schema: `docs/reference/run-result.md` in the plugin repo.

## How

Call the helper as the last action of the run, after the final summary is printed:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/data/lib/run-result.sh" \
  --skill <skill-name> --id <work item or PR id> --status <done|blocked|failed> \
  [--verdict <verdict>] [--vote <vote cast>] [--next "<next command or step>"] \
  [--pr <PR url>] [--wiki <wiki url>] [--work-item <work item url>] \
  [--summary "<one line>"]
```

It writes `.ai/run-results/<skill>-<id>.json` (latest run wins) and prints the path. Omit an option, or pass
an empty value, when there is nothing to report — it becomes `null`.

## Status

| `--status` | When |
|------------|------|
| `done` | The skill reached its normal end (it may still have skipped optional parts — say so in `--summary`) |
| `blocked` | The run stopped and needs a human: a gate failed, a question it must not guess, missing input |
| `failed` | An error ended the run (tool failure, build failure after retries, nothing produced) |

## Rules

- **Every exit path** — write the file on STOP and failure branches too, not only on success. A missing file means the run was interrupted before its end.
- **One line, no content** — `--summary` and `--next` are one short line each. Never put file contents, ticket text, diffs or secrets in them.
- **Links are URLs you already have** — the PR, wiki page and work item URLs the run created or read. Never construct one you did not see.
- **Never fail the run because of it** — if the helper exits non-zero, print one warning line and finish normally.
- **Not in git** — `.ai/run-results/` is listed in the `.gitignore` entries `/dx-init` suggests.
