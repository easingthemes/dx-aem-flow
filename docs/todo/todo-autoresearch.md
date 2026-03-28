# Autoresearch Loop Pattern — Detailed Plan

Inspired by [Karpathy's AutoResearch](https://github.com/karpathy/autoresearch) (March 2026): an autonomous experiment loop that proposes changes, verifies mechanically, keeps improvements, reverts failures, and repeats until a goal is reached.

Adapted for dx-aem-flow: the "metric" is **requirement alignment** — does the code match what the ticket specifies? The loop verifies against ticket requirements (not just "does it compile"), reverts on drift, and keeps an attempt log so the agent never repeats a failed approach.

## Phase 1: Shared Pattern Reference

**Added:** 2026-03-28
**Problem:** 10+ skills need the same loop pattern (attempt log, revert rules, drift detection, configurable limits). Without a shared reference, each skill will implement it differently, creating inconsistency and maintenance burden.
**Scope:** `plugins/dx-core/shared/autoresearch-loop.md` (new file)
**Done-when:** File exists at `plugins/dx-core/shared/autoresearch-loop.md` AND contains sections for: attempt log format, revert rules, drift detection, configurable retry limits, requirement-aware verification. At least 2 skills reference it via `shared/autoresearch-loop.md`.

**Approach:**

Create `plugins/dx-core/shared/autoresearch-loop.md` defining:

### 1. Attempt Log Format
```
.ai/specs/<id>-<slug>/autoresearch-log.md
```
Table format:
| # | Timestamp | Skill | Change | Metric Before | Metric After | Verdict | Reverted | Notes |
Each iteration appends a row. Agent MUST read this log before proposing a new change.

### 2. Revert Rules
- After each change, run verification
- If verification fails OR metric worsened → `git revert HEAD --no-edit`
- If verification passes but requirement drift detected → revert + log "drift"
- Never revert across multiple commits — each iteration is one atomic commit

### 3. Drift Detection
- After a fix passes mechanical checks (build, test, lint), re-read the original requirement (from `raw-story.md`, `explain.md`, or step's **What** field)
- Compare: does the change still align with what was asked?
- Drift signals: changed files outside step scope, added unrequested features, modified unrelated tests, altered behavior not mentioned in requirements

### 4. Configurable Retry Limits
- Default: `autoresearch.max-iterations: 5` in `.ai/config.yaml`
- Per-skill override via frontmatter: `max-iterations: N`
- Hard ceiling: 10 (safety net — never infinite)
- Early exit: if 3 consecutive reverts with same error category → stop, report

### 5. Requirement-Aware Verification
- Level 1: Mechanical (build, test, lint) — same as today
- Level 2: Spec alignment (does change match step's **What** + **Files**?)
- Level 3: Ticket alignment (does cumulative work match `raw-story.md` acceptance criteria?)
- Skills choose which levels to run (step-fix uses L1+L2, agent-all uses L1+L2+L3)

---

## Phase 2: Upgrade Existing Loop Skills

### 2a. `dx-step-fix` — Configurable retries + requirement-aware verify

**Added:** 2026-03-28
**Problem:** Currently tries 1 direct fix then escalates to heal steps. The single attempt often fails on complex issues where a second or third approach would succeed. No memory of what was tried — heal steps can repeat the same failed approach.
**Scope:** `plugins/dx-core/skills/dx-step-fix/SKILL.md`
**Done-when:** `dx-step-fix` SKILL.md references `shared/autoresearch-loop.md`, has configurable retry limit (default 3), writes attempt log entries to `autoresearch-log.md`, and checks step's **What** field after fix (not just build).

**Changes:**
- Replace hardcoded "one fix attempt" with configurable loop (default 3)
- After each fix: verify build AND re-check against step's **What** spec
- Log each attempt to `autoresearch-log.md` with change description + result
- Read attempt log before proposing — never repeat a failed approach
- Revert on drift (fix compiles but doesn't match step spec)
- Only escalate to heal after exhausting configured retries

### 2b. `aem-fe-verify` — Add revert-on-drift + attempt log

**Added:** 2026-03-28
**Problem:** Has 3-iteration fix loop but no memory between iterations. Iteration 3 can repeat iteration 1's failed approach. No revert mechanism — bad fixes accumulate. Verifies against visual only, not ticket requirements.
**Scope:** `plugins/dx-aem/skills/aem-fe-verify/SKILL.md`
**Done-when:** `aem-fe-verify` SKILL.md references `shared/autoresearch-loop.md`, writes attempt log, reverts failed fix attempts before trying next approach, and cross-checks visual fixes against ticket requirements (not just Figma match).

**Changes:**
- Add attempt log writes (what was changed, screenshot diff result)
- Read attempt log before each iteration — avoid repeating failed approaches
- Git revert after failed fix before trying next approach (clean slate)
- After visual match passes, cross-check against ticket requirements for drift
- Make iteration limit configurable (default stays 3)

### 2c. `dx-bug-fix` — Attempt memory for plan revision

**Added:** 2026-03-28
**Problem:** When plan attempt 1 fails and plan is revised for attempt 2, there's no structured record of WHY attempt 1 failed. The revised plan can make the same mistake.
**Scope:** `plugins/dx-core/skills/dx-bug-fix/SKILL.md`
**Done-when:** `dx-bug-fix` SKILL.md references `shared/autoresearch-loop.md`, logs each plan attempt with failure reason, and requires revised plans to explicitly address why prior attempt failed.

**Changes:**
- Log attempt 1 result to `autoresearch-log.md` before revising plan
- Revised plan (attempt 2) must reference attempt 1's failure and explain different approach
- Add configurable attempt limit (default 2, can raise to 3)

### 2d. `dx-agent-dev` — Verify against RE spec, not just build

**Added:** 2026-03-28
**Problem:** Self-check repair loop (max 2) only checks compilation + tests + lint. A fix can pass all mechanical checks but drift from the RE spec (e.g., hardcoded values, wrong component hierarchy, missing fields from requirements).
**Scope:** `plugins/dx-core/skills/dx-agent-dev/SKILL.md`
**Done-when:** `dx-agent-dev` SKILL.md has a spec-alignment check after mechanical self-check passes: re-reads RE spec tasks and verifies each task's deliverables are present in the code. Writes attempt log for repair iterations.

**Changes:**
- After self-check passes (compile + test + lint), add Level 2 verification: read RE spec tasks, verify each task's expected files/changes exist
- Log repair attempts to `autoresearch-log.md`
- On spec drift: revert repair, try different approach

### 2e. `dx-agent-all` — Outer requirement alignment after healing

**Added:** 2026-03-28
**Problem:** Healing cycles (build fix 6x + review heal 2x) can accumulate drift. After 8 potential fix iterations, the code may pass build + review but no longer match the original ticket requirements.
**Scope:** `plugins/dx-core/skills/dx-agent-all/SKILL.md`
**Done-when:** After Phase 4.5-heal completes, `dx-agent-all` performs Level 3 verification: re-reads `raw-story.md` acceptance criteria and checks cumulative code changes against them. If drift detected, logs to `autoresearch-log.md` and stops (does not auto-fix at orchestrator level).

**Changes:**
- Add Level 3 check after healing cycle completes
- Re-read `raw-story.md` + `explain.md` acceptance criteria
- Compare against cumulative diff (`base..HEAD`)
- If aligned → proceed to AEM phases
- If drifted → log, stop, report (human decision needed)

---

## Phase 3: Add Loops to Single-Pass Skills

### 3a. `aem-verify` — Fix gaps + re-verify loop

**Added:** 2026-03-28
**Problem:** Currently single-pass: reports dialog/field gaps but never fixes them. User must manually fix and re-run. For simple gaps (missing field config, wrong property value), the agent could fix and re-verify.
**Scope:** `plugins/dx-aem/skills/aem-verify/SKILL.md`
**Done-when:** `aem-verify` SKILL.md has an optional `--fix` flag that enables a fix-verify loop (max 3 iterations). Without `--fix`, behavior is unchanged (report only). With `--fix`: identifies fixable gaps → applies fix → re-verifies → keeps or reverts.

**Changes:**
- Add `--fix` flag (default: off, report-only preserved)
- Classify each gap: auto-fixable (wrong property value, missing field config) vs needs-human (architectural issue, missing dependency)
- Fix loop: fix one gap → re-verify → if improved, keep → next gap
- Git revert on regression (fix broke something else)
- Log to `autoresearch-log.md`
- Max 3 iterations, early exit if only needs-human gaps remain

### 3b. `aem-qa` — Auto-fix simple bugs + re-QA loop

**Added:** 2026-03-28
**Problem:** Reports bugs but waits for human Dev to fix. Simple bugs (wrong CSS class, missing null check, typo in property name) could be auto-fixed and re-verified, reducing QA-Dev cycle time.
**Scope:** `plugins/dx-aem/skills/aem-qa/SKILL.md`
**Done-when:** `aem-qa` SKILL.md has auto-fix capability for bugs classified as "simple" (severity: minor, clear fix path). Complex bugs still reported for human Dev. Fix attempts logged to `autoresearch-log.md`. Max 2 QA-fix-QA cycles for auto-fixes.

**Changes:**
- After bug discovery, classify: simple (auto-fixable) vs complex (needs human)
- Simple bugs: auto-fix → rebuild → re-deploy → re-QA (same checks)
- Complex bugs: report as today (no change)
- Log auto-fix attempts to `autoresearch-log.md`
- Max 2 auto-fix QA cycles, then report remaining

### 3c. `dx-plan-validate` + `dx-plan-resolve` — Validate-resolve loop

**Added:** 2026-03-28
**Problem:** Currently linear: validate once → resolve once. If resolve introduces new issues or doesn't fully address validation warnings, there's no re-check. Plan goes to execution with undetected problems.
**Scope:** `plugins/dx-core/skills/dx-plan-validate/SKILL.md`, `plugins/dx-core/skills/dx-plan-resolve/SKILL.md`, `plugins/dx-core/skills/dx-agent-all/SKILL.md` (Phase 2 orchestration)
**Done-when:** `dx-agent-all` Phase 2 runs validate → resolve → re-validate loop (max 2 cycles). If re-validate is clean → proceed. If still has warnings after 2 cycles → proceed with warnings logged.

**Changes:**
- In `dx-agent-all` Phase 2: after resolve, re-run validate
- If clean → proceed to execution
- If warnings remain → resolve again (cycle 2)
- If still warnings after cycle 2 → proceed but log warnings to `autoresearch-log.md`
- No changes to validate/resolve skills themselves — loop is in orchestrator

### 3d. `dx-req-dod` — Loop until DoD score threshold

**Added:** 2026-03-28
**Problem:** Auto-fix pass runs once then posts. Some auto-fixes create conditions for OTHER criteria to pass (e.g., generating test stubs enables test coverage criterion). A second pass would catch these cascading improvements.
**Scope:** `plugins/dx-core/skills/dx-req-dod/SKILL.md`
**Done-when:** `dx-req-dod` SKILL.md runs auto-fix → re-evaluate loop (max 2 cycles). Stops early if score doesn't improve between cycles. Logs each cycle to `autoresearch-log.md`.

**Changes:**
- After auto-fix pass 1: re-evaluate score
- If score improved AND still has auto-fixable failures → run pass 2
- If score didn't improve → stop (no point in another cycle)
- Max 2 auto-fix cycles
- Log score progression to `autoresearch-log.md`

---

## Phase 4: `dx-autoresearch` Orchestrator Skill (Future)

**Added:** 2026-03-28
**Problem:** Phases 2-3 add loops to individual skills. A top-level orchestrator would wrap the full pipeline (plan → execute → verify → fix) in a single goal-directed loop, running until all acceptance criteria are met or max iterations exhausted.
**Scope:** `plugins/dx-core/skills/dx-autoresearch/SKILL.md` (new skill)
**Done-when:** Skill exists, can be invoked with a work item ID, runs the full pipeline in a loop with requirement-aware verification between phases, and produces a final `autoresearch-log.md` with complete experiment history.

**Approach:**
- Wraps `dx-agent-all` phases in an outer loop
- After each full pass: Level 3 verification against ticket
- If gaps found: identify which phase needs re-running (plan? step? verify?)
- Re-run only the needed phase, not the whole pipeline
- Max iterations: configurable, default 3 full passes
- This is the "full autoresearch" experience — Phases 1-3 are prerequisites

---

## Implementation Priority

| Phase | Effort | Impact | Dependency |
|-------|--------|--------|------------|
| Phase 1 (shared pattern) | Small | Foundation | None |
| Phase 2a (dx-step-fix) | Medium | High — most common failure point | Phase 1 |
| Phase 2b (aem-fe-verify) | Medium | High — visual verification is error-prone | Phase 1 |
| Phase 2e (dx-agent-all) | Small | High — catches drift at orchestrator level | Phase 1 |
| Phase 2c (dx-bug-fix) | Small | Medium | Phase 1 |
| Phase 2d (dx-agent-dev) | Small | Medium | Phase 1 |
| Phase 3a (aem-verify) | Medium | Medium | Phase 1 |
| Phase 3c (validate+resolve) | Small | Medium | Phase 1 |
| Phase 3d (dx-req-dod) | Small | Low-Medium | Phase 1 |
| Phase 3b (aem-qa) | Large | Medium — requires rebuild+redeploy in loop | Phase 1 |
| Phase 4 (orchestrator) | Large | High — full autoresearch experience | Phases 1-3 |

## References

- [karpathy/autoresearch](https://github.com/karpathy/autoresearch) — Original 630-line autonomous ML experiment loop
- [uditgoenka/autoresearch](https://github.com/uditgoenka/autoresearch) — Claude Code skill adaptation (generalized to any domain)
- [Fortune: Karpathy's autonomous AI research agent](https://fortune.com/2026/03/17/andrej-karpathy-loop-autonomous-ai-agents-future/)
- [DataCamp Guide to AutoResearch](https://www.datacamp.com/tutorial/guide-to-autoresearch)
