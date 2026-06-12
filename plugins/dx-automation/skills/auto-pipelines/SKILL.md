---
name: auto-pipelines
description: Import ADO pipelines for enabled AI automation agents and set all required pipeline variables. Profile-aware — imports only pipelines for the configured profile (consumer or full-hub). Reads config from .ai/automation/infra.json.
argument-hint: ""
---

You import ADO pipeline YAML files into Azure DevOps and set all required variables. Uses `az pipelines` (audit-wrapped) and reads config from `.ai/automation/infra.json`. Only imports pipelines that are enabled for the configured profile.

## 0. Prerequisites

```bash
source .ai/lib/audit.sh
export AUDIT_LOG_PREFIX=infra
```

Read `.ai/automation/infra.json`. Extract:
- `automationProfile` — determines which pipelines to import
- `adoOrg` — ADO org URL
- `adoProject` — ADO project name
- `pipelineFolder` — optional ADO pipeline folder path (e.g. `\\KAI`). If set, pipelines are created inside this folder.
- Pipeline entries — **only those without `"disabled": true`**

Read `.ai/config.yaml` to get `scm.repo` (repository name for pipeline import).

Print: `Profile: <profile> — importing <N> pipelines`

Expected pipelines per profile:
- **consumer** (or legacy `pr-only`/`pr-delegation`): pr-review, pr-answer, eval, devagent, bugfix, dod-fix, simple
- **full-hub**: all enabled pipelines (includes `simple` — the SimpleAgent pipeline, `@kai-simple` comment trigger, YAML `ado-cli-simple.yml`)

**SimpleAgent + the KAI-HUB router are imported here like any other pipeline.** SimpleAgent has *no Lambda* — its trigger is an Azure-native Service Hook + Incoming WebHook service connection (configured by `/auto-webhooks`, not here). But "no Lambda" only affects the *trigger*: the pipeline YAML still must be imported as an ADO definition and given variables, which is exactly this skill's job. So:
- **`simple`** (`ado-cli-simple.yml`) — enabled by default; imported for both consumer and full-hub when not `disabled`. This dual-mode worker is what the comment hook fires directly in a single-repo project.
- **`hub`** (`ado-cli-hub.yml`) — **multi-repo only, `"disabled": true` by default** in `infra.template.json`. Import it only when the project routes `@kai-<agent>` comments centrally and fans agents out across repos. Skip it (like any disabled entry) unless explicitly enabled.

## 1. Import Pipelines

For each enabled pipeline (in order), import the YAML into ADO.

All pipelines use Claude Code CLI (single-step skill invocation): `.ai/automation/pipelines/cli/ado-cli-<agent>.yml`. The eval pipeline uses `.ai/automation/pipelines/eval/ado-eval-pipeline.yml`.

### 1a. Check if pipeline already exists

Before creating, check if a pipeline with this name already exists in the project:

```bash
EXISTING_ID=$(az pipelines list \
  --name "<pipeline-name>" \
  --project "<adoProject>" \
  --organization "<adoOrg>" \
  --query "[0].id" --output tsv 2>/dev/null)
```

- If `EXISTING_ID` is non-empty: **skip creation**, use existing ID. Report: `⏭ <pipeline-name> already exists (ID: <id>) — skipping`
- If empty: create the pipeline (step 1b)

### 1b. Create pipeline (only if not exists)

If `pipelineFolder` is set in infra.json, first ensure the folder exists:

```bash
az pipelines folder create \
  --path "<pipelineFolder>" \
  --project "<adoProject>" \
  --organization "<adoOrg>" 2>/dev/null || true  # ignore if already exists
```

Then create the pipeline with `--folder-path` if the folder is configured:

```bash
PIPELINE_ID=$(az_pipelines create \
  --name "<pipeline-name>" \
  --repository "<repo-name>" \
  --branch main \
  --repository-type tfsgit \
  --yml-path "<yaml-path>" \
  --folder-path "<pipelineFolder>" \
  --project "<adoProject>" \
  --organization "<adoOrg>" \
  --skip-first-run true \
  --query id --output tsv)
```

Omit `--folder-path` if `pipelineFolder` is not set or empty in infra.json.

After each import (or reuse), update `infra.json`:
- `pipelines.<agent>.id` → `$PIPELINE_ID` (or `$EXISTING_ID`)

Report: pipeline name, ID, YAML path, created/reused.

## 2. Set Pipeline Variables

For each imported pipeline, set required variables. Ask for secret values — **one pipeline at a time**, display current pipeline name clearly before asking.

### 2a. Anthropic API key

All pipelines use Claude Code CLI. Ask once, apply to all pipelines:

> **Anthropic API key?** (secret — used by Claude Code CLI for authentication)

Set: `ANTHROPIC_API_KEY` (secret).

### 2b. Common variables

> **Monthly token cap?** (default: `5000000` = 5M tokens per month)

```bash
az_pipelines_variable create \
  --name "MONTHLY_TOKEN_CAP" \
  --value "5000000" \
  --pipeline-name "<pipeline-name>" \
  --project "<adoProject>" \
  --organization "<adoOrg>"
```

### DoR pipeline additional variable

> **DoR wiki URL?** ADO wiki page with your Definition of Ready criteria.
>
> (Leave blank to skip — agent uses default criteria)

```bash
az_pipelines_variable create \
  --name "DOR_WIKI_URL" \
  --value "<value>" \
  --pipeline-name "<pipeline-name>" \
  --project "<adoProject>" \
  --organization "<adoOrg>"
```

### PR Review pipeline additional variable

> **Reviewer identities?** Comma-separated ADO identities to filter as reviewer.
>
> Format: `email@example.com, Display Name` (from `/auto-init` config — pre-fill from infra.json)

```bash
az_pipelines_variable create \
  --name "REVIEWER_IDENTITIES" \
  --value "<email, Name>" \
  --pipeline-name "<pipeline-name>" \
  --project "<adoProject>" \
  --organization "<adoOrg>"
```

### PR Answer pipeline additional variable

> **My identities?** Comma-separated ADO identities for PR Answer (whose PRs to respond on).
>
> (Pre-fill from infra.json if set during `auto-init`)

```bash
az_pipelines_variable create \
  --name "MY_IDENTITIES" \
  --value "<email, Name>" \
  --pipeline-name "<pipeline-name>" \
  --project "<adoProject>" \
  --organization "<adoOrg>"
```

### QA pipeline additional variables

> **Remote AEM Author URL?** For dialog/component verification (e.g. `https://author-myproject.adobeaemcloud.com`)
> Default: `http://localhost:4502`

> **Remote AEM Publisher URL?** For user-facing page verification (e.g. `https://publish-myproject.adobeaemcloud.com`)
> Default: `http://localhost:4503`

> **AEM username?** Default: `admin`

> **AEM password?** (secret)

Set: `AEM_AUTHOR_URL`, `AEM_PUBLISH_URL`, `AEM_USER`, `AEM_PASS` (secret).

### ADO org URL (ALL CLI pipelines)

Set this on ALL CLI pipelines (DoR, PR Review, PR Answer, DoD, DoD-Fix, BugFix, QA, DevAgent, DOCAgent, Estimation). The pipelines fetch the dx-aem-flow plugins by cloning the **public** GitHub repo (`https://github.com/easingthemes/dx-aem-flow.git`, hardcoded in each pipeline YAML) — no marketplace URL variable is needed. `ADO_ORG_URL` is used by the agents to reach the ADO REST API.

> **ADO org URL?** (pre-fill from `infra.json` > `adoOrg`)
>
> Used by the agents to call the ADO REST API (fetch work item, post comments).

```bash
az_pipelines_variable create \
  --name "ADO_ORG_URL" \
  --value "<adoOrg from infra.json>" \
  --pipeline-name "<pipeline-name>" \
  --project "<adoProject>" \
  --organization "<adoOrg>"
```

### Code-writing pipeline additional variables (BugFix, DevAgent, DoD-Fix)

Set these on ALL three code-writing pipelines. These enable cross-repo delegation — when a work item requires changes in another repo, the pipeline queues the equivalent pipeline in that repo.

> **ADO org URL?** (pre-fill from `infra.json` > `adoOrg`)
>
> Used by the delegation step to call ADO REST API.

```bash
az_pipelines_variable create \
  --name "ADO_ORG_URL" \
  --value "<adoOrg from infra.json>" \
  --pipeline-name "<pipeline-name>" \
  --project "<adoProject>" \
  --organization "<adoOrg>"
```

> **Multi-repo fan-out?** There is no per-pipeline cross-repo map anymore. The
> central **KAI-HUB** router (`ado-cli-hub.yml`) handles multi-repo fan-out: it
> reads the `repos.json` + `agents.json` registries
> (`.ai/automation/registries/`) and queues each agent's worker once per resolved
> repo. Single-repo projects don't import the hub at all — their dual-mode worker
> fires directly via its own webhook. See `dx-hub/shared/registry-format.md`.
>
> So workers no longer need a `CROSS_REPO_PIPELINE_MAP` variable. The only extra
> variable the hub itself needs is `ADO_PAT` (to queue cross-project worker runs).

### DevAgent pipeline additional variables

Set these on the DevAgent pipeline (in addition to `ANTHROPIC_API_KEY` + `ADO_ORG_URL` above):

| Variable | Value | Secret? |
|----------|-------|---------|
| `FIGMA_PERSONAL_ACCESS_TOKEN` | Optional — Figma API token for headless/CI Figma access (not needed locally — Figma MCP uses desktop app) | Yes |

### DOCAgent pipeline additional variables

Set these on the DOCAgent pipeline (in addition to `ANTHROPIC_API_KEY`):

| Variable | Value | Secret? |
|----------|-------|---------|
| `AEM_AUTHOR_URL` | Remote AEM author URL (same as QA pipeline) | No |
| `AEM_PUBLISH_URL` | Remote AEM publisher URL (same as QA pipeline) | No |
| `AEM_USER` | AEM username (same as QA pipeline) | No |
| `AEM_PASS` | AEM password (same as QA pipeline) | Yes |

### SimpleAgent pipeline additional variables

The SimpleAgent pipeline (`ado-cli-simple.yml`, triggered by a **`@kai-simple`** comment via an Azure-native Service Hook — no Lambda) runs the `/dx-simple` skill via the Claude Agent SDK against the **QA AEM environment**. It needs its own AEM credentials separate from the QA/DOC pipelines (which may target a different environment).

Set these on the SimpleAgent pipeline (in addition to `ANTHROPIC_API_KEY` + plugin marketplace variables above):

| Variable | Value | Secret? |
|----------|-------|---------|
| `AEM_QA_URL` | QA author URL (e.g. `https://qa-author.example.com`) | No |
| `AEM_QA_USER` | Service-account username on QA | Yes |
| `AEM_QA_PASSWORD` | Service-account password on QA | Yes |
| `PLAYWRIGHT_MCP_VERSION` | Playwright MCP (`@playwright/mcp`) version — defaults to value pinned in `ado-cli-simple.yml` (override only if needed) | No |
| `AEM_MCP_VERSION` | AEM MCP version — defaults to value pinned in `ado-cli-simple.yml` (override only if needed) | No |

> **AEM QA author URL?** For SimpleAgent visual verification + authoring writes (e.g. `https://qa-author.example.com`)

> **AEM QA service-account username?** (secret)

> **AEM QA service-account password?** (secret)

```bash
az_pipelines_variable create \
  --name "AEM_QA_URL" \
  --value "<qa-url>" \
  --pipeline-name "<simple-pipeline-name>" \
  --project "<adoProject>" \
  --organization "<adoOrg>"

az_pipelines_variable create \
  --name "AEM_QA_USER" \
  --value "<user>" --secret true \
  --pipeline-name "<simple-pipeline-name>" \
  --project "<adoProject>" \
  --organization "<adoOrg>"

az_pipelines_variable create \
  --name "AEM_QA_PASSWORD" \
  --value "<password>" --secret true \
  --pipeline-name "<simple-pipeline-name>" \
  --project "<adoProject>" \
  --organization "<adoOrg>"
```

The MCP version variables (`PLAYWRIGHT_MCP_VERSION`, `AEM_MCP_VERSION`) have inline defaults in the YAML — only set as pipeline variables to override.

### KAI-HUB pipeline additional variables (multi-repo only)

Only applies if `hub` is enabled (`"disabled": true` by default — skip otherwise). The hub queues each agent's worker (one run per resolved repo, possibly cross-project) via the ADO REST API, so it needs a PAT. It runs claude-code only for the `dx-discover-repos` step, so it **does** need `ANTHROPIC_API_KEY`. It reads the `repos.json` + `agents.json` registries from `.ai/automation/registries/` (files in the repo — not pipeline variables).

| Variable | Value | Secret? |
|----------|-------|---------|
| `ADO_PAT` | PAT with Build (Read & Execute) scope — used to POST worker runs (Basic auth; cross-project) | Yes |
| `ADO_ORG_URL` | ADO org URL (pre-fill from `infra.json` > `adoOrg`) | No |
| `ANTHROPIC_API_KEY` | LLM key for the discovery step | Yes |

```bash
az_pipelines_variable create \
  --name "ADO_PAT" \
  --value "<pat>" --secret true \
  --pipeline-name "<kai-hub-pipeline-name>" \
  --project "<adoProject>" \
  --organization "<adoOrg>"
```

> **Trigger note:** in a multi-repo project the `@kai-<agent>` Service Hook targets the **`hub`** Incoming WebHook, not the per-repo workers. `/auto-webhooks` §2b handles that. This skill only imports the YAML and sets the variables above.

## 3. Summary Report

```markdown
## ADO Pipelines Imported

| Pipeline | ID | Variables |
|----------|-----|-----------|
| <name from infra.json> | <id> | <N> set |
| ... | ... | ... |

(List each imported pipeline with its name from `infra.json`, assigned ID, and variable count.)

**infra.json** updated with pipeline IDs.
**Audit log:** `.ai/logs/infra.<week>.jsonl`

### Next step
`/auto-deploy` — Deploy Lambda code
```

## Success Criteria

- [ ] All pipelines imported (or confirmed existing) for the configured profile
- [ ] Pipeline variables set for every required variable (no empty/missing values)
- [ ] Summary report lists each pipeline with ID and variable count

## Examples

1. `/auto-pipelines` (hub, first run) — Reads `infra.json` for 11 enabled agents (the 10 core agents + `simple`; the `hub` router is `disabled` by default). Imports each pipeline one at a time into ADO (e.g., `KAI-DoR-Checker`, `KAI-PR-Review-Agent`), sets required variables (ADO PAT, LLM API key, resource prefix), and records each pipeline ID back to `infra.json`. All 11 imported successfully.

2. `/auto-pipelines` (consumer project) — Reads consumer-profile `infra.json` with 2 pipelines (PR Review, PR Answer). Imports `KAI-BrandB-PR-Review-Agent` and `KAI-BrandB-PR-Answer-Agent` with repo-specific names. Sets pipeline variables including hub Lambda URLs. Reminds user to register pipeline IDs with the hub's Lambda env vars.

3. `/auto-pipelines` (re-run, some pipelines exist) — Checks each pipeline by name before creating. Finds 6 of 10 already exist with matching IDs. Skips those 6, imports the 4 new ones, and updates `infra.json` with the new pipeline IDs.

## Troubleshooting

- **"Pipeline with this name already exists"**
  **Cause:** A pipeline with the same name was already imported (possibly from a previous run).
  **Fix:** This is handled automatically — the skill detects existing pipelines and reuses their IDs. If the existing pipeline is from a different repo or is stale, delete it manually in ADO and re-run.

- **Pipeline variable set fails with "unauthorized"**
  **Cause:** The ADO PAT used for the `az pipelines` CLI doesn't have pipeline admin permissions.
  **Fix:** Ensure the PAT has "Build: Read & Execute" and "Variable Groups: Read, Create, & Manage" scopes. Re-authenticate with `az devops login`.

- **Pipeline imported but not showing in infra.json**
  **Cause:** The skill updates `infra.json` after each import. If the process was interrupted, the last pipeline may be missing.
  **Fix:** Re-run `/auto-pipelines` — it will detect the existing pipeline by name and record its ID without creating a duplicate.

## Rules

- **Always source audit.sh first** — wrap all `az pipelines` mutating calls
- **Ask secrets interactively** — never read from environment, never store in infra.json
- **One pipeline at a time** — import and set variables before moving to next
- **Skip disabled agents** — check `"disabled": true` in infra.json before importing
- **Check before create** — always check if pipeline exists by name before creating; reuse existing ID
- **Never create duplicates** — if a pipeline with the same name exists, skip creation and use the existing ID
- **Update infra.json after each import** — record pipeline ID immediately
