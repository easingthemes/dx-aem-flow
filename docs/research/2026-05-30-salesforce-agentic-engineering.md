# Salesforce "Agentic Engineering" — What We Can Learn / Reuse

**Date:** 2026-05-30
**Source:** [How Salesforce Engineering Became Truly Agentic](https://www.salesforce.com/news/stories/how-engineering-became-agentic/)
(primary URL 403s for automated fetch; corroborated via
[The Decoder coverage](https://the-decoder.com/salesforce-claims-ai-agents-cut-a-231-day-migration-to-13-days-with-fewer-incidents/)
and Salesforce search snippets, May 2026).

**Why this doc exists:** Salesforce published a first-party account of moving their
*entire* engineering org to agentic development on Claude Code. The striking finding
is how much of what they describe we have **already built** in dx-aem-flow — and the
one or two ideas they have that we don't. This captures the comparison so the team
doesn't re-derive it, and seeds the follow-up TODOs.

---

## TL;DR

1. **We already match or lead them** on rule-based markdown frameworks, subagent
   teams, autonomous build→fix→validate loops, structural guardrails, and
   dev-as-orchestrator. Our confidence gates + durable recovery + three-layer override
   system are *more rigorous* than what the article describes.
2. **The one idea clearly worth importing:** their compounding gains came from
   **automatically folding every round of PR-review feedback back into the rule set**,
   so the next run starts smarter. We have all the pieces (`dx-pr-answerer`,
   `.ai/rules/pr-review.md`, the override system) but the learning loop is **manual**
   today. → TODO #143.
3. **Second:** they led with *numbers* (an ML-based "Effective Output" score). We have
   the raw telemetry (audit logs, `confidence.json`, spec dirs) but no aggregation. A
   metrics roll-up would let us prove the guardrails-improve-quality thesis on our own
   platform and tune gate thresholds with data. → TODO #144.

---

## What Salesforce reported

**Rollout & scale**
- Deliberate org-wide pivot to **Claude Code** as the primary agent tool; rolled out
  to all engineers; **token limits removed** to drive adoption.

**Practices**
- **Rule-based framework on Claude** = Markdown rule files + reference implementations
  to standardize AI-automated work (e.g. a migration).
- **Every round of PR feedback is incorporated back into the rule set** → accuracy
  improves continuously and outputs arrive "near production-ready." *(This is the
  load-bearing idea.)*
- **Subagents & agent teams** — scoped agents handling parallel workstreams; engineers
  **describe outcomes** while coordinated agents figure out the steps.
- **Autonomous build → fix → validate loops** run with no manual intervention,
  parallelized across **isolated environments**.

**Headline metrics (April 2026 vs April 2025)**
- Work items completed / developer: **+50.8%**
- PRs merged / developer: **+79%**
- ML-based "Effective Output" score: **+151.3% YoY**
- **Incidents −5%** despite the PR surge → guardrails baked structurally into the flow.

**Case study**
- Migrate **33 API endpoints** to cloud-native architecture: traditional estimate
  **231 person-days → 13 days (18×)**, delivered as **5 PRs** (largest = 21 endpoints
  with full test coverage).

**Culture / skills**
- Developers become **orchestrators of agent teams**.
- The emerging core skill: *"knowing how to structure problems for an agentic system,
  when to delegate versus stay in the loop, and how to build reusable patterns your
  team can compound on."*

**Open problems they admit**
- Context management in long sessions.
- **Variable quality of persistent config files (CLAUDE.md).**
- Security risk from broader agent autonomy.
- Junior-engineer growth paths in an automation-heavy environment.

---

## Point-by-point vs dx-aem-flow

| Salesforce practice | Our equivalent | Verdict |
|---|---|---|
| Rule-based markdown framework + reference impls | **Three-layer override system** (`.ai/rules/*.md` > `config.yaml overrides:` > plugin `rules/*.md`), shared by local skills *and* Lambda agents | **Ahead** — layered + config-driven + platform-agnostic |
| PR feedback folded back into rule set (compounding) | `dx-pr-answerer` + `.ai/rules/pr-{review,answer}.md` exist, but the feedback→rules loop is **manual** | **Gap → TODO #143** |
| Subagents & agent teams, parallel workstreams | `/dx-req` fans out 3 subagents; `/dx-simple` Phase 2 dispatches page-finder + inspector + file-resolver concurrently | Match |
| Autonomous build→fix→validate loops, isolated envs | `/dx-step-all` loop; SimpleAgent 7-phase flow w/ compile retries; DevAgent end-to-end; `isolation: worktree` | Match |
| Guardrails structural → incidents down despite PR surge | SimpleAgent **9 confidence gates (G1–G9)**, `dx-step-verify` 6-phase, branch-guard hooks, scope caps (≤5 files / ≤50 lines / ≤10 JCR writes), cost/time gates (G8 ≤$2, G9 ≤12min), `audit.sh` | **Ahead** — ours are explicit & quantified |
| Devs as orchestrators | Coordinator-skill pattern; main context stays lean (~30 turns) | Match |
| Org-wide rollout, no token limits | Cross-platform delivery (Claude Code, Copilot CLI, VS Code, Cursor, Windsurf) from one codebase | Match in spirit |
| ML "Effective Output" metric | Raw telemetry exists (`confidence.json`, audit logs, spec dirs) but **no aggregation** | **Gap → TODO #144** |

### Their open problems — our status

| Salesforce open problem | dx-aem-flow status |
|---|---|
| Long-session context management | **Solved structurally** — spec-dir convention + state checkpointing (`resume-state.json`, `work-plan.json`); Git is the memory; coordinators keep context lean |
| Variable CLAUDE.md/config quality | **Partial** — enforced via `validate-structure.sh`, `dx-init` generation, no-hardcode rule; no *quality scoring* of generated rules |
| Security risk from agent autonomy | **Solved** — confidence gates, scope caps, cost/time gates, audit logging, conditional rollback |
| Junior-engineer growth paths | Out of scope (org/cultural) |

---

## Recommendations (→ TODOs)

1. **Close the PR-feedback → rule-set loop** (`dx-rule-learn`). Highest leverage; it is
   *their* killer feature and we have all the parts. Distill recurring PR-review
   comments into human-approved additions to `.ai/rules/*.md`. → **TODO #143**.
   Cross-ref the related "continuous learning / instinct system" idea (#52,
   `todo-ecc-ideas.md`) — #143 is the narrower, PR-scoped, human-gated cut of it.
2. **Agentic-metrics roll-up.** Aggregate existing telemetry into per-agent success
   rate, gate-abort reasons, cost/time per ticket, PRs/ticket. Lets us tune thresholds
   with data and tell the same numbers-driven story. → **TODO #144**.
3. **Positioning: "orchestration is the skill."** Lift their narrative into `website/`
   docs; our human-re-trigger recovery (`@kai-simple` reply resumes a blocked run) is a
   concrete, honest "when to stay in the loop" story. → **TODO #145**.
4. **Batch/parallel migrations via worktree fan-out.** Their 18× win leaned on splitting
   one job into 5 PRs across isolated environments. Point DevAgent + `isolation:
   worktree` at *batch* component migrations rather than one ticket at a time; per-ticket
   branch state store already makes fan-out safe. → **TODO #146**.

---

## Sources
- Salesforce — [How Engineering Became Agentic](https://www.salesforce.com/news/stories/how-engineering-became-agentic/)
- The Decoder — [AI agents cut a 231-day migration to 13 days with fewer incidents](https://the-decoder.com/salesforce-claims-ai-agents-cut-a-231-day-migration-to-13-days-with-fewer-incidents/)
