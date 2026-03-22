---
name: auto-test
description: Run a local dry-run of an AI automation agent against real ADO data (no posts/commits made). Use to verify end-to-end connectivity and agent output before going live. Requires ADO PAT and LLM credentials in .env.
argument-hint: "[dor|dod|dod-fix|pr-review|pr-answer|bugfix|qa|devagent|docagent|estimation] [id] [[repoName]] [--dryRun]"
---

You run an AI automation agent locally against real ADO data. With `--dryRun`, results are logged but nothing is posted to ADO or committed. Without `--dryRun`, the agent runs fully (posts comments, applies fixes).

## 0. Prerequisites

Check required env vars are set (in shell or `.claude/settings.local.json`):
- `ANTHROPIC_API_KEY`
- ADO MCP authenticated (browser OAuth) or `ADO_MCP_AUTH_TOKEN` set

## 1. Parse Arguments

From the user's command:
- Agent: `dor`, `dod`, `dod-fix`, `pr-review`, `pr-answer`, `bugfix`, `qa`, `devagent`, `docagent`, or `estimation`
- Target ID: work item ID (dor) or PR ID (pr-review, pr-answer)
- Repo name (pr-review, pr-answer)
- `--dryRun` flag: default `true` for safety

If no arguments: Read `.ai/automation/infra.json` to get `automationProfile` and the list of enabled agents (those without `"disabled": true`). Then prompt with only the enabled agents:

> **Which agent to test?**

Only show agents that are enabled for this profile:
- **consumer** (or legacy `pr-only`/`pr-delegation`): PR Review, PR Answer, DevAgent, BugFix, DoD Fix
- **full-hub**: all agents

Full agent list (filter to enabled):
> 1. DoR — needs work item ID
> 2. DoD — needs work item ID
> 3. DoD Fix — needs work item ID
> 4. PR Review — needs PR ID + repo name
> 5. PR Answer — needs PR ID + repo name
> 6. BugFix — needs Bug work item ID
> 7. QA — needs work item ID
> 8. DevAgent — needs work item ID (User Story)
> 9. DOCAgent — needs work item ID (User Story)
> 10. Estimation — needs work item ID

If the user requests an agent that is disabled for this profile, report: `⚠ <agent> is not enabled for the <profile> profile. To enable it, re-run /auto-init.`

> **Target ID?** (work item ID or PR ID)

> **Dry run?** (default: yes — log results without posting to ADO)
> 1. Yes — dry run (recommended for first test)
> 2. No — live run (posts real comments/applies fixes)

## 2. Run Agent

```bash
node .ai/automation/scripts/pipeline-agent.js "<skill-prompt>"
```

Map agent names to skill prompts:
| Agent | Skill Prompt |
|-------|-------------|
| dor | `/dx-req-dod <id>` |
| dod | `/dx-req-dod <id>` |
| dod-fix | `/dx-req-dod <id>` |
| pr-review | `/dx-pr-review <pr-url> analyze only` (dry run) or `/dx-pr-review <pr-url>` (live) |
| pr-answer | `/dx-pr-answer <pr-url>` |
| bugfix | `/dx-bug-all <id>` |
| devagent | `/dx-agent-all <id>` |
| docagent | `/dx-doc-gen <id>` |
| estimation | `/dx-estimate <id>` |

Stream output as it runs. This may take 1-3 minutes depending on the agent.

## 3. Interpret Results

After completion, look for in the output:
- `[DOR] Posted DoR comment` — DoR ran and posted
- `[DOD] Posted DoD comment` — DoD ran and posted
- `[DOD-FIX] Applied fixes` — DoD Fix ran and applied auto-fixes
- `[PR-Review] Posted review` — PR Review ran
- `[PR-Answer] Posted reply` — PR Answer ran
- `[BUGFIX] Applied fix` — BugFix ran
- `[QA] Created Bug tickets` — QA ran
- `[DEVAGENT] Pipeline complete` — DevAgent ran
- `[DOCAGENT] Pipeline complete` — DOCAgent ran
- `--dryRun: true` in logs — confirms dry run mode (nothing actually posted)
- Any `[ALERT:CRITICAL]` lines — investigate before going live
- `status: skipped` (dedupe/rate-limit) — expected on re-runs

## 4. Summary

```markdown
## Local Test Results

**Agent:** <agent>
**Target:** <id> (<work item title or PR title>)
**Mode:** Dry run / Live run
**Status:** ✓ Completed / ✗ Failed

<Key output lines>

<If dry run and succeeded:>
✓ Agent ran successfully in dry-run mode. Ready to go live.
Run `/auto-test <agent> <id> --live` to post real results.

<If failed:>
⚠️  Check the error above. Common issues:
- ADO PAT expired → rotate in AWS Lambda env vars (`/auto-lambda-env`)
- LLM API key invalid → check pipeline variables
- Network connectivity → check AWS Lambda VPC config
```

## Success Criteria

- [ ] Agent ran to completion without `[ALERT:CRITICAL]` errors
- [ ] Dry-run mode confirmed — no posts, commits, or state changes made
- [ ] Output includes the agent's decision and reasoning for the test input

## Examples

1. `/auto-test pr-review 12345 --dryRun` — Runs the PR Review agent against PR #12345 in dry-run mode. Fetches the PR from ADO, runs the review logic locally, and prints the review output without posting any comments. Reports success — agent is ready for live use.

2. `/auto-test dor 2416553` — Runs the DoR (Definition of Ready) agent against work item #2416553 in dry-run mode (default). Checks story completeness, acceptance criteria quality, and technical feasibility. Prints the assessment without updating the work item.

3. `/auto-test pr-review 12345 --live` — After confirming with user, runs the PR Review agent in live mode. Posts actual review comments to the PR in ADO. Use only after a successful dry-run.

## Troubleshooting

- **"ADO PAT expired" error during test**
  **Cause:** The ADO Personal Access Token used by the Lambda has expired.
  **Fix:** Rotate the PAT in ADO, then update it with `/auto-lambda-env`. For local dry-run testing, ensure the PAT is set in the pipeline variables or environment.

- **"LLM API key invalid" error**
  **Cause:** The Anthropic API key is missing or expired.
  **Fix:** Check the pipeline variables for the LLM API key. Update with `/auto-lambda-env` if running against Lambda, or check local environment variables for dry-run mode.

- **Test passes in dry-run but fails in live mode**
  **Cause:** Live mode makes additional ADO API calls (posting comments, updating work items) that may require different permissions than read-only dry-run.
  **Fix:** Ensure the ADO PAT has write permissions for work items and PR comments. Check the error message for the specific API call that failed.

## Rules

- **Default to --dryRun** — never run live without explicit user confirmation
- **Stream output** — show progress as it happens (this can take minutes)
- **Confirm before live run** — ask explicitly if user wants to post real results
