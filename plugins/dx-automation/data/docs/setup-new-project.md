# Setting Up AI Automation for a New Project

This guide walks through adopting the `.ai/automation` agent system in a new project. The system runs on Azure DevOps Pipelines + AWS Lambda and supports ten agents: DoR Checklist, DoD Check, DoD Fix, PR Review, PR Answer, BugFix, QA, DevAgent, DOCAgent, and Estimation.

> **Preferred setup method:**
> - **Hub:** `/auto-init` → `/auto-provision` → `/auto-pipelines` → `/auto-deploy` → `/auto-lambda-env` → `/auto-webhooks` → `/auto-alarms`
> - **Consumer:** `/auto-init` → `/auto-pipelines` → register with hub → `/auto-webhooks`
>
> The skills automate most of the steps below. This manual guide is for understanding the infrastructure or troubleshooting.

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Node.js | v20+ | Agent step scripts, local runner |
| Python 3 | 3.8+ | JSON parsing in shell scripts |
| Azure CLI + azure-devops extension | latest | Pipeline management |
| AWS CLI | v2 | Lambda deploy |
| zip | any | Lambda packaging |

Run `.ai/automation/setup-cli.sh` to install Azure CLI extension and authenticate.

---

## Step 1: Fill in `infra.json`

```bash
cp .ai/automation/infra.template.json .ai/automation/infra.json
```

Open `infra.json` and replace every `{{PLACEHOLDER}}` value. Key decisions:

| Placeholder | What to put | Where to find it |
|-------------|-------------|-----------------|
| `{{ADO_ORG_URL}}` | `https://yourorg.visualstudio.com` | ADO > Organization Settings > URL |
| `{{ADO_PROJECT}}` | Your ADO project name | ADO project homepage |
| `{{AWS_REGION}}` | `us-east-1` (or your region) | Your AWS team's standard |
| `{{AWS_ACCOUNT_ID}}` | 12-digit account number | `aws sts get-caller-identity` |
| `{{PIPELINE_NAME_PREFIX}}` | `KAI` (hub) or `KAI-<RepoShortName>` (consumer) | Must be unique across repos in same ADO project |
| `{{RESOURCE_PREFIX}}` | Same prefix in lowercase (e.g. `myai`) | Used for DynamoDB/SQS/S3 resource names |
| `{{PIPELINE_FOLDER}}` | `\KAI` (optional) | ADO pipeline folder for organization |
| `{{API_GATEWAY_ID}}` | Fill in after Step 4 | AWS Console > API Gateway |
| `{{DOR_PIPELINE_ID}}` etc. | Fill in after Step 3 | ADO > Pipelines > pipeline > Edit > URL |

Remove all `_*_comment` fields before committing — they are documentation only.

---

## Step 2: Update `repos.json`

```bash
cp .ai/automation/repos.template.json repos-template-reference.json
```

Edit `.ai/automation/repos.json` and replace its contents with your project's repositories. The DoR agent uses this catalog to discover which repos to search for a given work item.

Good `description` fields significantly improve discovery accuracy — include tech stack details, component types, brands/markets, and team scope.

---

## Step 3: Import Pipelines to ADO

Import each YAML pipeline file into ADO:

1. **Create a pipeline folder** (optional but recommended): ADO > Pipelines > Manage folders > New folder. Use the prefix from infra.json (e.g. `\KAI`). Record the folder path in `infra.json` as `pipelineFolder`.
2. ADO > Pipelines > New pipeline > Azure Repos Git > select your repo > Existing Azure Pipelines YAML file
3. Set the path to the YAML file, e.g. `.ai/automation/pipelines/cli/ado-cli-dor.yml`
4. Save (don't run yet). If you created a folder, move the pipeline there.
5. Record the pipeline definition ID from the URL (`?definitionId=XXXXX`)
6. Update `infra.json` with each pipeline ID

Pipeline YAML files to import:

- `pipelines/cli/ado-cli-dor.yml` → DoR Agent
- `pipelines/cli/ado-cli-pr-review.yml` → PR Review Agent
- `pipelines/cli/ado-cli-pr-answer.yml` → PR Answer Agent
- `pipelines/eval/ado-eval-pipeline.yml` → Eval Gates
- `pipelines/cli/ado-cli-dod.yml` → DoD Agent
- `pipelines/cli/ado-cli-dod-fix.yml` → DoD Fix Agent
- `pipelines/cli/ado-cli-bug-fix.yml` → BugFix Agent
- `pipelines/cli/ado-cli-qa.yml` → QA Agent
- `pipelines/cli/ado-cli-dev-agent.yml` → DevAgent
- `pipelines/cli/ado-cli-doc-agent.yml` → DOCAgent
- `pipelines/cli/ado-cli-estimation.yml` → Estimation Agent

---

## Step 4: Provision AWS Infrastructure

Your infra team needs to create these resources (names come from your `infra.json`):

**DynamoDB tables** (all with on-demand billing):
- `{prefix}-dedupe` — partition key: `eventId` (String), TTL attribute: `ttl`
- `{prefix}-rate-limits` — partition key: `pk` (String), sort key: `sk` (String)
- `{prefix}-token-budget` — partition key: `pk` (String), sort key: `sk` (String)

**SQS queue** (standard):
- `{prefix}-dlq` — 14-day message retention

**S3 bucket**:
- `{prefix}-bundles-{account-id}` — lifecycle rule: delete after 90 days

**SNS topic**:
- `{prefix}-alerts` — subscribe your team's email

**API Gateway** (HTTP API v2):
- Name: `{PIPELINE_NAME_PREFIX}-Agent`
- Routes: `POST /wi` (→ WI Router Lambda, tag-based routing), `POST /pr-answer` (→ PR Router Lambda)
- Stage: `prod` (named stage)

Record the API Gateway ID in `infra.json`.

**IAM execution role** for Lambda:
- Must allow: `dynamodb:GetItem`, `dynamodb:PutItem`, `dynamodb:UpdateItem`, `dynamodb:Query` on your 3 tables
- Must allow: `sqs:SendMessage` on your DLQ
- Must allow: `s3:PutObject` on your bundle bucket

---

## Step 5: Deploy Lambda Functions

```bash
cd .ai/automation

# Deploy all Lambdas (reads function names from infra.json)
source ../../.ai/lib/audit.sh
lambda/deploy.sh all
```

The deploy script zips each handler + shared libs and calls `aws lambda update-function-code`. If the functions don't exist yet, create them in AWS Console first with:
- Runtime: Node.js 20.x
- Handler: `wi-router.handler` (WI Router), `pr-router.handler` (PR Router)
- Memory: 256 MB, Timeout: 30s
- Execution role: the IAM role from Step 4

There are only 2 Lambda functions:
- **WI Router** — receives all work item webhook events and routes to the correct pipeline based on the agent tag
- **PR Router** — receives PR comment webhook events and routes to the correct repo's PR Answer pipeline

After deploying, link each Lambda to the API Gateway routes in AWS Console.

---

## Step 6: Configure Pipeline Variables

In ADO, configure variables for each pipeline (Pipelines > pipeline > Edit > Variables). Use `/auto-pipelines` to automate this.

**All pipelines need:**

| Variable | Secret? | Description |
|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | Yes | Claude API key for Claude Code CLI |
| `ADO_ORG_URL` | No | ADO org URL (e.g. `https://yourorg.visualstudio.com`) |
| `DX_MARKETPLACE_URL` | No | Git URL for plugin marketplace repo (e.g. `https://org@dev.azure.com/org/project/_git/repo.git#branch`) |

**DoR additionally:** `DOR_WIKI_URL` — ADO wiki URL with Definition of Ready criteria.

**PR Review additionally:** `REVIEWER_IDENTITIES` — comma-separated ADO identities (`email,Display Name`).

**PR Answer additionally:** `MY_IDENTITIES` — comma-separated ADO identities.

**Code-writing pipelines (DoD Fix, BugFix, DevAgent) additionally:**

| Variable | Description |
|----------|-------------|
| `CROSS_REPO_PIPELINE_MAP` | JSON mapping repo names to pipeline IDs: `{"Other-Repo":"789"}` |

**QA and DOCAgent additionally:** `AEM_AUTHOR_URL`, `AEM_PUBLISH_URL`, `AEM_USER`, `AEM_PASS`.

**DevAgent additionally:** `FIGMA_PERSONAL_ACCESS_TOKEN` (secret).

---

## Step 7: Configure Lambda Environment Variables

In AWS Console > Lambda > each function > Configuration > Environment variables. Use `/auto-lambda-env` to set these interactively.

**Both Lambdas need (shared variables):**

| Variable | Value |
|----------|-------|
| `BASIC_USER` | Choose a webhook username (must match ADO Service Hook) |
| `BASIC_PASS` | Choose a webhook password (secret, must match ADO Service Hook) |
| `WEBHOOK_SECRET` | Choose a shared secret (must match ADO Service Hook header) |
| `ADO_PAT` | Your ADO Personal Access Token |
| `DYNAMODB_DEDUPE_TABLE` | From `infra.json` > `storage.dynamodb.dedupe.tableName` |
| `DYNAMODB_RATE_LIMIT_TABLE` | From `infra.json` > `storage.dynamodb.rateLimits.tableName` |
| `SQS_DLQ_URL` | From `infra.json` > `storage.sqs.dlq.queueUrl` |

**WI Router additional variables:**

| Variable | Value |
|----------|-------|
| `ADO_DOR_PIPELINE_ID` | Pipeline ID from `infra.json` |
| `ADO_DOD_PIPELINE_ID` | Pipeline ID from `infra.json` |
| `ADO_BUGFIX_PIPELINE_ID` | Pipeline ID from `infra.json` |
| `ADO_QA_PIPELINE_ID` | Pipeline ID from `infra.json` |
| `ADO_DEV_PIPELINE_ID` | Pipeline ID from `infra.json` |
| `ADO_DOC_PIPELINE_ID` | Pipeline ID from `infra.json` |
| `ADO_ESTIMATION_PIPELINE_ID` | Pipeline ID from `infra.json` |
| `TAG_GATE_*` | Tag names that trigger each agent (e.g. `TAG_GATE_DOR`, `TAG_GATE_DOD`, `TAG_GATE_ESTIMATION`, etc.) |

**PR Router additional variables:**

| Variable | Value |
|----------|-------|
| `ADO_ORG_URL` | ADO org URL |
| `ADO_PR_ANSWER_PIPELINE_MAP` | JSON: `{"repo-name":"pipeline-id"}` |
| `MY_IDENTITIES` | Same as pipeline variable |

---

## Step 8: Configure ADO Service Hooks

Service hooks have different scopes depending on type:

- **WI hooks** — project-scoped, created once by the hub (tag-based routing)
- **PR Answer hook** — **per-repo**, filtered to specific repository + base branch
- **PR Review** — build validation policy (per-repo, per-branch)

### WI Hooks (hub only — skip for consumers)

**User Story WI Hook** (ADO > Project Settings > Service Hooks > + Create subscription):

| Field | Value |
|-------|-------|
| Service | Web Hooks |
| Event | Work item updated |
| Work item type | User Story |
| URL | From `infra.json` > `webhooks.wi-userstory.url` |
| Basic auth username | Same as Lambda `BASIC_USER` |
| Basic auth password | Same as Lambda `BASIC_PASS` |
| HTTP headers | `x-webhook-secret: (same as Lambda WEBHOOK_SECRET)` |

This single hook handles DoR, DoD, QA, DevAgent, and DOCAgent — the Lambda checks which tag is present and queues the correct pipeline.

**Bug WI Hook**: Same as above but with `Work item type: Bug`. Handles BugFix agent.

### PR Answer Service Hook (all repos — hub AND each consumer)

Each repo creates its own hook filtered to that repository and base branch. Without repo filtering, a project-scoped hook fires on every PR comment across all repos in the ADO project.

| Field | Value |
|-------|-------|
| Event | Pull request commented on |
| Repository | **This repo only** (select from dropdown) |
| Target branch | Your base branch (e.g., `development`) |
| URL | Hub: from `infra.json` > `webhooks.pr-answer.url`. Consumer: the hub's PR Router Lambda URL. |
| Auth/headers | Same as WI hook |

The PR Router Lambda uses `ADO_PR_ANSWER_PIPELINE_MAP` to route events to the correct repo's PR Answer pipeline.

### PR Review Build Validation Policy (all repos)

No Service Hook needed — configure as a **Build Validation policy** on your target branch (ADO > Repos > Branches > branch > Branch policies > Build Validation). Select your repo's `KAI-*` PR Review pipeline.

---

## Step 9: Set Up Monitoring

```bash
cd .ai/automation
source ../../.ai/lib/audit.sh
lambda/cloudwatch/setup-alarms.sh --email your-team@example.com
```

This creates 4 CloudWatch alarms routing to the SNS topic in `infra.json`.

---

## Step 10: Smoke Test

```bash
# Create a .env file at repo root with:
# AZURE_DEVOPS_PAT=<your-pat>
# ANTHROPIC_API_KEY=<your-key>

# Run eval framework locally
.ai/automation/run.sh eval --all
```

---

## Customize: Policy

Edit `.ai/automation/policy/pipeline-policy.yaml` to adjust:
- Rate limits per pipeline
- Allowed capabilities per agent role
- Risk level thresholds
- Redaction patterns (add project-specific sensitive field names)

---

## Need Help?

- `CONFIGURATION.md` — detailed reference for all configuration options
- `docs/runbook.md` — diagnosing failures and operational alerts
- `docs/onboarding.md` — developer setup for day-to-day use
- `eval/` — run `node eval/run.js --all` to verify agent quality
