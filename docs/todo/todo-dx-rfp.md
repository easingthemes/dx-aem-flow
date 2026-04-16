# dx-rfp — deferred items

Tracking items from RFP spec review that are intentionally deferred so Subsystem A–F work can proceed without blocking on them.

## Cost / inference budget controls

**Added:** 2026-04-16
**Problem:** Full `/rfp all` on an enterprise-scale RFP (13 categories × 6 core steps × ~5 shards including perspectives and reviewer) can easily reach 400+ agent invocations per regen. With `opus` on `/rfp-estimate` and `/rfp-red-team`, a full run is a significant cost per cascade-invalidated regeneration. Spec states "rigor over token efficiency" is the explicit trade — but without user-facing levers, accidental full regens on scope drift become expensive.
**Scope:** `plugins/dx-rfp/skills/rfp/SKILL.md` (orchestrator), `plugins/dx-rfp/templates/config.yaml.template`, new `--light` and `--budget` flag handling, plus a pre-run estimate report.
**Done-when:** `/rfp --light` runs primary + reviewer only (no perspectives) and produces a complete (if lower-rigor) pipeline. `/rfp --budget <ceiling>` refuses to start if the estimated cost exceeds the ceiling. A pre-run estimate line is printed on every invocation: "Estimated agents: N primary + M perspectives + P reviewers + Q critics".
**Approach:**
1. Add `config.rfp.cost.light_mode.perspectives: false` (default false) — the flag toggles this at runtime.
2. Batch-perspective mode: one perspective agent handles all its assigned categories in a single prompt, splitting output by category heading — reduces invocations from `C × P` to `P`.
3. Add a `lib/cost-estimate.sh` helper that counts agents from registry + config.
4. Document in README "Cost-aware runs" section once implemented.

## Lock invalidation — scoped propagation

**Added:** 2026-04-16
**Problem:** Spec §10.6 invalidates `scope.md` globally when any task's `/rfp-analysis` is re-run. Cascade-confirmation UX in §10.2 reports the blast radius but offers no way to narrow it. In practice, most scope tweaks affect 1–2 tasks; forcing global downstream re-runs inflates cost (see above) and discards work that is still valid.
**Scope:** `plugins/dx-rfp/skills/rfp/SKILL.md` (cascade confirmation), `plugins/dx-rfp/lib/state.sh` (`state_invalidate_locks_for_config_change`), manifest diff logic.
**Done-when:** On `/rfp-analysis` re-run for a task, orchestrator diffs the old vs new scope shards, classifies changes as `task-local` vs `cross-cutting`, and only globalizes when cross-cutting lines changed. Confirmation prompt shows:
```
Scope changed for: be-api, fe-perf
Cross-cutting lines unchanged.
Re-run only be-api, fe-perf downstream? [Y/n]
```
**Approach:**
1. Introduce `scope.md` section tags (`## task-local` vs `## cross-cutting`).
2. Post-analysis diff pass classifies changes.
3. Extend `state_invalidate_locks_for_config_change` with a `scope: task-local|global` param.
4. Default to conservative (global) when classification is ambiguous.

## Token-efficient context bundles

**Added:** 2026-04-16
**Problem:** Spec §8.7 agent input protocol says reviewers read "**all** step-N raw outputs". On a 13-task × 5-shard step, that's 65 shards in one prompt. Context window and cost both suffer, and reviewer attention degrades on long contexts.
**Scope:** `plugins/dx-rfp/skills/rfp/SKILL.md` (agent input bundle assembly).
**Done-when:** Reviewer reads at most a configurable `reviewer.max_shards_per_invocation` (default 10). For larger tasks, the orchestrator shards the review into chunks and merges reviewer output.
**Approach:** Add `config.rfp.reviewer.max_shards_per_invocation` and a chunked-review dispatch in the orchestrator. Defer until the basic pipeline is working end-to-end.
