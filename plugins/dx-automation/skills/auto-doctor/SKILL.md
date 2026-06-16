---
name: auto-doctor
description: Run a health check on the AI automation setup — verifies local file integrity, ADO pipeline configuration, and Lambda function state. Each project is self-contained.
when_to_use: "Use when the AI automation setup seems broken, to verify Lambda functions are deployed, pipelines are configured, and infra.json is correct. Trigger on 'check automation', 'diagnose automation', 'automation health check'."
argument-hint: ""
---

You run a health check on the AI automation setup. Each project is self-contained — it owns its own Lambda and pipelines. Legacy profiles `consumer`, `pr-only`, and `pr-delegation` are treated as `per-project` (warn to re-run `/auto-init` if found).

## 0. Read Config

Read `.ai/automation/infra.json`. If missing: "Run `/auto-init` first." STOP.

Extract `automationProfile`. If value is `consumer`, `pr-only`, or `pr-delegation`: warn `⚠ Legacy profile '${profile}' — re-run /auto-init to migrate to per-project model.` and treat as per-project for the remainder of this check.

Also extract: pipeline entries (only those without `"disabled": true`), region, prefix, Lambda function names.

## 1. Local File Integrity

### Config files:
- `infra.json` — no remaining `{{PLACEHOLDER}}` values (check for `{{`)
- `repos.json` — **optional; validate only if present.** No pipeline, Lambda, or skill reads `repos.json` at runtime — it is documentation-only intent (future cross-repo discovery), so its absence is expected and harmless, especially for CLI-pipeline-only consumers (it was deliberately removed from some).
  - present + valid JSON → `✓`
  - present + invalid JSON → `✗ invalid JSON` (the only failing case — a hand-edited file that won't parse)
  - **absent → `— optional (unused — not read by any pipeline or agent)` — NOT an issue; do NOT report `✗`, and do NOT let it affect the Overall verdict.**

Check `infra.json` for unfilled placeholders:
```bash
python3 -c "
import json, re
with open('.ai/automation/infra.json') as f:
    content = f.read()
placeholders = re.findall(r'\{\{[^}]+\}\}', content)
if placeholders:
    print('UNFILLED PLACEHOLDERS:', list(set(placeholders)))
else:
    print('OK — no unfilled placeholders')
"
```

### Pipeline YAMLs (all profiles):
For each enabled pipeline entry in `infra.json`, check that the YAML file referenced in `pipelines.<agent>.yaml` exists on disk:
- Exists → `✓`
- Missing → `✗ MISSING`

### Lambda handlers (when Lambda agents are enabled):
Skip Lambda file checks if no Lambda-based agents are enabled (i.e., only PR Review, PR Answer, and Eval are in the enabled list — those run as ADO pipelines without Lambda).

- `lambda/wi-router.mjs`
- `lambda/pr-router.mjs`
- `lambda/queuePrAnswerPipeline.mjs`
- `lambda/package.json`

### Lambda shared libs (when Lambda agents are enabled):
- `lambda/lib/dedupe.js`, `lambda/lib/dlq.js`, `lambda/lib/rate-limiter.js`, `lambda/lib/aws-sig.js`, `lambda/lib/retry.js` — the libs the WI-Router/PR-Router handlers import and `deploy.sh` flattens into the zip. Missing any → `✗` (deploy will fail at the copy step).

Report: ✓ / ✗ for each category checked.

## 2. ADO Pipeline State

For each **enabled** pipeline in infra.json (skip any with `"disabled": true` or missing pipeline ID):

```bash
az pipelines show \
  --id "<pipeline-id>" \
  --project "<adoProject>" \
  --organization "<adoOrg>" \
  --query '{name:name,enabled:queueStatus,yamlPath:process.yamlFilename,defaultBranch:defaultBranch}' \
  --output json
```

Check:
- `enabled` is `enabled` (not `paused` or `disabled`)
- `yamlPath` matches `infra.json` `pipelines.<agent>.yaml`
- Pipeline ID matches what's in `infra.json`

Report: ✓ / ✗ for each pipeline with name and ID.

## 3. Lambda Function State

Skip if no Lambda-based agents are enabled (PR Review, PR Answer, Eval only — pipeline-only setup).

Check each Lambda function (WI Router, PR Router):

```bash
REGION=$(python3 -c "import json; print(json.load(open('.ai/automation/infra.json'))['region'])")

aws lambda get-function-configuration \
  --function-name "<function-name>" \
  --region "$REGION" \
  --query '{name:FunctionName,runtime:Runtime,handler:Handler,lastModified:LastModified,state:State,envVarCount:length(Environment.Variables)}' \
  --output json
```

Check:
- `state` is `Active`
- `runtime` is `nodejs20.x` — warn if runtime is end-of-life (`nodejs12.x`, `nodejs14.x`, `nodejs16.x`, `nodejs18.x`, `python3.7`, `python3.8`)
- `handler` is `wi-router.handler` (WI Router) or `pr-router.handler` (PR Router)
- `lastModified` — warn if older than 90 days (function may be stale)
- `envVarCount` > 0 (env vars have been set)

Check required env var KEYS are set (not values):
```bash
aws lambda get-function-configuration \
  --function-name "<function-name>" --region "$REGION" \
  --query 'keys(Environment.Variables)' --output json
```

WI Router required keys: `ADO_PAT`, `ADO_ORG_URL`, `BASIC_USER`, `BASIC_PASS`, `WEBHOOK_SECRET`, `DYNAMODB_DEDUPE_TABLE`, `DYNAMODB_RATE_LIMIT_TABLE`, `SQS_DLQ_URL`, `ADO_DOD_PIPELINE_ID`, `ADO_QA_PIPELINE_ID`, `ADO_DEV_PIPELINE_ID`, `ADO_DOC_PIPELINE_ID`, `ADO_ESTIMATION_PIPELINE_ID`, `TAG_GATE_DOD`, `TAG_GATE_QA`, `TAG_GATE_DEV`, `TAG_GATE_DOC`, `TAG_GATE_ESTIMATION`. (**DoR and BugFix are NOT WI-Router-routed** — both use Azure-native comment hooks (`@kai-dor` / `@kai-bugfix`) like SimpleAgent — so `ADO_DOR_PIPELINE_ID`/`TAG_GATE_DOR` and `ADO_BUGFIX_PIPELINE_ID`/`TAG_GATE_BUGFIX` are **not** required here.)

PR Router required keys: `ADO_PAT`, `ADO_ORG_URL`, `BASIC_USER`, `BASIC_PASS`, `WEBHOOK_SECRET`, `DYNAMODB_DEDUPE_TABLE`, `DYNAMODB_RATE_LIMIT_TABLE`, `SQS_DLQ_URL`, `MY_IDENTITIES`, `ADO_PR_ANSWER_PIPELINE_ID`.

Report: ✓ / ✗ for each function with state and missing env vars.

## 4. Webhook & Policy State (all profiles)

### PR Answer Service Hook

Check that a repo-scoped PR Answer hook exists for this repo. List service hooks and look for one matching:
- `eventType`: `ms.vss-code.git-pullrequest-comment-event`
- `publisherInputs.repository`: this repo's ID (from `scm.repo-id` in config.yaml)

Report: `✓ PR Answer hook (repo-scoped)` or `⚠ No repo-scoped PR Answer hook found — run /auto-webhooks`

**Migration check:** If a project-scoped PR Answer hook exists (same URL, no `repository` filter) — warn: `⚠ Legacy project-scoped PR Answer hook found (fires on ALL repos). Run /auto-webhooks to replace with repo-scoped hook.`

### PR Review Build Validation Policy

Check if a build validation policy exists for the PR Review pipeline on the base branch:
```bash
az repos policy list \
  --repository-id "<repo-id>" \
  --branch "refs/heads/<base-branch>" \
  --project "<adoProject>" \
  --organization "<adoOrg>" \
  --query "[?type.id=='0609b952-1397-4640-95ec-e00a01b2f659']" \
  --output json
```

Report: `✓ PR Review build policy on <branch>` or `⚠ No PR Review build policy — run /auto-webhooks`

### WI Hooks

Check that WI hooks exist (project-scoped, User Story + Bug). Required when work-item-triggered agents (DoD, QA, DevAgent, DOCAgent, Estimation) are enabled.

## 5. Summary Report

```markdown
## Automation Health Check

### Local Files
| Check | Status |
|-------|--------|
| Lambda handlers | ✓ / ✗ / — (skipped — pipeline-only) |
| Pipeline YAMLs | ✓ / ✗ |
| infra.json (no placeholders) | ✓ / ✗ |
| repos.json (optional) | ✓ / — absent (ok) / ✗ invalid JSON |

### ADO Pipelines
| Pipeline | ID | Status | YAML Path |
|----------|-----|--------|-----------|
| <only enabled pipelines> | ... | ... | ... |

### Lambda Functions
| Function | State | Runtime | Last Modified | Env Vars |
|----------|-------|---------|---------------|----------|
| <PREFIX>-WI-Router | ✓ Active | ✓ nodejs20.x | ✓ recent | 22 set |
| <PREFIX>-PR-Router | ✓ Active | ✓ nodejs20.x | ✓ recent | 11 set |

### Webhooks & Policies
| Check | Status |
|-------|--------|
| PR Answer hook (repo-scoped) | ✓ / ⚠ missing |
| PR Review build policy | ✓ / ⚠ missing |
| WI hooks (project-scoped) | ✓ / ⚠ missing (if WI agents enabled) |

### Overall: ✓ Healthy / ⚠️ Issues found
<List any failed checks with remediation steps>

### Hub Registration
| Check | Status |
|-------|--------|
| Hub project | ✓ <name> / ⚠ not set |
| PR Answer in hub's pipeline map | ℹ verify manually |
| Cross-repo map in hub | ℹ verify manually |

— Lambda/AWS checks skipped (managed by hub: <hubProject>)

### Overall: ✓ Healthy / ⚠️ Issues found
```

## Success Criteria

- [ ] All check categories completed (local files, ADO pipelines, Lambda, webhooks)
- [ ] Overall health verdict reported: Healthy or Issues Found
- [ ] Each failed check has a specific remediation suggestion

## Examples

1. `/auto-doctor` (hub project, all healthy) — Checks local files (infra.json, pipeline YAMLs, agent steps, shared libs), verifies 10 ADO pipeline IDs match infra.json, confirms 2 Lambda functions exist with correct names, and validates env var keys are set. Reports "All checks passed."

2. `/auto-doctor` (consumer project) — Detects `automationProfile: consumer` in infra.json. Checks only pipeline YAMLs and ADO pipeline IDs (2 pipelines). Skips Lambda, agent steps, and AWS resource checks with note "Lambda/AWS checks skipped (managed by hub)." Reports cross-repo registration reminders.

3. `/auto-doctor` (issues found) — Finds 3 issues: missing pipeline YAML for DoD-Fixer agent, PR-Router Lambda env var `ADO_PAT` not set, and infra.json pipeline ID doesn't match ADO for the DoR agent. Reports each with remediation: "Run `/auto-pipelines`", "Run `/auto-lambda-env`", "Re-import pipeline or update infra.json."

## Troubleshooting

- **"infra.json not found"**
  **Cause:** Automation hasn't been initialized for this project.
  **Fix:** Run `/auto-init` to scaffold the automation directory and create `infra.json`.

- **Pipeline ID mismatch between infra.json and ADO**
  **Cause:** The pipeline was deleted and re-created in ADO, or infra.json was manually edited.
  **Fix:** Run `/auto-pipelines` to re-import the pipeline. It will detect the existing pipeline by name and update the ID in infra.json.

- **Lambda checks fail with "access denied"**
  **Cause:** AWS credentials are not configured or lack Lambda read permissions.
  **Fix:** Configure AWS credentials (`aws configure`) and ensure the IAM user has `lambda:GetFunction` and `lambda:GetFunctionConfiguration` permissions. For consumer profiles, Lambda checks are skipped entirely.

## Rules

- **Profile-aware** — read `automationProfile` from infra.json FIRST and adapt all checks. Treat legacy `pr-only` and `pr-delegation` values as `consumer`. Never check Lambda, agent steps, or AWS resources for consumer profile. Never report missing Lambda/agent files as errors for consumer profile.
- **`repos.json` is optional** — never report its absence as `✗` or count it toward the Overall verdict. It has no runtime consumer (no pipeline, Lambda, or skill reads it). Only a *present-but-malformed* `repos.json` is a failure.
- **Read-only** — no AWS/ADO mutations in this skill (read commands only)
- **Cross-check infra.json vs reality** — pipeline IDs and Lambda names must match
- **Report missing env var keys** — never values (security)
- **Specific remediation** — for each failed check, suggest the skill that fixes it (e.g., "Run `/auto-lambda-env`")
- **Only check enabled agents** — skip any pipeline with `"disabled": true` in infra.json
