# Pattern Schema for Cross-Ticket Knowledge

Patterns are reusable decisions or approaches discovered across multiple tickets. They live in `.ai/graph/nodes/patterns/` and are consumed by `dx-plan` to inform future planning.

## Schema

```yaml
# .ai/graph/nodes/patterns/<topic>.yaml
id: pattern-<topic>
type: pattern
title: "Descriptive name for the pattern"
created: <ISO-8601>
updated: <ISO-8601>
agent: dx-pattern-extract
model: haiku
confidence: medium              # medium when first promoted, high after manual review
trust_tier: long-term           # long-term (3+ tickets) | verified (manually promoted)

description: |
  What the pattern is, when to use it, and why it works.
  2-5 sentences. Written for a planner agent, not a human tutorial.

approach: |
  The specific implementation approach. Include key file paths,
  class names, or config patterns. Concrete enough that dx-plan
  can reference it in a step.

tags:                           # For matching against research.md content
  - "tag1"
  - "tag2"

tickets:                        # Evidence: which tickets established this pattern
  - id: "<ticket-id>"
    decision: "Brief description of how this ticket used the pattern"
  - id: "<ticket-id>"
    decision: "Brief description of how this ticket used the pattern"

files:                          # Key files that implement the pattern
  - "path/to/canonical/example.ext"
```

## Field Rules

1. **id** — `pattern-<topic>` where topic is kebab-case, descriptive (e.g., `pattern-jwt-auth-middleware`, `pattern-dialog-dropdown-extension`).
2. **title** — Human-readable, 5-10 words. Describes the pattern, not the ticket.
3. **created/updated** — ISO-8601 timestamps. `updated` changes when new tickets are added.
4. **confidence** — Start at `medium` (auto-extracted). Promote to `high` after human review or after 5+ tickets confirm.
5. **trust_tier** — `long-term` when auto-promoted (3+ tickets). `verified` when manually reviewed and confirmed.
6. **description** — What the pattern IS. Written for an LLM planner, not a human developer.
7. **approach** — HOW to implement. Concrete file paths, class names, config keys. This is what dx-plan references in step instructions.
8. **tags** — Keywords for matching. Include: technology names, component types, architectural concepts, file extensions. dx-plan matches these against research.md content.
9. **tickets** — Evidence trail. Each entry records which ticket used this pattern and how. Minimum 3 entries for promotion.
10. **files** — Canonical implementation files. dx-plan can reference these as "follow the pattern in `<path>`".

## Promotion Rules

```
Ticket 1: Key Decision records approach X
Ticket 2: Key Decision records same approach X
Ticket 3: Key Decision records same approach X
  → dx-pattern-extract detects the recurrence
  → Writes pattern node to .ai/graph/nodes/patterns/
  → trust_tier: long-term, confidence: medium
```

A pattern is promoted when the **same approach** appears in **3 or more tickets**. "Same approach" means:
- Same architectural decision (e.g., "extend existing component" vs "create new")
- Same file/class pattern (e.g., "add field to existing Sling Model")
- Same technology choice (e.g., "use project's existing form validation utility")

## How dx-plan Consumes Patterns

Before generating `implement.md`, dx-plan scans `.ai/graph/nodes/patterns/*.yaml`:

1. **Tag matching** — Compare pattern tags against keywords from `research.md` (component names, file types, architectural concepts).
2. **File matching** — Compare pattern `files` against files mentioned in `research.md` findings.
3. **If matches found** — Include a `## Relevant Patterns` section in implement.md:

```markdown
## Relevant Patterns

| Pattern | Confidence | Tickets | Relevance |
|---------|-----------|---------|-----------|
| [JWT auth middleware](../.ai/graph/nodes/patterns/jwt-auth-middleware.yaml) | high | 3 | research.md mentions auth middleware files |

> **pattern-jwt-auth-middleware:** Use the existing JWT middleware at `src/middleware/auth.js`. Extend with new claims rather than creating a separate auth layer. (from #1234, #2345, #3456)
```

4. **Step references** — When a plan step relates to a known pattern, reference it: "Follow established pattern `pattern-jwt-auth-middleware` — extend existing middleware."

## Example

```yaml
id: pattern-dialog-dropdown-extension
type: pattern
title: "Extend existing AEM dialog dropdown fields"
created: 2026-04-01T10:00:00Z
updated: 2026-04-05T14:30:00Z
agent: dx-pattern-extract
model: haiku
confidence: medium
trust_tier: long-term

description: |
  When adding a new option to an AEM component, extend the existing
  dropdown dialog field rather than creating a new field or component.
  The project uses a standard pattern for dialog dropdowns with
  datasource nodes.

approach: |
  1. Add new option to the existing datasource node in _cq_dialog/.content.xml
  2. Handle the new value in the Sling Model's init() method
  3. Add conditional rendering in the HTL template using data-sly-test
  4. Null-guard: check authored value before rendering

tags:
  - "aem"
  - "dialog"
  - "dropdown"
  - "_cq_dialog"
  - "sling-model"

tickets:
  - id: "WORK-101"
    decision: "Added layout-mode dropdown to existing card dialog"
  - id: "WORK-205"
    decision: "Added color-theme dropdown to existing banner dialog"
  - id: "WORK-318"
    decision: "Added display-variant dropdown to existing teaser dialog"

files:
  - "ui.apps/src/main/content/jcr_root/apps/project/components/card/_cq_dialog/.content.xml"
  - "core/src/main/java/com/project/core/models/CardModel.java"
```
