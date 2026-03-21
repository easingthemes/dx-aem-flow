# AI Automation Operational Runbook

How to investigate failures, respond to alerts, and recover from issues.

Resource names below use `<prefix>` as shorthand for your `{{RESOURCE_PREFIX}}` from `infra.json`.

## Quick Health Check

```bash
cd .ai/automation

# DLQ depth (should be 0)
node eval/process-dlq.js --depth

# Token budget utilization
node eval/cost-report.js

# Rate limit usage
node eval/rate-limit-report.js
```

All tools require AWS credentials (`AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` or `~/.aws/credentials`).

---

## Common Failures

### 1. LLM Timeout / 429 Rate Limit

**Symptoms:** Pipeline step fails with `fetchWithRetry exhausted` or `429 Too Many Requests`.

**Impact:** Pipeline run fails. No comment posted to ADO.

**Resolution:**
- `retry.js` handles automatically (3 retries with exponential backoff + jitter)
- If persistent: check [Azure OpenAI status](https://status.azure.com/) for outages
- Check token budget: `node eval/cost-report.js` — if `halted`, wait for month rollover or increase `MONTHLY_TOKEN_CAP` pipeline variable
- If rate limited (429): reduce daily rate limits in `rate-limiter.js` or wait for daily reset (midnight UTC)

### 2. ADO API 401 Unauthorized

**Symptoms:** `adoClient` calls fail with HTTP 401.

**Impact:** Pipeline can't read work items, PR data, or post comments.

**Resolution:**
- **Pipeline runs (PR Review):** `System.AccessToken` expires with the run — re-run the pipeline
- **Lambda-triggered runs (WI Router, PR Router):** `ADO_PAT` may have expired → rotate PAT:
  1. Generate new PAT in ADO > User Settings > Personal Access Tokens
  2. Update Lambda env var `ADO_PAT` in AWS Console > Lambda > function > Configuration > Environment variables
  3. Redeploy is NOT needed — env var change takes effect on next invocation

### 3. Dedupe 409 ConditionalCheckFailed

**Symptoms:** Lambda returns `{ status: "duplicate" }`.

**Impact:** None — this is expected behavior. Duplicate webhook events are silently dropped.

**Resolution:** No action needed. DynamoDB conditional put correctly rejected a duplicate event. TTL auto-cleans entries after 1 hour.

### 4. Scanner Degraded Mode

**Symptoms:** Pipeline logs show `scanner: degraded mode (local patterns only)`.

**Impact:** Reduced scanner coverage. Local pattern-based detection still active (17 HIGH + 7 MEDIUM patterns). Azure Prompt Shields unavailable.

**Resolution:**
- Check if `AZURE_CONTENT_SAFETY_ENDPOINT` and `AZURE_CONTENT_SAFETY_KEY` are set in pipeline variables
- If set: check [Azure Content Safety status](https://status.azure.com/)
- Scanner is fail-open by design — pipelines continue with local pattern detection
- No manual intervention needed unless you see `scanner_risk: high` in bundle logs

### 5. Token Budget Halted

**Symptoms:** Pipeline fails with `Token budget exhausted — mode: halted`.

**Impact:** All LLM calls blocked for the rest of the month.

**Resolution:**
- Check utilization: `node eval/cost-report.js`
- **Wait for month rollover** (counters reset on 1st of each month)
- **Or increase cap:** Update `MONTHLY_TOKEN_CAP` in all pipeline variables
- Review token usage by pipeline to identify unexpected consumption

### 6. Rate Limit Exceeded

**Symptoms:** Lambda returns `{ status: "rate_limited" }` or pipeline logs `rate limit exceeded`.

**Impact:** Pipeline run skipped for the day.

**Resolution:**
- Check usage: `node eval/rate-limit-report.js`
- Default limits: DoR 20/day, PR Answer 30/day, per-identity 10/day
- Limits reset at midnight UTC
- To increase: modify `rate-limiter.js` defaults

### 7. CLI Pipeline Plugin Install Failure

**Symptoms:** CLI pipeline fails at "Install dx plugins" step with `fatal: unable to access` or `claude plugin install` errors.

**Impact:** Agent cannot run — no dx skills available.

**Resolution:**
- Check `ADO_ORG_URL` and `DX_MARKETPLACE_URL` pipeline variables are set correctly
- If same-repo: verify `dx-aem-flow/` directory exists in the checkout
- If cross-repo: `System.AccessToken` needs read access to the marketplace repo — check "Limit job authorization scope" in ADO project settings
- Re-run the pipeline after fixing variables

### 8. Cross-Repo Delegation Failed

**Symptoms:** CLI pipeline (BugFix, DevAgent, DoD Fix) writes `delegate.json` but target pipeline doesn't start.

**Impact:** Work item processed in wrong repo, or delegation silently dropped.

**Resolution:**
- Check `CROSS_REPO_PIPELINE_MAP` pipeline variable — must be valid JSON mapping repo names to pipeline IDs
- Check the "Cross-repo delegation" YAML step logs for API errors
- Verify `System.AccessToken` has "Queue builds" permission on the target pipeline
- Verify the target pipeline exists and is not paused/disabled

### 9. Push Policy Denied (PR Answer)

**Symptoms:** PR Answer step 5 posts suggestion comments instead of pushing code.

**Impact:** Code fix is suggested, not applied. Developer must apply manually.

**Resolution:** This is by design. Push policy checks 4 conditions:
- `thread_category` — fix must be from an `agree-will-fix` thread
- `old_code_unique` — each code replacement matched exactly once
- `lint_passes` — syntax check passed
- `scanner_risk` — no prompt injection detected

Check the bundle's `decision-journal` to see which condition failed.

---

## Investigating a Failed Run

### Step 1: Find the run

- **LLM-only pipeline runs (DoR, PR Review, PR Answer):** ADO > Pipelines > select pipeline > recent runs > click failed run
- **CLI pipeline runs (DoD, DoD Fix, BugFix, QA, DevAgent, DOCAgent):** ADO > Pipelines > select pipeline > recent runs. CLI pipelines produce Claude Code output in the `Run Claude Code` step logs.
- **Lambda invocations:** AWS Console > CloudWatch > Log groups > `/aws/lambda/<PREFIX>-WI-Router`, `/aws/lambda/<PREFIX>-PR-Router`

### Step 2: Check the bundle

Every pipeline run produces a bundle in S3 (`<prefix>-bundles-<account-id>`). Key files:

| File | What to check |
|------|--------------|
| `run.json` | `status`, `error`, `steps[]` with timing, `hashes` (prompt/config/policy) |
| `decision-journal.json` | All plan/execute/refuse decisions with reasons |
| `alerts.json` | Critical/warning/info events during the run |
| `artifacts/` | Step-by-step inputs and outputs |

Download a bundle:
```bash
# Get region and bucket name from infra.json
REGION=$(python3 -c "import json; print(json.load(open('.ai/automation/infra.json'))['region'])")
BUCKET=$(python3 -c "import json; print(json.load(open('.ai/automation/infra.json'))['storage']['s3']['bundles']['bucketName'])")

aws s3 cp s3://$BUCKET/<run_id>/ ./debug-bundle/ --recursive --region $REGION
```

### Step 3: Check DLQ

If a Lambda failed, the event lands in the DLQ:
```bash
node eval/process-dlq.js          # List all DLQ messages
node eval/process-dlq.js --depth  # Quick count
```

DLQ messages include: original event payload, error message, timestamp, Lambda name.

---

## Alert Response

### CloudWatch Alarms → SNS

4 alarms route to the `<prefix>-alerts` SNS topic:

| Alarm | Severity | Response |
|-------|----------|----------|
| `<prefix>-dlq-depth` (> 5 messages) | Warning | Check DLQ: `node eval/process-dlq.js`. Investigate root cause of failures. |
| `<prefix>-lambda-errors-wi-router` (> 3/hour) | Critical | Check CloudWatch Logs for WI Router Lambda. Common: PAT expired, ADO API down. |
| `<prefix>-lambda-errors-pr-router` (> 3/hour) | Critical | Check CloudWatch Logs for PR Router Lambda. Common: PAT expired, webhook misconfigured. |
| `<prefix>-lambda-throttles` (> 0) | Warning | Lambda concurrency limit hit. Check for event storms. Usually self-resolving. |

### Pipeline Alert Routing (lib/alerts.js)

Alerts from pipeline runs are logged to the bundle and console:

| Level | When | Action |
|-------|------|--------|
| `critical` | Scanner block, policy refusal, token budget halt | Investigate immediately. Check bundle decision-journal. |
| `warning` | Push policy denial, rate limit approach, degraded scanner | Review within 24h. Usually self-resolving. |
| `info` | Normal operations, step completions | No action. Structured logging only. |

---

## Rollback Procedures

### Bad Prompt Change

1. `git revert <commit>` the prompt `.md` file change
2. Push to the branch — eval pipeline triggers automatically
3. Verify: `cd .ai/automation && node eval/run.js --all` — all fixtures pass
4. Pipeline runs will use the reverted prompt on next trigger

### Bad Lambda Deploy

```bash
cd .ai/automation
REGION=$(python3 -c "import json; print(json.load(open('infra.json'))['region'])")
DOR_FUNC=$(python3 -c "import json; print(json.load(open('infra.json'))['lambdas']['dor']['functionName'])")

# List recent Lambda versions
aws lambda list-versions-by-function --function-name "$DOR_FUNC" --region "$REGION" \
  --query 'Versions[-3:].[Version,LastModified]'

# Roll back to previous version
source ../../.ai/lib/audit.sh
aws_lambda_deploy "$DOR_FUNC" <previous-zip>
```

### Disable an Agent Temporarily

- **Individual WI agent (DoR, DoD, BugFix, QA, DevAgent, DOCAgent, Estimation):** Remove or clear the agent's `TAG_GATE_*` env var from the WI Router Lambda. The Lambda skips agents whose tag gate env var is not set. No hook or route changes needed.
- **All WI agents at once:** Disable the 2 WI service hooks in ADO (Project Settings > Service Hooks > find "WI User Story" / "WI Bug" subscriptions > disable)
- **PR Router (PR Answer):** Disable the PR comment Service Hook in ADO
- **PR Review:** Set Build Validation policy to "Not required" or delete it
- **All agents:** Set daily rate limit to 0 in `rate-limiter.js` LIMITS defaults

---

## CloudWatch Insights Queries

```bash
# Run in CloudWatch > Logs > Insights
# Select log groups: /aws/lambda/<PREFIX>-WI-Router, /aws/lambda/<PREFIX>-PR-Router
```

| Query file | What it shows |
|-----------|--------------|
| `bundle-completeness.cwi` | Complete vs incomplete pipeline runs |
| `dedupe-rate.cwi` | Duplicate event rejection rate |
| `error-rate.cwi` | Pipeline step failures by type |
| `token-usage.cwi` | Daily/weekly token consumption |
| `alert-frequency.cwi` | Alert events per day by severity |

---

## Maintenance Tasks

### Monthly

- Review token budget: `node eval/cost-report.js`
- Check DLQ is empty: `node eval/process-dlq.js --depth`
- Rotate ADO PAT if expiring (ADO > User Settings > Personal Access Tokens)

### Weekly

- Run eval: `node eval/run.js --all` — verify no regressions
- Run retro: `node eval/retro.js --week latest` — review run patterns
- Quick health check (see top of this doc)

### After Prompt Changes

1. Run eval locally: `node eval/run.js --all`
2. Verify all fixtures pass
3. Push change — eval CI pipeline validates automatically
4. Monitor first few production runs for unexpected behavior
