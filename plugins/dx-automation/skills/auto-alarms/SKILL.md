---
name: auto-alarms
description: Create CloudWatch alarms and SNS subscription for AI automation monitoring. Creates 4 alarms (DLQ depth, WI-Router errors, PR-Router errors, throttles) and subscribes an email address to alerts. Reads config from .ai/automation/infra.json.
argument-hint: "[--email you@example.com]"
---

You create CloudWatch alarms and subscribe an email address to alerts. Wraps `lambda/cloudwatch/setup-alarms.sh` with audit logging.

## 0. Prerequisites

Read `.ai/automation/infra.json`. Check `automationProfile`:
- If `consumer` (or legacy `pr-only`/`pr-delegation`): "This repo uses the consumer profile — CloudWatch alarms are managed by the hub project. Do NOT configure alarms from this repo." **STOP.**

```bash
source .ai/lib/audit.sh
export AUDIT_LOG_PREFIX=infra
```

Confirm monitoring config from infra.json:
- `monitoring.snsTopic.name` — SNS topic name (`<prefix>-alerts`)
- `region`

## 1. Collect Email

If user passed `--email <address>`, use it. Otherwise ask:

> **Alert email address?** CloudWatch alarms will notify this email for DLQ depth, Lambda errors, and throttles. You'll need to confirm the subscription in your email.

## 2. Run Setup Script

```bash
cd .ai/automation
bash lambda/cloudwatch/setup-alarms.sh --email "<email>"
```

The script:
1. Creates the SNS topic `<prefix>-alerts` (idempotent)
2. Subscribes the email to the topic
3. Creates 4 CloudWatch alarms (reads definitions from `lambda/cloudwatch/alarms.json`, prefixes with resource prefix from `infra.json`)
4. Links each alarm to the SNS topic

Report the script's output.

## 3. Update infra.json

After the script runs, the SNS topic ARN is returned. Update `infra.json`:
- `monitoring.snsTopic.arn` → the created/retrieved ARN

## 4. Summary Report

```markdown
## CloudWatch Monitoring Configured

**SNS topic:** <prefix>-alerts
**Alert email:** <email> (confirm subscription in your inbox)

| Alarm | Trigger | Severity |
|-------|---------|----------|
| <prefix>-dlq-depth | DLQ > 5 messages | Warning |
| <prefix>-lambda-errors-wi-router | WI-Router Lambda errors > 3/hour | Critical |
| <prefix>-lambda-errors-pr-router | PR-Router Lambda errors > 3/hour | Critical |
| <prefix>-lambda-throttles | Any Lambda throttled | Warning |

**infra.json** updated with SNS ARN.
**Audit log:** `.ai/logs/infra.<week>.jsonl`

### Next step
`/auto-test --dryRun` — Verify end-to-end (local dry run)

### Operational commands
- `/auto-status` — Current DLQ depth, token budget, rate limits
- `/auto-doctor` — Full health check
- See `docs/runbook.md` for alert response procedures
```

## Success Criteria

- [ ] CloudWatch alarms created for all 4 metrics (DLQ depth, WI-Router errors, PR-Router errors, throttles)
- [ ] SNS email subscription created — confirmation email sent to the provided address
- [ ] `infra.json` updated with SNS topic ARN

## Examples

1. `/auto-alarms` — Reads `infra.json` for resource prefix and SNS topic ARN. Creates 4 CloudWatch alarms: DLQ depth > 0, WI-Router errors > 5/min, PR-Router errors > 5/min, Lambda throttles > 0. Subscribes the configured email to the SNS topic. Reminds user to confirm the SNS subscription via email.

2. `/auto-alarms team@example.com` — Creates all 4 alarms and subscribes `team@example.com` to the SNS alert topic. Reports each alarm name and threshold. Prints reminder to check inbox for subscription confirmation.

3. `/auto-alarms` (re-run, alarms exist) — `put-metric-alarm` is idempotent — overwrites existing alarms with current thresholds. SNS `create-topic` returns the existing topic ARN. `subscribe` is also idempotent if the email is already subscribed. Reports all alarms as configured.

## Troubleshooting

- **"SNS subscription confirmation not received"**
  **Cause:** The confirmation email may have gone to spam, or the email address was incorrect.
  **Fix:** Check the spam folder. If not found, re-run `/auto-alarms` with the correct email — SNS will resend the confirmation. The subscription won't be active until confirmed.

- **Alarms not triggering despite errors**
  **Cause:** The alarm metric namespace or dimensions don't match the Lambda function names.
  **Fix:** Verify that the function names in `infra.json` match the actual Lambda function names in AWS. The alarms use `FunctionName` dimension to filter metrics.

- **"Access denied" when creating alarms**
  **Cause:** The AWS credentials lack CloudWatch or SNS permissions.
  **Fix:** Ensure the IAM user has `cloudwatch:PutMetricAlarm`, `sns:CreateTopic`, and `sns:Subscribe` permissions.

## Rules

- **Always source audit.sh first** — setup-alarms.sh uses `aws_resource` wrapper
- **Email confirmation required** — remind user to check inbox for SNS subscription confirmation
- **Idempotent** — SNS create-topic is idempotent; alarms are overwritten if they exist (put-metric-alarm is idempotent)
