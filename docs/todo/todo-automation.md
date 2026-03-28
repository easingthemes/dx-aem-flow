# TODO: Clean Up Old Automation

## Clean Up Old Automation in Plugin — DONE

**Added:** 2026-03-22
**Completed:** 2026-03-22 — commit `1800b25`
**Problem:** `plugins/dx-automation/data/` contained ~40 files of obsolete custom JS agents, old pipelines, old eval framework, old runner scripts. Only CLI approach (`pipelines/cli/` + `pipeline-agent.js`) was current. Dead code caused confusion.
**Scope:** `plugins/dx-automation/data/agents/` (22 files), `data/eval/` (9 files), `data/docs/` (5 files), `data/pipelines/eval/` (1 file), `data/run.sh`, `data/setup-cli.sh`, `data/repos.template.json`.
**Done-when:** `ls plugins/dx-automation/data/agents/ 2>&1` returns "No such file or directory" AND `grep -r "agents/lib" plugins/dx-automation/skills/auto-init/SKILL.md` returns no matches.
**Resolution:** Deleted 40 files (-6,370 lines). Updated `auto-init` to stop scaffolding deleted files. Updated `auto-test` to use `pipeline-agent.js`.

**Note:** Existing consumer repos may still have old files in `.ai/automation/agents/`, `.ai/automation/eval/`, etc. That's a per-repo cleanup task, not a plugin issue.

## Budget Tracking

**Added:** 2026-03-28
**Problem:** Automation agents (DoR checker, PR reviewer, DevAgent, etc.) run 24/7 on ADO pipelines with no visibility into token consumption per agent. Cost overruns are invisible until the monthly bill arrives. Paperclip (companies.sh) solves this with per-agent monthly token budgets that halt agents when exhausted.
**Scope:** `plugins/dx-automation/` — all `auto-*` skills, `pipeline-agent.js`, `.ai/config.yaml` schema, `.ai/automation/prompts/`.
**Done-when:** `grep -r "budget" plugins/dx-automation/skills/auto-init/SKILL.md` returns a match AND `.ai/config.yaml` template contains an `automation.budget:` section AND `pipeline-agent.js` tracks and enforces token limits per agent run.
**Approach:** (1) Add `automation.agents.<name>.budget:` section to config.yaml schema with monthly token cap per agent. (2) Instrument `pipeline-agent.js` to log token usage per run to a DynamoDB table or CloudWatch metric. (3) Add a pre-run budget check that skips execution if monthly cap is reached. (4) Add `/auto-budget` skill to report usage across agents. Defer until local flow is solid — this is a post-stabilization improvement.
