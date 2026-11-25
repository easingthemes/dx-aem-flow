# PR Review Findings File: `.ai/pr-reviews/pr-<id>-findings.json`

Written by `dx-pr-review` (step 4d) next to `pr-<id>-findings.md`, and updated when the findings are
posted (`references/post-findings.md` step 7). The markdown file holds the comment text for posting;
this file holds only what a tool needs to count and to match findings with ADO threads — for example
how many of the bot's threads the author fixed versus closed as won't fix. Local only, like the rest of
`.ai/pr-reviews/`.

## Schema (version 1)

```json
{
  "schema": 1,
  "pr": "12345",
  "verdict": "approved-with-suggestions",
  "review_commit": "0123456789abcdef0123456789abcdef01234567",
  "created": "2026-01-01T12:00:00Z",
  "summary_thread_id": 9001,
  "issues": [
    { "n": 1, "severity": "MUST-FIX", "category": "bug", "file": "/src/app.js",
      "start_line": 42, "end_line": 45, "fixable": true, "patch": true, "thread_id": 9002 },
    { "n": 2, "severity": "QUESTION", "category": "question", "file": "/src/util.js",
      "start_line": 10, "end_line": 10, "fixable": false, "patch": false, "thread_id": null }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `schema` | number | `1` |
| `pr` | string | PR id |
| `verdict` | string | `approved` \| `approved-with-suggestions` \| `changes-requested` \| `rejected` |
| `review_commit` | string | Source-branch commit the review looked at |
| `created` | string | UTC ISO 8601 time the findings were saved |
| `summary_thread_id` | number \| null | ADO thread id of the summary thread; `null` until posted |
| `issues[].n` | number | Issue number, as in the markdown file |
| `issues[].severity` | string | `MUST-FIX` \| `QUESTION` |
| `issues[].category` | string | `bug` \| `security` \| `performance` \| `convention` \| `question` \| `other` |
| `issues[].file` | string | Repo path with a leading `/` |
| `issues[].start_line`, `end_line` | number | Line range on the source side |
| `issues[].fixable` | boolean | The reviewer gave enough detail for a patch |
| `issues[].patch` | boolean | A patch was posted with the thread |
| `issues[].thread_id` | number \| null | ADO thread id once posted; `null` when not posted or posting failed |

No comment text, ticket text or code is stored here. A follow-up review rewrites the file. Readers
should ignore unknown fields.
