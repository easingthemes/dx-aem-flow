---
name: dx-req-dor
description: Validate a fetched story against the Definition of Ready checklist, extract BA data for downstream skills, and identify open questions. Produces dor-report.md. Works with Azure DevOps/Jira. Use after /dx-req-fetch or when you need to assess story readiness. Trigger on "DoR check", "definition of ready", "story readiness", "check story quality".
argument-hint: "<ADO Work Item ID or Jira Issue Key (optional — uses most recent if omitted)>"
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
- **Note:** Area Path maps to `fields.components[].name`, Iteration Path maps to `fields.sprint.name` for DoR checklist evaluation.

You read `raw-story.md` from a fetched ADO/Jira story, validate it against the project's Definition of Ready wiki page, extract structured BA data for downstream skills, and generate open questions. Output: `dor-report.md`.

Use ultrathink for this skill — DoR validation requires careful cross-referencing of story content against checklist criteria, and open question generation requires the same depth as the former checklist skill.

## Persona (optional)

If `.ai/me.md` exists, read it. Use it to shape the tone of open questions. Structural constraints still apply. If `.ai/me.md` doesn't exist, use defaults.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir <work-item-id-if-provided>)
```

If the script exits with error, ask the user for the work item ID.

Read `raw-story.md` from `$SPEC_DIR` (required).

Also read if available (for second-pass mode):
- `explain.md` — distilled requirements
- `research.md` — codebase findings

## 2. Fetch DoR Checklist

Read `.ai/config.yaml` and look for `scm.wiki-dor-url`.

**If not configured:** Print error and STOP:
```
✗ scm.wiki-dor-url not configured in .ai/config.yaml.
  Add the wiki URL and re-run. See docs/authoring/wiki-checklist-format.md for page format requirements.
```

**Fetch the wiki page content via MCP:**
```
mcp__ado__wiki_get_page_content
  url: <scm.wiki-dor-url>
```

Parse the wiki markdown to extract checklist sections and criteria.

**If fetch fails:** Print error and STOP:
```
✗ Could not fetch DoR wiki page from <url>.
  Verify the URL is correct and the wiki page exists.
```

### If provider = jira (Confluence)

If `confluence.dor-page-title` is configured in `.ai/config.yaml`:

```
mcp__atlassian__confluence_search
  cql: "title = '<confluence.dor-page-title>' AND space = '<confluence.space-key>'"
```

Extract the page ID from results, then:

```
mcp__atlassian__confluence_get_page
  page_id: "<page ID from search>"
```

Use the page content as the DoR checklist.

If `confluence.dor-page-title` is NOT configured, fall back to the local checklist file at `.ai/rules/dor-checklist.md` (if it exists). If neither source is available, skip the wiki checklist comparison and validate against the built-in DoR criteria only.

## 3. Check Existing Output

1. Check if `dor-report.md` exists in the spec directory
2. If it exists, read it
3. Compare: has `raw-story.md` changed since the report was generated? (title match, section count)
4. If `research.md` now exists but the report has no "Codebase-Informed Questions" section → regenerate (second pass)
5. If unchanged locally → **check ADO comment for checkbox changes** (Step 8b). If BA checked new items → re-fetch story, re-validate, update report. If no checkbox changes and comment exists → print `dor-report.md already up to date — skipping` and STOP. If comment missing → skip to Step 8 to post it, then STOP.
6. If stale → print `dor-report.md outdated — regenerating` and continue. Track what changed (e.g., "second pass: added codebase questions", "BA addressed 2 items", "story updated: new comments") for the ADO update comment in Step 8.

## 4. DoR Scorecard Evaluation

Evaluate each DoR section against `raw-story.md` content:

| # | Section | What to check | Status values |
|---|---------|---------------|---------------|
| 1 | Story Basics | Title non-empty, Description non-empty, AC section exists with ≥1 testable condition, Priority stated, Parent Feature linked in Relations | ✅ Pass / ❌ Fail |
| 2 | Change Type | Explicit statement of change type (new feature, enhancement, config, content, bug fix, technical) — look for keywords or checkbox pattern | ✅ Pass / ⚠️ Warn |
| 3 | Component Details | Component name mentioned, new vs existing stated, AEM page URL provided, screenshot attached (image reference), what-changes bullet list | ✅ Pass / ⚠️ Warn / ❌ Fail |
| 4 | Authoring Changes | Dialog field table with columns (Field Label, Type, Options, Default, Change) — or explicit "no dialog changes" | ✅ Pass / ⊘ Skip / ⚠️ Warn |
| 5 | Design & Visual | Figma URL with `node-id=` parameter (component-level preferred), desktop design reference, mobile design reference | ✅ Pass / ⊘ Skip / ⚠️ Warn / ❌ Fail |
| 6 | Content & Testing | Content examples table, QA page URL (look for QA/stage environment URLs) | ✅ Pass / ⚠️ Warn |
| 7 | Scope & Boundaries | Brand(s) stated, market(s) stated, out-of-scope section present | ✅ Pass / ⚠️ Warn |
| 8 | Accessibility | A11y checklist or notes present — skip for backend-only or config-only changes | ✅ Pass / ⊘ Skip |
| 9 | Related Items | Parent Feature linked in Relations section | ✅ Pass / ⚠️ Warn |

**Scoring:**
- Count ✅ passes out of applicable sections (exclude ⊘ skipped)
- **10+ applicable passes:** Verdict = "Ready for Development"
- **7-9:** Verdict = "Can proceed — expect clarification questions"
- **Below 7:** Verdict = "Needs more detail before development"

**Skip logic:**
- Section 4 (Authoring) → ⊘ if change type is "content update" or "technical/infrastructure"
- Section 5 (Design) → ⊘ if story explicitly says "no visual changes" or change type is "configuration only" / "technical"
- Section 8 (Accessibility) → ⊘ if change type is "configuration only", "content update", or "technical/infrastructure"

### Section 5 — Figma Node-Level Validation

If a Figma URL with `node-id=` is found, perform an additional check:

1. Parse the URL to extract `fileKey` and `nodeId`
2. Call `mcp__plugin_dx-core_figma__get_metadata` with `nodeId`
3. Analyze the node type from the XML response:
   - **COMPONENT, INSTANCE, or non-page FRAME** → ✅ pass (component-level link)
   - **PAGE** → check child frames:
     a. Match child frame names against the component name from Section 3
     b. If a clear component match exists → ⚠️ warn: "Figma link points to a page, but component '<name>' was identified. Consider linking directly to node <childId> for faster extraction."
     c. If no match → ⚠️ warn: "Figma link points to a full page with no identifiable component frame matching the story. Consider linking to the specific component."

**If Figma MCP is unavailable:** Skip this sub-check silently (do not fail the DoR check because of MCP issues). Note: "Figma node validation skipped — MCP unavailable."

This check is advisory (⚠️ warning), never blocking (❌ fail).

## 5. Extract Structured BA Data

Parse `raw-story.md` to extract structured data that downstream skills can consume:

### Component
- **Name:** Extract component name mentions (look for AEM component names, class names, or explicit "Component: X")
- **Type:** New or Existing (look for "new component" vs references to existing behavior)
- **AEM Page:** Extract AEM author/publish URLs if present

### Dialog Fields
If a dialog field table is found (Section 4 pattern), extract it as-is:
| Field | Type | Options | Default | Change |

### Design
- **Figma:** Extract URLs matching `figma.com/design/` with `node-id=` parameter
- **Desktop/Mobile:** Note if design screenshots are attached or referenced

### Scope
- **Brands:** Extract brand mentions (look for brand names or "all brands")
- **Markets:** Extract market/country mentions (look for country codes or "all markets")
- **Out of Scope:** Extract bullet list from out-of-scope section if present

For each field: if not found in the story, write "(not provided)".

## 6. Generate Open Questions

Apply the same rigor as a senior developer reviewing requirements before coding.

### Self-Discovery First

**CRITICAL: Before adding ANY question, try to discover the answer yourself.**

1. **Story content** — read ALL sections of raw-story.md including comments and parent context
2. **Code search** — if research.md exists, check if it already answers the question
3. **Follow links** — if the story contains URLs, check if they provide the answer

**Rules:**
- If you discover the answer → record as an **Assumption**, not a question
- If discovery is inconclusive → keep the question with what you found
- **Never ask the BA how existing code works** — only ask about business decisions

### Pragmatism Filter

Read `rules/pragmatism.md` (plugin rules directory) and apply ALL filters. Additionally:

1. **Trust the story over the parent** — child story refining parent's approach is intentional
2. **Implementation detail, not requirement** — if the story says checkbox, build a checkbox
3. **Edge case with obvious answer** — if the story answers it, don't re-ask
4. **Don't re-ask what the story already answers** — read carefully before generating any question
5. **Reuse-first principle** — assume existing flows should be reused unless story says otherwise
6. **DoR data is trusted** — if a DoR section passed (✅), don't question that data
7. **Target: 2-5 genuinely useful questions.** Zero questions is a valid outcome for a well-written story.

### Codebase-Informed Questions (second pass only)

If `research.md` exists, cross-reference:
- Does research reveal existing code that contradicts the requirements?
- Does the current component support things the story doesn't address?
- Are there multi-brand/multi-variant implications not mentioned?

Add these under a separate "Codebase-Informed Questions" section.

## 7. Write dor-report.md

Write `$SPEC_DIR/dor-report.md`:

```markdown
# DoR Report: <Title> (ADO #<id>)

**Score:** <passes>/<total applicable> (<percentage>%)
**Verdict:** <Ready for Development / Can proceed — expect clarification questions / Needs more detail before development>
**DoR Source:** <wiki URL>

## Scorecard

| # | Section | Status | Notes |
|---|---------|--------|-------|
| 1 | Story Basics | <status> | <notes> |
| 2 | Change Type | <status> | <notes> |
| 3 | Component Details | <status> | <notes> |
| 4 | Authoring Changes | <status> | <notes> |
| 5 | Design & Visual | <status> | <notes> |
| 6 | Content & Testing | <status> | <notes> |
| 7 | Scope & Boundaries | <status> | <notes> |
| 8 | Accessibility | <status> | <notes> |
| 9 | Related Items | <status> | <notes> |

## Extracted BA Data

### Component
- **Name:** <name or "(not provided)">
- **Type:** <New / Existing / "(not provided)">
- **AEM Page:** <URL or "(not provided)">

### Dialog Fields
<!-- Include table if found, otherwise: "No dialog field details provided." -->

### Design
- **Figma:** <URL with node-id or "(not provided)">
- **Desktop:** <attached / referenced / "(not provided)">
- **Mobile:** <attached / referenced / "(not provided)">

### Scope
- **Brands:** <brand list or "(not provided)">
- **Markets:** <market list or "(not provided)">
- **Out of Scope:** <bullet list or "(not stated)">

## Gaps Requiring BA Action
<!-- Only if there are ❌ or ⚠️ items.
Each gap = one specific ask with expected deliverable.
If no gaps: "No gaps — story is well-prepared." -->

## Open Questions

### Blocking
<!-- Questions that MUST be answered before development can start.
Keep to 1-3 items max. If nothing blocks, omit this section. -->
- [ ] <Question> — _<one-sentence context, max 20 words>_

### Non-blocking
<!-- Non-blocking questions with topic tag. -->
- [ ] **[<topic>]** <Question> — _<context>_

### Assumptions
<!-- Confirmable statements. One line each. -->
- [ ] <Statement>

## Codebase-Informed Questions
<!-- Only present if research.md was available.
Omit entirely on first pass (before research). -->

## Agent Optimization
<!-- How BA-provided data affects downstream research -->
- <item> → <impact>
- **Estimated research reduction:** <percentage>% (<N> of <total> discovery steps skippable)

---
**Total open questions:** <count>
**Blocking development:** <count>
**Can proceed with assumptions:** <count>
```

## 8. Post ADO Comment (MANDATORY)

**This step is NOT optional.** Always post the DoR results as a comment on the ADO work item. Never skip this step — it is the primary way the BA sees the DoR findings.

### 8a. Fetch existing comments

```
mcp__ado__wit_list_work_item_comments
  project: "<ADO project — '<your ADO project from scm.wiki-project>' for work items>"
  workItemId: <id>
```

#### If provider = jira

Comments are included in the `jira_get_issue` response. Fetch the issue and search `fields.comment.comments[].body` for the signature:
```
mcp__atlassian__jira_get_issue
  issue_key: "<issue key>"
```

Scan all comments for text containing `[DoRAgent] Definition of Ready Check`.

### 8b. Read checkbox state from existing comment

If a `[DoRAgent]` comment exists, parse its checkbox lines to detect BA actions:

- `- [x] **Section**` → BA confirmed this item is addressed (or agent pre-checked it as passing)
- `- [ ] **Section**` → still unchecked — BA has NOT addressed this yet

**Compare against the original post:**
- If a checkbox was `- [ ]` in the original post and is now `- [x]` → BA addressed it
- Track which sections were newly checked as `ba_addressed_sections`

If `ba_addressed_sections` is non-empty:
1. Print: `BA checked <N> items: <list>. Re-fetching story to validate...`
2. Re-fetch the work item via MCP (`mcp__ado__wit_get_work_item`) to get updated content
   - **If provider = jira:** Re-fetch via `mcp__atlassian__jira_get_issue` with the issue key instead.
3. Re-run the scorecard evaluation (Steps 4-6) against the fresh story data
4. Update `dor-report.md` with the new scores
5. Continue to posting (Mode B — update comment)

If no checkboxes changed and report was not regenerated → Mode C (skip).

### 8c. Post — three modes

**Mode A — First post (no existing `[DoRAgent]` comment):**

Post the full DoR checklist. Read `.ai/templates/ado-comments/dor-check.md.template` and follow that structure exactly. Use checkboxes (`- [x]` for passing, `- [ ]` for failing/warning) instead of tables.

```
mcp__ado__wit_add_work_item_comment
  project: "<ADO project>"
  workItemId: <id>
  comment: "<comment following dor-check.md.template with checkboxes>"
  format: "markdown"
```

#### If provider = jira

```
mcp__atlassian__jira_add_comment
  issue_key: "<issue key>"
  comment: "<comment following dor-check.md.template with checkboxes>"
```

**Mode B — Update (BA checked items OR report regenerated):**

Post a SHORT update comment — do NOT re-post the full checklist. Format:

```markdown
### [DoRAgent] DoR Update

**Score:** <old score> → <new score> (<percentage>%)
**Trigger:** <what changed — e.g., "BA addressed 2 items: Component Details, QA page URL">

#### Resolved
- [x] **Component Details** — ✅ now passes (was ⚠️)
- [x] **Content & Testing** — ✅ QA URL added

#### Still Missing
- [ ] **Design & Visual** — Figma link still missing node-id

#### Updated Questions
<!-- Only if questions changed -->
- ❓ <new or updated question>

---
_[DoRAgent] Update | <ISO date> · <N> items resolved, <M> remaining_
```

**Mode C — No changes (no checkbox changes AND report not regenerated):**

Print `DoR comment already posted to ADO #<id> — no changes detected — skipping` and do NOT post.

### Format rules
- Use `format: "markdown"` — NEVER use `format: "html"`. ADO renders markdown natively.
- **Always use checkboxes** (`- [x]` / `- [ ]`) for DoR items — NEVER use tables. Checkboxes are interactive in ADO and enable the BA collaboration loop.
- Follow the template structure: `### [DoRAgent]` header for full post, `### [DoRAgent] DoR Update` for updates
- End with the signature line including action hint: `_[DoRAgent] Run | <date> · Check items above after updating the story, then re-run DoR._`

### On failure

If the ADO comment fails to post (network error, auth issue), print a warning but do NOT fail the skill:
```
⚠️ Could not post DoR comment to ADO #<id> — post manually from dor-report.md
```

## 9. Present Summary

```markdown
## dor-report.md created

**<Title>** (ADO #<id>)
- DoR score: <N>/<total> (<percentage>%) — <verdict>
- Open questions: <count> (<blocking count> blocking)
- BA data extracted: <list of non-empty sections>
- Research reduction: ~<percentage>%

### Recommended action:
<One of:
- "Send to BA — <N> blocking questions + <N> DoR gaps need answers before development"
- "Can proceed — all questions are non-blocking. Send DoR gaps to BA in parallel with development"
- "Story is well-prepared — no significant gaps or questions">
```

## Examples

### First pass (after fetch)
```
/dx-req-dor 2435084
```
Reads `raw-story.md`, validates against DoR wiki checklist, extracts component name "Hero" and 3 dialog fields, flags missing Figma node-id and QA URL as gaps. Produces `dor-report.md` with score 8/11 (73%). Posts summary comment to ADO (Mode A).

### Second pass (after research)
```
/dx-req-dor 2435084
```
Detects `research.md` exists but `dor-report.md` has no codebase-informed questions. Regenerates with additional section: "Research shows existing Hero component uses `showBadge` property — confirm this is the same field." Posts a SHORT update comment to ADO (Mode B) — not a full re-post.

### BA addressed items (checkbox loop)
```
/dx-req-dor 2435084
```
Reads existing `[DoRAgent]` comment, detects BA checked 2 items (Component Details, QA page URL). Re-fetches story from ADO, re-validates against DoR wiki. Score improves from 8/12 to 10/12. Posts short update comment (Mode B) with "Resolved" and "Still Missing" sections.

### Re-run (no changes)
```
/dx-req-dor 2435084
```
`dor-report.md` is up to date, `[DoRAgent]` comment exists with no new checkbox changes. Prints "no changes detected — skipping" (Mode C).

### Re-run (comment missing)
```
/dx-req-dor 2435084
```
`dor-report.md` is up to date but no `[DoRAgent]` comment on ADO. Posts the full checklist comment (Mode A), then stops.

### Well-prepared story
```
/dx-req-dor 2435084
```
All DoR sections pass. All checkboxes pre-checked. Zero open questions. Report says "Story is well-prepared — no significant gaps or questions." Research reduction estimate: ~80%.

## Troubleshooting

### "scm.wiki-dor-url not configured"
**Cause:** `scm.wiki-dor-url` not set in `.ai/config.yaml`.
**Fix:** Add the wiki URL under the `scm:` section. See `docs/authoring/wiki-checklist-format.md` for how to create the wiki page.

### Too many questions generated
**Cause:** Pragmatism filter not applied strictly enough.
**Fix:** The skill has a hard target of 2-5 questions. If exceeding, re-read the story — most "questions" are likely answerable from the content.

### DoR score seems too low
**Cause:** Story uses non-standard formatting that the parser doesn't detect.
**Fix:** The skill looks for specific patterns (tables, URLs, checkboxes). If the BA provided info in a different format, some sections may show ⚠️ despite having the data.

## Success Criteria

- [ ] `dor-report.md` exists in spec directory
- [ ] Every checklist item has status: pass, fail, or unclear
- [ ] ≥1 item assessed (not empty checklist)
- [ ] Open questions section present (even if empty)

## Rules

- **Evidence-based scoring** — every ✅/❌/⚠️ must reference what was found (or not found) in raw-story.md
- **No padding** — if the story is well-specified, the report can have 0 questions and all ✅. That's a GOOD outcome.
- **Developer perspective** — questions are about what blocks implementation, not project management
- **Self-discover before asking** — try to answer every potential question from the story content first
- **Respect the BA's work** — collaborative tone, not critical
- **Hard limit: ~50 lines of questions** — if Open Questions + Assumptions exceeds 50 lines, you're being too verbose
- **Brevity is respect** — the BA should be able to read and respond in 5 minutes
- **Extract everything** — even if a DoR section fails, extract whatever partial data exists
- **Two-pass design** — first pass works on raw-story.md alone; second pass adds codebase questions from research.md
- **Always post to ADO** — Step 8 is MANDATORY and must never be skipped. Three modes: full post (Mode A), short update (Mode B), or confirmed skip (Mode C). Even if Step 3 stops early, check for missing ADO comment first.
- **Never duplicate comments** — always check for existing `[DoRAgent]` signature before posting. On regeneration or checkbox changes, post a short update (Mode B), not a full re-post.
- **Checkboxes, not tables** — ADO comments use `- [x]` / `- [ ]` checkboxes for DoR items. These are interactive in ADO — BA can check them. Never use tables for the scorecard in ADO comments.
- **Checkbox collaboration loop** — on re-run, read checkbox state from the existing ADO comment. If BA checked new items, re-fetch the story, re-validate, and post an update. This is the primary BA↔Agent feedback mechanism.
- **Markdown format only** — always use `format: "markdown"` when posting to ADO. Never use HTML format.
