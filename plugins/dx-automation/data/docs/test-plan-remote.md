# Test Plan — Remote (Pipeline Agents via Webhooks)

Test the autonomous agents triggered by ADO webhooks → AWS Lambda → ADO Pipelines. See `test-plan-shared.md` for test work items and verification.

## Prerequisites

- AWS CLI authenticated (`aws sts get-caller-identity`)
- Azure CLI authenticated (`az account show`)
- `infra.json` fully filled — no `{{PLACEHOLDER}}` values
- Lambda deployed (`/auto-deploy`)
- Pipelines imported (`/auto-pipelines`)
- Webhooks configured (`/auto-webhooks`)

---

## Step 1 — Infrastructure health

```
/auto-doctor
```

**Pass:** All checks green — files valid, pipelines enabled with correct IDs, Lambdas active with all env var keys set.

```
/auto-status
```

**Pass:** DLQ depth = 0, token budget under 80%, rate limits under daily cap.

---

## Step 2 — API Gateway smoke test

```bash
GW_URL=$(python3 -c "import json; print(json.load(open('.ai/automation/infra.json'))['apiGateway']['url'])")
curl -s -o /dev/null -w "%{http_code}" "$GW_URL/wi"
```

**Pass:** HTTP 401 — Lambda rejects unauthenticated requests (proves route → Lambda integration works).

---

## Step 3 — User Story agent trigger (DoR)

1. Open test User Story in ADO
2. Add tag matching `TAG_GATE_DOR` (e.g., `KAI-AI-TRIGGER`)
3. Save

**Pass:** Within 1-2 minutes:
- Lambda log shows tag detected + pipeline queued (check CloudWatch)
- DoR pipeline run appears in ADO Pipelines
- DoR comment posted on the work item

---

## Step 4 — Estimation agent trigger

1. Open same or different User Story in ADO
2. Add tag matching `TAG_GATE_ESTIMATION` (e.g., `KAI-ESTIMATION-AUTOMATION`)
3. Save

**Pass:** Estimation comment posted with SP/hours breakdown.

---

## Step 5 — Bug agent trigger (BugFix)

1. Open test Bug in ADO
2. Add tag matching `TAG_GATE_BUGFIX` (e.g., `KAI-BUGFIX-AUTOMATION`)
3. Save

**Pass:** BugFix pipeline runs. Branch + PR created with fix.

---

## Step 6 — PR Answer trigger

1. Open a PR authored by you (matching `MY_IDENTITIES`)
2. Post a comment asking a question
3. Wait for webhook

**Pass:** PR Answer pipeline runs. Reply posted to the comment thread.

---

## Step 7 — PR Review (Build Validation)

> **Requires:** PR Review pipeline YAML on the target branch + Build Validation policy enabled.

1. Create or update a PR targeting `development`
2. Build Validation triggers automatically

**Pass:** PR Review pipeline runs as a required check. Review comments posted, vote cast.

---

## Step 8 — Dedupe verification

Re-apply the same tag to the same work item (or trigger same webhook again).

**Pass:** Lambda log shows `status: skipped` — dedupe prevented duplicate pipeline run.

---

## Step 9 — Rate limit verification

Check current usage:

```
/auto-status
```

**Pass:** Rate limit counters incremented for each agent run. No agent exceeds daily cap.

---

## Step 10 — Monitoring

```bash
REGION=$(python3 -c "import json; print(json.load(open('.ai/automation/infra.json'))['region'])")
RES_PREFIX=$(python3 -c "import json; print(json.load(open('.ai/automation/infra.json'))['storage']['dynamodb']['dedupe']['tableName'].rsplit('-',1)[0])")

aws cloudwatch describe-alarms --alarm-name-prefix "$RES_PREFIX-" --region "$REGION" \
  --query 'MetricAlarms[].{Name:AlarmName,State:StateValue}' --output table
```

**Pass:** 4 alarms (DLQ depth, WI Router errors, PR Router errors, throttles), all in `OK` state.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Webhook doesn't reach Lambda | Check Service Hook URL matches `infra.json` > `webhooks.*.url` |
| Lambda 401 | `BASIC_USER`/`BASIC_PASS` mismatch between Lambda env and Service Hook |
| Tag applied but no pipeline | `TAG_GATE_*` env var doesn't match the tag name |
| Pipeline fails | Check variables: `/auto-doctor` or `az pipelines variable list --pipeline-id <id>` |
| DLQ messages | Inspect: `/auto-status` then `node eval/process-dlq.js` |
| Duplicate runs | Dedupe table TTL expired (1h) — expected for re-tests after 1h |
