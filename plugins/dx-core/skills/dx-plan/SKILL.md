---
name: dx-plan
description: Generate an implementation plan with status-tracked steps. Creates implement.md from explain.md + research.md. Uses extended thinking for deep reasoning. Use after requirements are ready (from ADO flow or import).
argument-hint: "[Work Item ID or slug (optional — uses most recent if omitted)]"
model: opus
effort: high
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You read the spec documents and use extended thinking to generate `implement.md` — a concrete, step-by-step development plan with status tracking for automated execution.

Use ultrathink for this skill — implementation planning benefits from deep reasoning about dependencies, ordering, and edge cases.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir $ARGUMENTS)
```

If the script exits with error, ask the user for the work item ID or slug.

Read these files from `$SPEC_DIR` (in order of importance):
- `research.md` — codebase findings (required for a good plan)
- `explain.md` — distilled requirements
- `raw-story.md` — original story for reference (may not exist for non-ADO flows)

If `research.md` doesn't exist, warn the user: "No research.md found — run `/dx-req` first for a better plan. Proceeding with explain.md only."

Also check for Figma prototype files (from `/dx-figma-prototype`):
- `figma-conventions.md` — discovered project conventions (design tokens, naming, patterns)
- `prototype/index.html` — standalone HTML prototype
- `prototype/styles.css` — CSS with project token mappings
- `figma-extract.md` — raw Figma extraction data

If prototype files exist, the plan MUST reference them. Implementation steps should adapt the prototype into project-native code rather than building from scratch.

## Hub Mode Check

Read `shared/hub-dispatch.md` for hub detection logic.

If hub mode is active (`hub.enabled: true` AND cwd is `.hub/`):
1. Read `research.md` → `## Cross-Repo Scope` for per-repo scope
2. If cross-repo scope detected:
   a. Resolve target repos from config
   b. For each repo, dispatch planning: `cd <repo.path> && claude -p "/dx-plan <ticket-id>" --output-format json --allowedTools "Bash,Read,Edit,Write,Glob,Grep" --permission-mode bypassPermissions`
   c. Each repo generates its own `implement.md` locally
   d. Collect and summarize: "Plans generated in <N> repos"
3. Write state files
4. STOP — do not continue with local planning

If hub mode is not active: continue with normal flow below.

## 2. Check Existing Output

1. Check if `implement.md` exists in the spec directory
2. If it exists, read its content
3. Check staleness indicators:
   - Does the title in `implement.md` match the current spec?
   - Does the step count and files referenced align with current `research.md`?
   - Have `research.md` or `explain.md` changed since `implement.md` was generated?
4. If `implement.md` is current → print `implement.md already up to date — skipping` and STOP
5. If inputs changed or plan looks stale → print `implement.md exists but is outdated — regenerating` and continue
6. If not found → continue normally (first run)

## 3. Plan Format Rules

If `.ai/rules/plan-format.md` exists (project override), read and follow it. Otherwise read the plugin's `rules/plan-format.md`.

If `.github/instructions/` (or `.ai/instructions/`) exists, read instruction files relevant to the file types in this spec — these provide detailed code examples and framework patterns for generating concrete implementation steps.

### Optional: Design Exploration

If this is a complex feature with multiple valid approaches, check if `superpowers:brainstorming` is available and invoke it to explore the design space before planning.

**Fallback (if superpowers not installed):** Before generating the plan, briefly consider:
- Are there 2-3 valid approaches? Document the chosen one and why.
- What are the key tradeoffs (performance vs simplicity, reuse vs custom)?
- Are there unknowns that need spiking first?

If a brainstorming spec already exists in `docs/superpowers/specs/`, read it for design context.

## AEM Component Intelligence Rules

If `research.md` contains an `## AEM Component Intelligence` section, apply these three rules during step generation:

### Rule 1: Variant Completeness
When a step modifies a component, check AEM Component Intelligence for variants:
- **Variants in this repo** → include in the SAME step as additional files to modify (same change, different file path)
- **Variants in other repos** → add a NOTE at the bottom of the step: "⚠ Variant `<name>` in `<repo>` may need the same change. Verify in a separate session."

Every step that touches a component MUST account for all known variants. Missing a variant is a plan defect.

### Rule 2: Field Semantic Awareness
When a step references an AEM dialog field (e.g., for aria-label, display text, image alt), verify the field's semantic meaning from AEM Component Intelligence:
- Check the field's `Label` and `Sample Authored Values`
- If the plan's intended use doesn't match the field's actual semantic meaning → flag in the step with the correct field and explanation
- Example: plan says "use `heading` for product name" but AEM shows heading Label="Product Price", Value="$29.99" → step must note: "Use `text` (Product Name), NOT `heading` (Product Price)"

### Rule 3: Null Content Guard
When a step renders a dialog field value in the UI (link text, label, display content):
- Check AEM Component Intelligence for that field's authored values across pages
- If ANY page shows the field as empty ("(empty)" or blank) → add a sub-task to the step: "Guard: AEM shows `<field>` is empty on `<page>`. Wrap rendering in conditional to prevent empty elements (empty `<a>`, `<span>`, etc.)."

These rules are technology-agnostic — they specify WHAT to guard, not HOW. The project's `.claude/rules/` files provide syntax-specific patterns (HTL conditionals, HBS `{{#if}}`, etc.).

### Cross-Repo Step Markers

If `research.md` contains a `## Cross-Repo Scope` section with **Scope: Multi-repo**:

1. Read repo names from the Cross-Repo Scope section
2. Prefix each step title with a repo tag: `[This repo]`, `[{Repo-Name}]`
3. Group steps by repo: all backend-repo steps first, then this-repo steps
4. Between repo groups, add a separator note:

> Steps tagged [{Backend-Repo}] must be implemented in that repo. Deploy before starting [This repo] steps.

5. The `**Other repos required:**` line at plan completion lists all non-current repos from the scope section

Example:

### Step 1: Add dialog field [{Backend-Repo}]
**Files:** `ui.apps/.../component/_cq_dialog/.content.xml`
**What:** Add `newField` to dialog
**Verification:** Field appears in dialog XML

> Steps tagged [{Backend-Repo}] must be implemented in that repo. Deploy before starting [This repo] steps.

### Step 2: Consume new field [This repo]
**Files:** `ui.frontend/src/.../component.js`
**What:** Read `newField` from data model
**Verification:** Field renders on page

If research.md has no Cross-Repo Scope section or scope is "This repo only", do not add repo tags.

## 4. Generate implement.md

Analyze all inputs and write `implement.md` in the same spec directory.

Read `.ai/templates/spec/implement.md.template` and follow that structure exactly. Key rules:

- Every step MUST have `**Status:** pending` (initial state)
- Steps are ordered by implementation dependency
- Be specific about property names, types, default values, file paths with line numbers
- Include code snippets when helpful
- Risks section: only REAL technical risks. OMIT if none.

## 5. Status Tracking

Every step MUST have a `**Status:**` line with one of:
- `pending` — not yet started (initial state)
- `in-progress` — currently being worked on
- `done` — completed and verified
- `blocked` — cannot proceed, with reason

The step-* skills update these statuses as they execute.

## 6. Planning Principles

- **Reuse before create** — if research.md's "Existing Implementation Check" shows existing code covers a requirement (✅ or ⚡), the step MUST reuse/extend that code. Never create a new utility, helper, service, or component when an existing one can be extended. If research.md doesn't have this section, search the codebase yourself before planning a "Create new" step.
- **Every step references specific files and line numbers** from research.md
- **Steps are ordered by dependency** — what must be done first for the next step to work
- **Pattern references are concrete** — "follow the pattern in ModelName.java:45"
- **Each step has a Test line** — specific test command or compile check
- **Prototype-first** — if `prototype/` exists, implementation steps adapt it into the project's build system. The step should reference specific prototype files:
  - "Adapt HTML structure from `prototype/index.html` into the HBS template"
  - "Migrate CSS from `prototype/styles.css` into component SCSS, replacing flat values with project variables/mixins"
  - "Compare rendered output against `prototype/figma-reference.png`"
  - The prototype uses the project's naming conventions, so class names and structure should carry over with minimal changes.
- **Conventions as reference** — if `figma-conventions.md` exists, implementation steps should cite it for specific variable names, mixin usage, and naming patterns. E.g., "Use `@include media-breakpoint-up(lg)` for desktop breakpoint (see figma-conventions.md)."
- **No time estimates**
- **Scale to complexity** — simple change = 3-4 steps, complex feature = 10+

## 7. Present Summary

```markdown
## implement.md created

**<Title>**
- Steps: <count> (all pending)
- Files to modify: <count>
- Files to create: <count>
- Tests planned: <count> unit, manual verification included
- Risks identified: <count or "none">

### Next steps:
- `/dx-plan-validate` — verify plan covers all requirements
- `/dx-step` — execute first step
- `/dx-step-all` — execute all steps autonomously
```

## Examples

### Standard planning flow
```
/dx-plan 2416553
```
Reads `.ai/specs/2416553-add-pod-count-dropdown/explain.md` and `research.md`, generates `implement.md` with 6 steps covering model changes, dialog updates, HTL template, JS logic, SCSS, and tests. All steps start as `pending`.

### Re-run after research update
```
/dx-plan 2416553
```
Detects that `research.md` has changed since `implement.md` was generated. Prints "implement.md exists but is outdated — regenerating" and creates a fresh plan.

### Without research (degraded mode)
```
/dx-plan 2416553
```
If `research.md` doesn't exist, warns "No research.md found — run `/dx-req` first for a better plan" and generates from `explain.md` only. Plan will lack specific file paths and line numbers.

## Troubleshooting

### "No spec directory found"
**Cause:** No `.ai/specs/` directory matches the given ID or slug.
**Fix:** Run `/dx-req <id>` first to create the spec directory, or check the ID is correct.

### Plan has vague steps without file paths
**Cause:** `research.md` is missing or has thin results.
**Fix:** Run `/dx-req <id>` with search hints to get better codebase findings, then re-run `/dx-plan`.

### Plan creates new utilities instead of reusing existing ones
**Cause:** `research.md` didn't find existing utilities, or the "Existing Implementation Check" section is missing.
**Fix:** Run `/dx-req <id>` again — it may find more with different search terms. Or manually add findings to `research.md` before re-planning.

## Decision Tree: Step Granularity

```
Change set identified →
├── All files share one concern (same component) → 1 step (up to ~8 files)
├── Files split across concerns (FE + BE + test) → split by concern
├── >8 files in one concern → split by component boundary
└── Test files →
    ├── Unit tests for single component → include in component step
    └── Integration tests spanning components → separate step
```

## Decision Examples

### Reuse vs Create New
**Scenario:** Plan step says "add form validation for phone numbers"
**Discovery:** `src/core/scripts/libs/forms.js` has `validateField()` with email, text, number patterns
**Decision:** EXTEND — add phone regex to existing `validateField()`. Don't create new util.
**Why:** Existing utility covers >70% of need. Only a new regex pattern is needed.

### When to Create New
**Scenario:** Need color-coded severity badge component for QA dashboard
**Discovery:** Closest match is `HighlightBox` (callout alert) — wrong abstraction (alert vs badge)
**Decision:** CREATE — no existing component serves this purpose
**Why:** Repurposing HighlightBox would fight its design. Clean creation is simpler.

### Step Granularity
**Scenario:** Change touches hero.js (FE), HeroModel.java (BE), hero.html (template), hero-test.js (test)
**Decision:** 2 steps — Step 1: BE (HeroModel.java), Step 2: FE (hero.js + hero.html + hero-test.js)
**Why:** BE and FE are independent concerns. FE files change together (same concern).

## Pre-Presentation Validation

Before presenting the generated plan:
1. Re-read `explain.md` — list every requirement
2. For each requirement, verify ≥1 plan step addresses it
3. For each plan step, verify it traces to a requirement
4. Flag gaps: "Requirement #{N} has no corresponding plan step"
5. Flag extras: "Step #{N} does not trace to any requirement"

## Success Criteria

- [ ] `implement.md` exists in spec directory
- [ ] Every step has `**Status:** pending`
- [ ] Every step lists ≥1 file in `**Files:**`
- [ ] No duplicate step numbers
- [ ] Steps ordered by dependency (no forward references)

## Rules

- **Grounded in research** — every file reference must come from research.md findings
- **No duplication** — never plan to create something that already exists in the codebase. If research.md identifies existing utilities, helpers, services, or patterns, the plan MUST reuse them. A step that creates a new helper when an existing one covers the need is a plan defect.
- **Concrete over abstract** — property names, types, default values, paths
- **Dependency-ordered** — steps in the order they should be implemented
- **No invented requirements** — only implements what explain.md says
- **Domain-aware** — use correct terminology for the project's technology stack
- **Status on every step** — `**Status:** pending` is mandatory
- **Current repo only** — only plan steps for files that exist in this repo. If research.md has a "Cross-Repo Scope" section, add the `**Other repos required:**` header line but do NOT create steps for those repos. The developer runs the workflow in each repo separately.
