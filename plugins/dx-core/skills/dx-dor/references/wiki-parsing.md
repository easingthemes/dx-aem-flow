# Wiki Parsing Rules

## Fetch DoR Checklist

The DoR checklist rarely changes between tickets, but the wiki resolution path is expensive — a tree-traversal `wiki_get_page` call against a parent section can return a ~270kB JSON blob describing every nested page (≈65–80k tokens). Issue #136 showed that landing on every `/dx-dor` run was the second-largest Phase 1 context cost. The fetch path below caches the resolved content on disk and never lets the raw tree blob reach the parent thread.

### Cache-first

Before any MCP call, check `.ai/cache/dor-checklist.md`:

```bash
CACHE=.ai/cache/dor-checklist.md
META=.ai/cache/dor-checklist.meta.json
TTL_SECONDS=86400  # 24h — checklists are stable

if [ -f "$CACHE" ] && [ -f "$META" ]; then
  AGE=$(($(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE")))
  if [ "$AGE" -lt "$TTL_SECONDS" ]; then
    echo "DoR checklist cache hit ($CACHE, age ${AGE}s)"
    # Read $CACHE and proceed to "Parse Wiki Content"
  fi
fi
```

`$META` records the resolved source path / page ID and last-fetched timestamp so a re-run can short-circuit. To force a refresh: `rm .ai/cache/dor-checklist.md` or pass `--no-cache` to `/dx-dor`. Override TTL via `dor.cache-ttl-seconds` in `.ai/config.yaml` (default `86400`).

### Cache miss — resolve once, cache the body

Read `.ai/config.yaml` and attempt each source in order:

1. **ADO Wiki** — if `scm.wiki-dor-url` is configured:
   ```
   mcp__ado__wiki_get_page_content  url: <scm.wiki-dor-url>
   ```
   The URL form is the cheap path — no tree traversal. Pass the **full** URL exactly as configured. If `scm.wiki-dor-url` is missing or the call fails with a path-resolution error, fall back to the search path below.

   **Search fallback (issue #136 — never traverse the parent tree):**
   ```
   mcp__ado__wiki_search  searchText: "<DoR page title from scm.wiki-dor-page-title or 'Definition of Ready'>"
   ```
   Take the top hit, then call `wiki_get_page_content` with that hit's path. Do **not** call `wiki_get_page` against a parent section to enumerate children — that returns the full subtree JSON (~270kB) which is the exact failure mode #136 documents.

   **If a tree fetch is genuinely unavoidable** (e.g., disambiguating multiple candidate pages), dispatch it to a subagent with this contract:
   > "Use `mcp__ado__wiki_get_page` for path `<X>`. Return ONLY the resolved `gitItemPath` of the page whose title matches `<title>`. Do not paste the JSON tree."
   The raw blob then stays in the subagent context and only the resolved path crosses back.

   On success, write the markdown body to `.ai/cache/dor-checklist.md` and metadata to `.ai/cache/dor-checklist.meta.json`:
   ```json
   {"source": "ado-wiki", "url": "...", "gitItemPath": "...", "fetched_at": "<ISO-8601>"}
   ```

2. **Confluence** — if `confluence.dor-page-title` + `confluence.space-key` are configured:
   ```
   mcp__atlassian__confluence_search  cql: "title = '<dor-page-title>' AND space = '<space-key>'"
   ```
   Extract page ID, then `mcp__atlassian__confluence_get_page  page_id: "<id>"`. Cache the body to `.ai/cache/dor-checklist.md` with `{"source":"confluence","page_id":"<id>","fetched_at":"<ts>"}`.

3. **Local file** — if `.ai/rules/dor-checklist.md` exists, read it (same checkbox format as wiki). No caching needed (already on disk).

4. **None available** — print error and STOP:
   `No DoR checklist source found. Configure scm.wiki-dor-url, confluence.dor-page-title, or create .ai/rules/dor-checklist.md.`

## Parse Wiki Content

### Section Detection
- Regex: `^## (\d+)\. (.+)$` — section number + title
- Non-numbered `##` headings (e.g., `## Scoring`) are metadata, not checklist sections

### Criterion Detection
- Regex: `^- \[ \] \*\*(.+?)\*\* `(.+?)` — (.+)$`
- Captures: name, tag (mandatory/required/recommended/human), hint
- Tag behavior: `mandatory` — HARD GATE: Fail blocks entire verdict regardless of score; `required` — Fail if missing (contributes to count-based threshold); `recommended` — Warn if missing; `human` — always Warn

### Skip Trigger Detection
- Regex: `^> \*\*Skip:\*\* (.+)$` after a section's criteria
- If story's change type matches skip trigger — all criteria in that section get Skip

### Scoring Detection
- Look for `## Scoring` heading (no number prefix), parse `- <condition> → **<verdict>**`
- **Mandatory gate (always applies, before count-based scoring):** If ANY `mandatory` criterion has status Fail → verdict is "Needs more detail" regardless of other scores
- Default count-based thresholds (if wiki doesn't define `## Scoring`): all required pass — Ready; 1-2 fail — Can proceed; 3+ fail — Needs more detail

## Evaluation Logic

For each wiki-parsed section, evaluate each non-skipped criterion:
1. Read the criterion's hint text (after the `—`) as natural-language guidance
2. Search `raw-story.md` for evidence matching that hint
3. Score: evidence found — Pass; not found + `mandatory` — Fail (HARD GATE); not found + `required` — Fail; not found + `recommended` — Warn; `human` — always Warn

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
**Verdict:** <Ready for Development / Can proceed — expect clarification / Needs more detail — MANDATORY criteria not met: <list>>
**DoR Source:** <wiki URL or local file path>

## Scorecard

| # | Section | Status | Notes |
|---|---------|--------|-------|
<!-- One row per wiki-parsed section -->
<!-- mandatory failures show status "MANDATORY FAIL" (distinct from regular "Fail") -->
<!-- Gaps section: mandatory failures listed first with "MANDATORY" prefix -->

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
