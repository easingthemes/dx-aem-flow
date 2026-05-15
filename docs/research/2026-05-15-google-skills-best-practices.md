# Google Skills Repo — Best-Practice Review

**Date:** 2026-05-15
**Source:** [github.com/google/skills](https://github.com/google/skills) (`skills/cloud/*`)
**Skills sampled:** `bigquery-basics`, `gemini-api`, `cloud-run-basics`, `google-cloud-recipe-onboarding`
**Goal:** Identify patterns worth adopting in `dx-core` / `dx-aem` / `dx-hub` / `dx-automation`.

## TL;DR

Google's repo is narrower than ours (product docs as skills, no execution metadata,
no cross-platform plumbing) but its **authoring style** is consistently disciplined.
Six patterns are worth porting:

1. Trigger-rich descriptions
2. Progressive disclosure via `references/`
3. Explicit "Core Directives" with ALWAYS/DO NOT pairs
4. GFM markdown alerts (`> [!WARNING]`, `> [!IMPORTANT]`)
5. A formal "Recipe" archetype for first-run/procedural skills
6. Embedded failure-mode triage blocks

Plus three micro-conventions: MCP fallback escape hatch, Related Skills cross-links,
source-of-truth pointer at the bottom.

## What Google does

### Frontmatter is intentionally minimal

```yaml
---
name: bigquery-basics
description: >-
  Manages datasets, tables, and jobs in BigQuery, and integrates with BigQuery
  ML and Gemini for advanced data analytics and AI-driven insights. Use when
  you need to interact with BigQuery, run SQL queries, manage BigQuery
  resources, or leverage BigQuery's built-in ML capabilities. Also use when
  performing data analysis, ingesting data into BigQuery, or developing AI
  applications on BigQuery.
---
```

Only `name` + `description` (occasionally `compatibility`). No `model`, `tools`,
`paths`, etc. — they target a generic skills runtime, not Claude Code's richer
execution model. **Not something to copy** (we lose tiering and tool restriction).

### Descriptions pack multiple triggers

Note the description above: a one-liner of what it does, then **two** "Use
when…" sentences with multiple trigger phrases each. Compare to our typical
single-purpose phrasing (`aem-component`: *"Find all source files... Use when a
developer asks 'where is component X?'..."*). Most of our skill descriptions
cover one canonical trigger; Google covers ~4-6.

### Progressive disclosure via `references/`

The SKILL.md body is ~50-150 lines. Heavy detail lives in a sibling
`references/` directory, one file per topic:

```
bigquery-basics/
├── SKILL.md
└── references/
    ├── core-concepts.md
    ├── cli-usage.md
    ├── client-library-usage.md
    ├── mcp-usage.md
    ├── iac-usage.md
    └── iam-security.md
```

The SKILL.md ends with a "Reference Directory" section listing each file with a
one-line summary. **We already have `references/` in 7 skills** (`dx-pr-review`,
`dx-req`, `dx-pr-answer`, `dx-figma-*`, `dx-dor`, `aem-fe-verify`), but it's
inconsistent and not codified in our skill conventions.

### "Core Directives" with explicit anti-patterns

```markdown
## Core Directives

- **Unified SDK**: ALWAYS use the Gen AI SDK (`google-genai` for Python, ...).
- **Legacy SDKs**: DO NOT use `google-cloud-aiplatform`, `@google-cloud/vertexai`,
  or `google-generativeai`.
```

Pairs of ALWAYS/DO NOT are short, declarative, scannable. Then a `> [!WARNING]`
restates the same rule for emphasis.

### Markdown alerts for hard rules

```markdown
> [!IMPORTANT]
> Models like `gemini-2.0-*`, `gemini-1.5-*` are legacy and deprecated.
> Your knowledge is outdated.

> [!TIP]
> Use the Developer Knowledge MCP Server if `search_documents` is available.

> [!WARNING]
> Legacy SDKs are deprecated. Migrate urgently.
```

We use **bold** + ALL-CAPS + numbered "CRITICAL RULE:" prefixes. GitHub-flavored
alerts render natively on GitHub, VS Code, Cursor, and most renderers. Cleaner
and more semantic.

### Recipe skill archetype (procedural)

`google-cloud-recipe-onboarding` follows a distinct, reusable template:

```markdown
# <Title>

## Overview
[1-2 paragraphs of context]

## Clarifying Questions
[Numbered list the agent asks before proceeding]

## Prerequisites
[Bulleted hard requirements]

## Steps
### 1. <Verb-noun heading>
### 2. ...

## Validation Logic
[How to verify success — concrete checks]
```

**We don't have a formal archetype for our procedural skills** (`dx-init`,
`aem-init`, `dx-hub-init`, `dx-bug`, `dx-pr`). They each invented their own
shape. Adopting the Recipe template would make first-run flows more consistent.

### Failure-mode triage blocks

Cloud Run skill embeds this directly:

```markdown
### What to do if a deployment fails:
1. **IAM/Permission Error:** Read iam-security.md.
2. **Crash on Boot / Healthcheck failed:** Fetch logs immediately using
   `gcloud logging read ... --limit=20` to find the exact runtime error.
3. **Native Dependency Error (Node/Python):** If using `--no-build`, switch
   to `--source .` (Buildpacks) to compile native extensions properly.
```

Symptom → likely cause → exact remediation command. Inline, not buried in a
linked file. We do this in places (`dx-step-fix`, `aem-doctor`) but not
systematically.

### Validation Logic section

Every Recipe skill ends with:

```markdown
## Validation Logic

- **Project Created:** Does the user have a Project ID?
- **Billing Linked:** Is the project associated with a billing account
  (check via `gcloud beta billing projects describe PROJECT_ID`)?
- **CLI Authenticated:** Does `gcloud config list` show the correct account?
```

This is **identical in spirit to our TODO `Done-when:` rule** but applied to
skill execution rather than backlog items. Worth lifting into skill conventions.

### Micro-conventions

- **MCP fallback hint** at the end of the reference directory:
  *"If you need product information not found in these references, use the
  Developer Knowledge MCP server `search_documents` tool."*
  Clean escape hatch. We have `context7` (`query-docs`) available — should
  codify this pattern.

- **Related Skills cross-links** with explicit URLs. We don't systematically
  cross-link, even though we have natural chains (`dx-plan` → `dx-step` → `dx-pr`).

- **Source-of-truth pointer** to canonical upstream docs at the bottom, even
  with `references/` present. Helps when refs go stale.

## What we already do better

Don't change these:

- **Model/effort tiering** in frontmatter (Opus xhigh/high, Sonnet, Haiku low)
- **DOT digraph flow-control** for branching skills (we are unique here)
- **MCP tool-name prefix discipline** (cross-platform mapping table)
- **Three-layer override system** (`.ai/rules` → `config.yaml` → plugin defaults)
- **Cross-platform install** (Claude / Copilot / Cursor / Codex / Gemini)
- **Config-driven, never hardcoded** convention
- **Skill naming with plugin prefix** (`dx-*`, `aem-*`, `auto-*`, `dx-hub-*`)
- **Soft-dependency pattern** for superpowers methodology skills

## Concrete recommendations

Tracked as TODO items in [todo-skill-conventions.md](../todo/todo-skill-conventions.md).
Summary:

| # | Adopt | Rough scope | Priority |
|---|-------|-------------|----------|
| A | Audit + expand skill descriptions for trigger coverage | 40+ skills, frontmatter only | Medium |
| B | Codify `references/` pattern when SKILL.md exceeds ~150 lines | Convention + 5-8 skill refactors | Medium |
| C | Add "Core Directives" / ALWAYS-DO NOT to skills with anti-patterns | `dx-step`, `dx-pr`, `aem-init`, `aem-verify` | Medium |
| D | Standardize on GFM alerts (`> [!WARNING]` etc.) over bold ALL-CAPS | All skills, find-replace pass | Low |
| E | Formalize Recipe archetype + apply to `*-init` and `dx-bug`/`dx-pr` | New docs page + 4-6 skill refactors | Medium |
| F | Embed failure-mode triage blocks in ops skills | `dx-step-fix`, `aem-doctor`, `aem-verify` extensions | Low |
| G | Adopt MCP fallback hint as a template line in references-using skills | Template + 7 skill touches | Low |
| H | Add "Related Skills" section to skills with natural chains | `dx-plan`, `dx-step`, `dx-pr`, `dx-req`, init flows | Low |
| I | Add source-of-truth pointer to skills with external doc dependencies | `aem-*`, ADO/Jira/Figma skills | Low |
| J | Lift "Validation Logic" section into Recipe template | Bundled with E | Medium |

None of these are urgent — our skills already work. They are quality polish
that improves consistency, scannability, and (for A) auto-activation accuracy
across platforms.

## What we should NOT adopt

- **Stripping execution-metadata frontmatter** (`model`, `effort`, `tools`,
  `paths`). Google's runtime doesn't have it; ours does, and tiering is real
  cost/quality value.
- **`npx skills add` installer**. Our marketplace + `.claude-plugin/` model
  is more capable across platforms.
- **Single flat `skills/cloud/` namespace**. Our four-plugin separation
  (`dx-core` / `dx-hub` / `dx-aem` / `dx-automation`) is the better axis.
