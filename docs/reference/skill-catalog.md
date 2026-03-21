# Skill Catalog

## dx-core plugin — 58 skills

### Estimation — 1 skill

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| dx-estimate | `/dx-estimate` | `<work-item-id or URL>` | Analyze ADO/Jira User Story and produce structured estimation — hours/SP, implementation plan, AEM pages, open questions. Posts as ADO/Jira comment. | ADO/Jira comment |

### Requirements (`dx-req-*`) — 11 skills

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| dx-req-all | `/dx-req-all` | `<work-item-id>` | Full pipeline: fetch → dor → explain → research → share. Gates on DoR blocking questions. Logs run metrics to `.ai/learning/`. | All spec files + ADO comments |
| dx-req-fetch | `/dx-req-fetch` | `<work-item-id>` | Pull work item from Azure DevOps or Jira via MCP, save faithfully | `raw-story.md` |
| dx-req-dor | `/dx-req-dor` | `<work-item-id>` (optional) | Validate story against DoR wiki checklist (`scm.wiki-dor-url`), extract BA data, generate open questions. Posts interactive checkbox comment to ADO/Jira (idempotent). On re-run, reads checkbox state — if BA checked items, re-fetches story and re-validates. Two-pass: first on raw-story.md, second after research.md. | `dor-report.md` + ADO/Jira comment |
| dx-req-explain | `/dx-req-explain` | `<work-item-id>` (optional) | Distill story into developer-focused requirements. Reads DoR report for BA context. | `explain.md` |
| dx-req-research | `/dx-req-research` | `<work-item-id>` (optional) | Search codebase for related code via parallel agents. Skips discovery when DoR data available. | `research.md` |
| dx-req-share | `/dx-req-share` | `<work-item-id>` (optional) | Generate non-technical summary with assumptions from DoR. Posts to ADO/Jira (idempotent). | `share-plan.md` + ADO/Jira comment |
| dx-req-checklist | `/dx-req-checklist` | `<work-item-id>` (optional) | ⚠️ **Deprecated** — use `/dx-req-dor` instead. Kept for backward compatibility. | `checklist.md` |
| dx-req-tasks | `/dx-req-tasks` | `<work-item-id>` | Create child Task work items with hour estimates | ADO/Jira tasks |
| dx-req-dod | `/dx-req-dod` | `<work-item-id>` | Check Definition of Done against ADO/Jira wiki checklist (`scm.wiki-dod-url`) — validates actual deliverables: PR, tests, build, docs, child tasks | `dod.md` |
| dx-req-dod-fix | `/dx-req-dod-fix` | `<work-item-id>` | Fix DoD failures: auto-fix what's possible, create tasks for the rest | Updated `dod.md` + tasks |
| dx-req-import | `/dx-req-import` | `<path-to-file>` | Validate external (non-ADO) requirements document | `explain.md` |

### Figma (`dx-figma-*`) — 4 skills

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| dx-figma-all | `/dx-figma-all` | `[ADO ID] [Figma URL]` — both optional, any order | Run the full Figma workflow: extract → prototype → verify. Coordinator skill. | All outputs from the 3 skills below |
| dx-figma-extract | `/dx-figma-extract` | `[ADO ID] [Figma URL]` — both optional, any order | Extract design context, tokens, screenshots from Figma URL. Screenshot layer analysis (design quality), relevance check. | `figma-extract.md`, `prototype/figma-reference.png`, `prototype/.figma-asset-manifest.json` |
| dx-figma-prototype | `/dx-figma-prototype` | `<work-item-id>` (optional) | Research project conventions (2 parallel agents) + generate high-fidelity standalone HTML/CSS prototype | `figma-conventions.md`, `prototype/index.html`, `prototype/styles.css` |
| dx-figma-verify | `/dx-figma-verify` | `<work-item-id>` (optional) | Visually verify prototype against Figma reference screenshot. Compares, fixes gaps (max 2 rounds). | `figma-gaps.md`, `prototype/prototype-screenshot.png` |

### Planning (`dx-plan-*`) — 3 skills

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| dx-plan | `/dx-plan` | `<work-item-id>` (optional) | Generate step-by-step implementation plan with status tracking. Optionally invokes `superpowers:brainstorming` for design exploration before planning. | `implement.md` |
| dx-plan-validate | `/dx-plan-validate` | `<work-item-id>` (optional) | Verify plan covers all requirements, no extras, dependencies correct | Warnings/OK |
| dx-plan-resolve | `/dx-plan-resolve` | `<work-item-id>` (optional) | Research and fix risks flagged by validation | Updated `implement.md` |

### Execution (`dx-step-*`) — 9 skills

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| dx-step-all | `/dx-step-all` | `<work-item-id>` (optional) | Execute all plan steps autonomously (step → test → review → commit loop). Loads fix memory, logs fix patterns, promotes proven fixes to `.claude/rules/`. | All steps done |
| dx-step | `/dx-step` | `<work-item-id>` (optional) | Execute next pending step from implement.md. Optionally invokes `superpowers:test-driven-development` for TDD discipline. | Code changes |
| dx-step-test | `/dx-step-test` | `<work-item-id>` (optional) | Run tests and parse results into pass/fail summary | Test report |
| dx-step-review | `/dx-step-review` | `<work-item-id>` (optional) | Review step changes against plan and conventions | Review verdict |
| dx-step-fix | `/dx-step-fix` | `<work-item-id>` (optional) | Diagnose and fix a blocked step (compile error, test failure, review rejection). Optionally invokes `superpowers:systematic-debugging` for structured diagnosis. | Fix applied |
| dx-step-commit | `/dx-step-commit` | `<work-item-id>` (optional) | Stage and commit completed step changes | Git commit |
| dx-step-heal | `/dx-step-heal` | `<work-item-id>` (optional) | Diagnose pipeline failures, create corrective fix steps in implement.md | New fix steps |
| dx-step-build | `/dx-step-build` | none | Build and deploy using config build command, auto-fix errors iteratively | Build pass/fail |
| dx-step-verify | `/dx-step-verify` | `<work-item-id>` (optional) | 6-phase verification: compile, lint, test, secret scan, architecture, code review (max 3 fix cycles). Optionally invokes `superpowers:verification-before-completion` for evidence-based verification. | Verdict |

### Pull Request (`dx-pr-*`) — 8 skills

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| dx-pr | `/dx-pr` | `<work-item-id>` (optional) | Create pull request via ADO MCP, generate description from share-plan.md. Optionally invokes `superpowers:finishing-a-development-branch` for branch readiness. | PR URL |
| dx-pr-commit | `/dx-pr-commit` | `[pr]` | Commit changes with ADO work item linking; add `pr` to also create a PR | Git commit [+ PR] |
| dx-pr-review | `/dx-pr-review` | `<PR-id or URL>` | Review a single PR — analyze diff, save findings, optionally propose fix patches | Findings file |
| dx-pr-post | `/dx-pr-post` | `<PR-id or URL>` | Post saved PR review findings to ADO — threads with optional fix patches + vote | ADO comments |
| dx-pr-reviews | `/dx-pr-reviews` | none | Batch-review multiple open PRs assigned to you | Multiple reviews |
| dx-pr-answer | `/dx-pr-answer` | `<PR-id or URL>` (optional) | Answer open PR comments with codebase context, detect proposed patches | ADO replies |
| dx-pr-fix | `/dx-pr-fix` | `<PR-id or URL>` (optional) | Apply agree-will-fix code changes from reviews, commit, push, reply to threads | Code + replies |
| dx-pr-review-report | `/dx-pr-review-report` | `<PR-id or URL>` | Generate categorized report from PR review — groups by category, tracks patch resolution, posts to wiki. Uses report template from `assets/report-template.md`. | Report + wiki page |
| dx-pr-reviews-report | `/dx-pr-reviews-report` | `[--any] [PR URL | Repo URL | count] [count]` | Batch-generate review reports. Default: PRs where you are reviewer (excl. own), parallel agents. `--any`: all PRs with threads, sequential with selection. Helper script: `scripts/check-existing-reports.sh`. | Multiple reports + wiki |

### Bug Fix (`dx-bug-*`) — 4 skills

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| dx-bug-all | `/dx-bug-all` | `<bug-id>` | Full bug workflow: triage → verify → fix. Logs bug patterns, detects component hotspots. | Bug fixed |
| dx-bug-triage | `/dx-bug-triage` | `<bug-id>` | Fetch bug from ADO/Jira, find affected component, save triage | `raw-bug.md`, `triage.md` |
| dx-bug-verify | `/dx-bug-verify` | `<bug-id>` (optional) | Reproduce ADO/Jira bug via Chrome DevTools, capture screenshots | `verification.md` |
| dx-bug-fix | `/dx-bug-fix` | `<bug-id>` (optional) | Generate fix plan from triage, execute, create PR | `implement.md` + PR |

### Agent Roles (`dx-agent-*`) — 3 skills

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| dx-agent-all | `/dx-agent-all` | `<work-item-id>` | Full pipeline: RE → plan → develop → review → PR with checkpoints. Optionally invokes `superpowers:executing-plans` for execution discipline. | End-to-end delivery |
| dx-agent-re | `/dx-agent-re` | `<work-item-id>` | RE Agent — analyze story, produce structured requirements spec, post ADO/Jira comment | `re.json` |
| dx-agent-dev | `/dx-agent-dev` | `<work-item-id>` | Dev Agent — implement from RE spec, self-check (build/test/lint), commit | Code changes |

### Documentation — 2 skills

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| dx-doc-gen | `/dx-doc-gen` | `<work-item-id>` | Generate wiki docs from spec files (after development). Reads aem-doc-gen output for Authoring/Website sections. Posts to sprint-specific ADO Wiki/Confluence subfolder. | `docs/wiki-page.md` |
| dx-doc-retro | `/dx-doc-retro` | `<work-item-id>` | Retroactive wiki docs for completed stories — fetches ADO story, finds linked PRs, searches codebase, generates simplified docs. No spec files needed. | `docs/wiki-page.md` |

### Quality — 1 skill

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| dx-axe | `/dx-axe` | `<URL> [--fix] [--standard wcag2aa\|wcag21aa]` | Accessibility testing using axe MCP Server — analyze violations, get remediation guidance, apply fixes, verify. Requires Docker + Axe DevTools API key. | Violation report, fixes |

### Sync — 1 skill

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| dx-sync | `/dx-sync` | `[--dry-run] [--parallel] [repo1 repo2 ...]` | Sync plugin updates to consumer repos — runs sync-consumers.sh with selected repos and options | Sync report |

### Utility — 10 skills

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| dx-init | `/dx-init` | none (interactive) | Configure project — detect environment, generate .ai/config.yaml, README, rule templates | `.ai/` directory |
| dx-adapt | `/dx-adapt` | `[aem-fullstack\|aem-frontend\|frontend]` | Auto-detect project type, structure, and build commands. Saves `.ai/project.yaml` and substitutes real values into `.claude/rules/`. Run after `dx-init` and `aem-init`. | `.ai/project.yaml` |
| dx-doctor | `/dx-doctor` | `[dx\|aem\|seed-data\|auto\|all]` | Check health of all dx workflow files across installed plugins — config, rules, scripts, seed data, MCP, settings | Status report |
| dx-upgrade | `/dx-upgrade` | `[dx\|aem\|auto\|all]` | Fix all issues found by dx-doctor — updates stale files, installs missing files, reports manual actions | Upgrade report |
| dx-ticket-analyze | `/dx-ticket-analyze` | `<work-item-id or URL>` | Research ADO/Jira ticket, find all relevant source files | Research report |
| dx-eject | `/dx-eject` | `[dx\|aem\|auto\|all]` | Eject plugin assets into local repo — copies all skills, agents, rules, templates so project works without plugins | `.claude/skills/`, `.ai/ejected/` |
| dx-help | `/dx-help` | `<question>` | Answer architecture questions from local .ai/ docs | Answer |
| dx-hub-init | `/dx-hub-init` | `[path]` | Initialize hub directory for multi-repo orchestration | Hub config |
| dx-hub-status | `/dx-hub-status` | `[ticket-id \| --clean]` | Show status of hub dispatches across all repos | Status report |
| dx-hub-config | `/dx-hub-config` | `[show \| add-repo \| dispatch-mode \| auto-dispatch]` | View and edit hub configuration | Config update |

---

## Copilot Skill Discovery

Copilot CLI auto-discovers plugin skills directly — no copying to `.github/skills/` is needed. Both Claude Code and Copilot CLI users get the same `/dx-*` slash commands from the plugin system.

Coordinator skills are implemented as Copilot agents with `handoffs:` (see [agent-catalog.md](agent-catalog.md)): DxReqAll, DxStepAll, DxBugAll, DxAgentAll, DxFigma.

---

## Skill Dependencies

```
dx-req-all ─┬─ dx-req-fetch
             ├─ dx-req-dor (needs dx-req-fetch) → posts [DoRAgent] checkbox comment to ADO
             │    ↓ GATE: blocks if blocking questions exist
             │    ↻ BA checks items in ADO → re-run reads checkbox state → re-validates
             ├─ dx-req-explain (needs dx-req-fetch, reads dor-report.md)
             ├─ dx-req-research (needs dx-req-explain, reads dor-report.md)
             └─ dx-req-share (needs dx-req-explain, reads dor-report.md assumptions) → posts [DevPlan] to ADO

dx-agent-all ─┬─ dx-agent-re
              ├─ dx-plan (needs dx-req-explain + dx-req-research)
              ├─ dx-plan-validate (needs dx-plan)
              ├─ dx-plan-resolve (needs dx-plan-validate)
              ├─ dx-step-all ─┬─ dx-step
              │               ├─ dx-step-test
              │               ├─ dx-step-review
              │               ├─ dx-step-fix
              │               └─ dx-step-commit
              ├─ dx-step-build
              ├─ dx-step-verify
              ├─ dx-pr
              ├─ dx-doc-gen (optional, Phase 7)
              └─ aem-doc-gen (optional, Phase 7, AEM projects)

dx-bug-all ─┬─ dx-bug-triage
             ├─ dx-bug-verify (needs triage)
             └─ dx-bug-fix (needs triage + verify)

dx-req-dod ── (standalone, needs wiki-dod-url in config + linked PR in ADO)
dx-req-dod-fix ── dx-req-dod (needs dod.md), optionally invokes dx-doc-gen + aem-doc-gen
```

## dx-aem plugin — 10 skills

### Verification (3)

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| aem-snapshot | `/aem-snapshot` | `<component-name>` | Baseline component state before development — dialog fields, properties, pages | `aem-before.md` |
| aem-verify | `/aem-verify` | `<component-name>` | Check component after deployment, compare against baseline, create test page | `aem-after.md` |
| aem-fe-verify | `/aem-fe-verify` | `<component-name>` | Screenshot component in wcmmode=disabled, compare against Figma/requirements, fix loop | `aem-fe-verify.md` |
| aem-demo | `/aem-demo` | `<component-name>` | Open AEM editor, screenshot dialog, write authoring guide | `demo/` folder |

### QA (2)

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| aem-qa | `/aem-qa` | `<work-item-id>` (optional) | Full QA agent — navigate pages, check rendering/dialogs, screenshot, create Bug tickets | `qa.json` |
| aem-qa-handoff | `/aem-qa-handoff` | `<component> <id>` | Generate testing steps for QA team, post to ADO. Reuses `/aem-doc-gen` output or creates own test page | `qa-handoff.md` |

### Documentation (1)

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| aem-doc-gen | `/aem-doc-gen` | `<work-item-id>` | Generate AEM demo docs — find existing pages, create docs page, capture dialog + website screenshots on QA, write authoring guide with Authoring/Website sections | `demo/authoring-guide.md`, `demo/*.png` |

### Recon (5)

| Skill | Invocation | Argument | Description | Output |
|-------|-----------|----------|-------------|--------|
| aem-init | `/aem-init` | none (interactive) | Detect AEM structure, append `aem:` section to .ai/config.yaml, set up project seed data | Config update |
| aem-component | `/aem-component` | `<component-name>` | Find all source files, AEM pages, and dialog fields for a component (multi-platform, data-driven) | Component report |
| aem-page-search | `/aem-page-search` | `<component-name>` | Find all AEM pages using a specific component | Page list |
| aem-refresh | `/aem-refresh` | none | Update `.ai/project/` seed data from plugin, external docs repo, or manual sources | Seed data files |
| aem-doctor | `/aem-doctor` | `[components\|osgi\|dispatcher\|all]` | Check AEM project infrastructure health | Status report |

---

---

## dx-automation plugin (11 skills)

> Requires: `dx-core` plugin installed. Also requires AWS CLI and Azure CLI configured.
>
> Sets up ten autonomous agents (DoR checker, PR reviewer, PR answerer, DoD checker, DoD fixer, BugFix agent, QA agent, DevAgent, DOCAgent, Estimation) running as ADO pipelines triggered by AWS Lambda webhooks. All agents use Claude Code CLI (reuses dx skills directly in pipelines).
>
> **Cross-repo delegation:** Code-writing pipelines (BugFix, DevAgent, DoD-Fix) detect when a work item targets another repo and automatically queue the equivalent pipeline there via `delegate.json` + ADO REST API. See `docs/architecture/automation-design.md`.
>
> **Plugin installation:** All CLI pipelines auto-install dx plugins from a local marketplace path (same repo) or Git URL (cross-repo) before running Claude.

### Setup Sequence (run once in order)

| Skill | Description |
|-------|-------------|
| `/auto-init` | Scaffold `.ai/automation/` — generates `infra.json`, `repos.json`, `.env.template`. Prereq check, config questions, data bundle copy. |
| `/auto-provision` | Create all AWS resources: DynamoDB tables, SQS DLQ, S3 bucket, SNS topic, IAM role, Lambda functions (placeholder), API Gateway. |
| `/auto-pipelines` | Import ADO pipeline YAMLs into Azure DevOps and set all pipeline variables (LLM credentials, wiki URL, identities). |
| `/auto-deploy` | Package and deploy Lambda code for DoR, DoD, PR Answer, BugFix, QA, DevAgent, and/or DOCAgent. Wraps `lambda/deploy.sh` with audit logging. |
| `/auto-lambda-env` | Set Lambda environment variables interactively (ADO PAT, webhook secrets, DynamoDB table names, etc.). |
| `/auto-webhooks` | Configure ADO service hooks and PR Review build validation policy. WI hooks (project-scoped, hub only) + PR Answer hook (per-repo, all profiles) + PR Review build policy (per-repo). Consumers run this too. |
| `/auto-alarms` | Create CloudWatch alarms (DLQ depth, Lambda errors, throttles) and subscribe email to SNS alerts topic. |

### Ongoing Operations

| Skill | Argument | Description |
|-------|----------|-------------|
| `/auto-deploy` | `[dor\|dod\|pr-answer\|bugfix\|qa\|devagent\|docagent\|all]` | Redeploy Lambda after code changes. Safe to re-run at any time. |
| `/auto-doctor` | — | Full health check: file integrity, ADO pipeline state, Lambda function state, env var coverage. |
| `/auto-status` | — | Operational dashboard: DLQ depth, monthly token budget utilization, daily rate limit usage. |
| `/auto-eval` | `[--all \| --agent X \| --tier2 \| --fixture name]` | Run evaluation framework against test fixtures. Use after changing prompts or agent steps. |
| `/auto-test` | `<agent> <id> [--dryRun]` | Local dry-run against real ADO data. Verifies end-to-end connectivity without posting results. |
