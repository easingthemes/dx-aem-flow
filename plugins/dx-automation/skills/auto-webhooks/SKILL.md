---
name: auto-webhooks
description: Configure ADO service hooks and PR Review build validation policy for AI automation agents. Uses ADO REST API via az rest (no native CLI command for service hooks). Reads all config from .ai/automation/infra.json.
argument-hint: ""
---

You configure ADO service hooks and the PR Review build validation policy. ADO has no native `az devops service-hooks` CLI command — all REST calls use `az rest` (ADO PAT auth, audit-wrapped).

## 0. Prerequisites

Read `.ai/automation/infra.json`. Extract `automationProfile`.

```bash
source .ai/lib/audit.sh
export AUDIT_LOG_PREFIX=infra
```

**Profile determines scope:**
- **Full hub:** WI hooks (project-scoped) + PR Answer hook (repo-scoped) + PR Review build policy
- **Consumer:** PR Answer hook (repo-scoped) + PR Review build policy only. Consumers do NOT create WI hooks (hub owns those). Consumers DO need their own PR Answer hook and PR Review policy.

Extract:
- `adoOrg` — ADO org URL
- `adoProject` — ADO project name
- `pipelines.pr-review.id` — PR Review pipeline ID (for build validation policy)
- `pipelines.pr-answer.id` — PR Answer pipeline ID (for registering with hub)
- For **full-hub only**: `webhooks.wi-userstory.url`, `webhooks.wi-bug.url`
- Check if `webhooks.*.status` is already `configured` — skip if so

**For consumers:** The PR Answer hook URL points to the **hub's** PR Router Lambda. Ask:
> **Hub's PR Router Lambda URL?** The API Gateway URL from the hub project's infra.json (e.g., `https://<id>.execute-api.us-east-1.amazonaws.com/prod/pr-answer`).

Ask once for shared values needed for hooks:
> **Webhook username?** (same as Lambda `BASIC_USER` set in hub's `/auto-lambda-env`)

> **Webhook password?** (same as Lambda `BASIC_PASS`) — secret, not stored

> **Webhook secret?** (same as Lambda `WEBHOOK_SECRET`) — secret, not stored

Ask for ADO project ID (required by service hook API):
> **ADO project ID?** Find in ADO > Project Settings > Overview > Project ID (GUID format). You can also run: `az devops project show --project "<adoProject>" --query id --output tsv`

Get the repository ID for repo-scoped hooks:
```bash
REPO_ID=$(az repos show --repository "<repo-name>" --project "<adoProject>" --query id --output tsv)
```

Read `scm.base-branch` from `.ai/config.yaml` for branch filtering.

## 0b. List Existing Service Hooks

Before creating any hooks, list all existing subscriptions to avoid duplicates:

```bash
EXISTING_HOOKS=$(az rest --method GET \
  --uri "<adoOrg>/_apis/hooks/subscriptions?api-version=7.1" \
  --query "value[?consumerInputs.url != null].{id:id, event:eventType, url:consumerInputs.url, repoId:publisherInputs.repository}" \
  --output json)
```

For each hook to create, check if a subscription already exists with the same `eventType` AND the same `url` AND (for repo-scoped hooks) the same `repository`:
- If found: **skip creation**, report `⏭ <hook> already exists (ID: <id>) — skipping`
- If not found: create the hook

**Work-item hooks** are project-scoped and should exist only ONCE per project (hub only). If already configured from another repo, skip.

**PR Answer hooks are per-repo** — each repo needs its own hook filtered to that repo + base branch. Without repo filtering, a single project-scoped hook fires on every PR comment across hundreds of unrelated repos, flooding the Lambda with noise. **Migration:** If an existing project-scoped PR Answer hook exists (no `repository` filter — from an older setup), warn the user and offer to delete it after creating the repo-scoped replacement.

**PR Review build validation policy** is per-repo — always check by `repositoryId` before creating.

## 1. User Story WI Hook (Work Item Updated — User Story) — HUB ONLY

**Skip for consumer profile.**

Routes all User Story `workitem.updated` events to the WI Router Lambda at `/wi`. The Lambda uses tag-based routing to determine which agent to invoke (DoR, DoD, QA, DevAgent, DOCAgent).

```bash
az_resource "ado/hooks/wi-userstory" \
  az rest --method POST \
    --uri "$(adoOrg)/_apis/hooks/subscriptions?api-version=7.1" \
    --headers "Content-Type=application/json" \
    --body "{
      \"publisherId\": \"tfs\",
      \"eventType\": \"workitem.updated\",
      \"resourceVersion\": \"1.0\",
      \"consumerId\": \"webHooks\",
      \"consumerActionId\": \"httpRequest\",
      \"publisherInputs\": {
        \"projectId\": \"<PROJECT_ID>\",
        \"workItemType\": \"User Story\",
        \"tag\": \"KAI-TRIGGER\"
      },
      \"consumerInputs\": {
        \"url\": \"<wi-userstory-url>\",
        \"basicAuthUsername\": \"<BASIC_USER>\",
        \"basicAuthPassword\": \"<BASIC_PASS>\",
        \"httpHeaders\": \"x-webhook-secret:<WEBHOOK_SECRET>\"
      }
    }" \
    --query 'id' --output tsv
```

Update `infra.json`:
- `webhooks.wi-userstory.subscriptionId` → returned ID
- `webhooks.wi-userstory.status` → `"configured"`

## 2. Bug WI Hook (Work Item Updated — Bug) — HUB ONLY

**Skip for consumer profile.**

Routes all Bug `workitem.updated` events to the same WI Router Lambda at `/wi`. The Lambda uses tag-based routing to determine the agent (BugFix).

```bash
az_resource "ado/hooks/wi-bug" \
  az rest --method POST \
    --uri "<adoOrg>/_apis/hooks/subscriptions?api-version=7.1" \
    --headers "Content-Type=application/json" \
    --body "{
      \"publisherId\": \"tfs\",
      \"eventType\": \"workitem.updated\",
      \"resourceVersion\": \"1.0\",
      \"consumerId\": \"webHooks\",
      \"consumerActionId\": \"httpRequest\",
      \"publisherInputs\": {
        \"projectId\": \"<PROJECT_ID>\",
        \"workItemType\": \"Bug\",
        \"tag\": \"KAI-TRIGGER\"
      },
      \"consumerInputs\": {
        \"url\": \"<wi-bug-url>\",
        \"basicAuthUsername\": \"<BASIC_USER>\",
        \"basicAuthPassword\": \"<BASIC_PASS>\",
        \"httpHeaders\": \"x-webhook-secret:<WEBHOOK_SECRET>\"
      }
    }" \
    --query 'id' --output tsv
```

Update `infra.json`:
- `webhooks.wi-bug.subscriptionId` → returned ID
- `webhooks.wi-bug.status` → `"configured"`

## 3. PR Answer Service Hook (PR Commented On) — ALL PROFILES

Routes to the PR Router Lambda. **This hook is repo-scoped** — each repo (hub and every consumer) creates its own hook filtered to that repo and base branch. Without repo filtering, a project-scoped hook fires on every PR comment across all repos in the ADO project.

The PR Router Lambda uses `ADO_PR_ANSWER_PIPELINE_MAP` to route each repo's events to the correct PR Answer pipeline.

```bash
az_resource "ado/hooks/pr-answer" \
  az rest --method POST \
    --uri "<adoOrg>/_apis/hooks/subscriptions?api-version=7.1" \
    --headers "Content-Type=application/json" \
    --body "{
      \"publisherId\": \"tfs\",
      \"eventType\": \"ms.vss-code.git-pullrequest-comment-event\",
      \"resourceVersion\": \"1.0\",
      \"consumerId\": \"webHooks\",
      \"consumerActionId\": \"httpRequest\",
      \"publisherInputs\": {
        \"projectId\": \"<PROJECT_ID>\",
        \"repository\": \"<REPO_ID>\",
        \"branch\": \"<BASE_BRANCH>\"
      },
      \"consumerInputs\": {
        \"url\": \"<pr-answer-url>\",
        \"basicAuthUsername\": \"<BASIC_USER>\",
        \"basicAuthPassword\": \"<BASIC_PASS>\",
        \"httpHeaders\": \"x-webhook-secret:<WEBHOOK_SECRET>\"
      }
    }" \
    --query 'id' --output tsv
```

- `<pr-answer-url>` — for hub: from `webhooks.pr-answer.url` in infra.json. For consumer: the hub's PR Router Lambda URL (asked in step 0).
- `<REPO_ID>` — this repo's ADO repository GUID (from step 0).
- `<BASE_BRANCH>` — from `scm.base-branch` in config.yaml (e.g., `development`).

Update `infra.json`:
- `webhooks.pr-answer.subscriptionId` → returned ID
- `webhooks.pr-answer.status` → `"configured"`

## 4. PR Review Build Validation Policy — ALL PROFILES

PR Review is not a service hook — it's a build validation policy on the target branch. This triggers the PR Review pipeline on every PR against that branch.

Use `REPO_ID` from step 0 and `BASE_BRANCH` from config.yaml (already read). No need to ask again — default to `scm.base-branch`. Only ask if not set in config:
> **Target branch for PR Review?** (e.g. `main`, `develop`) — pull requests targeting this branch will trigger the PR Review agent.

```bash
REPO_ID="<repository-id>"
BRANCH="<base-branch>"
PR_REVIEW_PIPELINE_ID=$(python3 -c "import json; print(json.load(open('.ai/automation/infra.json'))['pipelines']['pr-review']['id'])")

az_resource "ado/policy/pr-review-build-validation" \
  az rest --method POST \
    --uri "<adoOrg>/<adoProject>/_apis/policy/configurations?api-version=7.1" \
    --headers "Content-Type=application/json" \
    --body "{
      \"isEnabled\": true,
      \"isBlocking\": false,
      \"type\": {\"id\": \"0609b952-1397-4640-95ec-e00a01b2f659\"},
      \"settings\": {
        \"buildDefinitionId\": $PR_REVIEW_PIPELINE_ID,
        \"queueOnSourceUpdateOnly\": true,
        \"manualQueueOnly\": false,
        \"displayName\": \"AI PR Review\",
        \"validDuration\": 720,
        \"scope\": [{
          \"repositoryId\": \"$REPO_ID\",
          \"refName\": \"refs/heads/$BRANCH\",
          \"matchKind\": \"Exact\"
        }]
      }
    }" \
    --query 'id' --output tsv
```

Update `infra.json`:
- `webhooks.pr-review.policyId` → returned ID
- `webhooks.pr-review.status` → `"configured"`

## 5. Summary Report

Adapt the report to the profile:

### For full-hub:

```markdown
## ADO Webhooks Configured (Hub)

| Hook | Event | Scope | URL | Status |
|------|-------|-------|-----|--------|
| WI User Story | workitem.updated | Project (tag: KAI-TRIGGER) | <wi-url> | ✓ configured |
| WI Bug | workitem.updated | Project (tag: KAI-TRIGGER) | <wi-url> | ✓ configured |
| PR Answer | git.pullrequest.comment-event | Repo: <repo>, branch: <branch> | <pr-answer-url> | ✓ configured |
| PR Review policy | Build validation | Repo: <repo>, branch: <branch> | (pipeline trigger) | ✓ configured |

**Tag-based routing:** The WI Router Lambda uses work item tags to determine which agent pipeline to queue. Adding a new agent only requires Lambda env vars (TAG_GATE_* + pipeline ID) — no new hook or route needed.

**infra.json** updated with subscription IDs and status.
**Audit log:** `.ai/logs/infra.<week>.jsonl`

### Verify
Test the WI hook: Go to ADO > Project Settings > Service Hooks > find "WI User Story" > click "Test" to send a sample event.

### Next step
`/auto-alarms` — Set up CloudWatch monitoring
```

### For consumer:

```markdown
## ADO Webhooks Configured (Consumer)

| Hook | Event | Scope | URL | Status |
|------|-------|-------|-----|--------|
| PR Answer | git.pullrequest.comment-event | Repo: <repo>, branch: <branch> | <hub-pr-answer-url> | ✓ configured |
| PR Review policy | Build validation | Repo: <repo>, branch: <branch> | (pipeline trigger) | ✓ configured |

WI hooks are managed by the hub project — not created here.

**infra.json** updated with subscription IDs and status.
**Audit log:** `.ai/logs/infra.<week>.jsonl`

### Next step
`/auto-doctor` — Verify setup health
```

## Success Criteria

- [ ] Service hooks created (or confirmed existing) for each enabled agent type
- [ ] No duplicate hooks — existing hooks preserved, not recreated
- [ ] PR Review build validation policy attached to the base branch
- [ ] Summary report lists each hook with status (created/exists/skipped)

## Examples

1. `/auto-webhooks` (hub project) — Creates 2 WI hooks (User Story + Bug, tag-filtered to `KAI-TRIGGER`) in the work-item ADO project (from scm.wiki-project config), 1 PR Answer hook scoped to the repo + base branch, and 1 PR Review build validation policy. Updates `infra.json` with subscription IDs.

2. `/auto-webhooks` (consumer project) — Skips WI hooks (managed by hub). Creates 1 PR Answer hook scoped to this repo + base branch pointing to the hub's Lambda URL, and 1 PR Review build validation policy. Reminds user to register the PR Answer pipeline ID in the hub's `ADO_PR_ANSWER_PIPELINE_MAP`.

3. `/auto-webhooks` (re-run, hooks already exist) — Lists existing service hooks via `az rest`, detects that the PR Answer hook and PR Review policy already exist for this repo. Skips creation with "already configured" status. Reports all hooks as healthy.

## Troubleshooting

- **"Hook created but Lambda not receiving events"**
  **Cause:** The hook was created in the wrong ADO project (hooks are project-scoped) or the API Gateway URL is incorrect.
  **Fix:** Verify the hook's ADO project matches where the repo lives (the code ADO project (from scm.project config) for code repos). Check the hook's URL points to the correct API Gateway endpoint from `infra.json`.

- **Duplicate Lambda invocations for the same event**
  **Cause:** Multiple hooks exist for the same event/repo combination (e.g., from a previous failed cleanup).
  **Fix:** List hooks with `az rest` and delete duplicates. The skill checks for existing hooks before creating, but orphaned hooks from manual creation won't be detected.

- **PR Review build policy not triggering**
  **Cause:** The build validation policy is scoped to a specific branch and repository. PRs targeting a different branch won't trigger it.
  **Fix:** Verify `scm.base-branch` in `.ai/config.yaml` matches the branch your PRs target. The policy is created for `refs/heads/<base-branch>` on the specific repository.

## Rules

- **Always source audit.sh first** — wrap `az rest` calls with `az_resource`
- **Never store passwords or secrets in infra.json** — only subscription IDs and status
- **Idempotent** — check `status: configured` in infra.json before creating (skip if already done)
- **Check remote before create** — always list existing hooks and compare by eventType+URL+repository before creating. This catches hooks created from another repo that aren't in the local infra.json
- **Work-item hooks are project-scoped (hub only)** — 2 hooks (User Story + Bug) should exist only once per project. Consumer profile skips these entirely.
- **PR Answer hook is per-repo** — each repo (hub and every consumer) creates its own hook filtered to that repository + base branch. A project-scoped hook would fire on every PR comment across all repos in the ADO project, flooding the Lambda with noise from hundreds of unrelated repos.
- **PR Review is per-repo** — build validation policy scoped to repositoryId+refName. Check by repositoryId before creating
- **Consumer profile runs this skill** — consumers create their own PR Answer hook (pointing to hub's Lambda URL) and PR Review build policy. They do NOT create WI hooks.
- **Never create duplicate hooks** — duplicate hooks cause double Lambda invocations (deduplication catches it but wastes resources)
- **Tag-based routing** — all WI webhooks route to a single `/wi` endpoint. The WI Router Lambda scans work item tags against configured TAG_GATE_* env vars to determine which agent to invoke. No per-agent routes needed.
- **Note about service hooks CLI:** ADO has no `az devops service-hooks` subcommand — `az rest` is the correct approach
- **PR Review is a build validation policy** — not a service hook (different ADO API endpoint)
