---
name: dx-pr-reviews-report
description: Generate categorized reports for multiple PR reviews — lists reviewed PRs, generates a report for each, and posts all to ADO Wiki or Confluence. Use when you want to document all recent PR reviews, mentions "report reviews", or wants batch PR review reports.
argument-hint: "[--any] [PR URL | Repo URL | count] [count]"
---

You generate review reports for multiple pull requests. By default, lists PRs where the current user is a reviewer (excluding own PRs) and processes them in parallel. With `--any`, lists all PRs with review threads without filtering and processes sequentially with user selection.

## Modes

| Mode | Filter | Processing | User Prompt |
|------|--------|------------|-------------|
| **Mine** (default) | `i_am_reviewer: true`, exclude own PRs | Parallel (all at once) | No — auto-generates all |
| **Any** (`--any` flag) | All PRs with review threads, no author filter | Sequential with selection | Yes — user picks which PRs |

## Defaults

Read `shared/ado-config.md` and `shared/provider-config.md` for how to look up project config from `.ai/config.yaml`.

- **Provider:** read from `.ai/config.yaml` `tracker.provider` — `ado` (default) or `jira`
- **Organization:** read from `.ai/config.yaml` `scm.org` — NEVER hardcode
- **Project:** read from `.ai/config.yaml` `scm.project`
- **Confluence space (Jira):** read from `.ai/config.yaml` `confluence.space-key`
- **Confluence PR review root (Jira):** read from `.ai/config.yaml` `confluence.pr-review-root`

## 1. Parse Input

Parse `$ARGUMENTS` to determine the mode:

### Flag detection

If `$ARGUMENTS` contains `--any`, remove it from the arguments and set `MODE=any`. Otherwise `MODE=mine`.

### Remaining arguments

| Input | Mode | Example |
|-------|------|---------|
| *(empty)* | Current repo, default count | `/dx-pr-reviews-report` (mine, 5 PRs) |
| `<number>` | Current repo, N PRs | `/dx-pr-reviews-report 5` |
| `--any` | Current repo, any mode, 10 PRs | `/dx-pr-reviews-report --any` |
| `--any <number>` | Current repo, any mode, N PRs | `/dx-pr-reviews-report --any 20` |
| `<repo URL>` | That repo, default count | `/dx-pr-reviews-report https://{org}/_git/My-Repo` |
| `<repo URL> <number>` | That repo, N PRs | `/dx-pr-reviews-report https://{org}/_git/My-Repo 20` |
| `<PR URL>` | Single PR (delegate) | `/dx-pr-reviews-report https://.../_git/.../pullrequest/12345` |

**Default count:** 5 for mine mode, 10 for any mode.

### Detect PR URL vs Repo URL

- Contains `/pullrequest/` → **single PR mode** — skip to step 4 and invoke `/dx-pr-review-report <URL>` directly.
- Contains `/_git/` but no `/pullrequest/` → **repo URL** — extract project and repo name from the URL. URL-decode the project. **The URL-extracted project takes precedence over the config default.**
- Numeric only → **count** for current repo

### Detect current repo

When no URL is provided, detect the repo from the git remote:

```bash
git remote get-url origin
```

Extract the repo name from the URL:
- `vs-ssh.visualstudio.com:v3/{org}/{project}/{repo}` → repo name is the last segment
- `{org}.visualstudio.com/{project}/_git/{repo}` → repo name after `_git/`

## 2. Load MCP Tools & Resolve Repo

Before any ADO calls, load the tools:

```
ToolSearch("+ado repo")
ToolSearch("+ado pull request thread")
ToolSearch("+ado wiki")
```

Resolve the repo name to an ID:

```
mcp__ado__repo_get_repo_by_name_or_id
  project: "<project from URL if provided, otherwise from config>"
  repositoryNameOrId: "<repo name>"
```

Save the `id` field — needed for all subsequent calls.

Also resolve the current user identity:

```bash
git config user.email
```

## 3. List PRs

### Mine mode (default)

Fetch PRs where the current user is a reviewer:

```
mcp__ado__repo_list_pull_requests_by_repo_or_project
  repositoryId: "<repo ID>"
  status: "All"
  i_am_reviewer: true
  top: <count * 2>
```

**Filter out own PRs:** Compare each PR's `createdBy.uniqueName` (case-insensitive) against the current user email from `git config user.email`. Remove matches — you don't need a report for your own PRs. Take the first `<count>` PRs after filtering (fetch extra to compensate for filtered-out PRs).

**Filter to PRs with meaningful review comments.** For each remaining PR, fetch threads:

```
mcp__ado__repo_list_pull_request_threads
  repositoryId: "<repo ID>"
  pullRequestId: <PR ID>
```

Skip PRs where **all threads are system-generated** (status updates, vote changes, policy evaluations, auto-complete). Only keep PRs that have at least one thread with an actual review comment. PRs with no meaningful comments don't need a report — mark them as `SKIP (no comments)` in the PR list.

### Any mode (`--any`)

Fetch recent PRs regardless of reviewer:

```
mcp__ado__repo_list_pull_requests_by_repo_or_project
  repositoryId: "<repo ID>"
  status: "All"
  top: <count>
```

Then filter to PRs with review threads — for each PR:

```
mcp__ado__repo_list_pull_request_threads
  repositoryId: "<repo ID>"
  pullRequestId: <PR ID>
```

Keep only PRs that have **at least one non-system review thread** (actual code review comments, not just status updates or vote changes).

### Check for existing reports

Use the helper script to check which PRs already have reports:

```bash
bash scripts/check-existing-reports.sh <pr-id-1> <pr-id-2> ...
```

Returns JSON: `[{"prId": N, "exists": true/false, "path": "..."}]`

### Present PR List

```markdown
## PRs <with My Reviews | with Reviews> — <repo name> (<count> found)

| # | PR | Title | Author | Status | Report |
|---|-----|-------|--------|--------|--------|
| 1 | [#12345](url) | Fix login bug | John D. | Completed | NEW |
| 2 | [#12346](url) | Add feature X | Jane S. | Active | EXISTS |
| 3 | [#12347](url) | Update styles | Bob K. | Completed | NEW |
| 4 | [#12348](url) | Config change | Alice W. | Completed | SKIP (no comments) |
```

For each PR show:
- **PR number** with link
- **Title** — truncated to 60 chars if needed
- **Author** — display name
- **Status** — Active / Completed / Abandoned
- **Report** — `NEW` (no report exists), `EXISTS` (report already generated), or `SKIP (no comments)` (no meaningful review comments — report not needed)

### Handle empty list

If no PRs found:
- Mine mode: "No PRs where you are a reviewer in <repo name>." and stop.
- Any mode: "No reviewed PRs in <repo name>." and stop.

### User confirmation

- **Mine mode:** Show the list, then proceed automatically — no selection prompt. Skip PRs marked `SKIP (no comments)`. Print: "Generating reports for <N> PRs (skipping <M> with no comments)..."
- **Any mode:** Show the list and ask: `Generate reports for which PRs? (e.g., "all", "1 3", "new only")`

## 4. Generate Reports

### Mine mode — Parallel Processing

Build the PR URL for each PR:
```
PR_URL = "<scm.org>/<project>/_git/<repo>/pullrequest/<id>"
```

Read wiki config from `.ai/config.yaml`:
- `tracker.provider` — `ado` (default) or `jira`
- `scm.wiki-id` — wiki identifier (ADO)
- `scm.wiki-project` — project that owns the wiki (ADO)
- `scm.wiki-pr-review-root` — parent page path (ADO)
- `confluence.space-key` — Confluence space key (Jira)
- `confluence.pr-review-root` — parent page title for PR reviews (Jira)

Spawn **one Agent per PR**, all in a single message (parallel execution):

```
Agent(
  subagent_type: "general-purpose",
  description: "PR report #<id>",
  prompt: "You are generating a PR review report. Follow the dx-pr-review-report skill logic exactly.

## Your task
Generate a categorized report for PR #<id> and post it to wiki.

## Config
- Provider: <tracker.provider>   # ado or jira
- Organization: <scm.org>
- Project: <project>
- Repository ID: <repo ID>
- Repository name: <repo name>
- PR ID: <id>
### ADO Wiki (if provider = ado)
- Wiki ID: <scm.wiki-id>
- Wiki project: <scm.wiki-project>
- Wiki PR review root: <scm.wiki-pr-review-root>
### Confluence (if provider = jira)
- Confluence space key: <confluence.space-key>
- Confluence PR review root: <confluence.pr-review-root>

## Report template
Read the report template from: <absolute path to plugin>/skills/dx-pr-review-report/assets/report-template.md
Use this template structure for the output — replace {{PLACEHOLDER}} tokens with actual PR data.

## Steps

1. Load MCP tools: ToolSearch('+ado repo'), ToolSearch('+ado pull request thread'), ToolSearch('+ado wiki'), ToolSearch('+ado work item'). If provider = jira, also: ToolSearch('+atlassian confluence')

2. Fetch PR details via mcp__ado__repo_get_pull_request_by_id. Extract title, author, reviewers, status, dates, work item links.

3. Resolve linked work item if present — check PR description for #12345 patterns, fetch via mcp__ado__wit_get_work_item.

4. Fetch all review threads via mcp__ado__repo_list_pull_request_threads. For each thread, fetch full comments via mcp__ado__repo_list_pull_request_thread_comments (fullResponse: true).

5. Filter to meaningful threads — skip system-generated threads (status updates, vote changes). Keep threads with actual review comments.

6. Categorize each comment into: Accessibility, Bug, Security, Regression, Functionality, Performance, Code Quality, Convention.

7. Read the report template, fill in the data, write to .ai/pr-reviews/reports/pr-<id>-report.md.
   Key formatting: each finding line includes *(reviewer: <comment author name>)* after the issue summary.
   Omit categories with 0 findings. Omit Patch Resolution if no patches. Sort categories by count desc.

8. Post to wiki based on provider:
   **If provider = ado:**
   - Page path: <wiki-pr-review-root>/<ticket-number> - <meaningful-title>
   - Check parent exists (mcp__ado__wiki_get_page), create if needed
   - Create page via mcp__ado__wiki_create_or_update_page
   **If provider = jira (Confluence):**
   - Find parent page: mcp__atlassian__confluence_search with CQL for <confluence.pr-review-root> in <confluence.space-key>
   - Convert markdown to Confluence storage format (XHTML) if server doesn't accept markdown
   - Create via mcp__atlassian__confluence_create_page or update via mcp__atlassian__confluence_update_page

9. Return a JSON summary line at the END of your response in this exact format:
REPORT_SUMMARY: {\"prId\": <id>, \"title\": \"<title>\", \"ticket\": \"<ticket or none>\", \"categories\": \"<e.g. 2 Bug, 1 A11Y>\", \"comments\": <total>, \"findings\": <meaningful>, \"patches\": \"<P proposed, F fixed>\", \"wiki\": \"<Posted or Local>\", \"reportPath\": \".ai/pr-reviews/reports/pr-<id>-report.md\"}
"
)
```

### Any mode — Sequential Processing

Process each selected PR by invoking `/dx-pr-review-report`:

```
Skill("dx-pr-review-report", args: "<PR URL or ID>")
```

Between each PR, print a separator:

```markdown
---
### Report <N> of <M>: PR #<id> — <title>
```

### Wiki Posting

- **Mine mode:** Each parallel agent handles its own wiki posting using the config values passed in the prompt. The agent uses ADO wiki or Confluence based on the `provider` value in the config block.
- **Any mode:** After each report is generated, if the user requested wiki posting (or `PIPELINE_MODE=true`), the individual `/dx-pr-review-report` skill handles wiki creation (ADO or Confluence based on `tracker.provider`). If the user said "all to wiki" at the start, pass this intent through to each invocation.

## 5. Print Summary

After all reports are generated (all agents complete in mine mode, or all sequential reports in any mode), print an aggregate summary:

```markdown
## PR Review Reports — <repo name> (<mine | any> mode)

| # | PR | Title | Ticket | Categories | Comments | Patches | Wiki |
|---|-----|-------|--------|------------|----------|---------|------|
| 1 | #12345 | Fix login bug | #2416553 | 2 Bug, 1 A11Y | 5 | 2/3 fixed | Posted |
| 2 | #12346 | Add feature X | #2437173 | 3 Func, 1 Perf | 8 | 1/1 fixed | Posted |
| 3 | #12347 | Update styles | — | 2 Convention | 3 | 0 | Local |

**Reports generated:** <N> | **Skipped (no comments):** <M>
**Total findings:** <sum across all PRs>
**Most common category:** <top category with count>
**Output:** .ai/pr-reviews/reports/pr-<id>-report.md
**Wiki:** <N posted to wiki> / <M local only>
```

For mine mode, parse the `REPORT_SUMMARY` JSON line from each agent's response to build the summary table.

## Examples

1. `/dx-pr-reviews-report 5` — Fetches last 5 PRs where you are a reviewer (excluding your own PRs). Pre-filters to PRs with meaningful review comments — skips PRs with only system threads (approvals, policy updates). Generates reports in parallel for the remaining PRs, posts each to ADO wiki.

2. `/dx-pr-reviews-report` — Same as above with default count of 5.

3. `/dx-pr-reviews-report --any 20` — Lists up to 20 PRs from the current repo that have review threads (any reviewer). User selects which to report. Generates reports sequentially.

4. `/dx-pr-reviews-report --any https://dev.azure.com/myorg/MyProject/_git/Other-Repo 20` — Lists up to 20 PRs from a different repo that have review threads. Generates reports for selected PRs.

5. `/dx-pr-reviews-report https://dev.azure.com/myorg/MyProject/_git/MyRepo/pullrequest/12345` — Detects a single PR URL, skips the listing step, and delegates directly to `/dx-pr-review-report` for that specific PR.

## Troubleshooting

- **"No PRs where you are a reviewer in <repo>"**
  **Cause:** You haven't been added as a reviewer on any recent PRs in this repo.
  **Fix:** Check if you're reviewing PRs in a different repo, or use `--any` to see all reviewed PRs.

- **"No reviewed PRs in <repo>"** (any mode)
  **Cause:** None of the recent PRs have review comment threads.
  **Fix:** Run `/dx-pr-review-all` first to review PRs, then generate reports.

- **"Report already exists for PR #<id>"**
  **Cause:** A previous run already generated a report.
  **Fix:** The PR shows `EXISTS` in the list. In mine mode it regenerates automatically. In any mode, select it to regenerate.

- **Wiki posting fails for some PRs**
  **Cause:** Wiki permissions or path issues. The skill logs failures and continues with remaining PRs.
  **Fix:** Check `scm.wiki-pr-review-root` in config and verify wiki access permissions.

- **Parallel agent fails for one PR**
  **Cause:** MCP tool error or PR data issue for that specific PR.
  **Fix:** The other agents continue independently. Check the failed agent's output for details. Retry the failed PR with `/dx-pr-review-report <PR URL>`.

## Rules

- **Mine by default** — without `--any`, filter to PRs where current user is reviewer, exclude own PRs (compare `createdBy.uniqueName` vs `git config user.email`)
- **Parallel for mine** — spawn one agent per PR, all in a single message for concurrent execution
- **Sequential for any** — process one at a time via `/dx-pr-review-report` with user selection, no author filtering
- **Auto-proceed for mine** — no selection prompt, generate all reports automatically
- **Selection for any** — show list and let the user choose which to report on
- **Skip existing reports** — mark PRs with existing reports but don't skip them automatically (let user decide in any mode; regenerate in mine mode)
- **Include all PR statuses** — don't limit to active only. Completed PRs with reviews are the main use case
- **Aggregate summary** — always show the cross-PR summary table at the end
- **Current repo as default** — when no arguments, detect repo from git remote
- **Identity from git** — resolve current user via `git config user.email`
- **MCP tools are deferred** — always load via ToolSearch before first use
- **No hardcoded values** — read all project-specific values from `.ai/config.yaml`
- **Config-driven wiki** — wiki path from `scm.wiki-pr-review-root`, never hardcode
