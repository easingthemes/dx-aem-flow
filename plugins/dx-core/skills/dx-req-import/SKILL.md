---
name: dx-req-import
description: Validate external requirements and create spec structure without ADO. Reads a requirements document, checks completeness, and generates explain.md + optional research.md. Use when you have requirements from a BA, Confluence page, or email instead of an ADO ticket.
argument-hint: "[path to requirements document]"
disable-model-invocation: true
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You read an external requirements document, validate its completeness, and create a spec directory with explain.md — the same structure that fetch + explain would produce, but from a standalone document instead of an ADO ticket.

## 1. Read the Requirements Document

The argument is a file path to a requirements document (markdown, text, or other readable format).

If no argument is provided, ask the user for the path.

Read the document contents.

## 2. Score Completeness

Evaluate the document against this rubric (score each 0-2):

| Criterion | 0 (Missing) | 1 (Partial) | 2 (Complete) |
|-----------|-------------|-------------|--------------|
| **What** — what's being built/changed | Not stated | Vague description | Clear, specific description |
| **Acceptance criteria** — how to verify it works | None | Some criteria listed | Testable criteria for each requirement |
| **Affected areas** — which parts of the system change | Not stated | General area mentioned | Specific components/files/layers identified |
| **Edge cases** — what about errors, empty states, defaults | Not mentioned | Some noted | Key edge cases addressed |

**Threshold: total >= 5 out of 8.**

If below threshold:
- Print the score table with specific gaps
- Suggest what to add for each missing criterion
- Print: "Document needs more detail before proceeding. Add the missing items and run `/dx-req-import` again."
- STOP

If at or above threshold, continue.

## 3. Generate Slug

Create a short slug from the document's main topic (2-4 words, lowercase, hyphenated).
Example: "starter kit pod layout" → `starter-kit-pod-layout`

## 4. Create Spec Directory

```bash
mkdir -p .ai/specs/<slug>
```

## 5. Generate explain.md

Distill the requirements document into explain.md following the EXACT same format as `/dx-req-explain`:

```markdown
# <Title>

## What & Why
<2-3 sentences>

## Requirements
<Numbered list of concrete, testable requirements. One sentence each.>

## Changes by Area
<ONLY if requirements don't cover everything. Compact format.>

## Out of Scope
<1-3 bullets. OMIT if scope is unambiguous.>

## References
- Source: <original document path>
```

Apply the same writing principles as explain: ~50 line hard limit, one sentence per requirement, collapse overlapping sections, omit empty sections.

## 6. Optional: Lightweight Research

If the document mentions specific component names, classes, or files:
1. Run targeted Glob/Grep searches for those names
2. Write a lightweight `research.md` with just:
   - Files found matching component/class names
   - Current config/dialog structure (if component exists)
   - Files inventory table

Skip the full 4-agent research (user can run `/dx-req-research` manually for deeper analysis).

If no specific code references are found, skip research.md.

## 7. Present Summary

```markdown
## Spec created from requirements

**<Title>**
**Directory:** `.ai/specs/<slug>/`
**Completeness score:** <X>/8

### Generated:
- explain.md — <N> requirements distilled
- research.md — <Y> files found (or "skipped — no code references")

### Next steps:
- Review `explain.md` — are the requirements accurate?
- `/dx-plan` — generate implementation plan
- `/dx-req-research` — deeper codebase analysis (if needed)
```

## Examples

1. `/dx-req-import docs/requirements/starter-kit-pods.md` — Reads the requirements document, scores it 6/8 (passes threshold), generates `.ai/specs/starter-kit-pods/explain.md` with distilled requirements, and runs a lightweight codebase search for referenced component names.

2. `/dx-req-import ~/Downloads/ba-notes.txt` — Reads a plain-text BA document, scores it 3/8 (below threshold), prints specific gaps ("Missing: acceptance criteria, affected areas") and stops without creating any files.

3. `/dx-req-import docs/feature-spec.md` — Reads a detailed spec that mentions specific component classes, searches the codebase for those classes, and writes both `explain.md` and a lightweight `research.md` with discovered file paths.

## Troubleshooting

- **"Document needs more detail before proceeding"**
  **Cause:** The requirements document scored below 5/8 on the completeness rubric.
  **Fix:** Add the missing items listed in the score table (e.g., testable acceptance criteria, specific affected areas) and re-run `/dx-req-import`.

- **Spec directory uses slug instead of ID**
  **Cause:** This is expected behavior. Without an ADO ticket, the directory is named `.ai/specs/<slug>/` instead of `.ai/specs/<id>-<slug>/`.
  **Fix:** No fix needed. If you later create an ADO ticket, run `/dx-req-fetch <id>` to create the ID-prefixed directory and move your files.

- **Research.md not generated**
  **Cause:** The requirements document doesn't mention specific component names, classes, or files that can be searched.
  **Fix:** Run `/dx-req-research` manually for a deeper codebase analysis after the spec is created.

## Rules

- **Validate before creating** — if the document is too vague, stop and ask for more detail. Don't generate garbage explain.md from garbage input.
- **Same explain.md quality** — the output explain.md must be indistinguishable from one generated via the ADO flow. Same format, same conciseness, same developer audience.
- **No ADO metadata** — since there's no ADO ticket, omit ADO links, assigned to, iteration path. Keep the References section pointing to the source document.
- **Slug, not ID** — without an ADO ID, the spec directory uses just the slug: `.ai/specs/<slug>/` not `.ai/specs/<id>-<slug>/`.
- **Don't invent** — if the document doesn't specify something, note it as a gap, don't fill it in.
