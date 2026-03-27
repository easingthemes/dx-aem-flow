---
name: dx-plan-validate
description: Cross-check the implementation plan against requirements. Verifies every requirement has a step, no unrequested features snuck in, and dependencies flow correctly. Use after /dx-plan and before /dx-step.
argument-hint: "[Work Item ID or slug (optional — uses most recent if omitted)]"
---

You cross-check implement.md against explain.md to verify the plan is complete, correct, and ready for execution.

Use ultrathink for this skill — careful cross-referencing benefits from deep reasoning.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir $ARGUMENTS)
```

Read from `$SPEC_DIR`:
- `explain.md` (required)
- `implement.md` (required)
- `research.md` (if exists — for file existence verification)

If either explain.md or implement.md is missing, print which is missing and STOP.

## 2. Validation Checks

Run these checks sequentially using extended thinking:

### Check 1: Requirement Coverage
For each numbered requirement in explain.md, find at least one step in implement.md that addresses it.

Report:
- ✅ Requirement N — covered by Step X
- ❌ Requirement N — NOT covered by any step

### Check 2: No Scope Creep
For each step in implement.md, verify it maps to at least one requirement in explain.md.

Report:
- ✅ Step N — implements Requirement X
- ⚠️ Step N — not directly tied to a requirement (flag for review)

### Check 3: Dependency Order
Verify steps are in valid execution order:
- Does any step reference files that a later step creates?
- Does any step depend on changes from a later step?

Report:
- ✅ Dependency order is valid
- ❌ Step N depends on Step M, but N comes before M

### Check 4: File Existence
If research.md is available, verify files referenced in implement.md actually exist (for "Modify" actions) or that their parent directories exist (for "Create" actions).

Report:
- ✅ All referenced files verified
- ❌ Step N references `path/to/file` — not found in codebase

### Check 5: Testing Coverage
Verify the testing plan covers the key changes:
- Each step with `**Test:**` has a valid test command or approach
- New functionality has unit tests planned

Report:
- ✅ Test coverage adequate
- ⚠️ Step N has no test specified

### Check 6: Reuse Check
If research.md has an "Existing Implementation Check" section, cross-reference it against implement.md:
- For each requirement marked ✅ (fully covered by existing code): verify the plan reuses that code, not creates new
- For each requirement marked ⚡ (partially covered): verify the plan extends existing code, not duplicates it
- Flag any step that creates a new utility, helper, service, or component when research.md shows an existing one covers the need

If research.md doesn't have the section, scan implement.md for "Create new" steps and verify no existing equivalent was missed by checking the codebase (quick Grep for similar names/patterns).

Report:
- ✅ Plan properly reuses existing code
- ❌ Step N creates new `<thing>` but existing `<path>` already provides this functionality
- ⚠️ Step N creates new code — verify no existing equivalent exists

## 3. Present Validation Report

```markdown
## Plan Validation: <Title>

| Check | Result | Details |
|-------|--------|---------|
| Requirement Coverage | ✅/❌ | <N>/<total> covered |
| No Scope Creep | ✅/⚠️ | <N> steps without requirement mapping |
| Dependency Order | ✅/❌ | <details if issues> |
| File Existence | ✅/❌ | <N> files verified |
| Testing Coverage | ✅/⚠️ | <details> |
| Reuse Check | ✅/❌/⚠️ | <N> reuse opportunities verified |

**Overall: PASS / FAIL / PASS WITH WARNINGS**

<If FAIL — list specific issues that must be fixed>
<If PASS WITH WARNINGS — list items to review but not blocking>
<If PASS — "Plan is ready for execution.">

### Next steps:
<If PASS:>
- `/dx-step` — execute first step
- `/dx-step-all` — execute all steps autonomously
<If FAIL:>
- Fix issues in implement.md and re-run `/dx-plan-validate`
```

## Examples

1. `/dx-plan-validate 2416553` — Cross-checks implement.md against explain.md for story #2416553. Reports that all 5 requirements are covered, no scope creep detected, dependency order is valid, and test coverage is adequate. Verdict: PASS.

2. `/dx-plan-validate` (no argument) — Uses the most recent spec directory. Finds that Requirement 3 has no corresponding step in implement.md and Step 7 references a file that doesn't exist. Verdict: FAIL with specific issues listed.

3. `/dx-plan-validate 2416553` (after plan-resolve) — Re-validates the updated plan. Confirms previously flagged risks are now resolved, all requirements are covered, and the reuse check passes. Verdict: PASS.

## Troubleshooting

- **"explain.md or implement.md not found"**
  **Cause:** The required spec files haven't been generated yet.
  **Fix:** Run `/dx-req <id>` and `/dx-plan <id>` first to generate both files.

- **False "scope creep" warnings on infrastructure steps**
  **Cause:** Steps like "set up test fixtures" or "update build config" don't map directly to a numbered requirement.
  **Fix:** These are flagged as warnings, not failures. Review them — infrastructure steps are legitimate and don't block execution.

- **Reuse check flags a "create new" step incorrectly**
  **Cause:** The existing utility found by the check has a similar name but different functionality.
  **Fix:** Review the flagged step and the existing code. If the existing code doesn't cover the need, proceed — the flag is advisory.

## Rules

- **Both files required** — can't validate without both explain.md and implement.md
- **Be strict on coverage** — every requirement MUST have a step. Missing coverage is a FAIL.
- **Be lenient on scope creep** — infrastructure steps (setup, testing) are legitimate even without a direct requirement mapping. Only flag clearly unrequested features.
- **Don't fix — report** — this skill reports issues, it does not modify implement.md
- **Fast feedback** — print results clearly so the developer can decide whether to fix or proceed
