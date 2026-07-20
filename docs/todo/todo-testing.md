# TODO: Testing & Evals

## Layer 2: Skill Triggering Evals

**Added:** 2026-03-21
**Problem:** No automated way to verify that natural language prompts or explicit `/dx-*` invocations trigger the correct skill. Skill description changes can silently break triggering.
**Scope:** New `tests/` directory at repo root. Needs: `tests/run-evals.sh`, bash helpers (`run_claude`, `assert_contains`, `assert_order`), CI workflow file.
**Done-when:** `ls tests/run-evals.sh` exists AND `bash tests/run-evals.sh --quick` runs without error (even if some evals fail).
**Approach:**
- [ ] Create `tests/` directory with bash test helpers
- [ ] Write trigger tests: does natural language prompt invoke the right skill?
- [ ] Write explicit invocation tests: does `/dx-req 12345` trigger `dx-req`?
- [ ] Add `ANTHROPIC_API_KEY` as GitHub Actions secret
- [ ] Create `tests/run-evals.sh` with `--quick` (10 key skills) and `--full` (all) modes
- [ ] CI workflow: run on release tags only (expensive, non-deterministic)

**Status update 2026-07-20:** ⚠️ **Marked "Done" in TODO.md #1 but the Done-when check FAILS.**
`tests/` does not exist in the working tree, `git log --all -- tests/run-evals.sh`
returns nothing, and every Approach checkbox above is still unchecked. Per the
CLAUDE.md verification rule (run the Done-when, don't infer from absence), this
item is **regressed / never landed**, not done. Reopened as TODO.md #1.

## Layer 3: Workflow Integration

**Added:** 2026-03-21
**Problem:** No automated verification that `/dx-init` and `/aem-init` produce correct output files with correct config values. Manual testing before releases is error-prone.
**Scope:** New test scripts in `tests/`. Tests run `/dx-init` and `/aem-init` in a temp project directory and verify output.
**Done-when:** A script exists that runs `/dx-init` in `/tmp/test-*`, checks for expected files (`.ai/config.yaml`, `.claude/rules/`, `.ai/lib/audit.sh`), and exits 0/1.
**Approach:**
- [ ] `/dx-init` in temp project → verify all expected files land with correct config
- [ ] `/aem-init` → verify AEM config extends correctly
- [ ] End-to-end: requirement fetch → plan → verify spec directory structure
- [ ] Run manually before major releases

## Automation Eval

**Added:** 2026-03-22
**Problem:** The old eval framework (`eval/gates.js`, `judge.js`, `mock.js`) tested custom JS agents and was deleted with them in `1800b25`. The CLI approach (`pipeline-agent.js` + plugin skills) has no equivalent automated testing.
**Scope:** `plugins/dx-automation/` — needs a new eval approach for CLI pipelines in `data/eval/` or `tests/`.
**Done-when:** A command exists to dry-run a pipeline agent against fixture data and compare output against expected findings (e.g., `node pipeline-agent.js --eval pr-review --fixture tests/fixtures/sample-pr.json`).
**Approach:** Current mitigation is manual `/auto-test --dryRun`. Need fixture-based eval that runs pipeline agents against known PRs/work items and verifies output quality.

## Skill-Lift ablation evals (with-vs-without) + skill retirement detection

**Added:** 2026-07-20
**Source:** [2026-07-20-skill-authoring-best-practices.md](../research/2026-07-20-skill-authoring-best-practices.md) §7–§8 (Philipp Schmid, "Don't Ship Skills Without Evals", AI Engineer World's Fair Track 5).
**Problem:** Our only skill eval (Layer 2 above) measures *trigger correctness* —
does prompt X invoke skill Y. It never measures whether a skill actually
*improves the outcome*. Two consequences: (1) we cannot prove a skill earns its
recurring token cost, so description/body edits are flown blind (the talk's
ablation harness measures exact "Skill Lift" = pass-rate delta with-skill vs.
without-skill); (2) we have no way to detect a **dead-weight skill** — one whose
value the base model has since absorbed, so evals pass even with the skill
unloaded. With 77 SKILL.md files (median 296 lines, each a per-turn cost), both
gaps directly bloat context. Complements #137 (measures token *cost*); this
measures the *benefit* side of the same ratio.
**Scope:** `tests/` (builds on Layer 2 harness). Per high-value skill: an
outcome-graded case set run twice (skill loaded / unloaded). Start with the
collision-prone + heaviest skills: `dx-pr-review`, `dx-simple`, `dx-req`,
`dx-agent-all`, `dx-bug-verify`.
**Done-when:** A command runs an ablation for a named skill and reports pass-rate
with vs. without it loaded, e.g. `bash tests/run-evals.sh --ablation dx-pr-review`
prints two pass rates and their delta. A skill whose delta is ≈0 is flagged as a
retirement candidate.
**Approach:**
- Grade **outcomes, not paths** (§8 rule 5): assert on produced artifact / API
  correctness / goal completion, not on which files the agent read.
- Run **3–5 trials per case** and report **pass^k (consistency)**, not pass@k
  (peak luck) (§8 rule 7).
- **Isolate each run** in a clean workspace — context bleed masks real failures
  (§8 rule 6).
- Retirement check (§8 rule 10): run the case set with the skill unloaded; if it
  still passes, the base model absorbed the value → propose retiring the skill.
- Gate: a skill PR should show **positive Skill Lift** before merge (§7).

## Cross-harness + negative eval coverage

**Added:** 2026-07-20
**Source:** [2026-07-20-skill-authoring-best-practices.md](../research/2026-07-20-skill-authoring-best-practices.md) §8 rules 3 & 8.
**Problem:** Layer 2's prompt set (once it exists) is single-harness and
positive-only. Two documented blind spots: (1) **no negative cases** — prompts
where a skill should NOT fire; without them we over-optimize triggering and never
catch keyword hijacking (acute here: 7 `dx-pr-*`, 5 verify, 4 `dx-bug-*`, 4
`dx-req-*` skills share keywords). (2) **single harness** — skills behave
differently across Claude Code, Copilot CLI, Cursor, and Gemini CLI, all of which
we ship to; a description that triggers correctly in one can mis-fire in another.
**Scope:** `tests/prompts/` (or equivalent) — add `should_trigger: false` cases;
CI matrix or documented per-harness run. Pairs with skill-conventions #14
(negative-trigger clauses are the *fix*; these cases are the *test*).
**Done-when:** (1) The eval set contains negative cases and asserts the target
skill does NOT activate on them; a deliberately broad description makes a negative
case fail. (2) At least the top ~10 skills are eval'd in ≥2 target harnesses with
results recorded.
**Approach:** Model cases on the talk's `test_cases.json` (`should_trigger`
boolean + `expected_checks`). Add one negative case per collision cluster first
(e.g. "review this React component" must not fire `dx-pr-review`). Defer the full
cross-harness matrix until the single-harness suite is green.
