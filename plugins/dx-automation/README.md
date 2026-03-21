# dx-automation — Autonomous Agent Infrastructure Plugin for Claude Code

Deploys ten autonomous AI agents (DoR checker, PR reviewer, PR answerer, DoD checker, DoD fixer, BugFix agent, QA agent, DevAgent, DOCAgent, Estimation) that run 24/7 as Azure DevOps pipelines triggered by AWS Lambda webhooks. Unlike `dx-dev-experience`/`dx-aem` which run interactively with you, these agents operate without you — triggered by ADO events and responding automatically.

## Prerequisites

- `dx-dev-experience` plugin installed
- AWS CLI configured (`aws sts get-caller-identity` works)
- Azure CLI configured (`az account show` works)

```bash
/plugin marketplace add easingthemes/dx-aem-ai-flow
/plugin install dx-dev-experience@dx-aem-ai-flow
```

## Installation

```bash
/plugin install dx-automation@dx-aem-ai-flow
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

Ten autonomous agents:

| Agent | Trigger | What it does |
|-------|---------|--------------|
| **DoR checker** | Work item state change (ADO webhook → Lambda) | Checks Definition of Ready criteria, posts ADO comment with pass/fail |
| **PR reviewer** | ADO build validation policy | Reviews PR diff, posts structured review comments |
| **PR answerer** | PR comment event (ADO webhook → Lambda) | Reads open PR comments, posts context-aware replies |
| **DoD checker** | Work item tag `KAI-DOD-AUTOMATION` (ADO webhook → Lambda) | Checks Definition of Done criteria, posts pass/fail report |
| **DoD fixer** | Chained after DoD check failures | Auto-fixes what's possible, creates ADO tasks for the rest |
| **BugFix agent** | Work item tag `KAI-BUGFIX-AUTOMATION` (ADO webhook → Lambda) | Triages Bug, applies fix, creates PR |
| **QA agent** | Work item tag `KAI-QA-AUTOMATION` (ADO webhook → Lambda) | Browser-based QA, screenshots, creates Bug tickets |
| **DevAgent** | Work item tag `KAI-DEV-AUTOMATION` (ADO webhook → Lambda) | Full autonomous development: requirements → plan → implement → test → review → commit → PR. Supports Figma design-to-code. |
| **DOCAgent** | Work item tag `KAI-DOC-AUTOMATION` (ADO webhook → Lambda) | Generate wiki documentation + AEM authoring guides with screenshots |
| **Estimation** | Work item tag `KAI-ESTIMATION-AUTOMATION` (ADO webhook → Lambda) | Estimate story points by analyzing codebase complexity |

These run as ADO pipelines (YAML) invoked by Lambda. The Lambda receives ADO webhooks via API Gateway, enqueues to SQS, and triggers the correct pipeline.

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

Pipeline YAML files in `data/pipelines/cli/` use `{{ADO_PROJECT}}/{{ADO_REPO}}` placeholders for the repository reference. These are filled by `/auto-pipelines` during import based on `infra.json` values. The `pipeline-agent.js` entry point reads `ADO_ORG_NAME` from environment (falls back to `"myorg"`).

## Audit Logging

All mutating AWS and Azure operations use audit wrappers from `.ai/lib/audit.sh` (installed by `dx-init`). Every create/update/delete is logged to `.ai/logs/infra.<week>.jsonl` with timestamp, resource type, and outcome. Read-only operations (`list`, `show`, `get`) are not logged.

## License

MIT
