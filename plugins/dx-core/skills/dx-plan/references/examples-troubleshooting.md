# dx-plan — examples and troubleshooting

## Examples

### Standard planning flow
```
/dx-plan 2416553
```
Reads `.ai/specs/2416553-add-layout-switcher/explain.md` and `research.md`, generates `implement.md` with 6 steps covering model changes, dialog updates, HTL template, JS logic, SCSS, and tests. All steps start as `pending`.

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
