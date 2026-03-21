---
name: dx-step-review
description: Review code changes for the current step against the plan and project conventions. Checks if changes match the plan, follow conventions, and have no obvious bugs. Use after /dx-step and /dx-step-test.
argument-hint: "[Work Item ID or slug (optional — uses most recent if omitted)]"
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You review the code changes made during the current step, comparing them against the implementation plan and project conventions.

Use ultrathink for this skill — code review benefits from deep reasoning about correctness.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir $ARGUMENTS)
```

Read from `$SPEC_DIR`:
- `implement.md` — find the most recently completed step (last `**Status:** done`)
- `explain.md` — for requirement context

## 2. Get the Diff

Run `git diff` to see uncommitted changes. If no uncommitted changes, run `git diff HEAD~1` to see the last commit's changes.

Also read the modified files in full for broader context.

## 3. Review Against Plan

For the current step from implement.md:
- Do the changes match what the step described?
- Are all files listed in **Files:** actually modified?
- Are there changes to files NOT listed in the step?

## 4. Review Against Conventions

Check the changes against project conventions. Reference `.claude/rules/` for the specific convention rules applicable to the changed file types. If `.github/instructions/` exists, also read the relevant instruction file for deeper framework patterns (e.g., `fe.javascript.instructions.md` for JS changes).

If no project rules exist, fall back to these generic checks:
- Naming conventions (consistent with project style)
- Framework patterns (correct use of annotations, decorators, etc.)
- Interface/implementation separation where expected
- Template patterns (correct data binding, no inline scripts)
- Test patterns (proper setup, meaningful assertions)

## 5. Check for Bugs

Look for common issues:
- Null pointer risks (unchecked optionals, missing null checks)
- Resource leaks (unclosed handles)
- Hardcoded paths or values that should be configurable
- Missing imports
- Incorrect property names (mismatch between config and code)

## 6. Present Review

```markdown
## Code Review: Step <N> — <title>

**Verdict:** ✅ APPROVED / ⚠️ APPROVED WITH NOTES / ❌ CHANGES REQUESTED

### Plan Compliance
<✅ or list of deviations>

### Convention Check
<✅ or list of violations>

### Bug Check
<✅ or list of issues>

<If CHANGES REQUESTED:>
### Required Changes
1. <specific change with file and line reference>
2. <specific change>

### Next steps:
<If APPROVED:> `/dx-step-commit` to commit changes
<If CHANGES REQUESTED:> `/dx-step-fix` to address issues, then re-review
```

## Success Criteria

- [ ] Review verdict is one of: APPROVED, APPROVED WITH NOTES, or CHANGES REQUESTED
- [ ] Every finding has a severity (critical/warning/note) and file location
- [ ] Diff reviewed matches the current step's changes (not stale)

## Examples

### Review after step completion
```
/dx-step-review 2435084
```
Finds the last completed step, diffs the changes, checks against plan instructions and project conventions. Reports verdict: APPROVED, APPROVED WITH NOTES, or CHANGES REQUESTED.

### Review catches convention violation
```
/dx-step-review 2435084
```
If the step added a hardcoded color instead of using an SCSS variable (per `.claude/rules/fe-styles.md`), reports: "CHANGES REQUESTED — use `$primary-color` from `_variables.scss` instead of `#FF0000`."

## Troubleshooting

### "No changes found"
**Cause:** Changes were already committed, or no files were modified.
**Fix:** The skill falls back to `git diff HEAD~1` to review the last commit. If that's also empty, there's nothing to review.

### Review flags issues in code not changed by this step
**Cause:** The diff includes unrelated changes.
**Fix:** This is a bug in the review — the skill should only review changes from the current step. The rule "Focused on this step" applies.

## Rules

- **Never switch branches or stash** — review happens on the current branch. Use `git diff` and `git diff HEAD~1` only. Never `git stash`, `git checkout`, or `git switch`.
- **Evidence-based** — every issue must reference a specific file, line, or convention
- **No style nitpicking** — only flag real issues (bugs, convention violations, plan deviations). Don't request changes to existing code that wasn't part of this step.
- **Focused on this step** — only review changes from the current step, not the entire codebase
- **Actionable feedback** — each issue must clearly state what needs to change
- **Be strict on conventions** — if the project has explicit rules in `.claude/rules/`, enforce them. This project's conventions are authoritative.
