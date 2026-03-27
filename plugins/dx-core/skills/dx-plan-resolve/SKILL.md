---
name: dx-plan-resolve
description: Resolve risks and issues flagged by plan-validate. Researches codebase for concrete solutions and updates implement.md steps with fixes. Use after /dx-plan-validate reports warnings or risks.
argument-hint: "[Work Item ID or slug (optional — uses most recent if omitted)]"
---

You resolve risks and issues found during plan validation by researching the codebase for concrete solutions, then updating `implement.md` with specific fix instructions.

Use ultrathink for this skill — solving risks requires deep reasoning about patterns and codebase specifics.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir $ARGUMENTS)
```

Read from `$SPEC_DIR`:
- `implement.md` (required)
- `research.md` (required — for codebase context)
- `explain.md` (for requirement context)

## 2. Identify Issues to Resolve

Scan `implement.md` for:
1. **Risks section** — anything listed under `## Risks`
2. **Blocked steps** — steps with `**Status:** blocked`
3. **Vague instructions** — steps that say "may need", "might require", "consider", "TBD" without a concrete solution

Collect each issue as a task to resolve.

If no issues found → print `No risks or issues to resolve — plan is ready.` and STOP.

## 3. Research Solutions

For each issue, search the codebase for how the project already solves similar problems.

If `.github/instructions/` (or `.ai/instructions/`) exists, read instruction files relevant to the issue's file types — these provide detailed framework patterns and code examples.

**Example: "Dynamic show/hide scoping inside nested repeatable fields"**
1. Search for existing repeatable fields that use show/hide → `Grep` for the show/hide pattern in config files
2. Find how they handle scoping → read the matching config and any companion JS
3. Identify the concrete pattern (scoped CSS classes, row-targeted selectors, etc.)
4. Formulate a specific solution with exact code/config to add

**General approach:**
- Search for the pattern or keyword in the existing codebase
- Find 1-2 working examples of the same technique
- Extract the concrete implementation details (class names, config structure, selectors, etc.)
- Formulate a specific fix, not a generic recommendation

## 4. Update implement.md

For each resolved issue:

**If the fix belongs in an existing step** — append the fix details to that step's `**What:**` section:
```markdown
**What:**
<existing instructions>
- **Risk mitigation:** Use unique scoped class `cmp-component__toggle--step{N}` on the
  checkbox field (see `card/config.xml:42` for the same pattern). This scopes
  the show/hide listener to the correct repeatable row.
```

**If the fix needs a new step** — insert a step in the correct dependency position:
```markdown
### Step N: <Descriptive title>
**Status:** pending
**Files:** `path/to/file`, `path/to/other-if-needed`
**What:**
- <concrete instructions with file:line references>
**Why:** Mitigates risk — <one sentence explaining the issue>
**Test:** <specific verification approach>
```

**Update the Risks section** — replace vague risk with resolution:
```markdown
## Risks
- ~~<original risk description>~~ → **Resolved:** <one-line solution> (Step N)
```

## 5. Present Summary

```markdown
## Plan Risks Resolved

| # | Risk/Issue | Resolution | Step Updated |
|---|-----------|------------|--------------|
| 1 | <risk description> | <one-line solution> | Step N |
| 2 | <risk description> | <one-line solution> | New Step M |

**Issues resolved:** <count>
**Steps modified:** <count>
**Steps added:** <count>

### Next steps:
- `/dx-plan-validate` — re-validate the updated plan
- `/dx-step-all` — execute all steps
```

## Examples

1. `/dx-plan-resolve 2416553` — Reads implement.md risks ("Dynamic show/hide scoping in nested repeatable fields"), searches the codebase for existing repeatable field patterns, finds a working example in `card/config.xml`, and updates Step 4 with a concrete fix using scoped CSS classes.

2. `/dx-plan-resolve` (no argument) — Uses the most recent spec directory. Finds 2 risks and 1 vague step. Resolves all by adding specific file:line references and inserting a new Step 3b for risk mitigation. Updates the Risks section with strikethrough originals and resolution notes.

3. `/dx-plan-resolve 2416553` (no issues) — Reads implement.md, finds no risks, blocked steps, or vague instructions. Prints "No risks or issues to resolve — plan is ready." and stops.

## Troubleshooting

- **"No risks or issues to resolve"**
  **Cause:** The plan has no Risks section, no blocked steps, and no vague instructions.
  **Fix:** This is good — the plan is ready for execution. Run `/dx-step-all` to proceed.

- **Resolution references a file that doesn't exist**
  **Cause:** The codebase search found a pattern in a file that was since moved or deleted.
  **Fix:** Run `/dx-plan-validate` after resolving to verify file existence. Fix any invalid references manually in implement.md.

- **Step numbering is broken after inserting new steps**
  **Cause:** A new step was inserted but cross-references to step numbers weren't updated.
  **Fix:** Re-run `/dx-plan-validate` — it checks dependency order and will flag any broken cross-references.

## Rules

- **Research before solving** — don't guess at solutions. Find working examples in the codebase first.
- **Concrete fixes only** — every solution must include specific file paths, class names, or code snippets. "Consider using unique selectors" is not a fix. "`class='cmp-component__toggle--step2'`" is a fix.
- **Minimal plan changes** — prefer adding to existing steps over creating new ones. Only add a new step if the fix is substantial enough to warrant separate execution.
- **Preserve step numbering** — when inserting steps, renumber correctly and update any cross-references.
- **Don't execute** — update the plan only. Execution happens in step-* skills.
- **One pass** — resolve what you can, report what you can't. Don't loop.
