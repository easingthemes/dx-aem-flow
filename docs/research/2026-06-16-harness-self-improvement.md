# Harness Self-Improvement — The 9→10 Gap

**Added:** 2026-06-16
**Context:** [2026-06-15-dev-agency-harness-review.md](2026-06-15-dev-agency-harness-review.md) rated us at 8/10 (Claude only) after disregarding easy fixes. Reaching 9 is implementation completions. Reaching 10 is an architectural shift.

---

## The Core Gap

At 9/10: the harness is correct, enforced, and cross-platform. Skills are well-structured. Hooks enforce behavior. Recovery is resumable. It stops improving the moment you stop editing it.

At 10/10: **running the harness also improves the harness.** Every ticket run, every PR review, every step failure is an input to a feedback loop. The system compounds.

Three capabilities close that gap. They build on each other — evals first (you can't improve what you can't measure), then learning loop (fold signals back in), then pattern promotion (scale wins across tickets).

---

## Pillar 1: Evals — Measure Your Own Quality

### The Problem

Right now there is no way to answer:
- Did the last model upgrade improve or regress dx-step outcomes?
- Which skill fails most often, and on what ticket types?
- If I rewrite `dx-plan`, how do I know the new version is better?

Every improvement is anecdotal. You ship a skill change and hope it's better. There's no regression detection, no baseline, no signal.

### What's Needed

A lightweight eval framework that runs skills against fixed inputs and scores outputs. Not a full ML pipeline — a folder of fixtures and a scoring script.

**Structure:**
```
.ai/evals/
├── dx-step/
│   ├── fixture-01-simple-dialog.md      # input: ticket + implement.md
│   ├── fixture-01-expected.md           # expected: what a good step does
│   └── fixture-01-score.sh             # grades actual vs expected (0-100)
├── dx-plan/
│   └── ...
└── run-evals.sh                         # runs all fixtures, outputs scores.json
```

**Scoring approach:** Binary checks (did it touch the right files? did it compile? did verify pass?) combined with a rubric-graded LLM evaluation using a cheap judge model (Haiku). The judge reads expected vs actual and scores against externalized criteria in `.ai/rules/code-quality-rubric.md` (TODO #67).

**Regression gate:** `run-evals.sh --compare baseline.json` fails if any skill score drops >5 points. Run in CI on every plugin change.

**What this enables:** Every other pillar depends on having a score. Without evals, you don't know if the learning loop is actually learning or drifting.

**TODO:** #1 (Layer 2) has been open since 2026-03-21. It has the right structure (10 prompt files, `--quick/--full` modes). What's missing is the scoring layer and the comparison gate.

**Done-when:** `bash .ai/evals/run-evals.sh --quick` produces a `scores.json` with per-skill scores; `--compare baseline.json` exits non-zero on regression.

---

## Pillar 2: Learning Loop — Failures and PR Feedback Fold Back In

### The Problem

When a reviewer leaves the same comment for the 4th time ("don't use inline styles in AEM components"), nothing happens. The agent makes the same mistake on the next ticket. The knowledge lives in someone's head, not in the harness.

When `dx-step-verify` rejects a step, that failure is logged but never analyzed. The agent retries, maybe succeeds, and the failure disappears. The harness doesn't learn that a certain step pattern is fragile.

### What's Needed

A loop that surfaces recurring signals as proposed rule changes, then waits for human approval before committing them.

**Two signal sources:**

**Source A — PR review comments** (extends TODO #143 `dx-rule-learn`):

After a PR is merged, `dx-pr-review` scans its review thread and extracts comments that were addressed (reviewer approved the fix). These are candidate rules — the reviewer identified a problem the harness missed.

```
PR #42: "AEM dialogs must use granite:data, not data-* attributes" (addressed, approved)
PR #47: Same comment, same fix
PR #51: Same comment, same fix

→ Proposed rule: .ai/rules/aem-dialog-conventions.md §3
  "MUST use granite:data for custom data attributes in AEM dialogs. MUST NOT use data-* HTML attributes."
```

The proposal is written as a diff to the relevant `.ai/rules/` file. A human reviews it with `dx-rule-learn review` and approves or rejects. On approval, `git commit` with a `chore(rules):` message.

**Source B — step failure patterns** (new):

`dx-step-verify` writes a structured failure record to `.ai/telemetry/failures.jsonl` on every rejection:
```json
{"ts":"2026-06-16T00:00:00Z","skill":"dx-step","step":3,"reject_reason":"missing_null_check","files":["src/components/Dialog.java"]}
```

A weekly `dx-pattern-scan` skill reads `failures.jsonl`, groups by `reject_reason`, and surfaces patterns that appear 3+ times as proposed additions to `.ai/rules/` or `dx-step-verify` criteria.

**Key constraint:** Nothing auto-commits. Every proposed change is a human-reviewable diff. The loop generates proposals; humans approve. This is the right boundary — the harness learns from data, humans validate the lessons.

**What this enables:** The harness permanently encodes knowledge that today lives in reviewer comments and repeated retries. After 6 months of operation, `.ai/rules/` is a distillation of everything your team has learned, not just what someone remembered to write down on day one.

**Done-when:** `dx-rule-learn scan` reads the last 30 merged PRs and produces at least one proposed rule diff for human review.

---

## Pillar 3: Pattern Promotion — Wins Scale Across Tickets

### The Problem

Every ticket is an island. If the same AEM dialog fix appears across 8 tickets this month, nobody notices. The agent re-derives the same solution each time. Knowledge never compounds.

We have the spec directory convention and context graphs (TODOs #75-80 Done) for within-ticket context. What's missing is cross-ticket intelligence.

### What's Needed

A skill that reads across spec dirs, spots recurring implementations, and proposes them as reusable skills or `references/` entries.

**Pattern detection:**

`dx-pattern-promote` runs as a periodic skill (weekly, or after N tickets close):

1. Reads all `implement.md` files in `.ai/specs/` from the last 30 days
2. Groups code changes by file pattern, component type, and implementation approach
3. Surfaces clusters where 3+ tickets made structurally similar changes
4. For each cluster: generates a draft skill or `references/` snippet that captures the pattern

```
Cluster detected: 6 tickets added the same i18n key validation boilerplate to AEM servlets.
→ Proposed: plugins/dx-aem/shared/aem-servlet-i18n-pattern.md
→ Reference to add in dx-step: "Check .shared/aem-servlet-i18n-pattern.md for i18n key validation"
```

**Promotion path:**
- Low-confidence patterns → note in `.ai/learning/patterns.md` (informational, no action)
- Medium-confidence → proposed `shared/` reference file for human review
- High-confidence (5+ tickets, same files, same structure) → proposed new skill for human review

**The flywheel:** Each promoted pattern reduces average turns-per-ticket for that class of change. After 12 months of operation, dx-aem skills encode the team's accumulated domain knowledge, not just generic AEM patterns from seed data.

**Relationship to existing work:**
- TODO #78 (cross-ticket pattern promotion) is marked **Done** in the context graphs work — but that was for decision-node patterns in structured YAML. This is for implementation patterns in actual code changes.
- `dx-pattern-extract` skill exists but reads single-ticket context graphs. Needs a cross-ticket mode.

**Done-when:** `dx-pattern-promote --last-30-days` produces at least one proposed skill or reference file from real ticket history; the proposal is a reviewable diff, not auto-committed.

---

## How the Three Pillars Connect

```
Run ticket
    │
    ├── Step failure → failures.jsonl ──────────────────┐
    │                                                    │
    ├── PR merged → review comments extracted ──────────┤
    │                                                    ▼
    └── implement.md written ──────────┐        Learning loop (Pillar 2)
                                       │        "3+ instances of X pattern"
                                       │                │
                                       ▼                ▼
                               Pattern promotion   Proposed rule diff
                               (Pillar 3)         for human review
                               "6 tickets did Y"         │
                                       │                 │
                                       └────────┬────────┘
                                                │
                                        Human approves
                                                │
                                    Skills / rules updated
                                                │
                                    Evals run (Pillar 1)
                                    "Did quality improve?"
                                                │
                                      Baseline updated if yes
                                      Alert if regression
```

Evals are the signal. The learning loop and pattern promotion are the actuators. Without evals, you don't know if the loop is making things better or worse.

---

## What This Is NOT

- **Not autonomous.** Every proposed change waits for human approval. No auto-commits.
- **Not a model fine-tune.** All improvements are to skills, rules, and references — plain Markdown. Any agent on any platform picks them up.
- **Not expensive.** Evals use Haiku as a judge. Learning loop runs once per merged PR. Pattern promotion runs weekly. Total added cost is low.
- **Not dependent on a specific Claude version.** The patterns work on any model; better models just surface better proposals.

---

## Implementation Order

Do these in sequence — each one enables the next.

| Step | What | Effort | Unlocks |
|------|------|--------|---------|
| 1 | Eval fixtures + scoring for top 5 skills | 1 week | Regression detection, baseline |
| 2 | `failures.jsonl` write from `dx-step-verify` | 2 days | Signal source for learning loop |
| 3 | `dx-rule-learn scan` from PR comments | 3 days | First proposals from real data |
| 4 | `dx-pattern-promote --last-30-days` | 1 week | Cross-ticket compounding |
| 5 | Eval gate in CI on plugin changes | 1 day | Regression protection |

Total: ~3 weeks of focused work.

---

## Relationship to Existing TODOs

| TODO | Status | Connection |
|------|--------|------------|
| #1 (Layer 2 evals) | Open | Pillar 1 — add scoring + comparison gate |
| #52 (continuous learning) | Open | Pillar 2 + 3 — this doc is the concrete design |
| #65 (iterative verify→fix loop) | Open | Pillar 1 signal source |
| #67 (externalized grading rubrics) | Open | Pillar 1 — judge model needs the rubric |
| #100 (OTel `skill_activated` event) | Open | Pillar 1 instrumentation |
| #143 (PR feedback → rule-set loop) | Open | Pillar 2, Source A — this doc specs the missing piece |
| #144 (agentic metrics roll-up) | Open | Pillar 1 + 2 — telemetry feeds proposals |

No new TODOs needed — the existing items cover the work. What was missing was the connecting design that shows how they form a system rather than isolated features.
