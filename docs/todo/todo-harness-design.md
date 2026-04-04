# Harness Design Patterns for dx-aem-flow

Research based on Anthropic's [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) and [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).

**Added:** 2026-04-04

---

## Executive Summary

Anthropic's harness engineering articles describe patterns for making Claude effective across long, multi-session autonomous coding runs. The key insights are: (1) separate generation from evaluation (GAN-style), (2) use structured artifacts for cross-session handoff, (3) manage context proactively with resets over compaction, (4) decompose work into one-feature-at-a-time sprints, and (5) continuously simplify the harness as models improve.

**Our dx-aem-flow plugins already implement several of these patterns** — spec directory convention, `implement.md` status tracking, `context: fork` isolation, error taxonomy with retries, and coordinator/executor separation. But there are concrete gaps where adopting Anthropic's patterns would yield real improvement, especially for `dx-automation` agents running unattended for hours.

---

## Pattern-by-Pattern Analysis

### 1. Generator/Evaluator Separation (GAN-Style Loop)

**What Anthropic does:** Separate the agent that writes code (generator) from the agent that grades it (evaluator). The evaluator uses browser automation (Playwright) to test like a human user, grades against explicit criteria with hard thresholds, and returns actionable feedback. Tuning a standalone evaluator to be skeptical is far more tractable than making a generator critical of its own work.

**What we have today:**
- `dx-step-verify` (6-phase gate) runs in `context: fork` — acts as an evaluator
- `dx-code-reviewer` agent provides code review
- `dx-step-build` compiles/deploys/fixes in isolation
- But: the same agent often both implements AND self-verifies within `dx-step`

**Gap:** Our evaluator skills run _after_ implementation as a gate, not as an iterative feedback loop. There's no "fail → feedback → retry → re-evaluate" cycle between generator and evaluator the way Anthropic's sprint contracts work.

**Recommendation — Iterative QA loop in `dx-step-verify`:**

Add a feedback loop to `dx-step-verify` where, on failure, it writes structured feedback to `{spec-dir}/verify-feedback.md` and the coordinator re-invokes `dx-step-fix` with that feedback, then re-verifies. Cap at 2-3 cycles. This is partially implemented (dx-step-fix exists, max 3 fix cycles) but the feedback artifact isn't structured or persistent — it lives only in conversation context.

```
digraph verify_loop {
  "dx-step" -> "dx-step-verify";
  "dx-step-verify" -> "PASS" [label="all gates pass"];
  "dx-step-verify" -> "verify-feedback.md" [label="fail"];
  "verify-feedback.md" -> "dx-step-fix";
  "dx-step-fix" -> "dx-step-verify" [label="cycle < 3"];
  "dx-step-fix" -> "BLOCKED" [label="cycle >= 3"];
}
```

**Priority:** High for `dx-automation` (unattended), Medium for interactive use.

---

### 2. Sprint Contracts (Pre-Agreed Definition of Done)

**What Anthropic does:** Before each sprint, the generator proposes what it will build and how success will be verified. The evaluator reviews that proposal. They iterate until agreement. This bridges the gap between high-level spec and testable implementation.

**What we have today:**
- `implement.md` contains step-by-step plan with acceptance criteria
- `dx-plan-validate` checks plan quality
- But: verification criteria are baked into the plan, not negotiated between generator/evaluator agents

**Gap:** Verification criteria in `implement.md` are written by the planning agent only. There's no separate evaluator reviewing whether those criteria are actually testable or sufficient.

**Recommendation — Add `dx-plan-contract` phase:**

After `dx-plan` generates `implement.md`, invoke `dx-step-verify` (or a lightweight variant) in review-only mode to validate that each step has concrete, testable done-criteria. The verifier can flag steps with vague acceptance criteria ("works correctly") and require specifics ("API returns 200 with JSON body matching schema X").

This could be a new node in `dx-plan`'s flow or a standalone skill `dx-plan-contract` that reads `implement.md` and writes back a `contract.md` with agreed verification criteria per step.

**Priority:** Medium — most valuable for complex multi-step features.

---

### 3. Structured Progress File for Cross-Session Handoff

**What Anthropic does:** A `claude-progress.txt` file alongside git history lets each new session quickly understand what happened before. The progress file contains human-readable context: what was done last, what broke, what needs attention. JSON `feature_list.json` tracks all features with pass/fail status — JSON chosen because models are less likely to corrupt it than Markdown.

**What we have today:**
- `implement.md` with per-step Status field (pending/in-progress/done/blocked)
- `run-state.json` tracks orchestrator phase + started timestamp
- `dev-all-progress.md` — visual pipeline progress table
- `.ai/learning/fixes.md` — accumulated fix patterns
- Git commits with descriptive messages

**Gap:** We have the pieces but they're scattered across 4+ files. A new session (or a context reset in automation) must read multiple files to reconstruct state. There's no single "read this first" file.

**Recommendation — Add `{spec-dir}/progress.md` as the single handoff artifact:**

Create a consolidated progress file per work item that gets updated at each phase boundary. Structure:

```markdown
# Progress: WORK-1234 — Add user profile page

## Current State
Phase: Implementation (step 3 of 7)
Branch: feature/WORK-1234-user-profile
Last updated: 2026-04-04T14:30:00Z

## What's Done
- [x] Step 1: Create UserProfile component — PASS (commit abc123)
- [x] Step 2: Add API endpoint /api/profile — PASS (commit def456)
- [ ] Step 3: Wire up state management — IN PROGRESS

## What Broke / Needs Attention
- Step 2 introduced a TypeScript strict-mode warning in ProfileService.ts:42
- Test `profile.spec.ts` flaky on CI (timing issue)

## Next Actions
1. Complete step 3 state management wiring
2. Fix TS warning from step 2
3. Move to step 4: Add form validation
```

Each coordinator skill (`dx-agent-all`, `dx-step-all`) updates this file. Automation agents read it first on session start. This is essentially `claude-progress.txt` adapted to our spec-directory convention.

**Priority:** High for `dx-automation` (context resets between Lambda invocations are the norm), Medium for interactive.

---

### 4. Context Resets Over Compaction

**What Anthropic does:** Full context resets (clearing the window and starting fresh with structured handoff artifacts) outperform compaction for long tasks. Compaction preserves continuity but doesn't eliminate context anxiety. Resets provide a clean slate — at the cost of needing good handoff artifacts.

**What we have today:**
- `context: fork` on `dx-step-build` and `dx-step-verify` — effectively mini-resets
- Automation agents (`dx-automation`) run as Lambda-triggered pipelines — each invocation IS a context reset
- But: no structured handoff protocol between automation invocations

**Gap:** Our automation agents already get context resets (each Lambda invocation is fresh), but we don't have a standardized "startup protocol" that reads handoff artifacts. The agent just gets a prompt and starts working.

**Recommendation — Standardize automation agent startup protocol:**

Add a preamble to all `dx-automation` agent prompts:

```markdown
## Session Startup Protocol
1. Read `{spec-dir}/progress.md` (if exists) — understand current state
2. Read recent git log (last 10 commits on feature branch)
3. Check `run-state.json` for stale state (>2 hours = likely crashed)
4. Read `implement.md` for step status
5. Determine next action based on state
```

This maps directly to Anthropic's "coding agent" startup sequence. The key insight: don't just read the ticket — read the _progress artifacts_ first.

**Priority:** High — directly improves automation agent reliability.

---

### 5. Feature List as JSON (Not Markdown)

**What Anthropic does:** Track features in `feature_list.json` with structured status. JSON is harder for models to accidentally corrupt than Markdown checkboxes. 200+ features, each with category, description, test steps, and pass/fail status.

**What we have today:**
- `implement.md` uses Markdown with `**Status:** pending` text fields
- Models occasionally garble the status markers or lose steps during edits

**Gap:** Markdown-based status tracking is fragile. Models can accidentally rewrite steps, change numbering, or corrupt status fields during edits.

**Recommendation — Consider `implement.json` alongside `implement.md`:**

Keep `implement.md` as the human-readable plan, but add a parallel `implement-status.json` for machine-readable step tracking:

```json
{
  "workItemId": "WORK-1234",
  "totalSteps": 7,
  "steps": [
    {"id": 1, "status": "done", "commit": "abc123", "verifiedAt": "2026-04-04T14:30:00Z"},
    {"id": 2, "status": "done", "commit": "def456", "verifiedAt": "2026-04-04T14:45:00Z"},
    {"id": 3, "status": "in-progress", "startedAt": "2026-04-04T15:00:00Z"},
    {"id": 4, "status": "pending"},
    {"id": 5, "status": "pending"},
    {"id": 6, "status": "pending"},
    {"id": 7, "status": "pending"}
  ]
}
```

Skills read status from JSON (reliable), write plan details in Markdown (readable). This separation of concerns matches the article's finding that JSON is more resistant to model corruption.

**Priority:** Medium — biggest value for long plans (7+ steps) where Markdown corruption risk is highest.

---

### 6. Grading Criteria for Subjective Quality

**What Anthropic does:** Turn subjective judgments ("is this design good?") into concrete, gradable dimensions with hard thresholds. Four criteria: Design Quality, Originality, Craft, Functionality. Weight criteria that the model struggles with more heavily.

**What we have today:**
- `dx-pr-review` has structured review criteria (correctness, security, performance, maintainability)
- `dx-step-verify` has 6 phases with pass/fail gates
- `aem-inspector` checks AEM-specific quality patterns
- But: criteria are implicit in agent prompts, not externalized as configurable rubrics

**Gap:** Review criteria are hardcoded in skill/agent prompts. Teams can't customize what "quality" means for their project without editing plugin files.

**Recommendation — Externalize grading rubrics to `.ai/rules/`:**

Create `.ai/rules/code-quality-rubric.md` (generated by `/dx-init`) that defines project-specific grading criteria:

```markdown
# Code Quality Rubric

## Dimensions (scored 1-5)

### Correctness (threshold: 4)
Does the implementation match the acceptance criteria exactly?
Failing: missing edge cases, partial implementation, stubbed functionality.

### Security (threshold: 5, blocking)
No secrets, no injection vectors, no auth bypass.
Any score below 5 blocks the PR.

### Maintainability (threshold: 3)
Readable code, reasonable abstractions, follows project conventions.

### Performance (threshold: 3)
No obvious N+1 queries, no blocking I/O in hot paths.
```

Skills like `dx-step-verify` and `dx-pr-review` read this file and grade against it. Teams customize thresholds per project. This mirrors how Anthropic calibrated their evaluator with few-shot examples.

**Priority:** Medium — valuable for teams with specific quality bars.

---

### 7. One-Feature-at-a-Time Decomposition

**What Anthropic does:** Agents work on exactly one feature per sprint. This prevents context exhaustion and enables clean git rollback if a feature fails.

**What we have today:**
- `dx-step` already implements one-step-at-a-time execution
- `dx-step-all` iterates through steps sequentially
- Each step gets its own commit

**Assessment:** **We already do this well.** Our step-by-step implementation with per-step commits maps directly to Anthropic's one-feature-at-a-time pattern. No changes needed.

---

### 8. Browser Automation for End-to-End Testing

**What Anthropic does:** Agents must test like human users — Playwright/Puppeteer for clicking through the UI, not just unit tests. Without explicit prompting to use browser automation, agents verify code changes but skip end-to-end functionality.

**What we have today:**
- `aem-inspector` uses Chrome DevTools MCP for browser-based AEM verification
- `aem-verify` checks author/publish rendering
- `dx-step-verify` runs compile + lint + test but NOT browser-based E2E

**Gap:** For non-AEM projects, `dx-step-verify` has no browser automation. It verifies code-level correctness but not runtime behavior.

**Recommendation — Add optional E2E gate to `dx-step-verify`:**

Add a Phase 5.5 "E2E Smoke Test" to `dx-step-verify` that:
1. Checks if `config.yaml` has an `e2e` section (test runner, base URL)
2. If present, runs the configured E2E test command
3. If browser MCP is available, performs basic smoke navigation

This should be opt-in via config, not mandatory. Many projects don't need it.

```yaml
# .ai/config.yaml
e2e:
  enabled: true
  command: "npx playwright test"
  base-url: "http://localhost:3000"
```

**Priority:** Low for now — AEM projects already have this via `aem-inspector`. Relevant when dx-core is used for frontend projects.

---

### 9. Harness Simplification as Models Improve

**What Anthropic does:** Every harness component encodes an assumption about what the model can't do alone. These assumptions expire as models improve. With Opus 4.6, they dropped sprints, context resets, and contract negotiation entirely — the model handled it natively.

**What we have today:**
- Model tier strategy (Opus/Sonnet/Haiku) with skill-level `model:` frontmatter
- But: harness complexity doesn't adapt to model capability

**Recommendation — Add model-conditional harness paths:**

In coordinator skills, check the active model and simplify the pipeline accordingly:

```markdown
## Model-Aware Pipeline
- If running on Opus: skip `dx-plan-validate` (Opus plans are reliable enough)
- If running on Haiku: enforce mandatory `dx-plan-validate` + `dx-plan-contract`
- If running on Sonnet: use default pipeline
```

This maps to Anthropic's principle: "re-examine the harness when a new model lands, stripping away pieces no longer load-bearing."

**Priority:** Low — interesting for future-proofing but not urgent.

---

## Implementation Roadmap

### Phase 1 — Quick Wins (can ship now)

| # | Change | Effort | Impact |
|---|--------|--------|--------|
| A | Add `{spec-dir}/progress.md` — single handoff artifact | Small | High |
| B | Standardize automation agent startup protocol | Small | High |
| C | Write structured `verify-feedback.md` from dx-step-verify failures | Small | Medium |

### Phase 2 — Medium-Term (1-2 sprints)

| # | Change | Effort | Impact |
|---|--------|--------|--------|
| D | Iterative verify→fix→re-verify loop (cap 3 cycles) | Medium | High |
| E | `implement-status.json` for machine-readable step tracking | Medium | Medium |
| F | Externalized grading rubrics in `.ai/rules/code-quality-rubric.md` | Medium | Medium |

### Phase 3 — Future Exploration

| # | Change | Effort | Impact |
|---|--------|--------|--------|
| G | `dx-plan-contract` — evaluator reviews plan testability | Medium | Medium |
| H | Optional E2E browser gate in dx-step-verify | Medium | Low |
| I | Model-conditional pipeline simplification | Small | Low |

---

## What We Already Do Well

Worth noting — the dx-aem-flow plugins already implement several patterns that Anthropic independently arrived at:

1. **One-feature-at-a-time** — `dx-step` / `dx-step-all` sequential execution
2. **Spec directory convention** — file-based state, skills discover each other's output by convention
3. **Context isolation** — `context: fork` on build/verify skills = mini context resets
4. **Error taxonomy** — TRANSIENT/VALIDATION/PERMANENT classification with retry logic
5. **Coordinator/executor separation** — `-all` skills orchestrate, leaf skills execute
6. **Config-driven** — no hardcoded values, everything from `config.yaml`
7. **Learning from failures** — `.ai/learning/fixes.md` accumulates patterns

The article validates these design choices. The main gaps are in **structured handoff artifacts**, **iterative feedback loops**, and **externalized grading criteria**.

---

## Sources

- [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) — Prithvi Rajasekaran, Anthropic Labs, Mar 24 2026
- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — Justin Young, Anthropic, Nov 2025
- [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — Anthropic Engineering
