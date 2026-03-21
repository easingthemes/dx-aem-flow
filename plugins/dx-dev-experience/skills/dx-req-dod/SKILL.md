---
name: dx-req-dod
description: Check Definition of Done criteria for a work item — tests, PR status, open threads, linked tasks, build, docs. Works with Azure DevOps/Jira. Use when a story moves to Ready for QA or needs a completeness check.
argument-hint: "[ADO Work Item ID, Jira Issue Key, or full URL]"
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*", "atlassian/*"]
---

## Defaults

Read `shared/provider-config.md` for provider detection and tool mapping.

Read `.ai/config.yaml`:
- `tracker.provider` (or `scm.provider` for backward compat) — `ado` (default) or `jira`

**If provider = ado:**
- **Organization:** `scm.org`
- **Project:** `scm.project`

**If provider = jira:**
- **Jira URL:** `jira.url`
- **Project Key:** `jira.project-key`
- **Note:** ADO state "Resolved" varies by Jira workflow — use `fields.status.name` to check the equivalent status.

You check whether a work item meets the Definition of Done. You fetch the DoD checklist from the wiki, check ADO/Jira state and codebase via MCP, and produce `dod.md` — a structured pass/fail report.

This validates the **actual deliverables** (code, tests, PR, build) — not agent workflow artifacts. Works the same whether the story was implemented manually or via the AI workflow.

Use ultrathink for this skill — cross-referencing multiple sources (ADO/Jira state, codebase, PR status) requires systematic verification.

## 1. Resolve Work Item

Parse the argument to extract the ADO work item ID (from number or URL).

If no argument provided:
```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir 2>/dev/null)
```
Extract ID from the spec directory name. If no spec dir found, ask the user for the work item ID.

Read `.ai/config.yaml` for:
- `scm.org` — ADO org URL
- `scm.project` — ADO project name
- `scm.repo-id` — repository ID
- `scm.wiki-dod-url` — DoD wiki page URL (**required**)
- `build.command` — build command

## 2. Fetch DoD Checklist from Wiki

Read `scm.wiki-dod-url` from `.ai/config.yaml`.

**If not configured:** Print error and STOP:
```
✗ scm.wiki-dod-url not configured in .ai/config.yaml.
  Add the wiki URL and re-run. See docs/authoring/wiki-checklist-format.md for page format requirements.
```

**Fetch the wiki page content via MCP:**
```
mcp__ado__wiki_get_page_content
  url: <scm.wiki-dod-url>
```

**If fetch fails:** Print error and STOP:
```
✗ Could not fetch DoD wiki page from <url>.
  Verify the URL is correct and the wiki page exists.
```

### If provider = jira (Confluence)

If `confluence.dod-page-title` is configured in `.ai/config.yaml`:

```
mcp__atlassian__confluence_search
  cql: "title = '<confluence.dod-page-title>' AND space = '<confluence.space-key>'"
```

Extract the page ID, then fetch:

```
mcp__atlassian__confluence_get_page
  page_id: "<page ID from search>"
```

If `confluence.dod-page-title` is NOT configured, fall back to `.ai/rules/dod-checklist.md`. If neither exists, validate against built-in DoD criteria only.

### Parse the Wiki Content

The wiki page uses a standard format (see `docs/authoring/wiki-checklist-format.md`):
- Numbered `## N. Section Title` headings define sections
- Each section has a markdown table with columns: `Criterion | Who checks | What to verify`
- `Who checks` values: `Agent` (automated), `Human` (manual), `Advisory` (warn-only)
- Optional `**Skip trigger:**` paragraphs define when to skip criteria
- A `## DoD Completion Summary` section with scoring rules

Parse the wiki content to extract:
1. **Sections** — numbered headings with their criteria tables
2. **Criteria** — each row in the criteria tables (criterion name, who checks, what to verify)
3. **Skip triggers** — conditions under which criteria are skipped
4. **Scoring rules** — from the completion summary section

## 3. Check Existing Output

If a spec directory exists for this work item:
1. Check if `dod.md` exists in it
2. If it exists, read content and check staleness (ADO ID match)
3. If inputs unchanged → print `dod.md already up to date — skipping` and STOP
4. If outdated → print `dod.md exists but is outdated — regenerating`
5. If not found → continue normally

## 4. Gather Evidence

Collect evidence for each criterion parsed from the wiki. Evidence comes from the **actual project state**, not from agent workflow files.

**From ADO (via MCP):**
- Work item details — state, assigned to, tags, title
- Linked PRs — check work item Relations for `vstfs:///Git/PullRequestId/` links
  - PR status (completed/active/abandoned)
  - PR reviewers and vote status (10 = Approved)
  - PR description (non-empty?)
- PR threads — any active (unresolved) threads?
- PR comments — any with "will fix" or "agree" that haven't been addressed? (check for commits after comment timestamp)
- Child tasks — all linked child Task work items resolved (Done/Closed)?

**From codebase:**
- Test files — grep for test files related to component name or work item ID in test directories (`**/test/**`, `**/tests/**`, `**/*Test.java`, `**/*.test.js`, `**/*.spec.js`)
- Build status — run build command from config if needed, or check recent CI results
- Secret scan — grep for common credential patterns in changed files
- Accessibility — check changed files against WCAG patterns (semantic HTML, aria attributes, keyboard handlers)

**From Figma (optional):**
- If Figma URL in work item description → note for visual fidelity advisory check

## 5. DoD Criteria Evaluation

For each criterion parsed from the wiki, evaluate as PASS, FAIL, WARN, or SKIP:

- **Agent** criteria → evaluate programmatically against the evidence gathered. Result: PASS or FAIL. Evidence must be specific (PR vote count, thread status, test file paths).
- **Human** criteria → cannot be verified by agent. Always mark as WARN with advisory message (e.g., "verify manually").
- **Advisory** criteria → evaluate if possible, but result is WARN at most, never FAIL.
- **Skip triggers** → if a skip condition matches (based on change type, story content), mark as SKIP with justification.

Map each wiki criterion to the appropriate evidence check based on the "What to verify" column. The verification instructions in the wiki are human-readable — interpret them to determine what ADO state, codebase patterns, or PR data to check.

## 6. Generate dod.md

Write `dod.md` to the spec directory (create spec dir if needed).

Read `.ai/templates/spec/dod.md.template` and follow that structure, adapting to the wiki-driven criteria:

- Build the Results table dynamically from parsed wiki sections
- Number criteria sequentially across all sections
- Include section grouping headers
- Score only Agent-verifiable criteria (exclude Human, Advisory, and SKIP)

## 7. Post ADO Comment (idempotent, unless dry run)

If dry run: print "Dry run — skipping ADO comment" and show what would be posted. Skip the rest of this step.

Before posting, check for an existing comment to avoid duplicates:

1. Fetch existing comments:
   ```
   mcp__ado__wit_list_work_item_comments
     project: "<ADO project>"
     workItemId: <id>
   ```

   ### If provider = jira

   Comments are included in the `jira_get_issue` response. Fetch the issue and search `fields.comment.comments[].body` for the signature:
   ```
   mcp__atlassian__jira_get_issue
     issue_key: "<issue key>"
   ```

2. Search for a comment containing the signature `DoD Check:` with the work item title.

3. If found:
   - Compare key metrics: verdict (PASS/FAIL), score, failure count
   - If unchanged → print `ADO comment already up to date — skipping` and skip
   - If changed → post a **minimal update comment** (not a full repeat):
     ```
     ### DoD Updated
     **Verdict:** <new verdict> (was <old verdict>)
     **Score:** <new score> (was <old score>)
     **Changes:** <1-2 bullet summary of what changed>
     ```

4. If not found → post full comment using template.

**Post:**
```
mcp__ado__wit_add_work_item_comment
  project: "<ADO project>"
  workItemId: <id>
  text: "<condensed dod results>"
  format: "markdown"
```

### If provider = jira

```
mcp__atlassian__jira_add_comment
  issue_key: "<issue key>"
  comment: "<condensed dod results>"
```

Read `.ai/templates/ado-comments/dod-summary.md.template` and follow that structure.

## 8. Present Summary

```markdown
## DoD Check: <Title> (ADO #<id>)

**Verdict:** <PASS/FAIL>
**Score:** <N>/<total automated criteria>
**Failures:** <count or "none">
**Warnings:** <count or "none">
**DoD Source:** <wiki URL>

<If FAIL:>
### Recommended action
Run `/dx-req-dod-fix <id>` to auto-fix failures, or fix manually:
<list failures with one-line fix instructions>
```

## Examples

### Check DoD for any story
```
/dx-req-dod 2435084
```
Fetches DoD checklist from wiki, checks PR status/votes/threads, tests, build, accessibility, child tasks. Produces `dod.md` with PASS/FAIL for each criterion. Works whether the story was implemented manually or via AI workflow.

### From URL
```
/dx-req-dod https://dev.azure.com/myorg/MyProject/_workitems/edit/2435084
```
Extracts ID from URL. Same check.

## Troubleshooting

### "scm.wiki-dod-url not configured"
**Cause:** The DoD wiki URL is not set in `.ai/config.yaml`.
**Fix:** Add `wiki-dod-url` under the `scm:` section. See `docs/authoring/wiki-checklist-format.md` for how to create the wiki page.

### DoD fails on "PR not found"
**Cause:** No PR has been created or linked to this work item.
**Fix:** Create a PR and link it to the work item in ADO.

### DoD fails on "tests not found"
**Cause:** No test files found for the changed components.
**Fix:** Write tests for the implementation. If the change is config/content only, this may be skippable.

### Wiki page format not recognized
**Cause:** The wiki page doesn't follow the expected format.
**Fix:** See `docs/authoring/wiki-checklist-format.md` for the required page structure.

## Rules

- **Wiki is the single source of truth** — criteria come from the wiki page, never hardcoded in the skill
- **Validate deliverables, not workflow** — check actual code, tests, PR, build — not agent-specific files like explain.md or implement.md
- **Evidence-based only** — every PASS/FAIL must cite specific evidence (file exists, PR vote count, thread status)
- **No assumptions** — if you can't verify a criterion, mark it WARN with "unable to verify" reason
- **Pragmatic thresholds** — a story with no test files is FAIL only if the implementation touches logic (not pure config/content changes)
- **Read config, never hardcode** — ADO URLs, build commands, branch names from config.yaml
- **Idempotent** — check existing dod.md before regenerating
- **Fail fast on missing config** — if wiki URL is not configured, error immediately with clear instructions
