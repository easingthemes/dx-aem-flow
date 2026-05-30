# Ideas from Salesforce "Agentic Engineering"

Follow-ups from [`2026-05-30-salesforce-agentic-engineering.md`](../research/2026-05-30-salesforce-agentic-engineering.md) —
Salesforce's first-party account of moving their engineering org to agentic
development on Claude Code. We already match or lead them on most patterns; these are
the gaps worth closing.

## PR-feedback → rule-set learning loop (`dx-rule-learn`)

**Added:** 2026-05-30
**Problem:** Salesforce's compounding accuracy gains came from **folding every round of
PR-review feedback back into their markdown rule set**, so each subsequent agent run
started smarter and outputs arrived near production-ready. We have all the pieces —
`dx-pr-answerer`, the shared `.ai/rules/pr-review.md` / `pr-answer.md`, and the
three-layer override system — but **nothing closes the loop**: lessons from a reviewed
PR never propagate back into the rules that drive the next run. The same review comment
gets written by hand, ticket after ticket.
**Scope:** New skill `plugins/dx-core/skills/dx-rule-learn/SKILL.md`; reads/writes
`.ai/rules/*.md` (esp. `pr-review.md`, project convention rules); consumes PR review
threads via ADO/Jira MCP and/or `.ai/specs/<id>-<slug>/` review artifacts. Optionally
hooked from `dx-pr` after a PR closes.
**Done-when:** `ls plugins/dx-core/skills/dx-rule-learn/SKILL.md` exists; running it on
a closed PR with recurring review comments produces a **human-approved** diff to an
`.ai/rules/*.md` file (never auto-commits rule changes), and `dx-plan`/`dx-step` pick up
the new rule on the next ticket. Verify with a fixture PR whose feedback ("use CSS
custom properties over hardcoded values") becomes a new line in the project rules.
**Approach:** Distill recurring/blocking review comments into atomic rule candidates,
each with a confidence score and a source-PR citation. Present as a proposed diff,
human approves before commit (consistent with our gate philosophy — never auto-mutate
rules). Start PR-scoped and project-scoped (no cross-project contamination — critical
for `dx-hub` multi-repo). **Cross-ref #52** (`todo-ecc-ideas.md` continuous-learning /
instinct system) — this is the narrower, PR-scoped, human-gated cut of that broader
idea; build #143 first as the concrete entry point.

## Agentic-metrics roll-up ("Effective Output"-style)

**Added:** 2026-05-30
**Problem:** Salesforce led with numbers — work items/dev +50.8%, PRs merged/dev +79%,
an ML "Effective Output" score +151.3% YoY, incidents −5% — to *prove* that structural
guardrails raise quality even as speed rises. We have the raw telemetry (audit logs,
per-run `confidence.json` gate scores, `.ai/specs/` per-ticket artifacts, pipeline cost
alerts) but **no aggregation**, so we can't tell the same data-driven story or tune gate
thresholds (G1–G9) with evidence instead of guesses.
**Scope:** New roll-up script/skill (e.g. `plugins/dx-core/skills/dx-metrics/` or a
helper under `.ai/lib/`); reads `.ai/specs/*/confidence.json`, audit logs
(`.ai/lib/audit.sh` output), and pipeline run records from `dx-automation`.
**Done-when:** A command emits a per-agent/per-period summary — success rate, gate-abort
reasons (which of G1–G9 fired most), cost/time per ticket, PRs per ticket — to a
machine-readable file plus a human summary. Verify: running it over a directory of
`.ai/specs/` produces a table with at least the abort-reason breakdown.
**Approach:** Keep it Markdown/JSON, no database. Phase 1: parse existing
`confidence.json` + audit logs into one `metrics.json`. Phase 2: surface gate-abort
histograms so SimpleAgent thresholds can be tuned empirically. Pairs naturally with the
token-footprint baseline work (#137).

## Positioning: "orchestration is the skill"

**Added:** 2026-05-30
**Problem:** Salesforce's narrative — *the new core competency is structuring problems,
deciding when to delegate vs. stay in the loop, and building reusable patterns the team
compounds on* — is precisely what our coordinator/subagent model and human-re-trigger
recovery embody, but our docs don't frame it that way. We undersell a story we already
live.
**Scope:** `website/` (architecture / positioning pages); possibly a top-level concept
page. No plugin-code change.
**Done-when:** A website page articulates the orchestrator-not-author framing and points
to concrete mechanisms (coordinator skills, parallel subagent dispatch, SimpleAgent's
`@kai-simple`-reply resume as the literal "when to stay in the loop" gate). Verify: page
exists and links to the dx-req fan-out + dx-simple recovery flow.
**Approach:** Low effort, high narrative value. Reuse the comparison table from the
research doc. Lead with our advantage: explicit quantified gates + durable recovery are a
*more honest* human-in-the-loop story than the article tells.

## Batch / parallel migration via worktree fan-out

**Added:** 2026-05-30
**Problem:** Salesforce's 18× migration win (231 person-days → 13 days) came from
splitting one large job into 5 PRs running across **isolated environments in parallel**.
Our DevAgent and `isolation: worktree` support exist but are pointed at one ticket at a
time; we have no pattern for fanning a single large migration into parallel,
independently-recoverable workstreams.
**Scope:** `dx-automation` DevAgent flow; `dx-core` coordinator skills that could spawn
worktree-isolated children; per-ticket branch state store (already the recovery
substrate for SimpleAgent #141).
**Done-when:** A documented pattern (and ideally a coordinator) can take a batch spec
("migrate these N components") and dispatch N worktree-isolated workstreams, each
producing its own PR and each independently resumable via the existing branch-as-state
recovery. Verify: a batch fixture produces ≥2 isolated worktrees with separate branches.
**Approach:** Lean on existing primitives — `isolation: worktree`, per-ticket branch
checkpointing, confidence gates per child. Keep children idempotent (Phase-0-style
resume). Lower priority than #143/#144; revisit once those land. Cross-ref #133 (do NOT
rebuild a stateful central hub) and #142 (multi-repo routing) for the dispatch mechanics.
