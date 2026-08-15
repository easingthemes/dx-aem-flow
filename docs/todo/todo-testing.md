# TODO: Testing & Evals

> **2026-08-15 — the runner question is settled.** Every item below was written
> against a hand-rolled `tests/run-evals.sh` that never landed. It is superseded:
> Anthropic ships **`claude plugin eval`** (in the CLI since 2.1.198, early-access
> gated, still publicly undocumented), which covers cases, graders, repeated runs,
> sandbox isolation, ablation, a stable v1 JSON result document, and CI exit codes.
> The first suite is live at `plugins/dx-core/evals/plan-validate-finds-gap/`
> (score 1.00 at `--runs 3`). Re-scope the items below against that harness rather
> than rebuilding it — **but note it only drives `claude`**, so the cross-harness
> half of #168 still needs a custom runner. Conventions and the run command are in
> CLAUDE.md § Behavioral evals.

## First suite landed — extend coverage

**Added:** 2026-08-15
**Problem:** Exactly one eval case exists (`dx-plan-validate`). It proves the
harness works and establishes the fixture/grader conventions, but it is not
coverage. No routing case, no negative case, no second skill.
**Scope:** `plugins/*/evals/`. Next candidates are the sandbox-safe, MCP-free
skills — `dx-simplify`, `dx-plan-resolve`, `dx-security`, `dx-pattern-extract`;
MCP-coupled skills (`dx-pr-*`, `dx-req-*`, all `aem-*`) need fixtures or tool
grants first and are a separate problem (see next item).
**Done-when:** `claude plugin eval plugins/dx-core` runs **≥3 cases** across ≥2
skills and reports a score for each.

## Every grader needs its own failing case

**Added:** 2026-08-15
**Problem:** In the first suite only 2 of 4 graders have ever been observed
failing. `coverage-2-of-3` was verified against a known-bad input and worked;
`gap-is-explained` was verified and **did not** (the judge voted PASS on a report
its rubric said to FAIL — see the suite README). `wrote-report` and
`no-extra-gaps` have never fired. An unverified grader is worse than no grader:
it makes a suite look protective when it is not.
**Scope:** `plugins/dx-core/evals/plan-validate-finds-gap/` first, then every
suite added afterwards.
**Done-when:** For each grader in a suite, a documented input exists that makes
*that grader* fail, and the failure has been observed at least once.
**Approach:** One scenario only exercises the graders it touches — `no-extra-gaps`
needs an input where the skill wrongly flags a covered requirement, which cannot
be produced by editing the fixture alone. Record verified/unverified per grader
in the suite README.

## Make the llm rubric fixture-independent

**Added:** 2026-08-15
**Problem:** `graders/gap-is-explained.md` opens by asserting ground truth in
prose ("Only R3 is genuinely uncovered by the plan"). When the fixture was
repaired for a sanity check, that premise silently became false and the judge
deferred to a confident, well-structured report over its own rubric — passing
3/3 what it was explicitly told to fail. The deterministic grader caught the
same change.
**Scope:** `plugins/dx-core/evals/plan-validate-finds-gap/graders/gap-is-explained.md`
**Done-when:** With the fixture temporarily repaired (all three requirements
covered), the case is re-run and `gap-is-explained` reports FAIL.
**Approach:** State the claim to verify rather than the ground truth — judge the
report's internal consistency against the plan it was given, not against a fact
written into the rubric.

## `/auto-eval` points at a runner that does not exist

**Added:** 2026-08-15
**Problem:** `plugins/dx-automation/skills/auto-eval/SKILL.md` instructs the user
to run `node eval/run.js` in `.ai/automation`. That runner was deleted with the
custom JS agents in `1800b25` and exists nowhere in the repo. The skill ships a
working interface to removed code — it fails for any user who invokes it.
**Scope:** `plugins/dx-automation/skills/auto-eval/`
**Done-when:** Either `/auto-eval` runs successfully end-to-end, or the skill is
removed/rewritten so it no longer references a non-existent runner.
**Approach:** Cheapest correct fix is to retarget it at `claude plugin eval`
against `plugins/dx-automation/evals/`; alternative is deletion, which also drops
the skill count by one. Related to the "Automation Eval" item below.

## Layer 2: Skill Triggering Evals

**Added:** 2026-03-21
**Problem:** No automated way to verify that natural language prompts or explicit `/dx-*` invocations trigger the correct skill. Skill description changes can silently break triggering.
**Scope:** ~~New `tests/` directory at repo root~~ → **superseded 2026-08-15**: routing cases go in `plugins/<plugin>/evals/` alongside the outcome cases, using `claude plugin eval`. No bash harness needed.
**Done-when:** A routing case exists whose grader is `type: tool_used, tool: Skill, input_match: '"skill"\s*:\s*"(?:[\w-]+:)?<name>"'`, and it passes for the intended skill. Verified empirically 2026-08-15 that the trace carries `{"skill":"dx-core:dx-pr-review"}` in exactly that shape.
**Note on scoring:** under `--ablation with-without`, `tool_used` graders on `Skill` are **excluded from the score in both arms** (the baseline can never fire a skill, so scoring it would rig the delta). Routing cases therefore need `--ablation none`, or a non-routing grader alongside.
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
**Done-when:** `claude plugin eval plugins/dx-core --case <case> --ablation with-without`
reports `delta` for at least one skill, and a skill whose delta is ≈0 is flagged as a
retirement candidate. **Superseded 2026-08-15:** ablation is built into the harness
(`--ablation with-without` runs a no-plugin baseline arm and reports
`aggregates.delta` = score − scoreWithout) — no custom runner needed.
**Blocker discovered 2026-08-15:** most skills terminate in an MCP write (ADO, Jira,
AEM) and the sandbox grants no `mcp__*` without an operator flag, so their *outcomes*
cannot be graded without fixtures or grants. Only ~13 dx-core skills are MCP-free.
This item is materially larger than originally scoped — start with those.
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
**Scope:** Negative cases go in `plugins/<plugin>/evals/` as `tool_used` graders with
`min: 0, max: 0` **and** `arm: both` (`max: 0` alone can never pass — `min` defaults to
1). Pairs with skill-conventions #14 (negative-trigger clauses are the *fix*; these
cases are the *test*). **Cross-harness half is NOT covered by `claude plugin eval`** —
it only drives `claude`, so Copilot CLI / Cursor / Gemini need a custom runner
(`claude -p --output-format stream-json` equivalents per harness).
**Done-when:** (1) The eval set contains negative cases and asserts the target
skill does NOT activate on them; a deliberately broad description makes a negative
case fail. (2) At least the top ~10 skills are eval'd in ≥2 target harnesses with
results recorded.
**Approach:** Model cases on the talk's `test_cases.json` (`should_trigger`
boolean + `expected_checks`). Add one negative case per collision cluster first
(e.g. "review this React component" must not fire `dx-pr-review`). Defer the full
cross-harness matrix until the single-harness suite is green.
