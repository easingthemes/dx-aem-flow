# TODO: Clean Up Old Automation Approaches in Consumer Repos

## Problem

`.ai/automation/` in consumer repos contains 3 historical approaches. Only the CLI approach is current. The old approaches are dead code taking up ~90 files.

## Three Approaches (chronological)

### 1. Custom JS Agents (OLD — DELETE)
**Location:** `.ai/automation/agents/`
**What:** Hand-written JS agent steps (fetch PR → review code → post comments) with custom LLM client, rate limiter, token budget, policy gates, deduplication, retry logic, storage, alerts.
**Files:** 52 files across `agents/dor/`, `agents/pr-review/`, `agents/pr-answer/`, `agents/orchestrator/`, `agents/roles/`, `agents/lib/`
**Why obsolete:** Replaced by CLI approach — Claude SDK + plugin skills handle all of this natively. The custom LLM client, rate limiter, deduplication, etc. are now handled by the SDK and Lambda infrastructure.

### 2. Custom Agent Pipelines (OLD — DELETE)
**Location:** `.ai/automation/pipelines/dor/`, `pipelines/pr-review/`, `pipelines/pr-answer/`, `pipelines/eval/`
**What:** ADO pipeline YAMLs that ran the custom JS agents directly.
**Files:** 4 pipeline YAMLs
**Why obsolete:** Replaced by CLI pipelines that use `pipeline-agent.js` with skill invocations.

### 3. CLI Pipelines (CURRENT — KEEP)
**Location:** `.ai/automation/pipelines/cli/`
**What:** ADO pipeline YAMLs that run `pipeline-agent.js` (Claude SDK) with plugin skill invocations like `/dx-pr-review`, `/dx-req-dod`.
**Files:** 10 pipeline YAMLs
**Entrypoint:** `.ai/automation/scripts/pipeline-agent.js` — wraps Claude SDK, passes skill prompts.

## What to Delete

```
.ai/automation/agents/              # 52 files — entire old agent codebase
.ai/automation/pipelines/dor/       # 1 file — old DOR pipeline
.ai/automation/pipelines/pr-review/ # 1 file — old PR review pipeline
.ai/automation/pipelines/pr-answer/ # 1 file — old PR answer pipeline
.ai/automation/pipelines/eval/      # 1 file — old eval pipeline
.ai/automation/prompts/             # 8 files — system prompts for old agents (CLI uses plugin skills, not these)
.ai/automation/eval/                # 9 files — test framework for old agents
.ai/automation/run.sh               # Old runner script
.ai/automation/setup-cli.sh         # Old setup script
.ai/automation/.env.template        # Old env template
.ai/automation/repos.json           # Old repo config
.ai/automation/repos.template.json  # Old repo template
```

**Total:** ~76 files to delete

## What to Keep

```
.ai/automation/pipelines/cli/       # 10 CLI pipeline YAMLs (current)
.ai/automation/scripts/             # pipeline-agent.js + .ts (CLI entrypoint)
.ai/automation/lambda/              # Lambda routers + deploy (infrastructure)
.ai/automation/infra.json           # Infrastructure registry
.ai/automation/infra.template.json  # Infra template
.ai/automation/policy/              # Pipeline policy (still referenced)
```

## Also Check

- Do CLI pipelines reference anything in `prompts/`? → No, they pass skill commands directly.
- Does `pipeline-agent.js` reference `agents/`? → No, it invokes Claude SDK with skill prompts.
- Does Lambda reference old agents? → Check `wi-router.mjs` and `pr-router.mjs` — they queue pipeline runs, not call agents directly.

## Where to Apply

All consumer repos: Experience-Vuse-Global-2.0, AEM-Platform-Core, Experience-Zonnic, Platform-Core, Platform-Core-Config.

Also update the `dx-automation` plugin's `/auto-init` skill to stop scaffolding old agent files.

## Priority

Medium-high — dead code confusion. Developers seeing 90+ automation files when only 10 pipelines + 2 scripts matter.
