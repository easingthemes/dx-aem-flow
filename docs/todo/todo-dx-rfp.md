# dx-rfp — deferred items

Tracking items from RFP spec review that are intentionally deferred so Subsystem A–F work can proceed without blocking on them.

## Pre-run cost visibility (keep — not gating, just transparency)

**Added:** 2026-04-16
**Problem:** Users should know before a full `/rfp all` how many agent invocations it will dispatch. Not for gating — for transparency. "About to dispatch ~N opus + ~M sonnet calls across C categories; proceed?" is useful UX. It is **not** a budget ceiling that refuses to run.
**Scope:** `plugins/dx-rfp/skills/rfp/SKILL.md` orchestrator prologue, new `plugins/dx-rfp/lib/cost-estimate.sh`.
**Done-when:** Every `/rfp` invocation prints a one-line estimate: `"Will dispatch: N×opus (estimate+red-team) + M×sonnet (analysis/work-packages/approach/clarifications) + P×reviewer + Q×critic across C categories"`. No prompt, no confirmation gate — just information. User Ctrl-C if they disagree.
**Approach:** `cost-estimate.sh` reads `config.yaml` (categories, perspectives, critics) + manifest (stale count from `/rfp status`) and computes a static count. Cheap. Called once at orchestrator start.

**Non-goals (rejected per §1.1 quality-first principle):**
- No `--budget <ceiling>` flag that refuses to run. Enterprise RFPs are multi-year client relationships worth millions; the plugin should never refuse to do its job over token cost.
- No automatic model downgrade. `/rfp-estimate` and `/rfp-red-team` stay on `opus`.

---

## Preview mode (`--preview`) — draft-only narrow scope, deferred

**Added:** 2026-04-16 (originally drafted as `--light`; narrowed after §1.1 quality-first clarification)
**Problem:** During very early exploratory work on an RFP (pre-qualification, "is this even worth bidding?"), a user may want a fast sketch against the client brief without triggering the full pipeline. This is distinct from the production workflow — it's throwaway analysis that either gets discarded or triggers a full `/rfp` if qualification passes.
**Scope:** deferred — do not ship until clear demand emerges from actual usage. Core pipeline runs at full rigor regardless.
**Done-when:** `/rfp --preview` runs only `/rfp-analysis` + `/rfp-clarifications` for one configurable task, with `perspectives: []` for that invocation only. Output is tagged `preview: true` in the summary front-matter so downstream full runs cannot confuse preview output for production output. No changes to model tier, reviewers, critics, or estimation methods anywhere in the pipeline.

**Non-axes (explicitly not cut in preview mode):**
- Model tier stays on the skill's configured tier. No `opus → sonnet` downgrade.
- Both reviewer archetypes still run when reviewer dispatches.
- All 5 critics still run when red-team dispatches.
- All 5 estimation methods still run when estimate dispatches.

The `rfp_run_mode` hash input (spec §11.3) still exists as mechanism — preview runs and full runs get separate context summaries so the two never cross-pollute. That mechanism is cheap and correct independent of whether `--preview` ships.

**Approach:** when (if) this is built:
1. Add `config.rfp.cost.preview_mode:` block — limits which steps run, nothing else.
2. Tag preview outputs in front-matter; orchestrator warns if a preview-tagged context is the most recent context when a full run starts ("found preview output for task X; will regenerate at full rigor").
3. Document in README that preview is for qualification / bid/no-bid, not for production drafts.

---

## Scoped lock invalidation — polish for cascade UX

**Added:** 2026-04-16
**Problem:** Spec §10.6 invalidates `scope.md` globally when any task's `/rfp-analysis` is re-run. In practice, most scope tweaks affect 1–2 tasks. Over-invalidation is defensible (err on re-run per §1.1) but the confirmation prompt could narrow the blast radius when the diff is trivially task-local.
**Scope:** `plugins/dx-rfp/skills/rfp/SKILL.md` (cascade confirmation), `plugins/dx-rfp/lib/state.sh` (`state_invalidate_locks_for_config_change`), manifest diff logic.
**Done-when:** On `/rfp-analysis` re-run, orchestrator diffs old vs new scope shards, classifies changes as `task-local` vs `cross-cutting`, and shows a narrowed prompt when all changes are task-local:
```
Scope changed for: be-api, fe-perf (task-local lines only)
No cross-cutting changes detected.
Re-run only be-api, fe-perf downstream? [Y/n]
```
Default answer is `Y` (re-run). User can decline to keep things fresher still per §1.1.
**Approach:**
1. Introduce `## task-local` vs `## cross-cutting` section tags in `scope.md`.
2. Post-analysis diff classifies.
3. Default to conservative (global) when ambiguous.

---

## Reviewer context chunking — polish for very large steps

**Added:** 2026-04-16
**Problem:** Spec §8.7 has reviewers read "all step-N raw outputs". On a 13-task × 5-shard step, that's 65 shards in one prompt. Context window and reviewer attention both suffer. **Not a cost concern per §1.1 — a quality concern** (attention degrades on long contexts).
**Scope:** `plugins/dx-rfp/skills/rfp/SKILL.md` (agent input bundle assembly).
**Done-when:** Reviewer reads at most `config.rfp.reviewer.max_shards_per_invocation` (default 15). For larger steps, the orchestrator chunks the review and merges reviewer output under a `merged_from: [chunk-1, chunk-2, ...]` key. Merging is deterministic (concatenate + dedup findings).
**Approach:** config key + chunked dispatch in orchestrator. Revisit after actual usage surfaces the number of tasks that ship per RFP.
