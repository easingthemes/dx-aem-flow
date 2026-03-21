---
name: auto-provision
description: Create all AWS resources for AI automation agents — DynamoDB tables, SQS queue, S3 bucket, SNS topic, IAM role, Lambda functions, and API Gateway. Reads config from .ai/automation/infra.json. Idempotent — skips already-existing resources.
argument-hint: ""
---

You create all AWS resources required by the AI automation agents. Everything is audit-logged via `audit.sh`. All resource names and config come from `.ai/automation/infra.json`.

## 0. Prerequisites

Read `.ai/automation/infra.json`. Check `automationProfile`:
- If `consumer` (or legacy `pr-only`/`pr-delegation`): "This repo uses the consumer profile — AWS resources are managed by the hub project. Do NOT provision AWS resources from this repo." **STOP.**

```bash
source .ai/lib/audit.sh
export AUDIT_LOG_PREFIX=infra
```

Extract and display:
- `region` — AWS region
- `storage.dynamodb.dedupe.tableName` — DynamoDB dedupe table name
- `storage.dynamodb.rateLimits.tableName`
- `storage.dynamodb.tokenBudget.tableName`
- `storage.sqs.dlq.queueName`
- `storage.s3.bundles.bucketName`
- `monitoring.snsTopic.name`
- `lambdas.wi-router.functionName`, `lambdas.pr-router.functionName`
- `apiGateway.name`

Confirm: "Ready to create these resources in `<region>`. Proceed?"

## 1. DynamoDB Tables

Create 3 tables (skip if already exists — catch `ResourceInUseException`):

```bash
# Dedupe table (TTL-enabled)
aws_resource "dynamodb/<dedupe-table>" \
  aws dynamodb create-table \
    --table-name "<prefix>-dedupe" \
    --attribute-definitions AttributeName=eventId,AttributeType=S \
    --key-schema AttributeName=eventId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"

aws_resource "dynamodb/<dedupe-table>/ttl" \
  aws dynamodb update-time-to-live \
    --table-name "<prefix>-dedupe" \
    --time-to-live-specification Enabled=true,AttributeName=ttl \
    --region "$REGION"

# Rate limits table (pk + sk composite key)
aws_resource "dynamodb/<rate-limits-table>" \
  aws dynamodb create-table \
    --table-name "<prefix>-rate-limits" \
    --attribute-definitions AttributeName=pk,AttributeType=S AttributeName=sk,AttributeType=S \
    --key-schema AttributeName=pk,KeyType=HASH AttributeName=sk,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"

# Token budget table (pk + sk composite key)
aws_resource "dynamodb/<token-budget-table>" \
  aws dynamodb create-table \
    --table-name "<prefix>-token-budget" \
    --attribute-definitions AttributeName=pk,AttributeType=S AttributeName=sk,AttributeType=S \
    --key-schema AttributeName=pk,KeyType=HASH AttributeName=sk,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"
```

Report: 3 tables created (or already existed).

## 2. SQS Dead Letter Queue

```bash
DLQ_URL=$(aws_resource "sqs/<prefix>-dlq" \
  aws sqs create-queue \
    --queue-name "<prefix>-dlq" \
    --attributes MessageRetentionPeriod=1209600 \
    --region "$REGION" \
    --query 'QueueUrl' --output text)
```

Update `infra.json`: set `storage.sqs.dlq.queueUrl` to the returned URL.

## 3. S3 Bundle Storage

```bash
BUCKET="<prefix>-bundles-<account-id>"

aws_resource "s3/$BUCKET" \
  aws s3 mb s3://$BUCKET --region "$REGION"

# 90-day lifecycle
aws_resource "s3/$BUCKET/lifecycle" \
  aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET" \
    --lifecycle-configuration '{
      "Rules": [{
        "ID": "delete-old-bundles",
        "Status": "Enabled",
        "Expiration": {"Days": 90},
        "Filter": {"Prefix": ""}
      }]
    }'
```

## 4. SNS Alerts Topic

```bash
SNS_ARN=$(aws_resource "sns/<prefix>-alerts" \
  aws sns create-topic \
    --name "<prefix>-alerts" \
    --region "$REGION" \
    --query 'TopicArn' --output text)
```

Update `infra.json`: set `monitoring.snsTopic.arn`.

## 5. IAM Execution Role

Create role trust policy inline, then create role and attach inline policy:

```bash
# Trust policy — Lambda service
TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}'

ROLE_ARN=$(aws_resource "iam/<prefix>-lambda-role" \
  aws iam create-role \
    --role-name "<prefix>-lambda-role" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --query 'Role.Arn' --output text)

# Attach AWS managed basic Lambda execution policy
aws_resource "iam/<prefix>-lambda-role/policy/AWSLambdaBasicExecutionRole" \
  aws iam attach-role-policy \
    --role-name "<prefix>-lambda-role" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Inline policy — DynamoDB + SQS + S3 access
aws_iam_put_role_policy "<prefix>-lambda-role" "<prefix>-storage-access" \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Effect\": \"Allow\",
        \"Action\": [\"dynamodb:GetItem\",\"dynamodb:PutItem\",\"dynamodb:UpdateItem\",\"dynamodb:Query\",\"dynamodb:Scan\"],
        \"Resource\": [
          \"arn:aws:dynamodb:$REGION:$ACCOUNT_ID:table/<prefix>-dedupe\",
          \"arn:aws:dynamodb:$REGION:$ACCOUNT_ID:table/<prefix>-rate-limits\",
          \"arn:aws:dynamodb:$REGION:$ACCOUNT_ID:table/<prefix>-token-budget\"
        ]
      },
      {
        \"Effect\": \"Allow\",
        \"Action\": \"sqs:SendMessage\",
        \"Resource\": \"arn:aws:sqs:$REGION:$ACCOUNT_ID:<prefix>-dlq\"
      },
      {
        \"Effect\": \"Allow\",
        \"Action\": \"s3:PutObject\",
        \"Resource\": \"arn:aws:s3:::<prefix>-bundles-$ACCOUNT_ID/*\"
      }
    ]
  }"
```

Update `infra.json`: set `storage.iamPolicy.attachedTo` to the role name.

## 6. Lambda Functions (placeholder)

Create 2 placeholder Lambda functions (real code deployed by `auto-deploy`):

```bash
# Create minimal placeholder zip
echo 'exports.handler = async () => ({ statusCode: 200 })' > /tmp/placeholder.js
zip -j /tmp/placeholder.zip /tmp/placeholder.js

# WI Router — handles all work-item routes (dor, dod, bugfix, qa, devagent, docagent)
aws_resource "lambda/<PREFIX>-WI-Router" \
  aws lambda create-function \
    --function-name "<PREFIX>-WI-Router" \
    --runtime nodejs20.x \
    --handler wi-router.handler \
    --role "$ROLE_ARN" \
    --zip-file fileb:///tmp/placeholder.zip \
    --timeout 30 \
    --memory-size 256 \
    --region "$REGION"

# PR Router — handles PR routes (pr-answer)
aws_resource "lambda/<PREFIX>-PR-Router" \
  aws lambda create-function \
    --function-name "<PREFIX>-PR-Router" \
    --runtime nodejs20.x \
    --handler pr-router.handler \
    --role "$ROLE_ARN" \
    --zip-file fileb:///tmp/placeholder.zip \
    --timeout 30 \
    --memory-size 256 \
    --region "$REGION"

rm /tmp/placeholder.js /tmp/placeholder.zip
```

## 7. API Gateway HTTP API + Routes

```bash
API_ID=$(aws_resource "apigateway/<PREFIX>-Agent" \
  aws apigatewayv2 create-api \
    --name "<PREFIX>-Agent" \
    --protocol-type HTTP \
    --region "$REGION" \
    --query 'ApiId' --output text)

# Lambda ARNs — 2 router functions
WI_ROUTER_ARN="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:<PREFIX>-WI-Router"
PR_ROUTER_ARN="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:<PREFIX>-PR-Router"

# Integration: WI Router (serves all work-item routes)
WI_INT_ID=$(aws_resource "apigateway/$API_ID/integration/wi-router" \
  aws apigatewayv2 create-integration \
    --api-id "$API_ID" \
    --integration-type AWS_PROXY \
    --integration-uri "$WI_ROUTER_ARN" \
    --payload-format-version 2.0 \
    --region "$REGION" \
    --query 'IntegrationId' --output text)

# Integration: PR Router (serves PR routes)
PR_INT_ID=$(aws_resource "apigateway/$API_ID/integration/pr-router" \
  aws apigatewayv2 create-integration \
    --api-id "$API_ID" \
    --integration-type AWS_PROXY \
    --integration-uri "$PR_ROUTER_ARN" \
    --payload-format-version 2.0 \
    --region "$REGION" \
    --query 'IntegrationId' --output text)

# WI route — single route for all work item webhooks (tag-based routing in Lambda)
aws_resource "apigateway/$API_ID/route/wi" \
  aws apigatewayv2 create-route \
    --api-id "$API_ID" \
    --route-key "POST /wi" \
    --target "integrations/$WI_INT_ID" \
    --region "$REGION"

# PR route points to PR Router
aws_resource "apigateway/$API_ID/route/pr-answer" \
  aws apigatewayv2 create-route \
    --api-id "$API_ID" \
    --route-key "POST /pr-answer" \
    --target "integrations/$PR_INT_ID" \
    --region "$REGION"

# Deploy stage
aws_resource "apigateway/$API_ID/stage/prod" \
  aws apigatewayv2 create-stage \
    --api-id "$API_ID" \
    --stage-name prod \
    --auto-deploy \
    --region "$REGION"

# Grant Lambda invoke permission to API Gateway
for FUNC_NAME in "<PREFIX>-WI-Router" "<PREFIX>-PR-Router"; do
  aws_resource "lambda/$FUNC_NAME/permission/apigateway" \
    aws lambda add-permission \
      --function-name "$FUNC_NAME" \
      --statement-id "apigateway-invoke" \
      --action lambda:InvokeFunction \
      --principal apigateway.amazonaws.com \
      --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*" \
      --region "$REGION"
done
```

Update `infra.json`:
- `apiGateway.id` → `$API_ID`
- `apiGateway.url` → `https://$API_ID.execute-api.$REGION.amazonaws.com/prod`
- `webhooks.wi-userstory.url` → `https://$API_ID.execute-api.$REGION.amazonaws.com/prod/wi`
- `webhooks.wi-bug.url` → `https://$API_ID.execute-api.$REGION.amazonaws.com/prod/wi`
- `webhooks.pr-answer.url` → `https://$API_ID.execute-api.$REGION.amazonaws.com/prod/pr-answer`

## 8. Summary Report

```markdown
## AWS Resources Provisioned

**Region:** <region>

| Resource | Name | Status |
|----------|------|--------|
| DynamoDB | <prefix>-dedupe | ✓ created |
| DynamoDB | <prefix>-rate-limits | ✓ created |
| DynamoDB | <prefix>-token-budget | ✓ created |
| SQS | <prefix>-dlq | ✓ created |
| S3 | <prefix>-bundles-<account> | ✓ created |
| SNS | <prefix>-alerts | ✓ created |
| IAM role | <prefix>-lambda-role | ✓ created |
| Lambda | <PREFIX>-WI-Router | ✓ created (placeholder) |
| Lambda | <PREFIX>-PR-Router | ✓ created (placeholder) |
| API Gateway | <PREFIX>-Agent | ✓ created |

**infra.json** updated with all IDs and ARNs.
**Audit log:** `.ai/logs/infra.<week>.jsonl`

### Next step
`/auto-pipelines` — Import ADO pipelines and set variables
```

## Success Criteria

- [ ] All resources created or confirmed existing (DynamoDB, SQS, S3, SNS, IAM, Lambda, API Gateway)
- [ ] `infra.json` updated with ARNs and resource identifiers for all created resources
- [ ] API Gateway endpoint URL saved and reachable (HTTP 200 or 403)

## Examples

1. `/auto-provision` — Reads `infra.json` for resource prefix and region. Creates DynamoDB tables (dedupe + rate-limit), SQS dead-letter queue, S3 bucket for artifacts, SNS topic for alerts, IAM role with all required policies, 2 Lambda functions (placeholder code), and API Gateway with `/wi` and `/pr` routes. Updates `infra.json` with all ARNs and IDs.

2. `/auto-provision` (partial re-run, some resources exist) — DynamoDB tables and SQS queue already exist (ResourceInUseException). Logs "already exists" for each and continues. Creates the missing Lambda functions and API Gateway. Updates `infra.json` with new resource identifiers.

3. `/auto-provision` (different region) — User configured `us-west-2` in `infra.json` instead of the default `eu-west-1`. All resources are created in the specified region. API Gateway endpoint URL reflects the region. IAM role policies are region-aware.

## Troubleshooting

- **"Access Denied" or "not authorized to perform" errors**
  **Cause:** The AWS credentials don't have sufficient permissions to create the required resources.
  **Fix:** Ensure the IAM user/role has permissions for DynamoDB, SQS, S3, SNS, IAM, Lambda, and API Gateway. Check `aws sts get-caller-identity` to verify you're using the right account.

- **"ResourceInUseException" for every resource**
  **Cause:** All resources were already provisioned (e.g., re-running after a successful provision).
  **Fix:** This is expected — the skill is idempotent. It logs "already exists" and continues. Check `infra.json` to confirm all ARNs are recorded.

- **Lambda created but with placeholder code**
  **Cause:** `/auto-provision` creates Lambda functions with placeholder handlers. Actual agent code is deployed separately.
  **Fix:** Run `/auto-deploy` next to upload the real Lambda code. This is the expected flow: provision first, deploy code second.

## Rules

- **Always source audit.sh first** — never use raw `aws` mutating commands
- **Idempotent** — if a resource already exists (ResourceInUseException, EntityAlreadyExists, etc.), log "already exists" and continue
- **Update infra.json after each step** — don't wait until the end
- **Derive all names from infra.json** — no hardcoded names
- **Account ID** — get from `aws sts get-caller-identity --query Account --output text`
