# Post Findings — Standalone Procedure

This reference describes the standalone posting procedure for PR review findings saved to disk by `/dx-pr-review`. Used by automation pipelines and when posting is deferred from the review step.

## 1. Load Findings File

```bash
cat .ai/pr-reviews/pr-<id>-findings.md
```

If not found, stop with: `No findings file for PR #<id>. Run /dx-pr-review first.`

Parse the metadata section — extract: PR ID, title, repo name, repo ID, project, author, source branch, target branch, review commit, verdict, patch file reference.

Parse the issues section — extract each issue: severity, file, start line, end line, fixable flag, comment text.

Parse the summary section — extract the summary text.

## 2. Load Patches (optional)

Check if a patch file exists:

```bash
cat .ai/pr-reviews/pr-<id>.patch 2>/dev/null
```

If found, read and split by `diff --git` markers into per-file patches. Map each file patch to its corresponding issue by matching the file path.

## 3. Load MCP Tools

```
ToolSearch("+ado pull request thread")
ToolSearch("+ado repo")
```

Resolve the repo ID if not in findings metadata:

```
mcp__ado__repo_get_repo_by_name_or_id
  project: "<project>"
  repositoryNameOrId: "<repo name>"
```

## 4. Post Issue Threads

For each issue in the findings:

### Without patch (no patch file, or issue not fixable)

```
mcp__ado__repo_create_pull_request_thread
  repositoryId: "<repo ID>"
  pullRequestId: <PR ID>
  content: "<comment text>"
  filePath: "<file path>"
  rightFileStartLine: <start line>
  rightFileEndLine: <end line>
  rightFileStartOffset: 1
  rightFileEndOffset: 1
  status: "active"
```

**Inline positioning rules:**
- `filePath` must start with `/` and be relative to repo root (e.g., `/ui.frontend/src/brand/components/hero/brand-hero.js`)
- Parse line numbers from the findings table `Line(s)` column: `L42-L45` -> `rightFileStartLine: 42`, `rightFileEndLine: 45`
- Single-line findings (e.g., `L42`): set both start and end to the same line
- If line numbers are missing or the issue is file-level, omit `filePath` and all `rightFile*` params — this creates a PR-level comment instead of an inline one
- Always set `rightFileStartOffset: 1` and `rightFileEndOffset: 1` (column precision not available)
- Right-side line numbers refer to the NEW version of the file (post-change)

### With patch (patch file exists and issue is fixable)

Format the comment with an embedded patch:

```markdown
<issue comment text>

<details>
<summary>Proposed fix (click to expand)</summary>

\`\`\`diff
<per-file unified diff for this issue's file>
\`\`\`

To apply: `git apply` the patch from the summary comment, or copy this diff.
</details>
```

> **CRITICAL — diff rendering in `<details>` blocks:**
> 1. **Blank line after `</summary>` is mandatory** — without it, ADO won't process the code fence as markdown
> 2. **NEVER HTML-encode diff content** — write raw `<p>`, `<span>`, `<div>`, NOT `&lt;p&gt;`, `&lt;span&gt;`, `&lt;div&gt;`. The code fence handles escaping for display. HTML-encoding creates double-encoding that shows literal `&lt;` text to the reader.
> 3. **Always include the triple-backtick code fence** with `diff` language tag — without it, HTML tags in the diff get parsed as actual HTML

Post with the same `mcp__ado__repo_create_pull_request_thread` call.

If a thread fails to post: log the error and continue with remaining issues.

## 5. Post Summary Thread

Post a general PR comment (no `filePath`) with the review summary:

### Without patches

```markdown
**[AI Review] Verdict: <verdict>**

Reviewed <N> files — <M> issues found.

<summary text>

| # | Sev | File | Line(s) | Comment |
|---|-----|------|---------|---------|
| 1 | MUST-FIX | `file.js` | L42-L45 | <short description> |
| 2 | QUESTION | `file.js` | L10 | <short description> |
```

### With patches

```markdown
**[AI Review] Verdict: <verdict> — with proposed fixes**

Reviewed <N> files — <M> issues found, <K> with proposed patches.

<summary text>

| # | Sev | File | Line(s) | Comment | Patch |
|---|-----|------|---------|---------|-------|
| 1 | MUST-FIX | `file.js` | L42-L45 | <short description> | included |
| 2 | QUESTION | `file.js` | L10 | <short description> | — |

<details>
<summary>Full combined patch (click to expand)</summary>

\`\`\`diff
<full combined patch from pr-<id>.patch>
\`\`\`

To apply all fixes:
\`\`\`bash
git apply pr-fixes.patch
\`\`\`
</details>
```

## 6. Set Vote

Determine vote from the verdict in the findings:

| Verdict | `vote` enum | ADO integer |
|---------|-------------|-------------|
| `approved` | `Approved` | 10 |
| `approved-with-suggestions` | `ApprovedWithSuggestions` | 5 |
| `changes-requested` | `WaitingForAuthor` | -5 |
| `rejected` *(explicit block)* | `Rejected` | -10 |
| *(clear existing vote)* | `NoVote` | 0 |

Cast the vote via MCP (the tool auto-adds the caller as a reviewer if not already one):

```
mcp__ado__repo_vote_pull_request
  repositoryId: "<repo ID>"
  pullRequestId: <PR ID>
  vote: "<Approved | ApprovedWithSuggestions | WaitingForAuthor | Rejected | NoVote>"
```

**In interactive mode** (user invoked directly): use `AskUserQuestion` to confirm the vote, map the choice to the enum, then call `repo_vote_pull_request`.

**In automation** (pipeline context — detected by prompt containing "analyze only" or "save results", or by being chained after `/dx-pr-review`): cast the vote automatically based on the verdict. Do NOT call `AskUserQuestion`.

## 7. Update Session

Update the existing session file `.ai/pr-reviews/pr-<id>.md` (or create it if it doesn't exist) with thread IDs from the posted comments. Follow the same format as `/dx-pr-review` step 10.

## 8. Report

Print a summary of what was posted:

```
Posted <N> review threads to PR #<id>
<if patches: <K> threads include fix patches>
Vote: <verdict>
Threads: <list of thread IDs>
```

## Rules

- **Read-only** — never modifies code, never pushes, only reads saved files and posts to ADO
- **Findings required** — always requires `.ai/pr-reviews/pr-<id>-findings.md` from a prior `/dx-pr-review` run
- **Patches optional** — posts with patches if `.ai/pr-reviews/pr-<id>.patch` exists, plain comments otherwise
- **Continue on failure** — if one thread fails to post, log and continue
- **Collapsible patches** — use `<details>` with mandatory blank line after `</summary>`, never HTML-encode diff content
- **MCP tools are deferred** — always load via ToolSearch before first use
- **URL project precedence** — if a PR URL was provided, use the project from the URL, not from config
- **Automation-safe** — no `AskUserQuestion` calls when running in pipeline context
