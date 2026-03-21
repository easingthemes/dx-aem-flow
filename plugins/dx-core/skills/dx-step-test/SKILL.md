---
name: dx-step-test
description: Run tests and report results. Executes the project's test command and parses the output into a pass/fail summary. Use after /dx-step to verify changes.
argument-hint: "[Work Item ID or slug (optional — uses most recent if omitted)]"
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You run the test suite and report results in a structured format.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir $ARGUMENTS)
```

Read `implement.md` from `$SPEC_DIR` to find the current step and its test command.

## 2. Determine Test Command

Find the most recently completed step (last step with `**Status:** done`) and check its **Test:** line.

If the step specifies a test command, use it.

If no specific test is specified, read the test command from `.ai/config.yaml` `build.test`. If not configured, try common patterns:
- Maven: `mvn test -pl <module>`
- npm: `npm test`
- Other: whatever is in the project's test configuration

## 3. Run Tests

Execute the test command with a 5-minute timeout.

## 4. Parse Results

From the test output, extract:
- **Tests run:** total count
- **Failures:** count
- **Errors:** count
- **Skipped:** count
- **Time elapsed:** total time
- **Failed test details:** for each failure, extract the test name and assertion message

## 5. Present Report

```markdown
## Test Results

**Command:** `<command run>`
**Result:** ✅ PASS / ❌ FAIL

| Metric | Count |
|--------|-------|
| Tests run | <N> |
| Passed | <N> |
| Failed | <N> |
| Errors | <N> |
| Skipped | <N> |
| Time | <N>s |

<If failures:>
### Failures

**<TestClass#testMethod>**
\```
<assertion error message, max 10 lines>
\```

### Next steps:
<If PASS:> `/dx-step-review` to review changes, or `/dx-step-commit` to commit
<If FAIL:> `/dx-step-fix` to diagnose and fix failures
```

## Success Criteria

- [ ] Test command exits with code 0
- [ ] Zero failing tests in parsed output
- [ ] Test report printed with pass/fail/skip counts

## Examples

### Run tests after step
```
/dx-step-test 2435084
```
Finds the last completed step's test command, runs it, parses output into a pass/fail summary table.

### No test command specified
```
/dx-step-test 2435084
```
Falls back to `build.test` from `.ai/config.yaml` (e.g., `mvn test`). Runs the full test suite and reports results.

## Troubleshooting

### Tests hang (timeout after 5 minutes)
**Cause:** Test is waiting for user input, a network resource, or a deadlocked thread.
**Fix:** Investigate which test hangs — check if it requires a running service (e.g., AEM instance). Kill and re-run with `-Dtest=SpecificTest` to isolate.

### "Zero tests found"
**Cause:** Test command ran but found no test classes matching the module.
**Fix:** Check the test command — it may target the wrong module or path. Verify `build.test` in `.ai/config.yaml`.

## Rules

- **Just run and report** — don't analyze failures or suggest fixes. That's step-fix's job.
- **Include full failure details** — the error messages are critical for step-fix.
- **Timeout at 5 minutes** — if tests hang, report timeout and suggest investigating.
- **Always report** — even if zero tests were found, report that clearly.
