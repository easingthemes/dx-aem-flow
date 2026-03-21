---
name: auto-deploy
description: Deploy Lambda code for AI automation agents (wi-router and/or pr-router). Packages agent steps + shared libs into a zip and uploads to AWS Lambda. Safe to re-run after code changes. Reads function names from .ai/automation/infra.json.
argument-hint: "[wi-router|pr-router|all]"
---

You deploy Lambda function code for the 2 AI automation agents (wi-router, pr-router). Wraps `lambda/deploy.sh` with audit logging. Safe to re-run at any time after code changes.

## 0. Prerequisites

Read `.ai/automation/infra.json`. Check `automationProfile`:
- If `consumer` (or legacy `pr-only`/`pr-delegation`): "This repo uses the consumer profile — Lambda functions are managed by the hub project. Do NOT deploy Lambda from this repo." **STOP.**

```bash
source .ai/lib/audit.sh
export AUDIT_LOG_PREFIX=infra
```

Extract Lambda function names and region from infra.json.

Verify: `zip` is installed (`which zip`). If missing: "Install zip: `brew install zip` (macOS) or `apt install zip` (Linux)". STOP.

## 1. Parse Target

Default target: `all`. If user passed an argument (`wi-router`, `pr-router`), use that.

## 2. Deploy

```bash
cd .ai/automation
bash lambda/deploy.sh <target>
```

The deploy script reads function names and files from `infra.json`, packages each Lambda + shared libs into a zip, and calls `aws_lambda_deploy` (audit-wrapped).

Report output from the script.

## 3. Verify Deployment

After deploy, check the last modified timestamp for each deployed function:

```bash
REGION=$(python3 -c "import json; print(json.load(open('.ai/automation/infra.json'))['region'])")

for FUNC in $(python3 -c "
import json
d = json.load(open('.ai/automation/infra.json'))
targets = ['wi-router', 'pr-router'] if '<target>' == 'all' else ['<target>']
for t in targets: print(d['lambdas'][t]['functionName'])
"); do
  aws lambda get-function --function-name "$FUNC" --region "$REGION" \
    --query 'Configuration.[FunctionName,LastModified,CodeSize]' --output table
done
```

## 4. Summary Report

```markdown
## Lambda Deploy Complete

| Function | Last Modified | Code Size |
|----------|--------------|-----------|
| <PREFIX>-WI-Router | <timestamp> | <bytes> |
| <PREFIX>-PR-Router | <timestamp> | <bytes> |

**Audit log:** `.ai/logs/infra.<week>.jsonl`

### Next step
`/auto-lambda-env` — Set Lambda environment variables
```

## Success Criteria

- [ ] Lambda function code updated — `LastModified` timestamp is recent (within last 60 seconds)
- [ ] Function exists and is in `Active` state after deployment
- [ ] Zip package was built from the correct source directory

## Examples

1. `/auto-deploy` — Packages agent step handlers and shared libs into zip files, then deploys both WI-Router and PR-Router Lambda functions. Reports deployment timestamps and package sizes. Both functions updated successfully.

2. `/auto-deploy wi-router` — Deploys only the WI-Router Lambda function (skips PR-Router). Useful after modifying only work-item-triggered agent steps. Reports the function name, timestamp, and package size.

3. `/auto-deploy` (after code changes) — Re-deploys both Lambdas with updated agent step code. The `deploy.sh` script packages fresh zips and uploads via `aws_lambda_deploy`. Reports successful deployment with new timestamps.

## Troubleshooting

- **"Function not found" error during deploy**
  **Cause:** The Lambda function hasn't been provisioned yet in AWS.
  **Fix:** Run `/auto-provision` first to create the Lambda functions, then re-run `/auto-deploy`.

- **Deploy succeeds but agent behavior doesn't change**
  **Cause:** Lambda may be using a cached version, or the environment variables reference old configuration.
  **Fix:** Check the Lambda's last modified timestamp in the deploy output. If it's current, the code is deployed — check environment variables with `/auto-lambda-env` or run `/auto-test --dryRun` to verify behavior.

- **"audit.sh not found" or audit wrapper errors**
  **Cause:** The audit helper script is missing or not sourced before deployment.
  **Fix:** Ensure `.ai/lib/audit.sh` exists (created by `/dx-init`). The deploy script sources it automatically — if the file is missing, re-run `/dx-init`.

## Rules

- **Always source audit.sh first** — deploy.sh uses `aws_lambda_deploy` wrapper
- **Derive function names from infra.json** — never hardcode
- **Report actual deploy output** — show what the script printed
