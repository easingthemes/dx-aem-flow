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

---

# Update 2026-05-15: Reality check against Claude Code docs

After cross-checking the Google-derived list against the official Claude Code
skills authoring guidance ([code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills)
and [platform.claude.com/.../agent-skills/best-practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)),
**3 items survive cleanly, 3 need reframing, 3 should be dropped, and 6 new
items emerge** that the Google-only review missed. The core principle Anthropic
hammers — *"the context window is a public good, every token competes"* —
inverts the impulse to add Core Directives / Related Skills / Markdown alert
boilerplate.

## Verdict per item

| # | Original | Verdict | Reason |
|---|----------|---------|--------|
| A | Trigger-rich descriptions | **Keep + extend** | Anthropic explicitly shows multi-trigger descriptions. Also adopt the dedicated `when_to_use` frontmatter field, which we don't currently use. |
| B | Progressive disclosure via `references/` | **Keep, fix threshold** | Anthropic documents this directly (Patterns 1, 2, 3). **Correct threshold: 500 lines, not 150.** Also: "keep references one level deep" is an explicit rule. |
| C | Core Directives blocks (ALWAYS/DO NOT) | **Drop the block, keep the spirit** | Anthropic doesn't endorse extracted directive blocks (violates "concise is key"). Real fix: replace weak imperatives (`should`, `consider`, `try to`) with `MUST` / `MUST NOT` **inline**. Anthropic explicit: *"stronger language like 'MUST filter' instead of 'always filter'."* |
| D | GFM markdown alerts | **Drop** | Anthropic's docs use `<Note>`/`<Tip>` (Mintlify), but their **skill examples never use GFM alerts**. Pure aesthetics. Zero documented behavioral benefit. |
| E | Recipe archetype | **Keep, rename** | Anthropic documents the same pattern but calls it "Workflows with checklists" — see PDF form-filling example. Drop the "Clarifying Questions" section (not in Anthropic's pattern); keep numbered steps + checkbox tracking + validation gates. |
| F | Failure-mode triage blocks | **Keep, low priority** | Not explicit, but consistent with the "solve, don't punt" principle. Ops skills only. |
| G | MCP fallback escape hatch | **Drop** | Anthropic explicitly says *"Avoid offering too many options"*. Adding "if X doesn't work, try Y MCP" is exactly that. Better fix: complete reference docs so fallback is unnecessary. |
| H | Related Skills cross-links | **Drop** | Claude already has all skill descriptions in context — cross-links don't aid discovery. Adds recurring token cost (skill content stays in context across turns). Violates "every line is a recurring token cost". |
| I | Source-of-truth pointer | **Keep, lowest priority** | Aligns with "no time-sensitive information". Low cost, modest value. |
| J | Validation Logic section | **Keep, reframe as "Validation Loop"** | Anthropic explicit: validator → fix → repeat, with *"Only proceed when validation passes"* gate. Use **machine-verifiable** checks (commands, file checks), not human checklists. |

## New items the Google-only review missed

The Anthropic docs surface six concrete, documented best-practices we should
adopt that don't appear in Google's repo at all:

### K. Adopt the dedicated `when_to_use` frontmatter field

Anthropic provides a separate `when_to_use` field for trigger phrases and
example requests, appended to `description` in the skill listing. Currently
none of our 40+ skills use it — we stuff everything into `description`,
which is capped at 1024 chars. Combined cap is 1,536 chars. Splitting
*what it does* (description) from *when to trigger* (when_to_use) is the
documented pattern.

### L. Audit weak imperatives → MUST / MUST NOT

Direct quote: *"Claude A might suggest reorganizing to make rules more
prominent, using stronger language like 'MUST filter' instead of 'always
filter'."* Replaces the dropped Core Directives idea (C) — the fix is
inline tightening, not a new section.

Audit grep:
```bash
grep -rE "\b(should|consider|try to|may want to|you can)\b" plugins/*/skills/*/SKILL.md
```

### M. Table of contents in reference files >100 lines

Direct quote: *"For reference files longer than 100 lines, include a table
of contents at the top. This ensures Claude can see the full scope of
available information even when previewing with partial reads."* Claude
will `head -100` reference files when it isn't sure they're relevant; a TOC
in the first 100 lines preserves discoverability.

### N. Enforce one-level-deep reference structure

Direct quote: *"Keep references one level deep from SKILL.md."* Claude
partially reads files when reached via nested references. Audit our
existing `references/` directories for nested links.

```bash
# Find references that link to other references (nested):
grep -rE "\.\./|references/[a-z-]+\.md" plugins/*/skills/*/references/
```

### O. Concise body audit — kill the boilerplate

Direct quote: *"Default assumption: Claude is already very smart. Only add
context Claude doesn't already have."* Our largest skills have explanatory
prose that Claude doesn't need. The fix is a line-by-line audit asking
*"does this paragraph justify its token cost?"* Most acutely needed in
`aem-component` (263 lines), and other 200+ line skills.

### P. Consistent terminology audit

Direct quote: *"Choose one term and use it throughout the Skill."* Examples
in our codebase: ticket / story / work-item / issue used interchangeably;
component / module / block in AEM skills; PR / pull-request / pull request
mixed. Pick one per concept, find-replace.

## Revised priority order

After the reality check, here is the recommended adoption order. Items in
**bold** are net-new from this update and were not in the Google-only
review.

| Order | Item | Effort | Why first |
|------:|------|--------|-----------|
| 1 | **K: Adopt `when_to_use` field** | Small | Pure addition, no risk, immediate auto-activation lift |
| 2 | A: Trigger-rich descriptions | Medium | Pairs naturally with K |
| 3 | **L: Replace weak imperatives with MUST/MUST NOT** | Small | Find-grep-edit, no structural risk |
| 4 | B: `references/` for skills >500 lines | Medium | Correct the threshold first |
| 5 | **N: Audit references for one-level-deep rule** | Small | Quick grep + fix |
| 6 | **M: TOC in reference files >100 lines** | Small | Mechanical |
| 7 | E: Workflow checklists (renamed from Recipe) | Medium | Real value for `dx-init` / `aem-init` / `dx-bug` |
| 8 | J: Validation Loop in workflow skills | Bundled with #7 | |
| 9 | **O: Concise body audit** | Medium | Highest value where skills exceed 200 lines |
| 10 | **P: Consistent terminology** | Small | Bundle with O |
| 11 | F: Failure-mode triage | Small | Ops skills only |
| 12 | I: Source-of-truth pointers | Tiny | Bundle with anything |

**Dropped from the original list:** C (Core Directives blocks), D (GFM
alerts), G (MCP fallback line), H (Related Skills cross-links). All
violated Anthropic's "concise is key" principle or had no documented
behavioral basis.

## Bottom line

The Google review surfaced the **right structural patterns** (progressive
disclosure, trigger-rich descriptions, workflow checklists) but also
several **purely aesthetic patterns** (markdown alerts, cross-link sections,
escape-hatch lines) that Anthropic's docs implicitly argue against.

The reality-checked list is **shorter and more concrete**: 4 small mechanical
items (K, L, M, N) that can ship in a single PR, then 3 medium items (A, B
+ refactors, E + checklists) that deliver real auto-activation and
maintainability wins. Skip the aesthetic polish (D, G, H) entirely — every
line in a skill is a recurring token cost across the whole session, so
adding cross-link sections "for completeness" is a net negative.
