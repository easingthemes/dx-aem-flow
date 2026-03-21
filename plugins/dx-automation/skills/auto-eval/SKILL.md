---
name: auto-eval
description: Run the AI automation evaluation framework against test fixtures. Verifies agent quality without hitting ADO or LLM APIs. Use after changing prompts, rules, or agent steps. Accepts --all, --agent, --tier2 flags.
argument-hint: "[--all | --agent dor|pr-review|pr-answer | --tier2 | --fixture [name]]"
---

You run the evaluation framework for the AI automation agents. Eval runs against pre-captured fixtures (no live ADO or LLM calls for tier-1 gates).

## 0. Prerequisites

Read `.ai/automation/infra.json` to confirm scaffold exists.

Check Node.js is available: `node --version`. If missing: STOP with install instructions.

Check eval fixtures exist:
```bash
ls .ai/automation/eval/fixtures/ 2>/dev/null | head -5
```

If no fixtures: "No eval fixtures found. Run `/auto-test --capture` first to capture fixtures from live ADO, or add fixtures manually to `.ai/automation/eval/fixtures/`."

## 1. Parse Arguments

Default: `--all` if no argument given.

Supported flags (pass through to `eval/run.js`):
- `--all` — run all fixtures
- `--agent <name>` — run only fixtures for a specific agent (`dor`, `pr-review`, `pr-answer`)
- `--tier2` — run tier-2 gates (makes real LLM calls; slower and costs tokens)
- `--fixture <name>` — run a single fixture by name

## 2. Run Eval

```bash
cd .ai/automation
node eval/run.js $ARGUMENTS
```

Report the output as-is.

## 3. Interpret Results

After eval completes, summarize:

- **Pass rate:** N/total fixtures passed
- **Failed fixtures:** list names of failed fixtures
- **Gate breakdown:** which gates failed (if any)

If any fixtures fail:
> ⚠️ **N fixture(s) failed.** Check the output above for details. Do NOT push prompt changes until all fixtures pass.

If all pass:
> ✓ **All fixtures passed.** Safe to push changes.

## 4. Common Eval Workflows

**After changing a prompt file:**
```bash
/auto-eval --all
```

**Before pushing a code change:**
```bash
/auto-eval --all
```

**Debug a specific agent:**
```bash
/auto-eval --agent pr-review
```

**Full quality regression (slower, uses LLM):**
```bash
/auto-eval --tier2
```

## Examples

1. `/auto-eval` — Runs tier-1 evaluation against all agent test fixtures. Parses agent step outputs, validates against expected results (no ADO or LLM calls). Reports 45/47 assertions passed, 2 failures in the PR Review agent's comment formatting logic.

2. `/auto-eval --agent pr-review` — Runs tier-1 fixtures for the PR Review agent only. Useful for debugging a specific agent after changing its prompt or step logic. Reports 12/12 assertions passed.

3. `/auto-eval --tier2` — Warns about token cost, then runs full quality regression including LLM calls. Tests that agent outputs meet quality thresholds for each scenario. Reports quality scores per agent and overall pass/fail.

## Troubleshooting

- **"Fixtures not found for agent"**
  **Cause:** No test fixtures exist in the eval directory for the specified agent.
  **Fix:** Create fixtures in `.ai/automation/eval/fixtures/<agent-name>/` with input/expected-output pairs. See existing fixtures for the format.

- **Tier-1 passes but tier-2 fails**
  **Cause:** Tier-1 tests structural correctness (format, required fields) while tier-2 tests semantic quality (LLM output relevance). A prompt change may produce valid structure but lower quality.
  **Fix:** Review the tier-2 failure details — they show the quality score vs threshold. Adjust the prompt or agent step logic and re-run.

- **Tier-2 costs more tokens than expected**
  **Cause:** Each tier-2 test makes LLM API calls. Running all agents' tier-2 tests can consume significant tokens.
  **Fix:** Use `--agent <name>` to scope tier-2 to a specific agent. Reserve full `--tier2` runs for pre-release validation.

## Rules

- **No ADO or LLM calls in tier-1** — fixtures are self-contained; safe to run anytime
- **Tier-2 costs tokens** — warn user before running `--tier2`
- **Never auto-push** — eval is advisory; user decides whether to push
