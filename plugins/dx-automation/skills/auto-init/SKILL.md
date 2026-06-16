---
name: auto-init
description: Scaffold AI automation for a project. Each project is self-contained — owns its own AWS infra and pipelines. Sets up .ai/automation/, generates infra.json. Run once after dx-init.
when_to_use: "Use when setting up AI automation for a project for the first time, when the user says 'set up automation', 'initialize AI agents', 'configure automation pipeline', or 'scaffold automation'. Run once after /dx-init."
argument-hint: ""
---

You scaffold and configure AI automation for the current project. Every project is **self-contained** — it owns its own AWS infrastructure (Lambda, DynamoDB, SQS, S3, API Gateway) and its own ADO pipelines. There is no hub/consumer split. Projects share no Lambda infrastructure with each other.

## Platform Compatibility

This skill scaffolds **Azure DevOps + AWS Lambda** automation. It is intentionally narrower than the rest of the dx-* and aem-* skills.

| Layer | Compatibility |
|---|---|
| **Skill invocation** (running `/auto-init` in your terminal) | Claude Code, Copilot CLI, VS Code Chat, Codex CLI, Gemini CLI — same as any other plugin skill |
| **Generated pipelines** (`.ai/automation/pipelines/`) | **Azure DevOps only** — pipeline YAMLs target ADO. No GitHub Actions, GitLab CI, Jenkins, or CircleCI templates exist |
| **Generated agent runtime** (`.ai/automation/agents/`) | **AWS Lambda only** — handlers assume Lambda invocation context, Anthropic API, and AWS Secrets Manager. No Cloud Functions, Azure Functions, or self-hosted variants |
| **Webhooks → triggers** | **ADO service hooks → API Gateway → Lambda** for work-item agents. PR Review/Answer use ADO build validation policy. SimpleAgent/BugFix use ADO Incoming Webhooks (Azure-native, no Lambda) |
| **AI provider** | Anthropic Claude API direct (Lambda agents); not Bedrock, Vertex, or other providers |
| **Tracker integration** | ADO work items + PR APIs. Jira-only projects can install dx-core but not dx-automation |

**If your project uses GitHub Actions, GitLab CI, or any CI/CD other than Azure DevOps, do not run `/auto-init` — it will produce pipeline YAMLs that target the wrong platform.** dx-core (`/dx-init`) and dx-aem (`/aem-init`) work fine on any tracker/CI combination; only dx-automation is ADO-locked.

This is tracked as a backlog item — see [`docs/todo/todo-automation.md` § CI/CD pipeline portability](../../../../docs/todo/todo-automation.md#cicd-pipeline-portability-non-ado) for non-ADO CI work and [`docs/todo/todo-provider-support.md`](../../../../docs/todo/todo-provider-support.md) for tracker/SCM portability (GitHub as tracker).

## Re-run Validation Protocol

**CRITICAL: When auto-init is re-run, EVERY step MUST execute. NEVER stop early.** If the user chooses "Keep config", skip to Phase 2 and continue through ALL remaining phases. Each step validates:

| File Category | Re-run Behavior |
|---|---|
| **Config** (infra.json) | Ask: keep / re-scaffold |
| **Data bundle** (.ai/automation/) | Compare against plugin data. Update **silently** only when the consumer copy is unmodified or differs in comments / project-specific names only. If a file has **functional local divergence** (added pipeline steps, gate scripts like `pr-answer-gate.sh`, branch-pins, lambda `AGENTS` edits, connection-name conventions) → show a diff and **ASK** before overwriting; default to keep. Never silently clobber local functional changes (the sync-clobber gap, TODO #151). Always preserve user-filled values in infra.json, repos.json, .env. |
| **Policy file** (.ai/automation/policy/pipeline-policy.yaml) | Compare against plugin data → if user customized: ask. If only template changed: update |
| **Generated files** (infra.json, repos.json, .env.template) | Validate structure and required fields exist — report missing fields from newer templates |

## Phase 0: Prerequisites

Check all prerequisites before proceeding:

1. **dx-init required** — read `.ai/config.yaml`. If missing: "Run `/dx-init` first." STOP.
2. **audit.sh required** — check `.ai/lib/audit.sh` exists. If missing: "Run `/dx-init` first — it installs the audit library." STOP.
3. **Ask the agent question (Question 5)** BEFORE checking CLI tools — the answer determines which tools are required.
4. **CLI tools** — verify: Node.js, AWS CLI, and Azure CLI are required. STOP if any are missing. (If user only enables PR-pipeline agents and no Lambda agents, AWS CLI is optional — prompt accordingly.)

5. **Existing scaffold** — if `.ai/automation/` already exists and has `infra.json`:

> **Automation already configured. What would you like to do?**
> **(A) Keep config** — validate all automation files against plugin data
> **(B) Re-scaffold** — re-run questions with current values pre-loaded

If **A**: Say "Config kept. Validating automation files..." — then **CONTINUE to Phase 2** to validate data bundle, policy, and generated files. **DO NOT stop or exit.**

## Phase 1: Collect Config

Ask these questions one at a time. Wait for each answer before asking the next.

**Question 1 — Agent selection** (ask this FIRST — it determines which subsequent questions to ask):

This is the same question from Phase 0 step 3. If already answered there, use the saved answer. Otherwise ask now using the Question 5 format below.

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

**Question 4 — Resource prefix:**
> **Resource prefix?** Used for all AWS resource names (DynamoDB tables, Lambda functions, S3 bucket, SQS queue, CloudWatch alarms).
>
> Example: `myproject` → `myproject-dedupe`, `myproject-DOR-Agent`
>
> Default: derive from `dx.project-name` in config.yaml, lowercase with hyphens only (e.g. `my-project`).

**Question 4b — AWS region:**
> **AWS region?** (default: `us-east-1`)

**Question 5 — Enable all agents, or customize?**
> **Which agents to enable?** Each project is self-contained — it owns its own AWS infrastructure and pipeline agents. You can enable all agents or pick the ones you need.
>
> 1. **All agents** (default) — DoR, DoD, DoD Fix, PR Review, PR Answer, BugFix, QA, DevAgent, DOCAgent, Estimation, Eval, SimpleAgent
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

Resolve the chosen selection into a list of enabled agents. Save `automationProfile: "per-project"` in infra.json alongside the enabled agents list.

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

### SimpleAgent secrets (only required if you intend to enable SimpleAgent / `@kai-simple`)

Prompt the user for:

| Prompt | Stored as | Where used |
|---|---|---|
| QA AEM author URL (e.g., `https://qa-author.example.com`) | ADO pipeline variable `AEM_QA_URL` | Pipeline `ado-cli-simple.yml` env |
| QA AEM service-account username | ADO pipeline variable `AEM_QA_USER` (secret) | Same |
| QA AEM service-account password | ADO pipeline variable `AEM_QA_PASSWORD` (secret) | Same |

Document in the generated `infra.json`:
```json
{
  "simpleAgent": {
    "qaAemUrl": "<from prompt>",
    "pipelineVariables": ["AEM_QA_URL", "AEM_QA_USER", "AEM_QA_PASSWORD"]
  }
}
```

### Optional — tune `/dx-simple` in `.ai/config.yaml`

`/dx-simple` runs out of the box on any component once SimpleAgent is enabled.
For faster compile cycles or a custom cost ceiling, add an optional block to
`.ai/config.yaml`:

```yaml
dx-simple:
  cost-ceiling-usd: 2.0
  build-compile-fast: "mvn compile -pl ui.frontend,core -am"
  recovery:                          # resumable error recovery (TODO #141)
    trigger-token: "@kai-simple"     # MUST match the ADO Service Hook comment filter
    max-attempts: 3                  # human-answer cycles before downgrading to hard
```

All keys are optional — defaults are applied when the block is absent.

> **Prerequisite for resumable recovery.** SimpleAgent's recovery uses the
> per-ticket git branch as the durable state store, so `.ai/specs/` **must be
> tracked** in git. The `/dx-init` gitignore ignores `.ai/specs/` by default —
> remove that line. Also configure the ADO **Service Hook** on the *"work item
> commented on"* event with a subscription filter requiring the comment to contain
> `trigger-token` (`@kai-simple`), wired to re-run `ado-cli-simple.yml`. Recovery is
> **human-re-triggered** (a human replies with the keyword); it is not automatic.

## Phase 2: Scaffold

Scaffolding is profile-aware. Consumer profile gets a minimal subset — only pipeline YAMLs and config. They NEVER get Lambda handlers, webhook config, or AWS resource definitions.

### 2.1. Create directories

```bash
mkdir -p .ai/automation
```

### 2.2. Copy data bundle

Copy the entire data bundle (pipelines, Lambda handlers, prompts, eval, docs):

```bash
PLUGIN_DIR="$(dirname "$(dirname "$0")")"
if [ -d ".ai/automation" ]; then
  rsync -a --ignore-existing "$PLUGIN_DIR/data/" ".ai/automation/"
  echo "Validated .ai/automation/ data bundle (new files added, existing preserved)"
else
  cp -r "$PLUGIN_DIR/data/." ".ai/automation/"
  echo "Installed .ai/automation/ data bundle"
fi
chmod +x .ai/automation/lambda/deploy.sh \
  .ai/automation/lambda/cloudwatch/setup-alarms.sh
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
- `{{PIPELINE_NAME_PREFIX}}` → use the `pipelineFolder` name (strip backslash, e.g. `\KAI` → `KAI`). If no folder, derive from `project.name` in config.yaml with a `KAI-<RepoShortName>` format (e.g., `KAI-MyApp` for Experience-MyApp). Strip common prefixes like `Experience-`. **Never ask the user about pipeline naming** — ADO lists all pipelines in the project dropdown, so names must be distinguishable across repos.
- `{{PIPELINE_FOLDER}}` → from Question 2 (e.g. `\\KAI`). If user left blank, remove the field or set to empty string.
- Leave `{{DOR_PIPELINE_ID}}`, `{{DOD_PIPELINE_ID}}`, etc. as-is (filled by later skills)

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

```markdown
## Automation Scaffolded

**Profile:** Per-project (self-contained)
**Pipeline prefix:** KAI-<RepoShortName>
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


## Examples

1. `/auto-init` — First-time setup. Asks which agents to enable, scaffolds full `.ai/automation/` directory with `infra.json` containing AWS resource prefix, region, and agent definitions. Prints next step: `/auto-provision`.

2. `/auto-init` (customize agents) — User picks specific agents (e.g., PR Review + PR Answer only — no Lambda agents needed). Scaffolds pipelines but skips Lambda-only setup. Prints next step: `/auto-pipelines`.

3. `/auto-init` (re-run on existing setup) — Detects `infra.json` already exists with `automationProfile: per-project`. Validates each section against current plugin data, finds 2 new agent definitions added in the latest plugin version, and asks whether to add them. Updates `infra.json` with the new agents while preserving existing pipeline IDs and configuration.

## Troubleshooting

- **"`.ai/config.yaml` not found — run `/dx-init` first"**
  **Cause:** `/auto-init` requires the base config from `/dx-init`.
  **Fix:** Run `/dx-init` to create `.ai/config.yaml` with SCM settings, then re-run `/auto-init`.

- **"infra.json already exists — overwrite?"**
  **Cause:** Automation was already initialized for this project.
  **Fix:** Choose "validate and update" to preserve existing pipeline IDs and AWS resource references. Only choose "overwrite" if the config is corrupted.

## Rules

- **Interactive — use AskUserQuestion** — Every question, confirmation, or choice in this skill MUST use the `AskUserQuestion` tool to pause and wait for the user's response. Never proceed past a question without receiving the user's answer first. Present numbered options in the question text, then STOP and wait. Do not batch multiple questions into one message — ask one, wait for the answer, then continue.
- **Agent question first** — ask which agents to enable before anything else (after dx-init check). This determines which tools are required.
- **Non-hub repos MUST NOT touch AWS** — for `consumer` profile: never scaffold Lambda handlers, AWS resource definitions, deploy scripts, or CloudWatch alarms. Never ask for AWS region, resource prefix, or AWS account. Never suggest running `/auto-provision`, `/auto-deploy`, `/auto-lambda-env`, or `/auto-alarms`. Consumers DO run `/auto-webhooks` (for repo-scoped PR Answer hook + PR Review build policy).
- **Prerequisites first** — check dx-init and audit.sh before anything else
- **Never overwrite infra.json** — if it already exists, ask before replacing
- **Validate on re-run** — every step executes on re-run; validate existing files against plugin data, smart-update what's outdated, ask when in doubt
- **Don't deploy anything** — this skill only scaffolds; no AWS/ADO calls (those are in later skills)
- **Derive defaults from config.yaml** — read dx config first, ask only what can't be detected
