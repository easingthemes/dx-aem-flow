---
name: auto-init
description: Scaffold AI automation for a project. Asks whether this is the hub (all agents + AWS infra) or a consumer (PR pipelines only). Sets up .ai/automation/, generates infra.json. Run once after dx-init.
argument-hint: ""
---

You scaffold and configure AI automation for the current project. First asks whether this is the **hub** (full setup: all agents + Lambda + webhooks + AWS resources) or a **consumer** (PR + delegation-ready pipelines, using the hub's shared infrastructure). Consumer repos never deploy or modify AWS resources.

## Re-run Validation Protocol

**CRITICAL: When auto-init is re-run, EVERY step MUST execute. NEVER stop early.** If the user chooses "Keep config", skip to Phase 2 and continue through ALL remaining phases. Each step validates:

| File Category | Re-run Behavior |
|---|---|
| **Config** (infra.json) | Ask: keep / re-scaffold |
| **Data bundle** (.ai/automation/) | Compare against plugin data → update silently if plugin files changed (preserving user-filled values in infra.json, repos.json, .env) |
| **Policy file** (.ai/automation/policy/pipeline-policy.yaml) | Compare against plugin data → if user customized: ask. If only template changed: update |
| **Generated files** (infra.json, repos.json, .env.template) | Validate structure and required fields exist — report missing fields from newer templates |

## Phase 0: Prerequisites

Check all prerequisites before proceeding:

1. **dx-init required** — read `.ai/config.yaml`. If missing: "Run `/dx-init` first." STOP.
2. **audit.sh required** — check `.ai/lib/audit.sh` exists. If missing: "Run `/dx-init` first — it installs the audit library." STOP.
3. **Ask the hub question (Question 5)** BEFORE checking CLI tools — the answer determines which tools are required.
4. **CLI tools** — verify based on profile:
   - **Full hub:** Node.js, AWS CLI, and Azure CLI are all required. Run `setup-cli.sh` if `.ai/automation/` exists. STOP if any are missing.
   - **Consumer:** Only Node.js is required (for pipeline agent scripts). AWS CLI and Azure CLI are NOT needed — this repo does not manage AWS resources.

5. **Existing scaffold** — if `.ai/automation/` already exists and has `infra.json`:

> **Automation already configured. What would you like to do?**
> **(A) Keep config** — validate all automation files against plugin data
> **(B) Re-scaffold** — re-run questions with current values pre-loaded

If **A**: Say "Config kept. Validating automation files..." — then **CONTINUE to Phase 2** to validate data bundle, policy, and generated files. **DO NOT stop or exit.**

## Phase 1: Collect Config

Ask these questions one at a time. Wait for each answer before asking the next.

**Question 1 — Hub or consumer?** (ask this FIRST — it determines which subsequent questions to ask):

This is the same question from Phase 0 step 3. If already answered there, use the saved answer. Otherwise ask now using the Question 5 format below.

After the profile is chosen, the remaining questions depend on the profile:

**Question 2 — Pipeline folder (optional):**
> **ADO pipeline folder?** Pipelines will be created inside this folder for organization.
>
> Example: `\KAI`, `\AI-Agents`
>
> Default: root folder (no folder). Stored as `pipelineFolder` in infra.json.

**Question 3 — Your ADO identity:**
> Before asking, run `git config user.email` and `git config user.name` to get the current git user. Offer that as the default suggestion.
>
> **Your ADO identity?** Used to filter PR Review (skip your own PRs) and PR Answer (respond to comments on your PRs).
>
> Format: `email@example.com, Display Name`
>
> Default: `<git-email>, <git-name>` (from git config)

**Question 4 — Resource prefix (full-hub only):**
> Only ask this for `full-hub` profile. For `consumer` profile, skip — they use the hub's existing AWS infrastructure and do NOT deploy their own Lambda, DynamoDB, SQS, S3, or API Gateway.
>
> **Resource prefix?** Used for all AWS resource names (DynamoDB tables, Lambda functions, S3 bucket, SQS queue, CloudWatch alarms).
>
> Example: `myproject` → `myproject-dedupe`, `myproject-DOR-Agent`
>
> Default: derive from `dx.project-name` in config.yaml, lowercase with hyphens only (e.g. `my-project`).

**Question 4b — AWS region (full-hub only):**
> Only ask this for `full-hub` profile.
>
> **AWS region?** (default: `us-east-1`)

**Question 4c — Hub reference (consumer only):**
> For consumer profile, ask which project is the hub so we can reference its shared Lambda:
>
> **Which project is the automation hub?** This is the project that owns the Lambda functions and webhooks. Pipeline IDs from this repo will be registered in the hub's Lambda env vars.
>
> Default: auto-detect from `repos:` in config.yaml if available, or from sibling repos detected by dx-init.

**Question 5 — Hub or consumer?**
> **Is this the main project for AI automation?** The main project owns all AWS infrastructure (Lambda, DynamoDB, webhooks) and runs all work-item-triggered agents. Other projects are consumers — they get PR pipelines and delegation-ready pipelines, but the hub controls which to actually use.
>
> 1. **Yes — this is the hub** — Set up all agents + Lambda + webhooks + AWS resources
> 2. **No — consumer** — PR Review + PR Answer + Eval + delegation-ready pipelines (DevAgent, BugFix, DoD Fix). Uses the hub's shared infrastructure. No AWS setup needed.
>
> Default: 2 (Consumer)

**If user chose 1 (hub), ask follow-up:**
> **Enable all agents, or customize?**
>
> 1. **All agents** (default) — DoR, DoD, DoD Fix, PR Review, PR Answer, BugFix, QA, DevAgent, DOCAgent, Estimation, Eval
> 2. **Customize** — pick individual agents

**If user chose customize, show the agent list:**
> **Which agents to enable?** (comma-separated numbers or "all")
>
> 1. **PR Review** — reviews PRs via build validation (no Lambda)
> 2. **PR Answer** — responds to PR comments (needs PR-Router Lambda)
> 3. **Eval** — quality gates on `.ai/` changes (no Lambda)
> 4. **DoR** — Definition of Ready check on tagged work items
> 5. **DoD** — Definition of Done check on tagged work items
> 6. **DoD Fix** — auto-fixes DoD failures (cross-repo aware)
> 7. **BugFix** — triages and fixes Bugs (cross-repo aware)
> 8. **QA** — browser-based AEM verification
> 9. **DevAgent** — full autonomous development (cross-repo, Figma support)
> 10. **DOCAgent** — wiki docs + AEM demo pages
> 11. **Estimation** — auto-estimates story points

**No delegation follow-up for consumers.** Consumer repos always get all 6 pipeline YAMLs (pr-review, pr-answer, eval, devagent, bugfix, dod-fix). The hub controls which pipelines it actually delegates to via its `CROSS_REPO_PIPELINE_MAP` and `ADO_PR_ANSWER_PIPELINE_MAP` env vars. Having unused pipeline YAMLs in the consumer costs nothing but not having them blocks delegation later.

Resolve the chosen profile into a list of enabled agents:
- **Hub + all**: all agents → profile `full-hub`
- **Hub + customize**: user's selection → profile `full-hub`
- **Consumer**: pr-review, pr-answer, eval, devagent, bugfix, dod-fix → profile `consumer`

Save the profile name in `automationProfile` in infra.json alongside the enabled agents list.

**If DoR enabled (full-hub or custom with DoR) — Question 5a:**
> **DoR wiki URL?** ADO wiki page containing your Definition of Ready criteria.
>
> Example: `https://dev.azure.com/myorg/myproject/_wiki/wikis/MyWiki/123/Definition-of-Ready`
>
> (Leave blank to skip wiki fetch — agent uses default criteria only)

**If QA enabled (full-hub or custom with QA) — Question 5b:**
> **Remote AEM Author URL?** For dialog and component verification (content editing instance).
>
> Example: `https://author-myproject.adobeaemcloud.com`
>
> (Leave blank for local AEM author at `http://localhost:4502`)

**If QA enabled (full-hub or custom with QA) — Question 5c:**
> **Remote AEM Publisher URL?** For user-facing page verification (publisher instance — always different from author).
>
> Example: `https://publish-myproject.adobeaemcloud.com`
>
> (Leave blank for local AEM publisher at `http://localhost:4503`)

**If DevAgent enabled (full-hub, consumer, or custom with DevAgent) — Figma note:**
> Figma design-to-code works automatically via the Figma MCP server (connects to the local Figma desktop app). No token or configuration needed — DevAgent extracts Figma URLs from work items and calls Figma MCP for design context.
>
> **Note:** Figma integration in CI/CD pipelines (headless environments without a local Figma app) is not yet supported. See TODO for remote Figma API support.

## Phase 2: Scaffold

Scaffolding is profile-aware. Consumer profile gets a minimal subset — only pipeline YAMLs and config. They NEVER get Lambda handlers, webhook config, or AWS resource definitions.

### 2.1. Create directories

```bash
mkdir -p .ai/automation
```

### 2.2. Copy data bundle (profile-aware)

**Full hub:** Copy the entire data bundle (pipelines, Lambda handlers, agents, prompts, eval, docs):

```bash
PLUGIN_DIR="$(dirname "$(dirname "$0")")"
if [ -d ".ai/automation" ]; then
  rsync -a --ignore-existing "$PLUGIN_DIR/data/" ".ai/automation/"
  echo "Validated .ai/automation/ data bundle (new files added, existing preserved)"
else
  cp -r "$PLUGIN_DIR/data/." ".ai/automation/"
  echo "Installed .ai/automation/ data bundle"
fi
chmod +x .ai/automation/setup-cli.sh .ai/automation/run.sh \
  .ai/automation/lambda/deploy.sh \
  .ai/automation/lambda/cloudwatch/setup-alarms.sh
```

**Consumer:** Copy ONLY the relevant subset — no Lambda, no webhook config, no AWS resource scripts:

```bash
PLUGIN_DIR="$(dirname "$(dirname "$0")")"
mkdir -p .ai/automation/pipelines/cli

# Copy eval pipeline
if [ -d "$PLUGIN_DIR/data/pipelines/eval" ]; then
  cp -r "$PLUGIN_DIR/data/pipelines/eval" .ai/automation/pipelines/
fi

# Copy CLI pipeline YAMLs for consumer agents (PR + delegation-ready)
for yml in ado-cli-pr-review.yml ado-cli-pr-answer.yml ado-cli-dev-agent.yml ado-cli-bug-fix.yml ado-cli-dod-fix.yml; do
  if [ -f "$PLUGIN_DIR/data/pipelines/cli/$yml" ]; then
    cp "$PLUGIN_DIR/data/pipelines/cli/$yml" .ai/automation/pipelines/cli/
  fi
done

echo "Installed .ai/automation/ (consumer profile — pipelines only, no Lambda/AWS)"
```

### 2.3. Copy policy file (validate on re-run)

```bash
mkdir -p .ai/automation/policy
SRC="$PLUGIN_DIR/data/policy/pipeline-policy.yaml"
DST=".ai/automation/policy/pipeline-policy.yaml"
if [ ! -f "$DST" ]; then
  cp "$SRC" "$DST"
  echo "Installed .ai/automation/policy/pipeline-policy.yaml"
elif diff -q "$SRC" "$DST" >/dev/null 2>&1; then
  echo "Validated .ai/automation/policy/pipeline-policy.yaml (up to date)"
else
  echo "REVIEW: .ai/automation/policy/pipeline-policy.yaml (differs from plugin data)"
fi
```

For `REVIEW` items: read both files, show the user what changed, and ask: **(A) Keep existing** (user may have customized), **(B) Replace with plugin version**.

### 2.4. Generate `.ai/automation/infra.json`

**Full hub:** Read `infra.template.json`, then fill in:
- `{{ADO_ORG_URL}}` → from `dx.scm.org-url` in config.yaml (or ask if not found)
- `{{ADO_PROJECT}}` → from `dx.scm.project` in config.yaml (or ask if not found)
- `{{AWS_REGION}}` → from Question 5b
- `{{AWS_ACCOUNT_ID}}` → run `aws sts get-caller-identity --query Account --output text` (leave as `{{AWS_ACCOUNT_ID}}` if fails — note for user)
- `{{RESOURCE_PREFIX}}` → from Question 5 (lowercase)
- `{{PIPELINE_NAME_PREFIX}}` → for the **hub repo**, use the `pipelineFolder` name (strip backslash, e.g. `\KAI` → `KAI`). If no folder, default to `KAI`. For **consumer repos**, append a short repo identifier: `KAI-<RepoShortName>` (e.g., `KAI-MyApp` for Experience-MyApp). Derive `RepoShortName` from `project.name` in config.yaml — strip common prefixes like `Experience-`. **Never ask the user about pipeline naming** — ADO lists all pipelines in the project dropdown (e.g., build policies), so names must be distinguishable across repos.
- `{{PIPELINE_FOLDER}}` → from Question 2 (e.g. `\\KAI`). If user left blank, remove the field or set to empty string.
- Leave `{{DOR_PIPELINE_ID}}`, `{{DOD_PIPELINE_ID}}`, etc. as-is (filled by later skills)

**Consumer:** Generate a minimal `infra.json` with only:
- `automationProfile`: `consumer`
- `adoOrg`, `adoProject`: from config.yaml
- `pipelineFolder`: from Question 2
- `hubProject`: from Question 5c (the project owning Lambda/webhooks)
- `pipelines`: entries for all consumer agents (pr-review, pr-answer, eval, devagent, bugfix, dod-fix). **Pipeline names must be repo-unique** because ADO's build policy dropdown lists all pipelines in the project. Use `KAI-<RepoShortName>-*` (e.g., `KAI-MyApp-PR-Review-Agent`, `KAI-MyApp-DevAgent`). Derive `RepoShortName` from `project.name` in config.yaml — strip common prefixes like `Experience-`. **Never ask the user about pipeline naming.**
- `webhooks.pr-answer`: entry for the repo-scoped PR Answer hook (URL left as placeholder — filled by `/auto-webhooks` using the hub's Lambda URL)
- **No** `lambdas`, `storage`, `monitoring`, or `apiGateway` sections

Write to `.ai/automation/infra.json`.

### 2.5. Generate `.ai/automation/repos.json`

Read the template. Replace the example repo entry with the current repo (from `git remote get-url origin` + `dx.project-name` in config.yaml). Write to `.ai/automation/repos.json`.

### 2.6. Generate `.ai/automation/.env.template`

**Full hub:**
```bash
cat > .ai/automation/.env.template << 'EOF'
# AI Automation — environment variables for local runner and Lambda
# Copy to .env and fill in values. NEVER commit .env to git.

# ADO credentials
AZURE_DEVOPS_PAT=                    # ADO Personal Access Token

# LLM credentials
ANTHROPIC_API_KEY=                   # Claude API key (used by all pipelines)

# Lambda env vars (also set in AWS Console)
BASIC_USER=                          # Webhook basic auth username
BASIC_PASS=                          # Webhook basic auth password
WEBHOOK_SECRET=                      # Shared webhook secret header value
ADO_PAT=                             # Same as AZURE_DEVOPS_PAT

# AWS credentials (for local runner; Lambda uses IAM role)
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=
EOF
```

**Consumer:** Generate a shorter `.env.template` with only the variables needed for pipeline agents (no Lambda/AWS vars):
```bash
cat > .ai/automation/.env.template << 'EOF'
# AI Automation — pipeline variables
# Copy to .env and fill in values. NEVER commit .env to git.

# ADO credentials
AZURE_DEVOPS_PAT=                    # ADO Personal Access Token

# LLM credentials
ANTHROPIC_API_KEY=                   # Claude API key (used by all pipelines)
EOF
```

### 2.7. Mark disabled agents

If user did NOT enable an agent, add `"disabled": true` to the relevant pipeline entry in infra.json.

## Phase 2b: Update agent.index.md

If `agent.index.md` exists at the project root and does not already contain `## CI/CD Pipeline Agents`, insert before `## Not Agent Files`:

```markdown

## CI/CD Pipeline Agents

| Path | What | Committed |
|------|------|-----------|
| `.ai/automation/` | CI/CD automation — pipeline agents, Lambda handlers, eval framework | Yes |
| `.ai/automation/policy/` | Runtime policy (capability gating, redaction, rate limits) | Yes |

| Agent | Trigger |
|-------|---------|
| DoR (Definition of Ready) | Tag work item |
| DoD (Definition of Done) | Tag work item |
| DoD Fix | Tag work item |
| PR Review | PR created/updated |
| PR Answer | Comment on your PR |
| BugFix | Tag bug ticket |
| QA | Tag work item |
| DevAgent | Tag work item |
| DOCAgent | Tag work item |
| Estimation | Tag work item |
```

Only include agents that were enabled in Question 6. If `agent.index.md` doesn't exist, skip (user hasn't run dx-init yet).

## Phase 3: Report + Next Steps

Adapt the report to the chosen profile:

### For full-hub profile:

```markdown
## Automation Scaffolded (Full Hub)

**Profile:** Full Hub
**Pipeline prefix:** KAI (hub) / KAI-<RepoShortName> (consumers)
**Region:** <region>
**Agents:** DoR <✓/✗> | DoD <✓/✗> | DoD Fix <✓/✗> | PR Review <✓/✗> | PR Answer <✓/✗> | BugFix <✓/✗> | QA <✓/✗> | DevAgent <✓/✗> | DOCAgent <✓/✗> | Estimation <✓/✗>
**ADO identity:** <email, Name>

**Files created:**
- `.ai/automation/` — Lambda handlers, ADO pipelines, eval framework
- `.ai/rules/` — shared rules (installed by dx-init). Edit to customize review criteria, answer tone, pragmatism filters. Changes apply to BOTH local dx skills and automation agents.
- `.ai/automation/policy/pipeline-policy.yaml` — agent capability gates, redaction policy, rate limits, token budget. Update the three `← Update` fields.
- `.ai/automation/infra.json` — fill remaining `{{PLACEHOLDER}}` values after provisioning
- `.ai/automation/repos.json` — add repos your agents should search (for DoR code discovery)
- `.ai/automation/.env.template` — credential reference (copy to `.env`, never commit)

<If AWS account ID was not auto-detected:>
⚠️  **AWS account ID not detected.** Run `aws sts get-caller-identity` and fill `{{AWS_ACCOUNT_ID}}` in `infra.json`.

### Setup Sequence

Run these skills in order to complete the setup:

1. `/auto-provision` — Create AWS resources (DynamoDB, SQS, S3, Lambda, API Gateway)
2. `/auto-pipelines` — Import ADO pipelines + set variables
3. `/auto-deploy` — Deploy Lambda code
4. `/auto-lambda-env` — Set Lambda environment variables
5. `/auto-webhooks` — Configure ADO service hooks
6. `/auto-alarms` — Set up CloudWatch monitoring
7. `/auto-test --dryRun` — Verify end-to-end

### Verify anytime
- `/auto-doctor` — Health check (files, ADO pipelines, Lambda functions)
- `/auto-status` — DLQ depth, token budget, rate limits
```

### For consumer profile:

```markdown
## Automation Scaffolded (Consumer)

**Profile:** Consumer
**Hub project:** <hub project name> (owns Lambda + webhooks)
**Agents:** PR Review ✓ | PR Answer ✓ | Eval ✓ | DevAgent ✓ | BugFix ✓ | DoD Fix ✓
**ADO identity:** <email, Name>

**Files created:**
- `.ai/automation/pipelines/` — ADO pipeline YAMLs (PR + delegation-ready)
- `.ai/automation/policy/pipeline-policy.yaml` — agent capability gates
- `.ai/automation/infra.json` — pipeline IDs (fill after import)
- `.ai/automation/.env.template` — credential reference

**⚠️ No AWS resources are managed by this repo.** Lambda, DynamoDB, SQS, S3, API Gateway are owned by the hub project (<hub>). Do NOT run `/auto-provision`, `/auto-deploy`, `/auto-lambda-env`, or `/auto-alarms` from this repo.

### Setup Sequence

1. `/auto-pipelines` — Import ADO pipelines + set variables
2. **Register with hub** — After importing pipelines, update the hub's Lambda env vars:
   - Add this repo's PR Answer pipeline ID to the hub's `ADO_PR_ANSWER_PIPELINE_MAP`
   - Add this repo's DevAgent/BugFix/DoD-Fix pipeline IDs to the hub's `CROSS_REPO_PIPELINE_MAP`
3. `/auto-webhooks` — Create repo-scoped PR Answer hook + PR Review build policy
4. `/auto-test --dryRun` — Verify pipelines run

### Verify anytime
- `/auto-doctor` — Health check (pipeline YAMLs, config)
```

## Examples

1. `/auto-init` (hub project) — User answers "yes" to "Is this the main project?" Scaffolds full `.ai/automation/` directory with `infra.json` containing AWS resource prefix, region, all 10 agent definitions (DoR, DoD, PR Review, PR Answer, DevAgent, BugFix, QA, DOCAgent, Estimation, DoD-Fix), Lambda handler templates, and deployment scripts. Prints next step: `/auto-provision`.

2. `/auto-init` (consumer project) — User answers "no" to hub question, provides hub project name. Scaffolds consumer-profile `infra.json` with only PR-related pipelines (PR Review, PR Answer), pipeline YAML files, and references to the hub's Lambda URLs. No AWS resources, no Lambda handlers. Prints next step: `/auto-pipelines`.

3. `/auto-init` (re-run on existing setup) — Detects `infra.json` already exists with `automationProfile: full-hub`. Validates each section against current plugin data, finds 2 new agent definitions added in the latest plugin version, and asks whether to add them. Updates `infra.json` with the new agents while preserving existing pipeline IDs and configuration.

## Troubleshooting

- **"`.ai/config.yaml` not found — run `/dx-init` first"**
  **Cause:** `/auto-init` requires the base config from `/dx-init`.
  **Fix:** Run `/dx-init` to create `.ai/config.yaml` with SCM settings, then re-run `/auto-init`.

- **"infra.json already exists — overwrite?"**
  **Cause:** Automation was already initialized for this project.
  **Fix:** Choose "validate and update" to preserve existing pipeline IDs and AWS resource references. Only choose "overwrite" if the config is corrupted or you're switching between hub and consumer profiles.

- **Consumer profile asks about AWS resources**
  **Cause:** This should not happen — consumer profiles skip all AWS configuration.
  **Fix:** Check that `infra.json` has `"automationProfile": "consumer"`. If it says `full-hub`, the profile was set incorrectly during init. Re-run `/auto-init` and answer "no" to the hub question.

## Rules

- **Interactive — use AskUserQuestion** — Every question, confirmation, or choice in this skill MUST use the `AskUserQuestion` tool to pause and wait for the user's response. Never proceed past a question without receiving the user's answer first. Present numbered options in the question text, then STOP and wait. Do not batch multiple questions into one message — ask one, wait for the answer, then continue.
- **Hub question first** — ask "Is this the main project?" before anything else (after dx-init check). This determines the entire flow.
- **Non-hub repos MUST NOT touch AWS** — for `consumer` profile: never scaffold Lambda handlers, AWS resource definitions, deploy scripts, or CloudWatch alarms. Never ask for AWS region, resource prefix, or AWS account. Never suggest running `/auto-provision`, `/auto-deploy`, `/auto-lambda-env`, or `/auto-alarms`. Consumers DO run `/auto-webhooks` (for repo-scoped PR Answer hook + PR Review build policy).
- **Prerequisites first** — check dx-init and audit.sh before anything else
- **Never overwrite infra.json** — if it already exists, ask before replacing
- **Validate on re-run** — every step executes on re-run; validate existing files against plugin data, smart-update what's outdated, ask when in doubt
- **Don't deploy anything** — this skill only scaffolds; no AWS/ADO calls (those are in later skills)
- **Derive defaults from config.yaml** — read dx config first, ask only what can't be detected
