---
description: ADO service hook scoping rules — hooks are per-project, not per-org
globs: ["**/*.sh", "**/auto-*/**", "**/infra.json"]
---

# ADO Service Hooks — Per-Project Scoping

## Key Constraint

ADO service hooks are scoped to an **ADO project**, NOT an organization. A hook created in project A cannot see events from project B. When creating or managing hooks, you MUST target the correct ADO project — the one where the repo or work items live.

## ADO Project Layout

Read the ADO project layout from `.ai/config.yaml` (`scm.project`) and `.ai/automation/infra.json`. A typical layout:

| ADO Project | Contains |
|---|---|
| **Work Items Project** | Work items (User Stories, Bugs), wiki |
| **Code Project** | Code repositories, pipelines |

## Hook Types and Scoping

### Work Item Hooks (WI Router)

- **Scope**: Project-level with tag filter (`KAI-TRIGGER`)
- **Who creates**: Hub only (one hook per WI type — User Story, Bug)
- **ADO Project**: The project where work items live (from `infra.json` or config)
- **Why project-scoped**: WIs aren't repo-scoped, tag filter limits noise

### PR Answer Hooks (PR Router)

- **Scope**: Per-repo + per-branch
- **Who creates**: Each repo (hub and every consumer) creates its own hook
- **ADO Project**: The project where the repo lives (from `.ai/config.yaml` `scm.project`)
- **Why per-repo**: A project-scoped hook fires on ALL PR comments across hundreds of unrelated repos. Each hook must filter to a specific `repository` + `branch` (base branch from config.yaml)
- **Lambda routing**: All per-repo hooks point to the same PR Router Lambda. The Lambda reads the repo name from the webhook payload and looks up the pipeline ID from `ADO_PR_ANSWER_PIPELINE_MAP`

### PR Review Build Policy

- Per-repo, per-branch — configured as a build validation policy on the base branch, not as a service hook

### SimpleAgent Comment Hook (Azure-native — no Lambda)

- **Scope**: Project-level, filtered on **comment text** (`comment contains @kai-simple`)
- **Event**: *Work item commented on* (`workitem.commented`)
- **Consumer**: the SimpleAgent pipeline's **Incoming WebHook** service connection (`resources.webhooks` in `ado-cli-simple.yml`) — **not** the WI Router Lambda. This is the one trigger that bypasses AWS entirely.
- **Who creates**: Hub only (`/auto-webhooks` step 2b)
- **Filter token**: read from `dx-simple.recovery.trigger-token` (default `@kai-simple`) — the skill, the pipeline header, and the hook filter share that single source of truth
- **Why Azure-native**: SimpleAgent is human-initiated and low-volume; a person types `@kai-simple` to start a run or to resume a blocked one. The same event covers both — Phase 0 (`resume-check.sh`) decides fresh-vs-resume. The WI Router's `AGENTS` array has no `simple` entry, so the Lambda never sees it.

## Azure-native vs Lambda — which path for a new agent?

ADO Service Hooks natively filter on **tag**, **comment text** (contains), **work-item type**, **state/field change**, and **PR events**. So any event-driven agent *can* be triggered the Azure-native way (Service Hook → Incoming WebHook service connection → pipeline `resources.webhooks`), one hook + connection per agent.

- **Azure-native** (SimpleAgent + BugFix model): no AWS infra, nothing to deploy. But you lose the Lambda's dedupe (ADO retry storms), per-agent rate limiting, monthly token-budget gating, and central tag-classification; any loop-prevention must live in the pipeline (both SimpleAgent and BugFix do this via in-skill resumable recovery + the bot never emitting its own trigger token). Best for **human-initiated, low-volume** agents (a `@kai-...` comment keyword). SimpleAgent (`@kai-simple`) and BugFix (`@kai-bugfix`, Bug-type filtered) both run this way. PR Answer is the next natural candidate.
- **Lambda router** (default for the other agents): keep the high-volume autonomous WI agents (DoR, DoD, QA, DevAgent, DOCAgent, Estimation) here so they retain dedupe, rate-limiting, the token budget, and one-hook-fans-out-to-many routing. PR Review stays a build validation policy (already Lambda-free). DoD-Fixer is chained, not event-triggered.

## Pipeline Naming

- **Hub**: `KAI-*` (e.g., `KAI-PR-Review-Agent`)
- **Consumer**: `KAI-<RepoShortName>-*` (e.g., `KAI-MyApp-PR-Review-Agent`)
- Reason: ADO's build policy dropdown lists ALL pipelines in the ADO project. Identical names across repos would be indistinguishable.

## Common Mistakes

- Creating a PR Answer hook in the wrong ADO project (hook won't see repo events)
- Creating a project-scoped PR Answer hook (fires on ALL repos — hundreds of noise events)
- Forgetting to add the repo to `ADO_PR_ANSWER_PIPELINE_MAP` on the PR Router Lambda
- Using identical pipeline names across repos (breaks build policy dropdown)
