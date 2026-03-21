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

## Pipeline Naming

- **Hub**: `KAI-*` (e.g., `KAI-PR-Review-Agent`)
- **Consumer**: `KAI-<RepoShortName>-*` (e.g., `KAI-MyApp-PR-Review-Agent`)
- Reason: ADO's build policy dropdown lists ALL pipelines in the ADO project. Identical names across repos would be indistinguishable.

## Common Mistakes

- Creating a PR Answer hook in the wrong ADO project (hook won't see repo events)
- Creating a project-scoped PR Answer hook (fires on ALL repos — hundreds of noise events)
- Forgetting to add the repo to `ADO_PR_ANSWER_PIPELINE_MAP` on the PR Router Lambda
- Using identical pipeline names across repos (breaks build policy dropdown)
