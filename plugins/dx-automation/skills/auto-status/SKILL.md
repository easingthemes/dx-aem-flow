---
name: auto-status
description: Show operational dashboard for AI automation agents — DLQ depth, monthly token budget, and daily rate limit usage. Hub profile only — requires AWS credentials. Read-only.
argument-hint: ""
---

You display an operational dashboard showing current DLQ depth, token budget utilization, and rate limit usage. All commands are read-only — no mutations.

## 0. Prerequisites

Read `.ai/automation/infra.json` to get `automationProfile`, region, and table names.

**Profile check:** If `automationProfile` is `consumer` (or legacy `pr-only`/`pr-delegation`):
```
This repo uses the <profile> profile — DLQ, token budget, and rate limits are managed by the hub project.
Run /auto-status from the hub repo instead.
```
STOP.

Check AWS credentials are available:
```bash
aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "NO_CREDENTIALS"
```

If no credentials: "AWS credentials not configured. Run `aws configure` or set `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`." STOP.

## 1. DLQ Depth

```bash
cd .ai/automation
node eval/process-dlq.js --depth
```

If DLQ depth > 0:
```bash
# Show message summaries (not full content)
node eval/process-dlq.js --list
```

## 2. Token Budget

```bash
cd .ai/automation
node eval/cost-report.js
```

## 3. Rate Limits

```bash
cd .ai/automation
node eval/rate-limit-report.js
```

## 4. Summary Report

Present results as a combined dashboard:

```markdown
## Automation Status

**DLQ:** <N> messages <(✓ empty | ⚠️ N messages pending)>
**Token budget:** <utilization>% of monthly cap (<tokens>/<cap>) — mode: <normal|suggest-only|halted>
**Rate limits today:** DoR <N>/20, PR Review <N>/50, PR Answer <N>/30

<If any DLQ messages:>
### DLQ Messages
<list of message summaries: timestamp, error type, function name>
Investigate: `cd .ai/automation && node eval/process-dlq.js`

<If budget > 80%:>
⚠️  Token budget at <N>% — approaching limit. Consider increasing `MONTHLY_TOKEN_CAP` pipeline variable.

<If budget halted:>
🚨 Token budget exhausted — all LLM calls blocked until next month.
```

## Examples

1. `/auto-status` — Queries AWS for DLQ depth (0 messages), monthly token usage (45% of budget), and daily rate limit usage (120/500 calls). Reports all metrics as healthy with green indicators.

2. `/auto-status` (DLQ has messages) — Reports DLQ depth of 3 messages with metadata (timestamps, error types, function names). Does not print message contents for security. Suggests running `node eval/process-dlq.js` to investigate.

3. `/auto-status` (budget warning) — Reports token budget at 85% with 6 days remaining in the month. Warns: "Approaching limit — consider increasing `MONTHLY_TOKEN_CAP` pipeline variable." DLQ and rate limits are healthy.

## Troubleshooting

- **"Access denied" when querying AWS**
  **Cause:** AWS credentials are not configured or lack read permissions for SQS, CloudWatch, or DynamoDB.
  **Fix:** Configure AWS credentials and ensure the IAM user has read permissions for the automation resources. This skill is read-only — it never modifies anything.

- **Token budget shows 0% but agents are running**
  **Cause:** The rate limit table in DynamoDB may not be tracking usage correctly, or the `MONTHLY_TOKEN_CAP` value is not set.
  **Fix:** Check the `DYNAMODB_RATE_LIMIT_TABLE` entries directly in DynamoDB. Verify that `MONTHLY_TOKEN_CAP` is set as a pipeline variable.

- **DLQ depth keeps growing**
  **Cause:** An agent is consistently failing (expired PAT, invalid API key, unhandled error in agent step).
  **Fix:** Process DLQ messages to identify the pattern. Common causes: expired ADO PAT (run `/auto-lambda-env` to update), LLM API key rotation needed, or a bug in agent step code (fix and run `/auto-deploy`).

## Rules

- **Read-only** — no AWS mutations
- **Don't print DLQ message contents** — may contain sensitive ADO data; print only metadata (timestamp, error type, function name)
