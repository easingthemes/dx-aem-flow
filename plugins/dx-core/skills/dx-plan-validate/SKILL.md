---
name: dx-plan-validate
description: Cross-check the implementation plan against requirements. Verifies every requirement has a step, no unrequested features snuck in, and dependencies flow correctly. Use after /dx-plan and before /dx-step.
when_to_use: "Use to cross-check an implementation plan against requirements. Trigger on 'validate plan', 'check the plan', 'plan-validate', 'is the plan complete', or between /dx-plan and /dx-step."
argument-hint: "[Work Item ID or slug (optional — uses most recent if omitted)]"
context: fork
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You cross-check implement.md against explain.md to verify the plan is complete, correct, and ready for execution.

Use ultrathink for this skill — careful cross-referencing benefits from deep reasoning.

## Output

You run in a forked context. Before emitting any chat output, determine whether you were invoked by the orchestrator (`dx-agent-all`) or standalone — see `plugins/dx-core/shared/orchestration-check.md`:

```bash
ORCHESTRATED=0
FLAG=".ai/run-context/orchestrating.flag"
if [ -f "$FLAG" ]; then
  AGE=$(( $(date +%s) - $(date -r "$FLAG" +%s) ))
  [ "$AGE" -lt 7200 ] && ORCHESTRATED=1
fi
```

- **If `$ORCHESTRATED == 1`** (orchestrator path): write the full report to `$SPEC_DIR/validation-report.md` and emit ONLY the `## Return` block to chat.
- **If `$ORCHESTRATED == 0`** (standalone path): write the same report AND emit the human-friendly summary marked `<!-- standalone-only -->` below, followed by the `## Return` block at the very end.

Per-phase progress lines during the run are allowed in both paths.

This skill writes its full report to `$SPEC_DIR/validation-report.md` (overall verdict, per-requirement mapping, reuse check, warnings). The orchestrator reads this file only on demand.

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

## 3. Write Validation Report

**Write** the following table and overall verdict to `$SPEC_DIR/validation-report.md`. Do not print to chat.

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

## Present Summary (standalone path only)

<!-- standalone-only — emit only when $ORCHESTRATED == 0 -->

When running standalone, emit the validation table to chat:

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

### Next step:
<If PASS or WARN:> - `/dx-step-all` — execute the plan
<If FAIL:> - `/dx-plan-resolve` — fix flagged issues, then re-validate
```

When orchestrated (`$ORCHESTRATED == 1`), skip this section entirely and emit only the `## Return` block.

## Return

This skill runs in a forked context. It MUST end with a `## Return` block per `plugins/dx-core/shared/skill-return-contract.md`.

Examples:

```markdown
## Return
verdict: pass
summary: All 9 requirements covered by 4 plan steps; no scope creep; reuse check clean.
artifacts:
  - .ai/specs/2490722-microsite/validation-report.md
next_action: continue to Phase 2.5 (feature branch)
```

```markdown
## Return
verdict: warn
summary: Plan covers all reqs but has 2 non-blocking warnings (no test infra; 2 open PO questions).
artifacts:
  - .ai/specs/2490722-microsite/validation-report.md
next_action: continue (warnings non-blocking) or run /dx-plan-resolve
```

```markdown
## Return
verdict: fail
summary: Requirement #5 (test coverage) has no corresponding plan step.
artifacts:
  - .ai/specs/2490722-microsite/validation-report.md
next_action: run /dx-plan-resolve
```
