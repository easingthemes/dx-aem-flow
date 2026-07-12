# TODO — Recursive Language Models (RLM)

Background: [2026-07-12-recursive-language-models.md](../research/2026-07-12-recursive-language-models.md)

## RLM deep-dive research — training, frameworks, and workflow patterns

**Added:** 2026-07-12
**Problem:** Initial sweep (2026-07-12 research doc) established what RLMs are and that our coordinators are "RLM-shaped" but not RLM-disciplined. Open questions the sweep did not answer: (1) how the official `alexzhang13/rlm` library is actually driven from Claude Code (it advertises this) and whether it composes with plugin skills; (2) what the v3 paper revision (May 2026) changed vs. v1; (3) whether Prime Intellect's `verifiers`/`prime-rl` RL-training story matters for API-model consumers like us or only for people fine-tuning; (4) how RLM relates to Microsoft CodeAct (#158) — same "reason in code" family, potentially one eval covers both; (5) concrete failure modes (inefficient exploration code, recursion depth 1) and which of our phases they'd bite.
**Scope:** `docs/research/` (new dated doc), `docs/todo/todo-rlm.md` (this file — update findings), cross-refs into `todo-subagent-improvements.md` (#47/#49) and `2026-06-15-microsoft-codeact.md` (#158).
**Done-when:** A follow-up `docs/research/2026-*-rlm-deep-dive.md` exists that answers all 5 numbered questions above, each with a source link or a hands-on test note, and ends with a go/no-go recommendation for the implementation item below.
**Approach:** Clone and run `alexzhang13/rlm` against a real long-context task from this repo (e.g. a >500-line skill audit or a full `docs/todo/` sweep); diff paper v1 vs v3 abstracts/changelogs; read the ADK integration write-up for the parallelism + lazy-loading patterns.

## RLM-pattern implementation — never-read-raw rule for coordinators + spec-dir as answer store

**Added:** 2026-07-12
**Problem:** Coordinator skills (`dx-agent-all`, `dx-bug-all`, `dx-pr-review`) read large artifacts (big PR diffs, long ticket comment threads, AEM content trees) directly into their own context, causing context rot and cost bloat — exactly what the RLM paper shows degrades quality. The RLM fix: the coordinator never sees raw bulk content; it dispatches sub-agents per chunk and aggregates small structured results in code, and the answer is built iteratively in a durable artifact (for us: the spec dir) rather than in one generation.
**Scope:** `plugins/dx-core/skills/dx-agent-all/`, `plugins/dx-core/skills/dx-bug-all/`, `plugins/dx-core/skills/dx-pr-review/` (chunk-dispatch rule); `plugins/dx-core/skills/dx-pr-review/references/` (aggregation guidance); `.ai/specs/` conventions doc if the answer-store contract changes.
**Done-when:** `grep -n "never read the raw" plugins/dx-core/skills/{dx-agent-all,dx-bug-all,dx-pr-review}/SKILL.md` (or equivalent MUST NOT wording) hits in all three skills, AND each defines a size threshold above which content is chunk-dispatched to sub-agents with a structured result envelope, AND one coordinator has been manually verified on an oversized input (per Testing Changes in CLAUDE.md).
**Approach:** Gated on the deep-dive item's go/no-go. Start with `dx-pr-review` (>5-file PRs already have an escalation rule — extend it to chunk-dispatch); reuse the Result-envelope work from #46 and context-budget examples from #47. Keep recursion depth at 1 (coordinator → worker), parallel fan-out where phases are independent (#45).
