---
name: dx-req-explain
description: Generate developer-focused requirements from a fetched ADO story. Creates explain.md with concise, actionable requirements distilled from raw-story.md. Use after /dx-req-fetch or when the user wants to understand a story's dev requirements.
argument-hint: "[ADO Work Item ID (optional — uses most recent if omitted)]"
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You read `raw-story.md` from a fetched ADO story and generate `explain.md` — a concise, developer-oriented distillation of the requirements.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir <work-item-id-if-provided>)
```

If the script exits with error, ask the user for the work item ID.

Read `raw-story.md` from `$SPEC_DIR`.

## 1b. Read DoR Report (if available)

If `dor-report.md` exists in the spec directory, read the "Extracted BA Data" section. Use this to:
- Pre-populate "Changes by Area" with dialog fields from DoR report
- Use component name and type (new/existing) to frame requirements
- Include brand/market scope in requirements
- Reference Figma node-id URL directly

Additive — if `dor-report.md` doesn't exist, explain works as before.

## 2. Check Existing Output

1. Check if `explain.md` exists in the spec directory
2. If it exists, read its content
3. Read `raw-story.md` and extract the title and key content markers (acceptance criteria keywords, section headings)
4. Compare: does `explain.md` still fulfill this skill's goal?
   - Title header in `explain.md` matches the title from `raw-story.md`
   - All major sections from `raw-story.md` are addressed (requirements cover acceptance criteria)
   - The Requirements list covers the key terms from the raw story
5. If valid → print `explain.md already up to date — skipping` and STOP
6. If stale (title mismatch, raw-story has new sections or changed acceptance criteria) → print `explain.md exists but is outdated — regenerating` and continue
7. If not found → continue normally (first run)

## 3. Generate explain.md

Analyze the raw story and write `explain.md` in the same spec directory.

### explain.md Format

Read `.ai/templates/spec/explain.md.template` and follow that structure exactly. Key rules:

- Requirements are flat numbered list, one testable statement each, target 8-12 items
- Flag potential reuse: "(check: may overlap with existing <name>)"
- OMIT any section that doesn't add information beyond Requirements
- References use `{scm.org}` and `{scm.project_url_encoded}` from `.ai/config.yaml`

## 4. Writing Principles

- **Concise above all** — target 40-50 lines total. Each section should earn its space. If a section repeats what another section already covers, cut it.
- **One sentence per requirement** — requirements are single clear statements, not paragraphs. No sub-bullets under requirements unless absolutely necessary.
- **Collapse overlapping sections** — if "Authoring Changes" just restates requirements, omit it. If "Data/Integration Changes" is one bullet, fold it into requirements. Only keep a section if it adds genuinely new information beyond the Requirements list.
- **Written for a developer** who needs to understand what to build, not for a BA or PM
- **Strips ceremony** — no AC1/FR-001 numbering, no MUST formalism, no spec-speak
- **Combines and deduplicates** — the raw story often has the same information in description, acceptance criteria, AND comments. Merge into one coherent picture.
- **Omit empty sections** — if a section doesn't apply, leave it out entirely. No "N/A" placeholders.
- **Never invent requirements** — if something is ambiguous, state it plainly: "Description says X but doesn't specify Y"
- **Preserve specifics** — keep exact values, property names, option labels, Figma links, and technical details from the raw story
- **Flag contradictions** — if the description says one thing and acceptance criteria says another, note it explicitly

## 5. Present Summary

After saving:

```markdown
## explain.md created

**<Title>** (ADO #<id>)
- Requirements: <count> items
- Sections: <list of sections included>
- Ambiguities noted: <count or "none">

### Next steps:
- `/dx-req-research` — search codebase for related code
- `/dx-plan` — create implementation plan
```

## Examples

### Generate requirements
```
/dx-req-explain 2435084
```
Reads `raw-story.md` from `.ai/specs/2435084-add-language-selector/`, distills into `explain.md` with 10 numbered requirements, What & Why section, and Changes by Area.

### Re-run (idempotent)
```
/dx-req-explain 2435084
```
If `explain.md` exists and still covers all acceptance criteria from `raw-story.md`, prints "explain.md already up to date — skipping".

### After raw-story update
```
/dx-req-explain 2435084
```
If `raw-story.md` was re-fetched with new acceptance criteria, detects the mismatch and regenerates `explain.md`.

## Troubleshooting

### "No raw-story.md found"
**Cause:** `/dx-req-fetch` hasn't been run yet for this work item.
**Fix:** Run `/dx-req-fetch <id>` first.

### explain.md is too long or verbose
**Cause:** The story has many sections with overlapping content.
**Fix:** Re-run — the skill has a hard limit of ~50 lines. If still verbose, the story itself may need simplification. Each requirement should be one sentence.

### Requirements miss key acceptance criteria
**Cause:** Acceptance criteria are embedded in comments or parent context rather than the main description.
**Fix:** Check that `raw-story.md` includes the Comments and Parent Context sections. Re-fetch if needed.

## Decision Examples

### Right Level of Detail
**Story:** "Add phone validation to registration form"
**Too vague:** "Form needs validation" (which form? which fields? what rules?)
**Too prescriptive:** "Use regex /^\+?[1-9]\d{1,14}$/ in validateField() at line 234"
**Just right:** "Phone field must accept international format (+country code). Validate on blur. Show inline error. Use existing form validation in forms.js."

### Out of Scope Detection
**Story:** "Fix hero image not loading"
**Requirement:** Fix the image loading bug
**NOT a requirement:** "Refactor hero component to use lazy loading" (enhancement, not in story)
**Decision:** List lazy loading under "Out of Scope"

## Success Criteria

- [ ] `explain.md` exists in spec directory
- [ ] Contains ≥1 numbered requirement
- [ ] Contains "Acceptance Criteria" section
- [ ] Contains "Out of Scope" section
- [ ] No TODO/TBD placeholders remaining

## Rules

- **Read raw-story.md only** — do not make MCP calls. All data comes from the already-fetched raw story.
- **Developer audience** — write for someone who will code this, not someone who will approve it.
- **No padding** — if the story is simple, explain.md should be short. Don't manufacture complexity.
- **Preserve intent** — distill, don't distort. The explain.md must be traceable back to raw-story.md.
- **Hard limit: ~50 lines** — if your output exceeds 50 lines of markdown, you're being too verbose. Cut aggressively. Prefer a tight 8-12 item requirements list over sprawling prose across many sections.
