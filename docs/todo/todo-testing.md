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
