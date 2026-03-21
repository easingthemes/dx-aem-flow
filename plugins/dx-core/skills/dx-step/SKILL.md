---
name: dx-step
description: Execute the next pending step from the implementation plan. Reads implement.md, finds the first pending step, implements it, verifies compilation, and updates the status. Use to execute steps one at a time.
argument-hint: "[Work Item ID or slug (optional — uses most recent if omitted)]"
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You execute the next pending step from implement.md — read the instructions, implement the changes, verify compilation, and mark the step done.

## Flow

```dot
digraph step {
    "Locate spec directory" [shape=box];
    "Find next step" [shape=diamond];
    "All done" [shape=doublecircle];
    "Step status?" [shape=diamond];
    "Mark in-progress" [shape=box];
    "Execute the step" [shape=box];
    "Verify compilation" [shape=box];
    "Verification passed?" [shape=diamond];
    "Classify error" [shape=diamond];
    "TRANSIENT: Retry" [shape=box];
    "Retry passed?" [shape=diamond];
    "VALIDATION: Auto-fix" [shape=box];
    "Auto-fix passed?" [shape=diamond];
    "Mark done + present summary" [shape=doublecircle];
    "Mark blocked + present summary" [shape=doublecircle];

    "Locate spec directory" -> "Find next step";
    "Find next step" -> "All done" [label="none pending"];
    "Find next step" -> "Step status?" [label="found"];
    "Step status?" -> "Mark in-progress" [label="pending"];
    "Step status?" -> "Execute the step" [label="in-progress (resume)"];
    "Step status?" -> "Find next step" [label="blocked (skip)"];
    "Mark in-progress" -> "Execute the step";
    "Execute the step" -> "Verify compilation";
    "Verify compilation" -> "Verification passed?";
    "Verification passed?" -> "Mark done + present summary" [label="yes"];
    "Verification passed?" -> "Classify error" [label="no"];
    "Classify error" -> "TRANSIENT: Retry" [label="TRANSIENT"];
    "Classify error" -> "VALIDATION: Auto-fix" [label="VALIDATION"];
    "Classify error" -> "Mark blocked + present summary" [label="PERMANENT"];
    "TRANSIENT: Retry" -> "Retry passed?";
    "Retry passed?" -> "Mark done + present summary" [label="yes"];
    "Retry passed?" -> "Mark blocked + present summary" [label="no"];
    "VALIDATION: Auto-fix" -> "Auto-fix passed?";
    "Auto-fix passed?" -> "Mark done + present summary" [label="yes"];
    "Auto-fix passed?" -> "Mark blocked + present summary" [label="no"];
}
```

## Node Details

### Locate spec directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir $ARGUMENTS)
```

Read `implement.md` from `$SPEC_DIR`.

### Find next step

Parse implement.md and find the first step with `**Status:** pending`.

If a step has `**Status:** in-progress`, it was interrupted — route to "Step status?" with `in-progress`.

If a step has `**Status:** blocked`, skip it and find the next pending step. Print: "Skipping Step N (blocked). Executing Step M instead."

### All done

1. Check if implement.md has an `**Other repos required:**` line. If so, print:
   ```
   > Cross-repo: This plan covers <current repo> only. Switch to <other repo(s)> and run `/dx-req-all <id>` there.
   ```
2. Print: "All steps are done. Run `/dx-pr` to create a pull request."
3. STOP.

### Step status?

Route based on the step's current status:
- **pending** → go to "Mark in-progress"
- **in-progress** → go to "Execute the step" (resume interrupted step)
- **blocked** → go back to "Find next step" (skip and find next pending)

### Mark in-progress

Update the step's status in implement.md:
```
**Status:** in-progress
```

### Execute the step

Read the step's full instructions:
- **Files** — which files to modify or create
- **What** — specific instructions for changes
- **Why** — requirement being addressed (for context)

Implement the changes:
- Read each file listed in **Files** before modifying it
- Follow the **What** instructions precisely
- **Before creating any new utility, helper, or abstraction:** search the codebase (`commons/`, `utils/`, `shared/`, `lib/`, `scripts/libs/`, `mixins/`) for existing implementations. If one exists, use it instead of creating new code. If `research.md` exists in the spec directory, check its "Existing Implementation Check" section for reusable code.
- Use Edit tool for modifications, Write tool for new files
- Follow project conventions — read `.claude/rules/` for rules matching the file types being modified (e.g., `fe-javascript.md` for JS, `fe-styles.md` for SCSS). If `.github/instructions/` exists, also read the relevant instruction file for framework-specific patterns. For AEM frontend work involving modals, overlays, or focus traps, check if `shared/aem-dom-rules.md` exists (dx-aem plugin) and follow its DOM constraints.

**Test-first approach:**

If the step has a `Test:` line and `superpowers:test-driven-development` is available, invoke it to guide the RED-GREEN-REFACTOR cycle.

**Fallback (if superpowers not installed):** When a step includes tests:
1. **RED:** Write/locate the test first. Run it — confirm it fails (proves the test validates something).
2. **GREEN:** Write the minimal implementation to pass the test. No extras (YAGNI).
3. **REFACTOR:** Clean up only after green — duplication, naming, structure — while staying green.

If a test passes immediately before any code change, the test isn't validating new behavior — fix it.

### Verify compilation

Run the step's **Test** command if specified. Otherwise, read the build command from `.ai/config.yaml` `build.command` and run a compile check (not full build):

If the project uses Maven: `mvn compile -pl <module> -q`
If the project uses npm: `npm run build`
Otherwise: use whatever compile/typecheck command is configured.

### Verification passed?

- **yes** — compilation/test exits 0 → go to "Mark done + present summary"
- **no** — error detected → go to "Classify error"

### Classify error

Classify the error against the taxonomy in `shared/error-handling.md`:
- **TRANSIENT** → go to "TRANSIENT: Retry"
- **VALIDATION** → go to "VALIDATION: Auto-fix"
- **PERMANENT** → go to "Mark blocked + present summary"

### TRANSIENT: Retry

Retry the command (up to 2 times). If still failing, go to "Mark blocked + present summary".

### Retry passed?

- **yes** — retry succeeded → go to "Mark done + present summary"
- **no** — still failing after retries → go to "Mark blocked + present summary"

### VALIDATION: Auto-fix

Attempt ONE auto-fix (syntax fix, missing import, lint fix). Re-run verification. Do NOT attempt more than one auto-fix.

### Auto-fix passed?

- **yes** — fix + verify passes → go to "Mark done + present summary"
- **no** — fix fails or verify still fails → go to "Mark blocked + present summary"

### Mark done + present summary

Update implement.md:
```
**Status:** done
```

Print:
```markdown
## Step N complete: <step title>

**Files modified:** <list>
**Compilation:** passed
**Next:** Step <N+1> — <title> (or "All steps done")

Run `/dx-step-test` to run tests, `/dx-step-review` to review changes, or `/dx-step` for the next step.
```

### Mark blocked + present summary

Update implement.md:
```
**Status:** blocked
```

Include the error category, message, and suggested action. Print the summary with the failure details.

## Success Criteria

- [ ] Target step status updated: pending → done (or blocked with reason)
- [ ] If done: compilation/build command exits 0
- [ ] If done: files modified match step's `**Files:**` list
- [ ] implement.md updated in-place (no corruption of other steps)

## Examples

### Execute next step
```
/dx-step 2435084
```
Finds the first pending step in `implement.md`, marks it `in-progress`, implements the code changes, verifies compilation, marks it `done`.

### Resume interrupted step
```
/dx-step 2435084
```
If a step is `in-progress` (from a previous interrupted run), resumes it instead of starting the next pending step.

### All steps complete
```
/dx-step 2435084
```
If no pending steps remain, prints "All steps are done. Run `/dx-pr` to create a pull request."

## Troubleshooting

### Step marked blocked after compilation failure
**Cause:** The implemented code doesn't compile, and the one auto-fix attempt also failed.
**Fix:** Run `/dx-step-fix` to diagnose and fix the error, or manually fix and reset the status to `pending` in `implement.md`.

### Step creates a new helper instead of reusing existing one
**Cause:** The step instructions in `implement.md` say "create new" when an existing utility would work.
**Fix:** Fix `implement.md` first — update the step's What instructions to reference the existing code. Then re-run `/dx-step`.

### "No implement.md found"
**Cause:** Planning hasn't been done yet.
**Fix:** Run `/dx-plan <id>` to generate the implementation plan first.

## Decision Examples

### Fixable Error (VALIDATION)
**Error:** `error TS2304: Cannot find name 'HeroProps'`
**Classification:** VALIDATION / SYNTAX — missing import
**Action:** Add `import { HeroProps } from './hero.types'`, re-run compilation
**Outcome:** Fixed. Mark step done.

### Unfixable Error (PERMANENT)
**Error:** `bash: mvn: command not found`
**Classification:** PERMANENT / MISSING_DEPENDENCY
**Action:** Do NOT attempt fix. Mark step blocked: "Maven not installed on this machine."

### Ambiguous Error (needs classification)
**Error:** `ECONNREFUSED 127.0.0.1:4502`
**Classification:** TRANSIENT / TIMEOUT — AEM is not running
**Action:** Retry once (AEM may be starting). If still failing → mark blocked: "AEM instance not available."

## Rules

- **One step at a time** — execute exactly one step, then stop. Let the coordinator or user decide what's next.
- **Read before writing** — always read a file before editing it. Never blindly edit.
- **Follow conventions** — read `.claude/rules/` and `.github/instructions/` (if it exists) for the relevant file types before writing code. For AEM modal/overlay work, also check `shared/aem-dom-rules.md`.
- **Don't improvise** — implement exactly what the step says. If instructions are unclear, mark the step blocked with a note rather than guessing.
- **Update status immediately** — mark in-progress before starting, done/blocked when finished. This is the state machine that coordinators rely on.
- **Compile check is mandatory** — never mark a step done without verifying compilation passes.
