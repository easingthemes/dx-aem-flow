# Harness Self-Improvement — The 9→10 Gap

**Added:** 2026-06-16
**Verified:** 2026-06-16 — online research against big-company production evidence
**Context:** [2026-06-15-dev-agency-harness-review.md](2026-06-15-dev-agency-harness-review.md) rated us at 8/10 (Claude only). Reaching 9 is implementation completions. Reaching 10 is an architectural shift.

---

## Verification Status Per Pillar

| Pillar | Original proposal | After research | Confidence |
|--------|------------------|---------------|------------|
| Evals | Custom script, 5 skills, fixture folder | **Strengthened + revised** — Anthropic ships native skill evals (March 2026); use the platform, don't build from scratch | **High — proven in production** |
| Learning loop | PR comments → proposed rule diffs, human approves | **Validated with critical framing fix** — "release engineering for skills" not "self-improvement"; human gate is non-negotiable | **Medium — design is right, execution risk is real** |
| Pattern promotion | Cross-run clustering → proposed skills | **Downgraded** — cross-run agent memory fails in production (MemGPT, etc.); file-based + human-reviewed variant is viable but experimental, no major company has shipped it for coding agents | **Low — experimental only** |

---

## The Core Gap (unchanged)

At 9/10: the harness is correct, enforced, cross-platform. Stops improving when you stop editing it.

At 10/10: **running the harness also improves the harness.** Every ticket, PR review, and step failure feeds a loop. The system compounds.

---

## Pillar 1: Evals — VALIDATED AND REVISED

### The Proof Case

**The April 2026 Anthropic incident is the definitive argument for evals.** Three independent harness changes degraded Claude Code quality with no model change:

1. Default reasoning effort `high` → `medium` (March 4) — noticeably lower performance
2. Caching bug cleared conversation context repeatedly (March 26) — Claude appeared forgetful because it was losing information
3. System prompt length constraint (April 16) — measurably degraded coding output quality

None of these changed the model. All three passed review. All three shipped. Users noticed before Anthropic did. If a harness eval had run on every change to harness configuration, all three would have been caught before release.

Source: [dev.to — Claude Code didn't get worse. The harness did.](https://dev.to/practiceoverflow/claude-code-didnt-get-worse-the-harness-did-and-that-ends-one-of-the-most-common-ai-complaints-od5)

### What Big Companies Are Actually Shipping

**Anthropic (March 2026):** Native eval support in skill format. Skills now accept test cases with prompts, expected outputs, and pass/fail criteria. Built-in benchmark mode records pass rates, execution time, and token usage across your full eval set. Parallel multi-agent test execution (each in a clean context, no contamination). A/B testing with blind judging between skill versions.

This means: **Pillar 1 is not a build task — it's a configuration task.** The platform already ships the mechanism.

Source: [Claude Agent Skills Now Support Self-Testing and Benchmarks](https://zenvanriel.com/ai-engineer-blog/claude-agent-skills-software-testing-rigor/)

**TribeAI claude-evals (production reference):** Open-source eval framework for Claude Agent SDK. Ships with 50 calibrated test cases. Four grader types: exact match, regex, contains (deterministic) + LLM-as-judge with variance reduction (reruns if scores differ >0.2). Regression severity classification: CRITICAL (>20% regression), HIGH (>10%), MEDIUM (5-10%), LOW (<5%). $0.50/task budget ceiling. CI integration via GitHub Actions.

The 50-case starting point is independently validated by Anthropic's own guidance: "50 representative prompts with golden outputs is enough to start."

Source: [github.com/TribeAI/claude-evals](https://github.com/TribeAI/claude-evals)

**Microsoft ASSERT (Build 2026):** Policy-driven eval framework open-sourced at Build 2026. Generates evaluation scenarios from written specifications and governance documents — not generic benchmarks, but spec-derived cases. Works across LangChain, CrewAI, OpenAI, Anthropic. Outputs are fully inspectable locally (spec, generated cases, model outputs, judge rationale, metrics). Closed-loop: run ASSERT → apply controls → re-run → validate improvement with before/after metrics.

Source: [Microsoft Foundry Build 2026 — Open Trust Stack](https://devblogs.microsoft.com/foundry/build-2026-open-trust-stack-ai-agents/)

### Revised Implementation for dx-aem-flow

Don't build `run-evals.sh`. Use native Anthropic skill eval format + TribeAI claude-evals for Agent SDK testing.

**Phase 1 — Native skill evals (use existing platform):**
Write eval test cases in SKILL.md format for the top 5 skills:
- `dx-step` — does it produce the right file changes for known ticket patterns?
- `dx-step-verify` — does it correctly reject known failure patterns?
- `dx-plan` — does the decomposition match expected step count and scope?
- `aem-component` — does it touch the right files for a known component type?
- `dx-req` — does it extract the right structured fields from a raw story?

**Phase 2 — Agent SDK regression detection:**
Use TribeAI claude-evals structure: 50 golden cases, deterministic graders where possible, LLM judge (Haiku) for subjective quality. Run on every plugin change via CI. CRITICAL threshold at >20% regression blocks merge.

**Phase 3 — Microsoft ASSERT for policy coverage:**
Write ASSERT specs from `.ai/rules/` — the rules ARE the policy. Generate edge-case scenarios from rule content. Covers safety and constraint compliance that golden-case evals miss.

**Done-when:** Running evals on `dx-step` after changing `effort: high` → `effort: medium` in its frontmatter produces a measurable score delta. The April 2026 incident is not possible undetected.

---

## Pillar 2: Learning Loop — VALIDATED WITH CRITICAL FRAMING FIX

### What Failed (and Why Our Design Avoids It)

Research confirms: **autonomous self-improvement is the failure mode, not the goal.**

"Systems where agents write post-mortems and store conclusions for future runs are based on the idea that agents learn from mistakes and improve. However, for agents deployed in production workflows, unreliable improvement can be more damaging than no improvement at all."

"Uncontrolled drift: continuous self-modification without validation gates leads to performance degradation. Reward exploitation: agents optimizing for intermediate metrics rather than actual task quality."

Source: [MachineLearningMastery — The Practitioner's Guide to AgentOps](https://machinelearningmastery.com/the-practitioners-guide-to-agentops/)

### What Actually Works: Release Engineering for Skills

AgentDevel (arxiv 2601.04620) reframes self-evolving agents as release engineering — not continuous self-modification but structured release cycles with promotion criteria, staged rollout, and rollback. This is the validated model.

The distinction that makes our design viable:
- **Fails:** agent detects failure → agent writes new rule → agent commits it → next run uses it
- **Works:** agent detects failure → agent proposes rule diff → human reviews → human commits → next run uses it

Our human approval gate is not an optional safety measure — it IS the mechanism that makes the loop safe to run in production.

"Real software development systems improve because developers build external workflows around them: collecting logs, running tests, diagnosing failures, and releasing new versions only after they pass checks."

Source: [AgentDevel: Reframing Self-Evolving LLM Agents as Release Engineering](https://arxiv.org/pdf/2601.04620)

### Revised Framing

Don't call this a "learning loop." It's **skill release engineering** — the same discipline we apply to code, applied to the Markdown files that shape agent behavior.

**Source A — PR review comments:**

After a PR merges, scan the review thread for comments that were: (1) addressed with a code fix and (2) approved by the reviewer. These are confirmed gaps in the harness — the reviewer caught something the agent missed.

Extract as candidate rule additions. Surface as diffs to `.ai/rules/`. Human reviews, approves or rejects. On approval, commit with `chore(rules): <what changed and why>`. Evals (Pillar 1) run — confirm the rule actually helps, not hurts.

This is not the agent learning. This is a developer workflow tool that makes the improvement cycle faster and less likely to miss patterns.

**Source B — Step failure taxonomy:**

`dx-step-verify` writes structured failure records to `.ai/telemetry/failures.jsonl` on every rejection. Weekly, `dx-pattern-scan` groups by `reject_reason`, surfaces patterns appearing 3+ times. Proposed as additions to `dx-step-verify` criteria or `.ai/rules/`.

Again: proposal, human approval, eval gate, commit.

**Key constraint (non-negotiable):** Nothing auto-commits. The loop generates structured proposals; humans validate the lessons; evals confirm quality before merge. This is the release engineering model, not the self-improvement model.

**Done-when:** `dx-rule-learn scan --last-30-prs` produces at least one proposal diff for human review. Running evals before and after applying the proposal shows a measurable improvement or no regression.

---

## Pillar 3: Pattern Promotion — DOWNGRADED TO EXPERIMENTAL

### What Failed in Production

The research is clear: **cross-run agent memory has largely failed to deliver in production.**

"MemGPT's architecture having seen little actual use in production." Cross-run memory tiers (episodic, semantic, procedural) are theoretically appealing but practically fragile — agents drift, memory becomes stale or contradictory, retrieval is unreliable.

Source: [Towards Data Science — A Practical Guide to Memory for Autonomous LLM Agents](https://towardsdatascience.com/a-practical-guide-to-memory-for-autonomous-llm-agents/)

### Why Our Variant Is Different (But Still Unproven)

Our proposal is not agent memory. It's human-reviewed file promotion:

- Spec dir files are plain Markdown on disk, not a vector store
- Pattern detection is a weekly scan, not real-time agent inference
- Promoted patterns become versioned `references/` files or skills, not memory entries
- Every promotion requires human review before it affects any future run

This is closer to "developer runs a report and updates a library" than "agent updates its own memory." That distinction matters.

**But:** No major company has shipped this pattern for coding agents specifically. The research found general knowledge accumulation strategies (partner playbooks, domain blueprints) but not automated cross-ticket pattern promotion from spec dirs. This remains experimental.

### Revised Status

Keep the concept in the roadmap but do not build it until Pillars 1 and 2 are working. Reasons:

1. Without evals (Pillar 1), you can't verify that promoted patterns actually improve outcomes
2. Without the rule-learning loop (Pillar 2), you don't have the human-review workflow established
3. Pattern promotion is the highest-risk pillar — getting it wrong silently degrades every future ticket

**If pursued:** Start with a read-only reporting mode. `dx-pattern-report --last-30-days` produces a Markdown summary of recurring implementations for a human to read. No diff generation, no auto-proposal. Build intuition about whether the patterns are real before building the promotion machinery.

**Done-when (reporting phase):** `dx-pattern-report` produces a human-readable summary that a developer finds useful for deciding which patterns to manually extract into `references/`.

---

## Revised Implementation Order

| Step | What | Effort | Confidence | Pillar |
|------|------|--------|-----------|--------|
| 1 | Write native skill evals for top 5 skills (use Anthropic platform) | 3-5 days | High | 1 |
| 2 | `failures.jsonl` write from `dx-step-verify` | 2 days | High | 2 |
| 3 | CI eval gate via TribeAI claude-evals structure | 2 days | High | 1 |
| 4 | `dx-rule-learn scan` — extract PR review signal as proposals | 3 days | Medium | 2 |
| 5 | Human review workflow + eval gate on proposals | 2 days | Medium | 2 |
| 6 | `dx-pattern-report` — read-only cross-ticket summary | 3 days | Low | 3 |
| 7 | Pattern promotion to `references/` (only after step 6 proves value) | 1 week | Experimental | 3 |

Total to a real, validated learning system: ~3 weeks. Steps 1-5 are high-confidence. Steps 6-7 are experimental.

---

## What to Use Right Now (Exists Today)

| Tool | What it gives us | Status |
|------|-----------------|--------|
| Anthropic native skill evals | Per-skill test cases, benchmark mode, parallel execution, A/B testing | Ships in Claude Code / skill format; just write the test cases |
| TribeAI claude-evals | 50-case golden dataset, 4 grader types, CI regression detection | Open-source, production-ready |
| Microsoft ASSERT | Policy-driven eval generation from specs | Open-source, Build 2026 |
| AgentDevel release engineering model | Multi-stage gating, promotion criteria, rollback | Published model we can implement ourselves |

None of Pillar 1 requires building new infrastructure. The platform ships it. The gap is writing the test cases.

---

## Relationship to Existing TODOs

| TODO | Status | Connection | Change |
|------|--------|------------|--------|
| #1 (Layer 2 evals) | Open | Pillar 1 — but use native format, not custom script | Revised scope |
| #52 (continuous learning) | Open | Pillar 2 + 3 — reframe as "skill release engineering" | Reframed |
| #65 (iterative verify→fix loop) | Open | Pillar 1 signal source | Unchanged |
| #67 (externalized grading rubrics) | Open | Pillar 1 — judge model needs the rubric | Unchanged |
| #100 (OTel `skill_activated` event) | Open | Pillar 1 instrumentation | Unchanged |
| #143 (PR feedback → rule-set loop) | Open | Pillar 2 Source A — add eval gate before commit | Strengthened |
| #144 (agentic metrics roll-up) | Open | Pillar 1 + 2 telemetry | Unchanged |

---

## Sources

- [dev.to — Claude Code didn't get worse. The harness did.](https://dev.to/practiceoverflow/claude-code-didnt-get-worse-the-harness-did-and-that-ends-one-of-the-most-common-ai-complaints-od5) — April 2026 incident, definitive eval proof case
- [Claude Agent Skills Now Support Self-Testing and Benchmarks](https://zenvanriel.com/ai-engineer-blog/claude-agent-skills-software-testing-rigor/) — Anthropic native skill eval, March 2026
- [github.com/TribeAI/claude-evals](https://github.com/TribeAI/claude-evals) — production reference impl, 50 cases, CI
- [Microsoft Foundry Build 2026 — ASSERT](https://devblogs.microsoft.com/foundry/build-2026-open-trust-stack-ai-agents/) — policy-driven, open-source
- [AgentDevel: Reframing Self-Evolving LLM Agents as Release Engineering](https://arxiv.org/pdf/2601.04620) — validated model for safe skill improvement
- [MachineLearningMastery — AgentOps Guide](https://machinelearningmastery.com/the-practitioners-guide-to-agentops/) — autonomous self-improvement failure modes
- [Towards Data Science — Memory for Autonomous LLM Agents](https://towardsdatascience.com/a-practical-guide-to-memory-for-autonomous-llm-agents/) — MemGPT failure in production, memory tier problems
