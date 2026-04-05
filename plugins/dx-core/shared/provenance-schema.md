# Provenance Schema for Spec Output Files

Every Markdown file written to `.ai/specs/<id>-<slug>/` (or `.ai/pr-reviews/`) MUST include a provenance frontmatter block as the very first content, before the `# Heading`.

## Schema

```yaml
---
provenance:
  agent: <skill-name>        # The skill that produced this file (e.g., dx-plan, dx-req, aem-snapshot)
  model: <model-tier>        # opus | sonnet | haiku — from the skill's own model configuration
  created: <ISO-8601>        # Timestamp when the file was written (e.g., 2026-04-05T14:30:00Z)
  confidence: <level>        # high | medium | low — see definitions below
  verified: false            # Set to true ONLY by dx-step-verify on PASS
---
```

## Field Rules

1. **agent** — Use the skill name exactly as it appears in the skill's frontmatter `name:` field.
2. **model** — Use the model tier from the skill's frontmatter (`model:` field). If no model is specified, use `sonnet` (the default tier).
3. **created** — ISO-8601 timestamp with timezone. Use the current time when writing the file.
4. **confidence** — Self-assessed by the producing skill. See definitions below.
5. **verified** — Always `false` when first written. Only `dx-step-verify` sets this to `true` after all verification phases pass. If the file has no provenance block (pre-migration), skip the update.

## Confidence Levels

| Level | Meaning | Examples |
|-------|---------|---------|
| **high** | Based on verified sources — fetched data, actual codebase search results, passing tests | `raw-story.md` (ADO/Jira fetch), `research.md` (codebase search), `aem-before.md` (AEM query) |
| **medium** | Involves synthesis or interpretation of source material | `explain.md` (requirements distillation), `implement.md` (planning), `share-plan.md` (non-technical summary) |
| **low** | Speculative or based on incomplete data — degraded mode, missing prerequisites | Any output produced when prerequisite files are missing or agents failed partially |

**Downgrade rule:** If a skill operates in degraded mode (missing prerequisites, partial agent failures), downgrade confidence by one level from the default.

## Example

```yaml
---
provenance:
  agent: dx-plan
  model: opus
  created: 2026-04-05T14:30:00Z
  confidence: medium
  verified: false
---
# Implementation Plan: WORK-1234 — Add User Profile
...
```

## Consuming Provenance

- **dx-step-verify** — On PASS, update `implement.md` provenance to set `verified: true`.
- **dx-step** — When updating step status in `implement.md`, preserve the provenance frontmatter block unchanged.
- **All other consumers** — Read provenance if useful for context (e.g., trust filtering), but do not modify it.

## Non-Markdown Files

JSON output files (e.g., `qa.json`) do not use YAML frontmatter. If provenance is needed for JSON files in the future, add a top-level `"provenance": {}` key.
