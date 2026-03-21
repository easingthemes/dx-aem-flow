---
name: auto-lambda-env
description: Set environment variables on AI automation Lambda functions. Interactively collects secrets and operational values, then applies them via AWS CLI. Reads function names and pre-filled values from .ai/automation/infra.json.
argument-hint: ""
---

You set Lambda environment variables for the AI automation agents. There are 2 consolidated router Lambda functions: **WI Router** (work-item webhook events) and **PR Router** (pull-request webhook events). Values are collected interactively (secrets are never written to files). Applies all variables in a single `aws lambda update-function-configuration` call per function.

## 0. Prerequisites

Read `.ai/automation/infra.json`. Check `automationProfile`:
- If `consumer` (or legacy `pr-only`/`pr-delegation`): "This repo uses the consumer profile — Lambda environment variables are managed by the hub project. Do NOT modify Lambda env vars from this repo." **STOP.**

```bash
source .ai/lib/audit.sh
export AUDIT_LOG_PREFIX=infra
```

Pre-fill these from infra.json (don't ask for values already known):
- `DYNAMODB_DEDUPE_TABLE` ← `storage.dynamodb.dedupe.tableName`
- `DYNAMODB_RATE_LIMIT_TABLE` ← `storage.dynamodb.rateLimits.tableName`
- `SQS_DLQ_URL` ← `storage.sqs.dlq.queueUrl`
- `ADO_DOR_PIPELINE_ID` ← `pipelines.dor.id` (WI Router)
- `ADO_DOD_PIPELINE_ID` ← `pipelines.dod.id` (WI Router)
- `ADO_BUGFIX_PIPELINE_ID` ← `pipelines.bugfix.id` (WI Router)
- `ADO_QA_PIPELINE_ID` ← `pipelines.qa.id` (WI Router)
- `ADO_DEV_PIPELINE_ID` ← `pipelines.devagent.id` (WI Router)
- `ADO_DOC_PIPELINE_ID` ← `pipelines.docagent.id` (WI Router)
- `ADO_ESTIMATION_PIPELINE_ID` ← `pipelines.estimation.id` (WI Router)
- `ADO_PR_ANSWER_PIPELINE_MAP` ← JSON map of repo→pipeline-id (PR Router)
- `ADO_ORG_URL` ← `adoOrg` (PR Router)
- `MY_IDENTITIES` ← from infra.json if set (PR Router)

## 1. Collect Secrets

Ask these **one at a time** — these cannot be pre-filled from infra.json:

> **ADO Personal Access Token?** (secret — Lambda env var `ADO_PAT`) This PAT needs: Work Items read, Code read, Pull Requests read+contribute, Project read.

> **Webhook basic auth username?** (Lambda env var `BASIC_USER`) Example: `automation-webhook`. Must match what you'll set in ADO Service Hooks.

> **Webhook basic auth password?** (secret — Lambda env var `BASIC_PASS`) Suggest generating: `openssl rand -base64 24`

> **Webhook secret?** (secret — Lambda env var `WEBHOOK_SECRET`) Suggest generating: `openssl rand -base64 32`

> **DoR trigger tag?** (Lambda env var `TAG_GATE_DOR` — WI Router) Tag name that triggers the DoR agent. Example: `AI-TRIGGER`. Default: `<UPPERCASE-PREFIX>-AI-TRIGGER`

> **DoD trigger tag?** (Lambda env var `TAG_GATE_DOD` — WI Router) Default: `KAI-DOD-AUTOMATION`

> **BugFix trigger tag?** (Lambda env var `TAG_GATE_BUGFIX` — WI Router) Default: `KAI-BUGFIX-AUTOMATION`

> **QA trigger tag?** (Lambda env var `TAG_GATE_QA` — WI Router) Default: `KAI-QA-AUTOMATION`

> **DevAgent trigger tag?** (Lambda env var `TAG_GATE_DEV` — WI Router) Default: `KAI-DEV-AUTOMATION`

> **DOCAgent trigger tag?** (Lambda env var `TAG_GATE_DOC` — WI Router) Default: `KAI-DOC-AUTOMATION`

> **Estimation trigger tag?** (Lambda env var `TAG_GATE_ESTIMATION` — WI Router) Default: `KAI-ESTIMATION-AUTOMATION`

## 2. Apply to WI Router Lambda

The WI Router (`<PREFIX>-WI-Router`) handles all work-item webhook events and routes to the appropriate pipeline (DoR, DoD, BugFix, QA, DevAgent, DOCAgent, Estimation) based on tag gates.

```bash
WI_ROUTER_FUNC=$(python3 -c "import json; print(json.load(open('.ai/automation/infra.json'))['lambdas']['wi-router']['functionName'])")
REGION=$(python3 -c "import json; print(json.load(open('.ai/automation/infra.json'))['region'])")

aws_lambda_config "$WI_ROUTER_FUNC" \
  --environment "Variables={
    ADO_PAT=<secret>,
    BASIC_USER=<user>,
    BASIC_PASS=<secret>,
    WEBHOOK_SECRET=<secret>,
    ADO_DOR_PIPELINE_ID=<pipeline-id>,
    ADO_DOD_PIPELINE_ID=<pipeline-id>,
    ADO_BUGFIX_PIPELINE_ID=<pipeline-id>,
    ADO_QA_PIPELINE_ID=<pipeline-id>,
    ADO_DEV_PIPELINE_ID=<pipeline-id>,
    ADO_DOC_PIPELINE_ID=<pipeline-id>,
    ADO_ESTIMATION_PIPELINE_ID=<pipeline-id>,
    TAG_GATE_DOR=<tag>,
    TAG_GATE_DOD=<tag>,
    TAG_GATE_BUGFIX=<tag>,
    TAG_GATE_QA=<tag>,
    TAG_GATE_DEV=<tag>,
    TAG_GATE_DOC=<tag>,
    TAG_GATE_ESTIMATION=<tag>,
    DYNAMODB_DEDUPE_TABLE=<table>,
    DYNAMODB_RATE_LIMIT_TABLE=<table>,
    SQS_DLQ_URL=<url>
  }" \
  --region "$REGION"
```

## 3. Apply to PR Router Lambda (merge-safe)

The PR Router (`<PREFIX>-PR-Router`) handles all pull-request webhook events. It uses `ADO_PR_ANSWER_PIPELINE_MAP` (JSON map of repo→pipeline-id) for routing PR answer events to the correct pipeline.

```bash
PR_ROUTER_FUNC=$(python3 -c "import json; print(json.load(open('.ai/automation/infra.json'))['lambdas']['pr-router']['functionName'])")

aws_lambda_config "$PR_ROUTER_FUNC" \
  --environment "Variables={
    ADO_PAT=<secret>,
    BASIC_USER=<user>,
    BASIC_PASS=<secret>,
    WEBHOOK_SECRET=<secret>,
    ADO_ORG_URL=<adoOrg>,
    ADO_PR_ANSWER_PIPELINE_MAP=<json-map>,
    MY_IDENTITIES=<identities>,
    DYNAMODB_DEDUPE_TABLE=<table>,
    DYNAMODB_RATE_LIMIT_TABLE=<table>,
    SQS_DLQ_URL=<url>
  }" \
  --region "$REGION"
```

**Important:** `aws lambda update-function-configuration` replaces ALL env vars. Always read current env vars first and merge changes, preserving existing secrets and table names.

## 4. Verify

```bash
# List env var KEYS only (not values — never print secrets)
for FUNC in "$WI_ROUTER_FUNC" "$PR_ROUTER_FUNC"; do
  echo "=== $FUNC ==="
  aws lambda get-function-configuration \
    --function-name "$FUNC" --region "$REGION" \
    --query 'Environment.Variables' --output json | python3 -c "
import sys, json
d = json.load(sys.stdin)
for k in sorted(d.keys()):
    print(f'  {k}: [set]')
"
done
```

## 5. Summary Report

```markdown
## Lambda Environment Variables Set

| Variable | WI Router | PR Router |
|----------|-----------|-----------|
| ADO_PAT | ✓ | ✓ |
| BASIC_USER | ✓ | ✓ |
| BASIC_PASS | ✓ | ✓ |
| WEBHOOK_SECRET | ✓ | ✓ |
| ADO_DOR_PIPELINE_ID | ✓ | — |
| ADO_DOD_PIPELINE_ID | ✓ | — |
| ADO_BUGFIX_PIPELINE_ID | ✓ | — |
| ADO_QA_PIPELINE_ID | ✓ | — |
| ADO_DEV_PIPELINE_ID | ✓ | — |
| ADO_DOC_PIPELINE_ID | ✓ | — |
| ADO_ESTIMATION_PIPELINE_ID | ✓ | — |
| ADO_PR_ANSWER_PIPELINE_MAP | — | ✓ |
| ADO_ORG_URL | — | ✓ |
| MY_IDENTITIES | — | ✓ |
| TAG_GATE_DOR | ✓ | — |
| TAG_GATE_DOD | ✓ | — |
| TAG_GATE_BUGFIX | ✓ | — |
| TAG_GATE_QA | ✓ | — |
| TAG_GATE_DEV | ✓ | — |
| TAG_GATE_DOC | ✓ | — |
| TAG_GATE_ESTIMATION | ✓ | — |
| DYNAMODB_DEDUPE_TABLE | ✓ | ✓ |
| DYNAMODB_RATE_LIMIT_TABLE | ✓ | ✓ |
| SQS_DLQ_URL | ✓ | ✓ |

**Audit log:** `.ai/logs/infra.<week>.jsonl`

### Next step
`/auto-webhooks` — Configure ADO service hooks
```

## Examples

1. `/auto-lambda-env` — Reads `infra.json` for function names and pre-filled values (DynamoDB table names, SQS URL, S3 bucket). Asks interactively for secrets (ADO PAT, Anthropic API key). Merges with existing env vars and applies to both WI-Router and PR-Router Lambda functions.

2. `/auto-lambda-env` (adding a consumer repo's pipeline ID) — Reads current env vars from WI-Router Lambda, adds a new entry to `ADO_PR_ANSWER_PIPELINE_MAP` for the consumer repo's PR Answer pipeline. Preserves all existing values and applies the merged configuration.

3. `/auto-lambda-env` (updating expired ADO PAT) — Asks for the new ADO PAT value. Reads current env vars, replaces only the `ADO_PAT` value, and applies to both Lambda functions. All other env vars remain unchanged.

## Troubleshooting

- **"update-function-configuration replaces ALL env vars" warning**
  **Cause:** AWS Lambda's update API replaces the entire environment variable set, not individual values.
  **Fix:** The skill always reads current env vars first and merges changes. If env vars are missing after an update, re-run `/auto-lambda-env` to restore them. Check the audit log for what was applied.

- **Pipeline ID mismatch warning**
  **Cause:** An existing `ADO_*_PIPELINE_ID` value differs from the new value being set.
  **Fix:** Review the warning message — it shows old vs new values. If the pipeline was re-created, confirm the update. If the IDs should match, check `/auto-pipelines` output for the correct ID.

- **Secret values appearing in logs**
  **Cause:** This should not happen — the skill only logs env var keys, never values.
  **Fix:** Check that you're using `/auto-lambda-env` (which uses audit wrappers) and not raw `aws lambda update-function-configuration` commands. The audit log records the operation but not secret values.

## Rules

- **Always source audit.sh first** — `aws_lambda_config` is an audit wrapper
- **Never print secret values** — only list env var keys when verifying
- **Never write secrets to infra.json** — only non-secret pre-filled values come from infra.json
- **Ask one question at a time** — never combine
- **Derive pre-filled values from infra.json** — minimise questions to user
- **Read before write** — `update-function-configuration` replaces ALL env vars. Always read current env vars first and merge changes
- **Warn on pipeline ID overwrite** — if an existing `ADO_*_PIPELINE_ID` differs from the new value, warn the user: "Pipeline ID will change from <old> to <new>. Proceed?" Skip if values match.
