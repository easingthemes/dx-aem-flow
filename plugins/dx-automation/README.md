# dx-automation — Autonomous Agent Infrastructure Plugin for Claude Code

Deploys eleven autonomous AI agents (DoR checker, PR reviewer, PR answerer, DoD checker, DoD fixer, BugFix agent, QA agent, DevAgent, DOCAgent, Estimation, SimpleAgent) that run 24/7 as Azure DevOps pipelines. Most are triggered by AWS Lambda webhooks; **SimpleAgent and BugFix are triggered by Azure-native Service Hooks (no Lambda)** — see [Trigger mechanisms](#trigger-mechanisms). Unlike `dx-core`/`dx-aem` which run interactively with you, these agents operate without you — triggered by ADO events and responding automatically.

## Prerequisites

- `dx-core` plugin installed
- AWS CLI configured (`aws sts get-caller-identity` works)
- Azure CLI configured (`az account show` works)

```bash
/plugin marketplace add easingthemes/dx-aem-flow
/plugin install dx-core@dx-aem-flow
```

## Installation

```bash
/plugin install dx-automation@dx-aem-flow
```

## Quick Start

Run these once, in order, to provision and connect the infrastructure:

```bash
/auto-init          # Scaffold .ai/automation/ — generate infra.json, repos.json, .env.template
/auto-provision     # Create AWS resources (DynamoDB, SQS, S3, Lambda, API Gateway)
/auto-pipelines     # Import ADO pipelines + set LLM/ADO variables
/auto-deploy        # Deploy Lambda code
/auto-lambda-env    # Set Lambda env vars (ADO PAT, webhook secrets, table names)
/auto-webhooks      # Configure ADO service hooks + PR Review build policy
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

Two paths start pipelines:

- **AWS Lambda webhook router** — the WI Router (`wi-router.mjs`) and PR Router (`pr-router.mjs`) receive ADO service-hook events via API Gateway, deduplicate, rate-limit, apply the token budget, classify by tag / PR event, and queue the right pipeline. Used by every agent **except** SimpleAgent. (PR Reviewer is the other non-Lambda case: it runs from an ADO **build validation policy**, not a hook.)
- **Azure-native Service Hook** — an ADO Service Hook with a simple subscription filter posts to an **Incoming WebHook service connection** that the pipeline declares under `resources.webhooks`. No AWS infra, nothing to deploy. Used by **SimpleAgent**: event *work item commented on*, filter *comment contains `@kai-simple`* → service connection → `ado-cli-simple.yml`. The same event drives both the first run and recovery; the pipeline's Phase 0 decides fresh-vs-resume.

**Tradeoffs.** The Lambda path adds dedupe (ADO retry storms), per-agent rate limiting, monthly token-budget gating, and central tag-classification (one hook fans out to many pipelines; adding an agent is just env vars). The Azure-native path drops all of that infrastructure in exchange for one Service Hook + one service connection + one `resources.webhooks` block **per agent**, and any loop-prevention / dedupe must live in the pipeline itself. It fits low-frequency, human-initiated agents (a person types `@kai-simple`) better than high-volume autonomous ones.

**Which other pipelines could adopt it?** ADO Service Hooks natively filter on **tag**, **comment text** (contains), **work-item type**, **state/field change**, and **PR events** — so technically any event-driven agent can be triggered this way (each needs its own hook + service connection + pipeline webhook resource):

| Agent | Current trigger | Azure-native option | Notes |
|-------|-----------------|---------------------|-------|
| **SimpleAgent** | `@kai-simple` comment | ✅ in use (reference impl) | comment-contains filter |
| **PR Reviewer** | build validation policy | already Lambda-free | keep policy, or use a "PR created" hook |
| **PR Answerer** | PR comment → Lambda | ✅ "PR commented on" + `@kai-…` filter | but loses the Lambda's cheap identity/loop/dedupe gates — they'd move into the pipeline |
| **DoR / DoD / QA / DevAgent / DOCAgent / Estimation** | tag `KAI-*` + `KAI-TRIGGER` → Lambda | ✅ per-agent hook filtered on the agent tag (or a `@kai-…` comment, or a State transition) | loses dedupe + rate-limit + token-budget governance; one hook + connection per agent |
| **BugFix** | `@kai-bugfix` comment on a Bug | ✅ in use (Azure-native, no Lambda) | comment-contains + Bug-type filter; resumable recovery (triage→verify→fix) |
| **DoD Fixer** | chained after DoD check | n/a | not event-triggered — stays an internal chain |

Recommended migration candidates: **human-initiated, low-volume** agents (like PR Answerer via a `@kai-answer` keyword). Keep the **high-volume autonomous** WI agents on the Lambda router so they retain dedupe, rate-limiting, and the token budget. Full write-up: [Automation Infrastructure → Azure-native Service Hook trigger](../../website/src/pages/architecture/automation-infra.mdx).

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
