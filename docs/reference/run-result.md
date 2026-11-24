# Run Result File: `.ai/run-results/<skill>-<id>.json`

Written at the end of every run (including STOP and failure) by the coordinator skills `dx-agent-all`,
`dx-bug-all`, `dx-pr-review` and `dx-prep`, through `plugins/dx-core/data/lib/run-result.sh`
(procedure: `plugins/dx-core/shared/run-result.md`). Meant for tools that start a skill and need its
outcome — a local dashboard, a script, a hub — without parsing terminal output.

- One file per skill and id; a new run overwrites it (latest wins).
- Local only: `.ai/run-results/` belongs in `.gitignore`.
- A missing file after the session ended means the run was interrupted before its end.

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
| `finished_at` | string | UTC ISO 8601 time the file was written |

### `status`

| Value | Meaning |
|-------|---------|
| `done` | The skill reached its normal end. Optional parts may have been skipped — `summary` says which |
| `blocked` | Stopped for a human: a gate failed, a question it must not guess, input missing |
| `failed` | An error ended the run |

All string values are single-line; control characters are replaced by spaces. Readers should ignore
fields they do not know, so new optional fields can be added within schema 1.
