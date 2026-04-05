# Decision Schema for Structured Decision Nodes

Decisions are non-obvious design choices made during planning. They live in `.ai/graph/nodes/decisions/` and are produced by `dx-plan` alongside `implement.md`. They enable `dx-pattern-extract` to scan decisions as structured data (instead of parsing markdown) and future graph tools to query decision lineage across tickets.

## Schema

```yaml
# .ai/graph/nodes/decisions/<ticket>-<slug>.yaml
id: decision-<ticket>-<slug>
type: decision
ticket: "<ticket-id>"
title: "Descriptive name for the decision"
created: <ISO-8601>
agent: dx-plan
model: <model-tier>
confidence: <low | medium | high>
trust_tier: shared              # shared (single ticket) | long-term (verified or pattern-promoted)
status: active                  # active | superseded | rejected

chosen: |
  What was chosen. 1-2 sentences.

why: |
  The deciding factor. 1-2 sentences explaining WHY this option won.

alternatives:
  - name: "<Alternative A>"
    reason_rejected: "<Why it was rejected — 1 sentence>"
  - name: "<Alternative B>"
    reason_rejected: "<Why it was rejected — 1 sentence>"

affects_steps:                  # Which implement.md steps depend on this decision
  - 1
  - 3

tags:                           # For matching by dx-pattern-extract
  - "tag1"
  - "tag2"

lineage:                        # Links to upstream spec artifacts
  - "requirement-<ticket>-raw"
  - "research-<ticket>"

files:                          # Key files involved in this decision
  - "path/to/relevant/file.ext"
```

## Field Rules

1. **id** -- `decision-<ticket>-<slug>` where slug is kebab-case, descriptive of the decision (e.g., `decision-1234-jwt-over-sessions`, `decision-2416-extend-dropdown`).
2. **type** -- Always `decision`.
3. **ticket** -- The work item ID this decision belongs to.
4. **title** -- Human-readable, 5-10 words. Describes the choice, not the ticket.
5. **created** -- ISO-8601 timestamp of when the decision was made.
6. **agent** -- Always `dx-plan` (the producing agent).
7. **model** -- The model tier used during planning (`opus`, `sonnet`, `haiku`).
8. **confidence** -- Inherits from `implement.md` provenance. Same confidence propagation rules apply (lowest input confidence is the ceiling).
9. **trust_tier** -- `shared` when first created (visible to other agents on the same ticket). Promoted to `long-term` if the decision becomes part of a pattern via `dx-pattern-extract`.
10. **status** -- `active` when created. Set to `superseded` if a later planning run replaces it. Set to `rejected` if the decision was reversed.
11. **chosen** -- What was chosen. Concrete and specific (file paths, class names, config keys).
12. **why** -- The deciding factor. Not a restatement of `chosen` -- explain the reasoning.
13. **alternatives** -- Each rejected alternative with a one-sentence reason. Minimum 1 alternative for a non-trivial decision.
14. **affects_steps** -- Step numbers from `implement.md` that depend on this decision. Helps trace decisions to implementation.
15. **tags** -- Keywords for matching by `dx-pattern-extract`. Include: technology names, architectural concepts, component types, file patterns. Same purpose as pattern tags.
16. **lineage** -- References to upstream spec artifacts that informed this decision. Use the format `<type>-<ticket>[-<detail>]` (e.g., `requirement-1234-raw`, `research-1234`). These become formal edges in Phase 5.
17. **files** -- Key files involved in or affected by this decision. Helps `dx-pattern-extract` match decisions across tickets by file overlap.

## Relationship to implement.md Key Decisions

Decision YAML files are the **structured counterpart** to the `## Key Decisions` section in `implement.md`. The markdown section remains for human readability; the YAML files enable machine queries.

- `dx-plan` writes both: the markdown section in `implement.md` AND the YAML files in `.ai/graph/nodes/decisions/`
- Content is the same -- the YAML is not a subset or superset
- If the Key Decisions section is omitted (trivial change), no YAML files are written either

## How dx-pattern-extract Consumes Decisions

`dx-pattern-extract` reads decision nodes as its **primary source** for identifying recurring patterns:

1. Scan `.ai/graph/nodes/decisions/*.yaml` for all decision files
2. Group by similarity: same `tags`, same `files`, same `chosen` approach
3. Fall back to `implement.md` `## Key Decisions` markdown for tickets that predate Phase 4 (no YAML files yet)
4. Apply the same 3-ticket promotion threshold as before

Structured YAML is more reliable than markdown parsing -- field names are explicit, alternatives are already separated, and tags enable keyword matching without NLP heuristics.

## Example

```yaml
id: decision-2416553-extend-layout-dropdown
type: decision
ticket: "2416553"
title: "Extend existing dropdown for layout mode"
created: 2026-04-05T14:30:00Z
agent: dx-plan
model: opus
confidence: medium
trust_tier: shared
status: active

chosen: |
  Extend the existing layout dropdown in the card component dialog
  rather than creating a new component or dialog field.

why: |
  The project already has a standard pattern for dialog dropdowns with
  datasource nodes. Extending is lower risk and follows the established
  codebase convention from 3 prior tickets.

alternatives:
  - name: "New dedicated layout component"
    reason_rejected: "Over-engineered for a single dropdown field; fragments dialog logic across components"
  - name: "Radio button group instead of dropdown"
    reason_rejected: "Inconsistent with existing layout selectors in other components; dropdown is the project standard"

affects_steps:
  - 1
  - 2
  - 4

tags:
  - "aem"
  - "dialog"
  - "dropdown"
  - "layout"
  - "_cq_dialog"

lineage:
  - "requirement-2416553-raw"
  - "research-2416553"

files:
  - "ui.apps/src/main/content/jcr_root/apps/project/components/card/_cq_dialog/.content.xml"
  - "core/src/main/java/com/project/core/models/CardModel.java"
```
