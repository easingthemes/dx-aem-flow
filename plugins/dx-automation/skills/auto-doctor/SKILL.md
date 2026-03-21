---
name: auto-doctor
description: Run a health check on the AI automation setup — verifies local file integrity, ADO pipeline configuration, and (for hub only) Lambda function state. Profile-aware — adapts checks based on automationProfile in infra.json.
argument-hint: ""
---

You run a health check on the AI automation setup. Adapts checks based on the `automationProfile` in `infra.json` (`full-hub` or `consumer`). Legacy profiles `pr-only` and `pr-delegation` are treated as `consumer`.

## 0. Read Config

Read `.ai/automation/infra.json`. If missing: "Run `/auto-init` first." STOP.

Extract `automationProfile` (default to `full-hub` if field is absent — legacy installs predate profiles).

Also extract: pipeline entries (only those without `"disabled": true`), and for full-hub: region, prefix, Lambda function names.

Print: `Profile: <profile>`

## 1. Local File Integrity

Checks depend on the profile.

### Config files (all profiles):
- `infra.json` — no remaining `{{PLACEHOLDER}}` values (check for `{{`)
- `repos.json` — exists and is valid JSON

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

### Lambda handlers (full-hub only):
- `lambda/wi-router.mjs`
- `lambda/pr-router.mjs`
- `lambda/queuePrAnswerPipeline.mjs`
- `lambda/package.json`

**Skip for consumer profile** — these profiles do not manage Lambda. Do NOT report Lambda files as missing.

### Shared libs (full-hub only):
- `agents/lib/adoClient.js`, `agents/lib/dedupe.js`, `agents/lib/config.js` (spot check 3 files)

**Skip for consumer profile.**

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

## 3. Lambda Function State (full-hub only)

**Skip entirely for consumer profile.** Print: `— Lambda checks skipped (profile: consumer — Lambda is managed by the hub project)`

For full-hub, check each Lambda function (WI Router, PR Router):

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

WI Router required keys: `ADO_PAT`, `ADO_ORG_URL`, `BASIC_USER`, `BASIC_PASS`, `WEBHOOK_SECRET`, `DYNAMODB_DEDUPE_TABLE`, `DYNAMODB_RATE_LIMIT_TABLE`, `SQS_DLQ_URL`, `ADO_DOR_PIPELINE_ID`, `ADO_DOD_PIPELINE_ID`, `ADO_BUGFIX_PIPELINE_ID`, `ADO_QA_PIPELINE_ID`, `ADO_DEV_PIPELINE_ID`, `ADO_DOC_PIPELINE_ID`, `ADO_ESTIMATION_PIPELINE_ID`, `TAG_GATE_DOR`, `TAG_GATE_DOD`, `TAG_GATE_BUGFIX`, `TAG_GATE_QA`, `TAG_GATE_DEV`, `TAG_GATE_DOC`, `TAG_GATE_ESTIMATION`.

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

### WI Hooks (full-hub only)

**Skip for consumer profile.**

Check that WI hooks exist (project-scoped, User Story + Bug). These are created once by the hub.

### Hub Registration (consumer only)

**Skip for full-hub profile.**

For consumer repos, check that the hub knows about this repo's pipelines:

1. Read `hubProject` from infra.json — report `✓ hub: <name>` or `⚠ hubProject not set in infra.json`
2. Remind user: "Verify that this repo's PR Answer pipeline ID is registered in the hub's `ADO_PR_ANSWER_PIPELINE_MAP` Lambda env var."
3. Remind about `CROSS_REPO_PIPELINE_MAP` for DevAgent/BugFix/DoD-Fix (consumer pipelines use `KAI-<RepoShortName>-*` naming).

## 5. Summary Report

Adapt the report format to the profile:

### For full-hub:

```markdown
## Automation Health Check (Full Hub)

### Local Files
| Check | Status |
|-------|--------|
| Agent steps (DoR, PR Review, PR Answer) | ✓ / ✗ |
| Lambda handlers | ✓ / ✗ |
| Pipeline YAMLs | ✓ / ✗ |
| infra.json (no placeholders) | ✓ / ✗ |
| repos.json | ✓ / ✗ |

### ADO Pipelines
| Pipeline | ID | Status | YAML Path |
|----------|-----|--------|-----------|
| <only enabled pipelines> | ... | ... | ... |

### Lambda Functions
| Function | State | Runtime | Last Modified | Env Vars |
|----------|-------|---------|---------------|----------|
| <PREFIX>-WI-Router | ✓ Active | ✓ nodejs20.x | ✓ recent | 22 set |
| <PREFIX>-PR-Router | ✓ Active | ✓ nodejs20.x | ✓ recent | 11 set |

### Overall: ✓ Healthy / ⚠️ Issues found
<List any failed checks with remediation steps>
```

### For consumer:

```markdown
## Automation Health Check (Consumer)

### Local Files
| Check | Status |
|-------|--------|
| Pipeline YAMLs | ✓ / ✗ |
| infra.json (no placeholders) | ✓ / ✗ |
| repos.json | ✓ / ✗ |

### ADO Pipelines
| Pipeline | ID | Status | YAML Path |
|----------|-----|--------|-----------|
| <consumer pipelines — pr-review, pr-answer, eval, devagent, bugfix, dod-fix> | ... | ... | ... |

### Webhooks & Policies
| Check | Status |
|-------|--------|
| PR Answer hook (repo-scoped) | ✓ / ⚠ missing |
| PR Review build policy | ✓ / ⚠ missing |

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
- **Read-only** — no AWS/ADO mutations in this skill (read commands only)
- **Cross-check infra.json vs reality** — pipeline IDs and Lambda names must match
- **Report missing env var keys** — never values (security)
- **Specific remediation** — for each failed check, suggest the skill that fixes it (e.g., "Run `/auto-lambda-env`")
- **Only check enabled agents** — skip any pipeline with `"disabled": true` in infra.json
