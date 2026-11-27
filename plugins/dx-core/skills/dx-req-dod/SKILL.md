---
name: dx-req-dod
description: "Check Definition of Done and auto-fix gaps — PR, tasks, docs — then post a summary to ADO. Use for 'check DoD'. Not for fetching requirements (dx-req), child Tasks (dx-req-tasks) or pre-PR checks (dx-step-verify)."
argument-hint: "[ADO Work Item ID, Jira Issue Key, or full URL]"
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*", "atlassian/*"]
---

## Defaults

Read `../../shared/provider-config.md` for provider detection and tool mapping.

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

## Progress Tracking

Follow `.ai/rules/task-progress.md` (plugin default: `rules/task-progress.md`). The progress **file** is the source of truth — write it at every phase transition:

```bash
DX_PROGRESS_FILE="dod-progress.md" DX_PROGRESS_TITLE="/dx-req-dod Progress" \
  bash "${CLAUDE_PLUGIN_ROOT}/shared/update-progress.sh" "$SPEC_DIR" "<phase>" "<status>"
```

Status values: `pending` · `in_progress` · `done` · `failed` · `skipped` · `blocked`. One row per phase, updated in place.

If `TaskCreate` is in this session's tool list, also mirror the same phases into tasks so the user gets a live checklist — `TaskList` first to cancel stale tasks from an interrupted run. If it is absent (the default on Opus 4.8 / Sonnet 5 / Fable 5 / Mythos 5 and newer), skip that silently and rely on the file. Never block a phase transition on a task tool being present.

1. DoD Check (gather evidence, evaluate criteria)
2. Auto-Fix Gaps (if failures found)
3. Post to ADO/Jira

## 1. Resolve Work Item

Parse the argument to extract the ADO work item ID (from number or URL).

If no argument provided:
```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir 2>/dev/null)
```
Extract ID from the spec directory name. If no spec dir found, ask the user for the work item ID.

As soon as the ID is known, start the run (see [Run Result](#run-result)):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/data/lib/run-result.sh" --start --skill dx-req-dod --id <id> --progress-file dod-progress.md
```

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

Run result: `--status blocked --next "set scm.wiki-dod-url, then /dx-req-dod <id>" --metric fail_at=config`.

**Fetch the wiki page content via MCP:**
```
mcp__ado__wiki
  action: "get_page_content"
  url: <scm.wiki-dod-url>
```

**If fetch fails:** Print error and STOP:
```
✗ Could not fetch DoD wiki page from <url>.
  Verify the URL is correct and the wiki page exists.
```

Run result: `--status failed --next "/dx-req-dod <id>" --metric fail_at=wiki`.

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
3. If inputs unchanged → print `dod.md already up to date — skipping`, write the run result (`--status done --summary "dod.md already up to date — nothing to do"`, `--verdict` from the existing `dod.md`) and STOP
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

## 7. Post ADO Comment (one comment, updated in place, unless dry run)

If dry run: print "Dry run — skipping ADO comment" and show what would be posted. Skip the rest of this step.

The work item carries **one** DoD comment. Every later run edits that comment — it never posts a second one.

**Build the text:** read `.ai/templates/ado-comments/dod-summary.md.template` and follow that structure (same shape as the DoR comment: `### [DoDAgent] Definition of Done Check` header, checkbox checklist, `_[DoDAgent] Run | …_` footer). Its `<!-- … -->` lines are instructions — leave them out of the posted comment (ADO shows them as literal text). Use `format: "Markdown"`, checkboxes, never tables.

1. Fetch existing comments:
   ```
   mcp__ado__wit_work_item
     action: "list_comments"
     project: "<ADO project>"
     workItemId: <id>
   ```

   ### If provider = jira

   Comments are included in the `jira_get_issue` response. Fetch the issue and search `fields.comment.comments[].body` for the signature:
   ```
   mcp__atlassian__jira_get_issue
     issue_key: "<issue key>"
   ```

2. Find the newest comment containing `[DoDAgent] Definition of Done Check`. If none, also accept the legacy header `### DoD Check:` (older runs) — it gets replaced by the new format. Keep its `id`.

3. **Found** — compare verdict, score, checkbox states, auto-fixed and needs-human lists:
   - Unchanged → print `DoD comment already up to date — skipping` and skip.
   - Changed → **edit that comment in place** with the full new text:
     ```
     mcp__ado__wit_work_item_comment_write
       action: "update"
       project: "<ADO project>"
       workItemId: <id>
       commentId: <id of the DoD comment>
       text: "<comment following dod-summary.md.template>"
       format: "Markdown"
     ```

     #### If provider = jira
     ```
     mcp__atlassian__jira_edit_comment
       issue_key: "<issue key>"
       comment_id: "<id of the DoD comment>"
       comment: "<comment following dod-summary.md.template>"
     ```

     Print `DoD comment updated in place`. ADO/Jira let only the comment's author edit it. If the edit is refused (another identity posted it, e.g. a pipeline vs. a local run), fall back to a **short** update comment — never a second full checklist:
     ```markdown
     ### [DoDAgent] DoD Update

     **Score:** <old score> → <new score> (<percentage>%)
     **Verdict:** <new verdict> (was <old verdict>)

     #### Resolved
     - [x] **<criterion>** — now passes

     #### Still Failing
     - [ ] **<criterion>** — <what's missing>

     ---
     _[DoDAgent] Update | <ISO date> · <N> resolved, <M> remaining_
     ```
     Print `DoD comment owned by another identity — posted an update comment`.

4. **Not found** → post the full comment:
   ```
   mcp__ado__wit_work_item_comment_write
     action: "add"
     project: "<ADO project>"
     workItemId: <id>
     text: "<comment following dod-summary.md.template>"
     format: "Markdown"
   ```

   ### If provider = jira

   ```
   mcp__atlassian__jira_add_comment
     issue_key: "<issue key>"
     comment: "<comment following dod-summary.md.template>"
   ```

Keep the comment id — step 8f edits the same comment with the final results.

**On failure:** if posting/editing fails (network, auth), print a warning and continue — `dod.md` has the full report.

## 8. Auto-Fix Gaps (if any FAIL criteria)

If all criteria passed, skip to step 9.

### 8a. Cross-Repo Scope (pipeline mode only)

In pipeline mode there is no peer-to-peer delegation — the central KAI-HUB router
fans this worker out per repo. This step only **documents** scope for the hub.

If `DX_PIPELINE_MODE` is set:
1. Ensure `$SPEC_DIR/research.md` has a `## Cross-Repo Scope` section listing the
   repo aliases the work touches (the hub's `dx-discover-repos` tier 2 reads it).
2. Do NOT write `delegate.json` or queue a pipeline — continue with local fixes.

If `DX_PIPELINE_MODE` is not set: skip (local mode). See `../../shared/repo-discovery.md`.

### 8b. Categorize Failures

Classify each FAIL criterion:

**Auto-fixable** (agent can fix directly):
- Missing documentation (`share-plan.md`) → generate from explain.md
- Missing test stubs → create test file skeletons from implement.md
- Incomplete implement.md steps → mark verified steps as done
- Open PR threads with "agree/will fix" → apply code changes from review comments

**Needs-human** (create Task work items):
- PR not approved → needs human reviewer
- Design decisions unresolved → needs BA/PO input
- Manual testing required → needs QA
- Stakeholder sign-off missing → needs PM

### 8c. Auto-Fix Loop

For each auto-fixable failure:
1. Print: `Fixing: <criterion> — <action>`
2. Execute the fix (write file, generate content, apply patch)
3. Verify the fix resolves the criterion
4. Print: `Fixed: <criterion>` or `Fix failed: <criterion> — <reason>`

Track results: `{criterion, action, result: fixed|failed|skipped}`.

### 8d. Create Task Work Items for Remaining Failures

For each needs-human failure, create a child Task work item — unless one already exists. First list the story's child Tasks (from its relations; for Jira, JQL `parent = <issue key>`) and skip any failure whose `[DoD] <criterion description>` title matches an open child Task. A re-run then updates the DoD comment but does not add the same tasks again. This check is what lets non-interactive runs create these tasks without asking (`../../shared/interaction-mode.md`).


**If provider = ado:**
- Title: `[DoD] <criterion description>`
- Description: `DoD check for ADO #<parent-id> failed: <failure details>\n\nHow to fix: <actionable instruction>`
- Parent: link to the original work item

**If provider = jira:**
```
mcp__atlassian__jira_create_issue
  project_key: "<jira.project-key>"
  issue_type: "<jira.child-issue-type>"
  summary: "[DoD] <criterion description>"
  parent_key: "<parent issue key>"
  description: "DoD check for <parent issue key> failed: <details>\n\nHow to fix: <instruction>"
```

Track created tasks: `{criterion, taskId, title}`.

### 8e. Documentation Generation

If a documentation, demo or QA-handoff criterion failed and the story's PR is merged:
1. Invoke `/dx-post-merge <work-item-id>` — QA demo page (AEM projects), wiki page, QA handoff comment, in that order. Pass `--skip demo` when the failing criteria are about docs only.
2. If it stops with `Not deployed to QA yet`, leave the criterion failing and note `re-run /dx-post-merge <id> after the QA deploy`.
3. If the skill is not available: print `Documentation generation skipped (/dx-post-merge not installed).`

### 8f. Re-evaluate

Re-run DoD criteria evaluation (same as step 5) against updated evidence. Update `dod.md` with new results. Track the delta:
- Criteria that flipped from FAIL → PASS
- Criteria still failing (with created Task IDs)

Then re-run step 7 — it finds the comment posted above and **edits it in place** with the final results (Auto-Fixed + Needs Human sections filled). Do not post a second comment.

## 9. Present Summary

```markdown
## DoD Check: <Title> (ADO #<id>)

**Verdict:** <PASS/FAIL>
**Score:** <N>/<total automated criteria>
**Failures:** <count or "none">
**Warnings:** <count or "none">
**DoD Source:** <wiki URL>

<If auto-fixes were attempted:>
### Auto-Fixed
| Criterion | Action | Result |
|-----------|--------|--------|
| <criterion> | <what was done> | Fixed / Failed |

### Tasks Created (needs human)

**If provider = ado:**
| Criterion | Task | Assigned |
|-----------|------|----------|
| <criterion> | ADO #<task-id>: <title> | <assignee or unassigned> |

**If provider = jira:**
| Criterion | Task | Assigned |
|-----------|------|----------|
| <criterion> | [<issue-key>]({jira.url}/browse/<issue-key>): <title> | <assignee or unassigned> |

### Updated Score
**Before:** <N>/<total> → **After:** <M>/<total>

<If all pass after fixes:>
**Verdict: Ready for QA** — all DoD criteria now met.

<If still failing after fixes:>
**Verdict: <M>/<total> passed.** <count> tasks created for remaining items.

<If no fixes needed (all passed initially):>
### Recommended action
No action needed — all automated DoD criteria passed.
```

Then write the run result as the last action (see [Run Result](#run-result)).

## Run Result

Machine-readable outcome for a tool that started this skill (dashboard, script, hub), per `../../shared/run-result.md`. Never fail the run because of it.

**Start** — once, as soon as the work item ID is known (step 1). **End** — last action of **every** exit, after the final message:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/data/lib/run-result.sh" --skill dx-req-dod --id <id> --status <done|blocked|failed> \
  --verdict "<PASS|FAIL>" --next "<next step or none>" --work-item "<work item url>" \
  --summary "<one line, e.g. DoD: FAIL 8/10 — 2 tasks created>" \
  --metric criteria_pass=<n> --metric criteria_total=<n> --metric fixed=<n> --metric tasks_created=<n> [--metric fail_at=<step>]
```

| Exit | `--status` | `--next` |
|------|------------|----------|
| Verdict produced (PASS or FAIL — the check itself succeeded), comment posted or dry run | `done` | `none`, or what is left (`[DoD]` tasks open, `/dx-post-merge <id>` after the QA deploy) |
| `dod.md` already up to date — nothing to do | `done` | `none` |
| `scm.wiki-dod-url` not configured | `blocked` | `set scm.wiki-dod-url, then /dx-req-dod <id>` |
| DoD wiki or work item could not be fetched, comment could not be posted | `failed` | `/dx-req-dod <id>` |

Counts are the final ones (after step 8f). `/dx-post-merge` run from step 8e writes its own result (`dx-post-merge-<id>.json`).

## Examples

### Check DoD for any story
```
/dx-req-dod 2435084
```
Fetches DoD checklist from wiki, checks PR status/votes/threads, tests, build, accessibility, child tasks. Produces `dod.md` with PASS/FAIL for each criterion. Auto-fixes what it can and creates Task work items for the rest.

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

### Auto-fix marks criterion as fixed but re-check still fails
**Cause:** The fix was applied but verification requires additional conditions (e.g., tests must actually pass, not just exist).
**Fix:** Review generated test stubs or documentation, fill in real content, and re-run `/dx-req-dod`.

### Task work items created but not linked to parent
**Cause:** ADO MCP call succeeded for creation but parent link failed (permissions or API issue).
**Fix:** Manually link the created Tasks to the parent story in ADO, or re-run (it checks for existing tasks before creating duplicates).

## Rules

- **Wiki is the single source of truth** — criteria come from the wiki page, never hardcoded in the skill
- **Validate deliverables, not workflow** — check actual code, tests, PR, build — not agent-specific files like explain.md or implement.md
- **Evidence-based only** — every PASS/FAIL must cite specific evidence (file exists, PR vote count, thread status)
- **No assumptions** — if you can't verify a criterion, mark it WARN with "unable to verify" reason
- **Pragmatic thresholds** — a story with no test files is FAIL only if the implementation touches logic (not pure config/content changes)
- **Read config, never hardcode** — ADO URLs, build commands, branch names from config.yaml
- **Idempotent** — check existing dod.md before regenerating; one `[DoDAgent]` comment per work item, edited in place on re-runs
- **Fail fast on missing config** — if wiki URL is not configured, error immediately with clear instructions
- **Conservative auto-fixes** — only fix things the agent can verify; when in doubt, create a Task work item instead
- **Never fake evidence** — don't mark tests as passing without running them, don't mark PR as approved without verifying
- **Audit trail** — every auto-fix is traceable in the updated dod.md
