# Wiki Parsing Rules

## Fetch DoR Checklist

Read `.ai/config.yaml` and attempt each source in order:

1. **ADO Wiki** — if `scm.wiki-dor-url` is configured:
   ```
   mcp__ado__wiki_get_page_content  url: <scm.wiki-dor-url>
   ```
   If fetch fails, try next source.
2. **Confluence** — if `confluence.dor-page-title` + `confluence.space-key` are configured:
   ```
   mcp__atlassian__confluence_search  cql: "title = '<dor-page-title>' AND space = '<space-key>'"
   ```
   Extract page ID, then `mcp__atlassian__confluence_get_page  page_id: "<id>"`.
3. **Local file** — if `.ai/rules/dor-checklist.md` exists, read it (same checkbox format as wiki).
4. **None available** — print error and STOP:
   `No DoR checklist source found. Configure scm.wiki-dor-url, confluence.dor-page-title, or create .ai/rules/dor-checklist.md.`

## Parse Wiki Content

### Section Detection
- Regex: `^## (\d+)\. (.+)$` — section number + title
- Non-numbered `##` headings (e.g., `## Scoring`) are metadata, not checklist sections

### Criterion Detection
- Regex: `^- \[ \] \*\*(.+?)\*\* `(.+?)` — (.+)$`
- Captures: name, tag (required/recommended/human), hint
- Tag behavior: `required` — Fail if missing; `recommended` — Warn if missing; `human` — always Warn

### Skip Trigger Detection
- Regex: `^> \*\*Skip:\*\* (.+)$` after a section's criteria
- If story's change type matches skip trigger — all criteria in that section get Skip

### Scoring Detection
- Look for `## Scoring` heading (no number prefix), parse `- <condition> → **<verdict>**`
- Default if absent: all required pass — Ready; 1-2 fail — Can proceed; 3+ fail — Needs more detail

## Evaluation Logic

For each wiki-parsed section, evaluate each non-skipped criterion:
1. Read the criterion's hint text (after the `—`) as natural-language guidance
2. Search `raw-story.md` for evidence matching that hint
3. Score: evidence found — Pass; not found + `required` — Fail; not found + `recommended` — Warn; `human` — always Warn

**Common evidence patterns:** non-empty title, AC heading with testable conditions, Relations section with parent Feature, Figma URL with `node-id=`, image refs (`![](...)` / `<img>`), markdown tables with expected columns, change-type keywords (new feature, enhancement, config, content, bug fix, technical).

Hints are natural language — the agent interprets using its understanding of the story content.

## Extract Structured BA Data

Parse `raw-story.md` to extract structured data for downstream phases:

- **Component:** name, type (New/Existing), AEM page URL
- **Dialog Fields:** extract table as-is if found (Field | Type | Options | Default | Change)
- **Design:** Figma URL with `node-id=`, desktop/mobile screenshot references
- **Scope:** brands, markets, out-of-scope bullet list

For each field: if not found, write "(not provided)".

## Generate Open Questions

### Self-Discovery First
**Before adding ANY question, try to discover the answer yourself** from story content, research.md (if exists), and linked URLs. Discovered answers become **Assumptions**, not questions. Never ask the BA how existing code works — only business decisions.

### Pragmatism Filter
Read `rules/pragmatism.md` and apply ALL filters. Additionally:
1. Trust the story over the parent — refinement is intentional
2. Implementation detail, not requirement — build what the story says
3. Edge case with obvious answer — don't re-ask
4. Don't re-ask what the story already answers
5. Reuse-first — assume existing flows unless story says otherwise
6. DoR data is trusted — passed sections are settled
7. **Target: 2-5 genuinely useful questions.** Zero is valid for a well-written story.

### Codebase-Informed Questions (second pass only)
If `research.md` exists: check for code contradictions, unsupported variants, multi-brand implications. Separate section.

## dor-report.md Output Format

Write `$SPEC_DIR/dor-report.md`:

```markdown
# DoR Report: <Title> (ADO #<id>)

**Score:** <passes>/<total applicable> (<percentage>%)
**Verdict:** <Ready for Development / Can proceed — expect clarification / Needs more detail>
**DoR Source:** <wiki URL or local file path>

## Scorecard

| # | Section | Status | Notes |
|---|---------|--------|-------|
<!-- One row per wiki-parsed section -->

## Extracted BA Data

### Component
- **Name:** <name or "(not provided)">  **Type:** <New / Existing>  **AEM Page:** <URL>

### Dialog Fields
<!-- Table if found, otherwise "No dialog field details provided." -->

### Design
- **Figma:** <URL with node-id>  **Desktop:** <status>  **Mobile:** <status>

### Scope
- **Brands:** <list>  **Markets:** <list>  **Out of Scope:** <list or "(not stated)">

## Gaps Requiring BA Action
<!-- Each gap = one specific ask. If none: "No gaps — story is well-prepared." -->

## Open Questions

### Blocking
- [ ] <Question> — _<context, max 20 words>_
### Non-blocking
- [ ] **[<topic>]** <Question> — _<context>_
### Assumptions
- [ ] <Statement>

## Codebase-Informed Questions
<!-- Only if research.md available. Omit on first pass. -->

## Agent Optimization
- <item> — <impact>
- **Estimated research reduction:** <percentage>%

---
**Total open questions:** <count> | **Blocking:** <count> | **With assumptions:** <count>
```

## Rules

- **Evidence-based scoring** — every Pass/Fail/Warn must reference what was found (or not) in raw-story.md
- **No padding** — 0 questions and all Pass is a GOOD outcome for a well-specified story
- **Developer perspective** — questions about what blocks implementation, not project management
- **Self-discover before asking** — try to answer from story content first
- **Respect the BA's work** — collaborative tone, not critical
- **Hard limit: ~50 lines of questions** — Open Questions + Assumptions must not exceed this
- **Brevity is respect** — BA should read and respond in 5 minutes
- **Extract everything** — even if a section fails, extract partial data
- **Two-pass design** — first pass on raw-story.md; second adds codebase questions from research.md
- **Dynamic sections** — scorecard rows come from wiki-parsed sections, not a fixed list
