# dx-automation — Autonomous Agent Infrastructure Plugin for Claude Code

Deploys eleven autonomous AI agents (DoR checker, PR reviewer, PR answerer, DoD checker, DoD fixer, BugFix agent, QA agent, DevAgent, DOCAgent, Estimation, SimpleAgent) that run 24/7 as Azure DevOps pipelines. Unlike `dx-core`/`dx-aem` which run interactively with you, these agents operate without you — triggered by ADO events and responding automatically.

**Azure-native is the default path, and needs no AWS at all.** An ADO Service Hook posts to an Incoming WebHook service connection that the pipeline declares under `resources.webhooks` — one hook, one connection, no infrastructure to provision, deploy or pay for. The **AWS Lambda router is optional**, for teams that want central tag-classification, cross-agent dedupe, per-agent rate limits and token-budget gating in one place. Start Azure-native; add Lambda only if you hit a governance need it solves. See [Trigger mechanisms](#trigger-mechanisms).

## Prerequisites

- `dx-core` plugin installed
- Azure CLI configured (`az account show` works)
- AWS CLI configured (`aws sts get-caller-identity` works) — **only for the optional Lambda router.**
  Azure-native setups need no AWS account.

```bash
/plugin marketplace add easingthemes/dx-aem-flow
/plugin install dx-core@dx-aem-flow
```

## Installation

```bash
/plugin install dx-automation@dx-aem-flow
```

## Quick Start

### Azure-native (recommended — no AWS)

```bash
/auto-init          # Scaffold .ai/automation/ — generate infra.json, repos.json, .env.template
/auto-pipelines     # Import ADO pipelines + set LLM/ADO variables
/auto-webhooks      # Create the Incoming WebHook service connections + ADO Service Hooks,
                    # and the PR Review build policy
```

`/auto-init` detects an Azure-native-only selection and skips the AWS questions; it will not ask
you to provision or deploy anything.

### With the optional Lambda router

Add these three steps — and `/auto-alarms` for CloudWatch — around the pipeline import:

```bash
/auto-provision     # Create AWS resources (DynamoDB, SQS, S3, Lambda, API Gateway)
/auto-deploy        # Deploy Lambda code
/auto-lambda-env    # Set Lambda env vars (ADO PAT, webhook secrets, table names)
/auto-alarms        # Create CloudWatch alarms + subscribe email to SNS
```

After setup, verify everything works:

```bash
/auto-test dor 12345 --dryRun    # Dry-run DoR agent against a real work item
```

## Skills (11)

### Setup Sequence (run once in order)

| Skill | Description |
|-------|-------------|
| `/auto-init` | Scaffold `.ai/automation/` — config questions, copy data bundle, generate `infra.json` and `repos.json`. No AWS/ADO changes. |
| `/auto-provision` | Create all AWS resources: DynamoDB (3 tables), SQS DLQ, S3 bucket, SNS topic, IAM role, Lambda placeholders, API Gateway. |
| `/auto-pipelines` | Import ADO pipeline YAMLs into Azure DevOps, set all pipeline variables (LLM key, ADO org, wiki URL). |
| `/auto-deploy` | Package and deploy Lambda code for DoR, DoD, PR Answer, BugFix, QA, and/or DevAgent agents. |
| `/auto-lambda-env` | Set Lambda environment variables interactively: ADO PAT, webhook secrets, DynamoDB table names. |
| `/auto-webhooks` | Configure ADO service hooks + PR Review build policy. WI hooks (project-scoped, hub only) + PR Answer hook (per-repo, all profiles) + PR Review policy (per-repo). Consumers run this too. |
| `/auto-alarms` | Create CloudWatch alarms (DLQ depth, Lambda errors, throttles) and subscribe email to SNS alerts. |

### Ongoing Operations

| Skill | Argument | Description |
|-------|----------|-------------|
| `/auto-doctor` | — | Health check: file integrity, infra.json completeness, ADO pipeline state, Lambda function state. |
| `/auto-status` | — | Operational dashboard: DLQ depth, monthly token budget utilization, daily rate limit usage. |
| `/auto-eval` | `[--all \| --agent X \| --tier2 \| --fixture name]` | Run evaluation framework against test fixtures. Use after changing prompts or agent logic. |
| `/auto-test` | `<agent> <id> [--dryRun]` | Local dry-run against real ADO data — verifies end-to-end connectivity without posting results. |

## What Gets Deployed

Eleven autonomous agents:

| Agent | Trigger | What it does |
|-------|---------|--------------|
| **DoR checker** | Work item state change (ADO webhook → Lambda) | Checks Definition of Ready criteria, posts ADO comment with pass/fail |
| **PR reviewer** | ADO build validation policy | Reviews PR diff, posts structured review comments |
| **PR answerer** | PR comment event (ADO webhook → Lambda) | Reads open PR comments, posts context-aware replies |
| **DoD checker** | Work item tag `KAI-DOD-AUTOMATION` (ADO webhook → Lambda) | Checks Definition of Done criteria, posts pass/fail report |
| **DoD fixer** | Chained after DoD check failures | Auto-fixes what's possible, creates ADO tasks for the rest |
| **BugFix agent** | Bug comment contains `@kai-bugfix` (Azure-native Service Hook → pipeline Incoming WebHook, **no Lambda**) | Triages Bug, applies fix, creates PR — resumable (triage→verify→fix) |
| **QA agent** | Work item tag `KAI-QA-AUTOMATION` (ADO webhook → Lambda) | Browser-based QA, screenshots, creates Bug tickets |
| **DevAgent** | Work item tag `KAI-DEV-AUTOMATION` (ADO webhook → Lambda) | Full autonomous development: requirements → plan → implement → test → review → commit → PR. Supports Figma design-to-code. |
| **DOCAgent** | Work item tag `KAI-DOC-AUTOMATION` (ADO webhook → Lambda) | Generate wiki documentation + AEM authoring guides with screenshots |
| **Estimation** | Work item tag `KAI-ESTIMATION-AUTOMATION` (ADO webhook → Lambda) | Estimate story points by analyzing codebase complexity |
| **SimpleAgent** | `@kai-simple` comment → **Azure-native Service Hook** (no Lambda); same event starts the first run and recovery | Apply small AEM change (a11y label / color / spacing / copy) via authoring (AEM MCP write) OR code (file edits → PR) split. 9 confidence gates. ≤5 files / ≤50 lines / ≤10 JCR writes. |

These run as ADO pipelines (YAML). For ten agents the Lambda router receives ADO webhooks via API Gateway, enqueues to SQS, and triggers the correct pipeline. **SimpleAgent is the exception** — it has no Lambda in its path (see below).

## Trigger mechanisms

Two paths start pipelines. **Azure-native is the default and is sufficient on its own** — the
reference projects run this way, with no AWS account involved.

- **Azure-native Service Hook (default).** An ADO Service Hook with a subscription filter posts to
  an **Incoming WebHook service connection** that the pipeline declares under `resources.webhooks`.
  Nothing to provision, deploy, pay for or monitor; the trigger is visible and debuggable in the ADO
  UI. Cost per agent: one Service Hook + one service connection + one `resources.webhooks` block.
  Loop-prevention and dedupe live in the pipeline (the shipped pipelines dedupe on the work-item
  revision, which increments per comment).
- **AWS Lambda webhook router (optional).** The WI Router (`wi-router.mjs`) and PR Router
  (`pr-router.mjs`) receive ADO service-hook events via API Gateway, deduplicate in DynamoDB,
  rate-limit, apply the token budget, classify by tag / PR event, and queue the right pipeline.
  Choose it when you want that governance centralised, or when one hook fanning out to many
  pipelines beats one hook per agent — adding an agent then costs only new env vars.

**Which to pick.** Default to Azure-native. Reach for Lambda when you need cross-agent dedupe
against ADO retry storms, per-agent or per-identity rate limits, monthly token-budget gating, or a
single hook fanning out to many pipelines. It is the granular-control option, not the starting
point.

**Multi-repo.** `ado-cli-hub.yml` is the Azure-native equivalent of the WI Router: one
`@kai-<agent>` comment fires the hub, which resolves the agent from
`.ai/automation/registries/agents.json`, dedupes against recent worker runs, runs
`/dx-discover-repos`, and fans the agent's worker pipeline out once per resolved repo. Multi-repo
projects therefore do not need Lambda either.

### Per-pipeline trigger status

Azure-native listeners that ship today (`resources.webhooks` in the pipeline YAML):
`ado-cli-simple.yml`, `ado-cli-bug-fix.yml`, `ado-cli-dor.yml`, `ado-cli-hub.yml`.

| Agent | Ships with its own Azure-native listener | How it runs without Lambda |
|-------|------------------------------------------|----------------------------|
| **SimpleAgent** | ✅ `@kai-simple` comment | direct; same event covers first run and recovery (Phase 0 decides) |
| **BugFix** | ✅ `@kai-bugfix` comment on a Bug | direct; resumable recovery over triage→verify→fix |
| **DoR** | ✅ `@kai-dor` comment on a User Story | direct; stateless check, no recovery |
| **Hub router** | ✅ `@kai-<agent>` comment | fans out to any worker pipeline (multi-repo) |
| **PR Reviewer** | n/a | ADO **build validation policy** — never used Lambda |
| **DoD / DoD fixer / QA / DevAgent / DOCAgent / Estimation** | ❌ not yet | via the hub router, or a manual pipeline run. A per-agent hook needs a `resources.webhooks` block added to each YAML (mechanical — mirror `ado-cli-dor.yml`) |
| **PR Answerer** | ❌ not yet | Lambda today. An Azure-native port also has to move the PR-Router's identity / self-comment / bot-loop gates into the pipeline |

So: three agents plus the multi-repo router are Azure-native out of the box, PR Reviewer never
needed AWS, and the remaining seven are reachable today through the hub router or a manual run.
Closing the last two rows is tracked work, not a design limit.

## Configuration

`/auto-init` generates `.ai/automation/infra.json` (resource IDs written by each setup skill) and prompts for:

```yaml
# infra.json (generated)
{
  "resourcePrefix": "myproject-automation",
  "region": "eu-west-1",
  "ado": {
    "orgUrl": "https://myorg.visualstudio.com",
    "project": "My Project",
    "wikiUrl": "https://myorg.visualstudio.com/wiki"
  },
  "repos": [...],
  "database": { "dynamo": { ... } },
  "queue": { "sqs": { ... } },
  "storage": { "s3": { ... } },
  "compute": { "lambda": { ... } },
  "api": { "gateway": { ... } },
  "alerts": { "sns": { ... } }
}
```

`repos.json` lists the ADO repositories each agent monitors.

## Pipeline YAML Templates

Pipeline YAML files in `data/pipelines/cli/` fetch dx-aem-flow plugin sources from the public GitHub repo (`https://github.com/easingthemes/dx-aem-flow`, `main` branch) at run time via `git clone`, then load them through the Claude Agent SDK's `plugins:` option (`PLUGIN_BASE_DIR` points at the cloned checkout). No template-placeholder substitution and no ADO mirror repo are required. The `pipeline-agent.js` entry point reads `ADO_ORG_NAME` from environment (falls back to `"myorg"`).

## Audit Logging

All mutating AWS and Azure operations use audit wrappers from `.ai/lib/audit.sh` (installed by `dx-init`). Every create/update/delete is logged to `.ai/logs/infra.<week>.jsonl` with timestamp, resource type, and outcome. Read-only operations (`list`, `show`, `get`) are not logged.

## License

MIT
