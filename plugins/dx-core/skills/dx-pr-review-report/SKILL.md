---
name: dx-pr-review-report
description: Generate a categorized report from an existing PR review — groups comments by category (accessibility, bug, functionality, regression, etc.), tracks patch resolution, and posts to ADO Wiki or Confluence. Use when you want to document what was reviewed in a PR.
argument-hint: "<PR URL or ID>"
---

You generate a structured report from an existing PR review. The report groups review comments by category, summarizes patch outcomes, and optionally posts to the ADO wiki.

## Defaults

Read `shared/ado-config.md` and `shared/provider-config.md` for how to look up project config from `.ai/config.yaml`.

- **Provider:** read from `.ai/config.yaml` `tracker.provider` — `ado` (default) or `jira`
- **Organization:** read from `.ai/config.yaml` `scm.org` — NEVER hardcode
- **Project:** read from `.ai/config.yaml` `scm.project`
- **Wiki parent page (ADO):** read from `.ai/config.yaml` `scm.wiki-pr-review-root` — parent wiki page for PR review reports
- **Confluence space (Jira):** read from `.ai/config.yaml` `confluence.space-key`
- **Confluence PR review root (Jira):** read from `.ai/config.yaml` `confluence.pr-review-root` — parent page title for PR review reports

## 1. Parse Input

The argument is either:

- **Full URL**: `https://{org}.visualstudio.com/{project}/_git/{repo}/pullrequest/{id}` or `https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{id}` — extract `project`, `repo`, and `pullRequestId`. URL-decode the project. **The URL-extracted project takes precedence over the config default.**
- **PR ID only** (number): Detect repo from `git remote get-url origin`, read `.ai/config.yaml` for repo → ADO project mapping

Load MCP tools before any ADO calls:

```
ToolSearch("+ado repo")
ToolSearch("+ado pull request thread")
ToolSearch("+ado wiki")
ToolSearch("+ado work item")
```

## 2. Fetch PR Details

Resolve the repo ID first:

```
mcp__ado__repo_get_repo_by_name_or_id
  project: "<project from URL if provided, otherwise from config>"
  repositoryNameOrId: "<repo name>"
```

Then fetch the PR:

```
mcp__ado__repo_get_pull_request_by_id
  repositoryId: "<repo ID>"
  pullRequestId: <PR ID>
```

Extract:
- **Title**, **PR ID**, **Author** (displayName)
- **Source branch**, **Target branch**
- **Status** (active, completed, abandoned)
- **Created date**, **Closed date** (if completed)
- **Reviewers** and their votes
- **Description** — for understanding the PR intent
- **Work item links** — from `resourceRef` relations (artifact links with `vstfs:///Git/PullRequestId/`)

### 2a. Resolve Linked Work Item

Try to find a linked ADO ticket:

1. Fetch the PR's work item references:
   ```
   mcp__ado__repo_list_pull_requests_by_commits
   ```
   Or check the PR description for work item IDs (patterns: `#12345`, `AB#12345`, `ADO #12345`).

2. If a work item is linked, fetch it:
   ```
   mcp__ado__wit_get_work_item
     project: "<project>"
     id: <work item ID>
   ```
   Extract the **ticket number** and **title** for the wiki page name.

3. If no linked work item is found, use the PR title and ID instead.

## 3. Fetch All Review Threads

```
mcp__ado__repo_list_pull_request_threads
  repositoryId: "<repo ID>"
  pullRequestId: <PR ID>
```

For each thread, fetch the full conversation:

```
mcp__ado__repo_list_pull_request_thread_comments
  repositoryId: "<repo ID>"
  pullRequestId: <PR ID>
  threadId: <thread ID>
  fullResponse: true
```

### 3a. Filter Meaningful Threads

Skip system-generated threads (status updates, vote changes, auto-merge notifications). Keep only threads that contain actual review comments — i.e., threads where:
- A reviewer left a code comment (has `filePath` + `rightFileStartLine`)
- A reviewer left a general comment with substantive content (not just "LGTM" or status changes)

For each meaningful thread, extract:
- **Author** — who wrote the comment (reviewer name)
- **File** and **line range** (if code-level comment)
- **Comment text** — the review feedback
- **Thread status** — active, fixed, closed, won't fix, by design
- **Reply count** — how many replies in the thread
- **Has patch** — does the comment contain a `<details>` block with a diff?
- **Author response** — did the PR author reply? What did they say?
- **Resolution** — was the issue fixed (thread status = fixed/closed), declined (won't fix/by design), or still open (active)?

## 4. Categorize Comments

Classify each meaningful comment into one of these categories based on its content:

| Category | Indicators |
|----------|-----------|
| **Accessibility** | ARIA, keyboard, focus, screen reader, alt text, semantic HTML, contrast, WCAG |
| **Bug** | null pointer, crash, exception, undefined, error handling, edge case, race condition |
| **Security** | XSS, injection, sanitization, authentication, authorization, CSRF, secrets |
| **Regression** | "this used to work", "breaks existing", backward compatibility, side effect |
| **Functionality** | logic error, wrong behavior, missing feature, incorrect output, business rule |
| **Performance** | memory leak, unnecessary re-render, N+1 query, large payload, caching |
| **Code Quality** | naming, duplication, dead code, complexity, maintainability, readability |
| **Convention** | project patterns, style guide, naming conventions, file structure |

Use the comment text and context to classify. If a comment spans multiple categories, pick the primary one. If unsure, default to **Code Quality**.

## 5. Generate Report

Create the report directory:

```bash
mkdir -p .ai/pr-reviews/reports
```

Read the report template from `assets/report-template.md` (relative to this skill's directory). Use the template structure as the output format — replace `{{PLACEHOLDER}}` tokens with actual values from the PR data collected in steps 2–4.

Write the result to `.ai/pr-reviews/reports/pr-<id>-report.md`.

**Key formatting rules:**
- For each finding: `- **<file>:<line>** — <concise summary> *(reviewer: <comment author>)*`
- Status line below each finding: `  - Status: Fixed / Declined / Open`
- If patch proposed: `  - Patch: Proposed → Fixed by author / Proposed → Declined / Proposed → Open`
- If author replied: `  - Author: "<brief quote>"`
- Omit categories with 0 findings entirely
- Omit Patch Resolution section if no patches were proposed
- Sort categories by finding count descending

### Title Generation

The `<meaningful-title>` should be:
1. If a linked ticket exists: use the ticket title, improved for clarity if needed
2. If no ticket: generate a meaningful title from the PR changes (not just the PR title)
3. Keep it concise — max 60 characters
4. Should describe what was changed, not the PR process

Examples:
- `[2416553] - Enhanced PLP Filter Sticky Behavior`
- `[2437173] - Security Banner & Animated Barcode Validation`
- `[No Ticket] - Fix Hero Component Null Reference`

## 6. Post to Wiki

If the user asks to post to wiki, OR if `PIPELINE_MODE=true`:

Read `tracker.provider` from `.ai/config.yaml` (default: `ado`).
- If `ado` → follow **Section 6-ADO** below.
- If `jira` → follow **Section 6-Confluence** below.

### 6-ADO: Post to ADO Wiki

#### 6a. Read Wiki Config

```yaml
scm:
  wiki-id: "<wiki identifier>"
  wiki-project: "<project that owns the wiki>"
  wiki-pr-review-root: "<parent page path for PR review reports>"
```

If `scm.wiki-pr-review-root` is not configured:
```
Wiki PR review root not configured — add `scm.wiki-pr-review-root` to .ai/config.yaml.
Report saved locally only: .ai/pr-reviews/reports/pr-<id>-report.md
```
And STOP wiki posting.

If `scm.wiki-id` is not configured, same — save locally and stop.

### 6b. Build Wiki Path

```
WIKI_ROOT = <scm.wiki-pr-review-root>   # e.g., /My-Wiki/PR-Reviews
PAGE_TITLE = "<ticket-number> - <meaningful-title>"  # e.g., "2416553 - Enhanced PLP Filter Sticky"
WIKI_PATH = "${WIKI_ROOT}/${PAGE_TITLE}"
```

If no ticket number: use `PR-<id>` as prefix (e.g., `PR-12345 - Fix Hero Null Reference`).

### 6c. Create Wiki Page

Check if parent page exists:

```
mcp__ado__wiki_get_page
  wikiIdentifier: <scm.wiki-id>
  project: <scm.wiki-project>
  path: "${WIKI_ROOT}"
```

If parent page doesn't exist (404), create it:

```
mcp__ado__wiki_create_or_update_page
  wikiIdentifier: <scm.wiki-id>
  project: <scm.wiki-project>
  path: "${WIKI_ROOT}"
  content: "# PR Review Reports\n\nAI-generated reports from pull request code reviews."
```

Create or update the report page:

```
mcp__ado__wiki_create_or_update_page
  wikiIdentifier: <scm.wiki-id>
  project: <scm.wiki-project>
  path: "${WIKI_PATH}"
  content: <contents of pr-<id>-report.md>
```

### 6-Confluence: Post to Confluence

#### 6d. Read Confluence Config

```yaml
confluence:
  space-key: "<space key>"
  pr-review-root: "<parent page title for PR review reports>"
```

If `confluence.pr-review-root` is not configured:
```
Confluence PR review root not configured — add `confluence.pr-review-root` to .ai/config.yaml.
Report saved locally only: .ai/pr-reviews/reports/pr-<id>-report.md
```
And STOP wiki posting.

If `confluence.space-key` is not configured, same — save locally and stop.

#### 6e. Find Parent Page

```
mcp__atlassian__confluence_search
  cql: "title = '<confluence.pr-review-root>' AND space = '<confluence.space-key>'"
```

Extract `page_id` → `PARENT_PAGE_ID`. If not found, create it:

```
mcp__atlassian__confluence_create_page
  space_key: "<confluence.space-key>"
  title: "<confluence.pr-review-root>"
  body: "<h1>PR Review Reports</h1><p>AI-generated reports from pull request code reviews.</p>"
  parent_id: <space root page or omit for top-level>
```

#### 6f. Check if Report Page Exists

```
PAGE_TITLE = "<ticket-number> - <meaningful-title>"

mcp__atlassian__confluence_search
  cql: "title = '<PAGE_TITLE>' AND ancestor = '<PARENT_PAGE_ID>' AND space = '<confluence.space-key>'"
```

#### 6g. Content Format Conversion (CRITICAL)

Skills generate markdown. Before posting to Confluence, test if the MCP server accepts markdown directly by making a test call. If the page renders correctly with raw markdown, use markdown. If it renders as raw text, convert markdown to basic Confluence storage format (XHTML):
- `# Heading` → `<h1>Heading</h1>`
- `**bold**` → `<strong>bold</strong>`
- `*italic*` → `<em>italic</em>`
- `- item` → `<ul><li>item</li></ul>`
- Code blocks → `<ac:structured-macro ac:name="code"><ac:plain-text-body><![CDATA[...]]></ac:plain-text-body></ac:structured-macro>`
- Tables → `<table><tr><th>...</th></tr><tr><td>...</td></tr></table>`
- Links `[text](url)` → `<a href="url">text</a>`

#### 6h. Create or Update Page

If page doesn't exist:

```
mcp__atlassian__confluence_create_page
  space_key: "<confluence.space-key>"
  title: "<PAGE_TITLE>"
  body: "<converted content>"
  parent_id: "<PARENT_PAGE_ID>"
```

If page exists:

```
mcp__atlassian__confluence_update_page
  page_id: "<existing page ID>"
  title: "<PAGE_TITLE>"
  body: "<converted content>"
  version_number: <current version + 1>
```

Print: `Report posted to Confluence: <space-key> > <pr-review-root> > <PAGE_TITLE>`

## 7. Present Summary

```markdown
## dx-pr-review-report complete

**<meaningful-title>** (PR #<id>)
- Ticket: <ticket number or "none">
- Total comments: <N> | Meaningful: <M>
- Categories: <list with counts>
- Patches: <P proposed, F fixed, D declined>
- Output: `.ai/pr-reviews/reports/pr-<id>-report.md`
- Wiki: <posted to path> / <local only>
```

## Examples

1. `/dx-pr-review-report https://dev.azure.com/myorg/MyProject/_git/MyRepo/pullrequest/12345` — Fetches PR #12345, finds 8 review threads (5 meaningful), categorizes as: 2 Bug, 2 Functionality, 1 Accessibility. 3 had patches proposed — 2 fixed, 1 declined. Generates report and offers to post to wiki.

2. `/dx-pr-review-report 12345` — Uses current repo. Finds linked ticket #2416553. Generates report titled "2416553 - Enhanced PLP Filter Sticky Behavior". Posts to wiki at configured `wiki-pr-review-root`.

3. `/dx-pr-review-report 12345` (no previous review) — PR has no review comments from anyone. Reports: "No review comments found on PR #12345 — nothing to report." and stops.

## Troubleshooting

- **"No review comments found on PR #<id>"**
  **Cause:** The PR has no review threads, only system-generated threads.
  **Fix:** Run `/dx-pr-review <PR URL>` first to review the PR, then generate the report.

- **"Wiki PR review root not configured"**
  **Cause:** `.ai/config.yaml` is missing `scm.wiki-pr-review-root`.
  **Fix:** Add the config field with the wiki parent page path.

- **Thread details incomplete**
  **Cause:** Some threads may have been deleted or the user lacks permissions.
  **Fix:** The skill continues with available data. Missing threads are noted in the summary.

## Rules

- **Read-only** — this skill only reads PR data and generates reports. It never modifies PR threads or votes.
- **Meaningful comments only** — skip system threads, status changes, and trivial "LGTM" comments
- **Category-first organization** — group by category, not by file or chronological order
- **Patch tracking** — always report whether patches were proposed and what the author did with them
- **Linked ticket for title** — prefer the work item title over PR title for meaningful naming
- **Config-driven wiki** — wiki path from `scm.wiki-pr-review-root`, never hardcode
- **No hardcoded values** — read all project-specific values from `.ai/config.yaml`
- **Concise findings** — report the issue essence in one line, not the full comment text
- **Omit empty categories** — don't show categories with zero findings
- **MCP tools are deferred** — always load via ToolSearch before first use
- **URL project precedence** — if a PR URL was provided, use the project from the URL, not from config
