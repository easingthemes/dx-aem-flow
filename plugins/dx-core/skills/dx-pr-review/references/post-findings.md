# Post Findings — Standalone Procedure

This reference describes the standalone posting procedure for PR review findings saved to disk by `/dx-pr-review`. Used by automation pipelines and when posting is deferred from the review step. Covers Azure DevOps, Bitbucket Cloud, and Bitbucket DC.

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

## 3. Detect Platform and Load Tools

Read the `Platform:` field from the findings metadata (added by `/dx-pr-review` step 10). If absent, default to `ado`.

### ADO

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

### Bitbucket Cloud / DC

Resolve the auth token (see `shared/bitbucket-config.md` — token resolution):

```bash
TOKEN="${BITBUCKET_TOKEN:-$(grep 'bitbucket-token:' .ai/config.yaml 2>/dev/null | awk '{print $2}' | tr -d '"')}"
[ -z "$TOKEN" ] && echo "ERROR: Bitbucket token not found." && exit 2
```

For DC, also set:

```bash
BB_HOST=$(grep 'bitbucket-host:' .ai/config.yaml | awk '{print $2}' | tr -d '"')
BB_BASE="$BB_HOST/rest/api/1.0"
```

The workspace/project key and repo slug come from findings metadata (`Project / Workspace:`, `Repo:`).

## 4. Post Issue Threads

### Idempotency — skip threads you already posted

**Before posting anything**, fetch the PR's existing comments so a re-run never double-posts.

**ADO:**

```
mcp__ado__repo_list_pull_request_threads
  repositoryId: "<repo ID>"
  pullRequestId: <PR ID>
```

Build a set of `(filePath, startLine)` from existing threads anchored to a file (`threadContext.filePath` + `threadContext.rightFileStart.line`). Also note whether any existing thread's first comment already contains the `**[AI Review]` marker (the summary thread).

**Bitbucket Cloud:**

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.bitbucket.org/2.0/repositories/{workspace}/{repoSlug}/pullrequests/{id}/comments?pagelen=100"
```

Build a set of `(inline.path, inline.to)` from existing inline comments. Check for `**[AI Review]` in any top-level `content.raw` for the summary guard.

**Bitbucket DC:**

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "$BB_BASE/projects/{project}/repos/{repoSlug}/pull-requests/{id}/comments?limit=100"
```

Build a set of `(anchor.path, anchor.line)` from existing inline comments. Check for `**[AI Review]` in any `text` for the summary guard.

**Skip rules (all platforms):**
- **Skip** any finding whose `(filePath, line)` already has a matching comment — it was posted on a prior run. Log `already posted: <file> L<line>` and continue.
- **Skip** the summary thread (step 5) if an `**[AI Review]` summary already exists.
- If **every** finding and the summary are already posted, post nothing and go straight to the vote (step 6). This is the crash-before-vote recovery path.

For each issue in the findings (that survived the idempotency skip above):

### Without patch (no patch file, or issue not fixable)

**ADO:**

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

ADO inline positioning rules:
- `filePath` must start with `/` and be relative to repo root
- `L42-L45` → `rightFileStartLine: 42`, `rightFileEndLine: 45`. Single line: set both to the same value.
- If line numbers are missing, omit `filePath` and all `rightFile*` params — creates a PR-level comment
- Always set `rightFileStartOffset: 1` and `rightFileEndOffset: 1`
- Right-side line numbers refer to the NEW version of the file (post-change)

**Bitbucket Cloud:**

```bash
# With inline context
BODY=$(jq -n --arg text "<comment>" --arg path "<file>" --argjson line <line> \
  '{content: {raw: $text}, inline: {path: $path, to: $line}}')
# File-level only (no line)
BODY=$(jq -n --arg text "<comment>" '{content: {raw: $text}}')

curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "$BODY" \
  "https://api.bitbucket.org/2.0/repositories/{workspace}/{repoSlug}/pullrequests/{id}/comments"
```

Cloud path note: no leading slash — e.g., `src/components/hero.js` not `/src/components/hero.js`.

**Bitbucket DC:**

```bash
# With inline context
BODY=$(jq -n --arg text "<comment>" --arg path "<file>" --argjson line <line> \
  '{text: $text, anchor: {line: $line, lineType: "ADDED", fileType: "TO", path: $path}}')
# File-level only (no line)
BODY=$(jq -n --arg text "<comment>" '{text: $text}')

curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "$BODY" \
  "$BB_BASE/projects/{project}/repos/{repoSlug}/pull-requests/{id}/comments"
```

### With patch (patch file exists and issue is fixable)

Format the comment with an embedded patch (same format for all platforms):

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
> 1. **Blank line after `</summary>` is mandatory** — without it, the platform won't process the code fence as markdown
> 2. **NEVER HTML-encode diff content** — write raw `<p>`, `<span>`, `<div>`, NOT `&lt;p&gt;`, `&lt;span&gt;`, `&lt;div&gt;`. The code fence handles escaping for display.
> 3. **Always include the triple-backtick code fence** with `diff` language tag

Post with the same platform-specific API call as above (substitute the formatted markdown for the plain text).

If a comment fails to post: log the error and continue with remaining issues.

## 5. Post Summary Thread

Post a general PR comment (no inline context) with the review summary. The comment format is the same for all platforms — only the API call differs.

### Comment text — without patches

```markdown
**[AI Review] Verdict: <verdict>**

Reviewed <N> files — <M> issues found.

<summary text>

| # | Sev | File | Line(s) | Comment |
|---|-----|------|---------|---------|
| 1 | MUST-FIX | `file.js` | L42-L45 | <short description> |
| 2 | QUESTION | `file.js` | L10 | <short description> |
```

### Comment text — with patches

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

### Post via platform API

**ADO** (no `filePath` = PR-level comment):

```
mcp__ado__repo_create_pull_request_thread
  repositoryId: "<repo ID>"
  pullRequestId: <PR ID>
  content: "<summary markdown>"
  status: "active"
```

**Bitbucket Cloud** (no `inline` block = PR-level comment):

```bash
BODY=$(jq -n --arg text "<summary markdown>" '{content: {raw: $text}}')
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "$BODY" \
  "https://api.bitbucket.org/2.0/repositories/{workspace}/{repoSlug}/pullrequests/{id}/comments"
```

**Bitbucket DC** (no `anchor` block = PR-level comment):

```bash
BODY=$(jq -n --arg text "<summary markdown>" '{text: $text}')
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "$BODY" \
  "$BB_BASE/projects/{project}/repos/{repoSlug}/pull-requests/{id}/comments"
```

## 6. Set Vote

Determine vote from the verdict in the findings. The clamping rules apply to all platforms.

### Vote mapping

| Verdict | Interactive | Automation (clamped — never positive on MUST-FIX, never hard-blocking) |
|---------|-------------|---------|
| `approved` | Approve | Approve |
| `approved-with-suggestions` | Approve with suggestions | Approve with suggestions |
| `changes-requested` | Request changes | **No vote (0)** — do not hard-block |
| `rejected` | Reject | **No vote (0)** — do not hard-block |
| *(clear vote)* | No vote | No vote |

Detect automation before voting:

```bash
AUTOMATION=0
[ "$DX_PIPELINE_MODE" = "true" ] && AUTOMATION=1
FLAG=".ai/run-context/orchestrating.flag"
if [ -f "$FLAG" ]; then
  AGE=$(( $(date +%s) - $(date -r "$FLAG" +%s) ))
  [ "$AGE" -lt 7200 ] && AUTOMATION=1
fi
```

**When `AUTOMATION=1`**: cast vote automatically, clamped at both ends. Positive votes only when no MUST-FIX exists; `changes-requested`/`rejected` → `NoVote` on all platforms. The summary thread must state plainly the bot is NOT approving when clamped. Never call `AskUserQuestion`.

**When `AUTOMATION=0`**: use `AskUserQuestion` to confirm the vote, then call the platform API.

### ADO

```
mcp__ado__repo_vote_pull_request
  repositoryId: "<repo ID>"
  pullRequestId: <PR ID>
  vote: "<Approved | ApprovedWithSuggestions | WaitingForAuthor | Rejected | NoVote>"
```

The tool auto-adds the caller as a reviewer if not already one.

### Bitbucket Cloud

```bash
# Approve (covers both Approved and ApprovedWithSuggestions)
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  "https://api.bitbucket.org/2.0/repositories/{workspace}/{repoSlug}/pullrequests/{id}/approve"

# Request changes
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  "https://api.bitbucket.org/2.0/repositories/{workspace}/{repoSlug}/pullrequests/{id}/request-changes"

# Remove/clear approval (NoVote)
curl -s -X DELETE -H "Authorization: Bearer $TOKEN" \
  "https://api.bitbucket.org/2.0/repositories/{workspace}/{repoSlug}/pullrequests/{id}/approve"
```

### Bitbucket DC

```bash
# Approve
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  "$BB_BASE/projects/{project}/repos/{repoSlug}/pull-requests/{id}/approve"

# Request changes (Needs Work) — resolve user slug first
USER_SLUG=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$BB_BASE/users?filter=$(git config user.email)" | jq -r '.values[0].slug')
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"user\": {\"name\": \"$USER_SLUG\"}, \"approved\": false, \"status\": \"NEEDS_WORK\"}" \
  "$BB_BASE/projects/{project}/repos/{repoSlug}/pull-requests/{id}/participants/$USER_SLUG"

# NoVote / clear
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"user\": {\"name\": \"$USER_SLUG\"}, \"approved\": false, \"status\": \"UNAPPROVED\"}" \
  "$BB_BASE/projects/{project}/repos/{repoSlug}/pull-requests/{id}/participants/$USER_SLUG"
```

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

- **Read-only** — never modifies code, never pushes, only reads saved files and posts to the SCM platform
- **Findings required** — always requires `.ai/pr-reviews/pr-<id>-findings.md` from a prior `/dx-pr-review` run
- **Patches optional** — posts with patches if `.ai/pr-reviews/pr-<id>.patch` exists, plain comments otherwise
- **Continue on failure** — if one comment fails to post, log and continue
- **Collapsible patches** — use `<details>` with mandatory blank line after `</summary>`, never HTML-encode diff content
- **Platform detection required** — read `Platform:` from findings metadata before any API calls; default to `ado`
- **MCP tools are deferred (ADO only)** — always load via ToolSearch before first ADO call; Bitbucket uses curl
- **URL project precedence** — if a PR URL was provided, use the project/workspace from the URL, not from config
- **Automation-safe** — no `AskUserQuestion` calls when running in pipeline context
- **Vote clamping applies on all platforms** — `changes-requested`/`rejected` → no vote in automation mode, on ADO, Cloud, and DC alike
