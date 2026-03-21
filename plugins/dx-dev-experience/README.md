# dx-dev-experience — Development Workflow Plugin for Claude Code

A comprehensive development workflow plugin for Azure DevOps and Jira projects. Covers the entire lifecycle: requirements gathering, implementation planning, step-by-step execution with testing and review, code review, bug fixes, and PR management. Works with any tech stack — pair with the [aem](https://github.com/yourorg/claude-aem) plugin for AEM projects.

## Installation

```bash
/plugin marketplace add easingthemes/dx-aem-ai-flow
/plugin install dx-dev-experience@dx-aem-ai-flow
```

## Quick Start

```bash
/dx-init                    # One-time project setup — generates .ai/config.yaml
/dx-req-all 2416553         # Fetch work item (ADO/Jira), distill requirements, research codebase
/dx-plan                    # Generate step-by-step implementation plan
/dx-step-all                # Execute all steps autonomously (test + review + commit loop)
/dx-step-build                   # Build & deploy, auto-fix errors
/dx-step-verify             # 6-phase verification before shipping
/dx-pr                      # Create pull request
```

## Skills (48)

### Estimation

| Skill | Description |
|-------|-------------|
| `/dx-estimate` | Analyze work item (ADO/Jira) and produce structured estimation — hours/SP, implementation plan, open questions |

### Requirements

| Skill | Description |
|-------|-------------|
| `/dx-req-all` | Full requirements pipeline: fetch → dor → explain → research → share |
| `/dx-req-fetch` | Pull ADO work item and save as raw-story.md |
| `/dx-req-dor` | Validate story against DoR checklist, extract BA data, generate open questions |
| `/dx-req-explain` | Distill story into developer-focused requirements |
| `/dx-req-research` | Search codebase for related code |
| `/dx-req-share` | Generate non-technical summary for Teams/ADO |
| `/dx-req-checklist` | ⚠️ Deprecated — use `/dx-req-dor` instead |
| `/dx-req-tasks` | Create child Task work items with hour estimates |
| `/dx-req-dod` | Check Definition of Done compliance — reviews PR, tasks, docs |
| `/dx-req-dod-fix` | Auto-fix DoD gaps found by dx-req-dod |
| `/dx-req-import` | Validate external (non-ADO) requirements document |

### Planning

| Skill | Description |
|-------|-------------|
| `/dx-plan` | Generate implementation plan with status-tracked steps |
| `/dx-plan-validate` | Verify plan covers all requirements, no extras |
| `/dx-plan-resolve` | Fix risks flagged by validation |

### Execution

| Skill | Description |
|-------|-------------|
| `/dx-step-all` | Execute all plan steps (step → test → review → commit loop) |
| `/dx-step` | Execute next pending step |
| `/dx-step-test` | Run tests and parse results |
| `/dx-step-review` | Review step changes against plan and conventions |
| `/dx-step-fix` | Diagnose and fix a blocked step |
| `/dx-step-commit` | Stage and commit completed step |
| `/dx-step-heal` | Diagnose pipeline failures, create corrective steps |
| `/dx-step-build` | Build & deploy to local environment, auto-fix errors |

### Build & Ship

| Skill | Description |
|-------|-------------|
| `/dx-step-verify` | 6-phase verification with auto-fix (compile, lint, test, secrets, architecture, review) |
| `/dx-pr` | Create pull request via ADO MCP |

### PR Review

| Skill | Description |
|-------|-------------|
| `/dx-pr-review` | Review a single PR — analyze code, post comments, propose fixes |
| `/dx-pr-post` | Post saved PR review findings to ADO — threads with optional fix patches + vote |
| `/dx-pr-reviews` | Batch-review multiple open PRs |
| `/dx-pr-answer` | Answer open PR comments with codebase context |
| `/dx-pr-fix` | Apply agree-will-fix code changes, commit, push, reply |

### Bug Fix

| Skill | Description |
|-------|-------------|
| `/dx-bug-all` | Full bug workflow: triage → verify → fix |
| `/dx-bug-triage` | Fetch bug, find affected component, save triage |
| `/dx-bug-verify` | Reproduce bug via Chrome DevTools |
| `/dx-bug-fix` | Generate and execute fix plan |

### Recon

| Skill | Description |
|-------|-------------|
| `/dx-init` | Configure project — generates .ai/config.yaml, README, rule templates |
| `/dx-ticket-analyze` | Research ADO ticket, find all relevant source files |
| `/dx-help` | Answer architecture questions from local docs |
| `/dx-pr-commit` | Commit with ADO work item linking, optional PR creation |

### Agent Roles

| Skill | Description |
|-------|-------------|
| `/dx-agent-re` | RE Agent — analyze story, produce structured requirements spec |
| `/dx-agent-dev` | Dev Agent — implement from spec, self-check, commit |
| `/dx-agent-all` | Full pipeline: requirements → development with checkpoints |

### Documentation

| Skill | Description |
|-------|-------------|
| `/dx-doc-gen` | Generate wiki docs from spec files — reads aem-doc-gen output for Authoring/Website sections, posts to ADO wiki |
| `/dx-doc-retro` | Retroactive wiki docs for completed stories — fetches ADO story, finds linked PRs, generates docs |

### Utility

| Skill | Description |
|-------|-------------|
| `/dx-adapt` | Adapt project config after plugin updates — regenerate templates, filter rules |
| `/dx-doctor` | Check health of all dx workflow files — config, rules, scripts, seed data, MCP, settings |
| `/dx-upgrade` | Fix all issues found by dx-doctor — updates stale files, installs missing files |
| `/dx-eject` | Eject all plugin assets into local repo — skills, agents, rules, templates. Works without plugins after. |

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `dx-code-reviewer` | Opus | Deep code review with confidence-based filtering (≥80) |
| `dx-pr-reviewer` | Sonnet | PR diff analysis, structured findings with severity |
| `dx-file-resolver` | Haiku | Source file lookup across repos via ADO MCP |
| `dx-doc-searcher` | Haiku | Local documentation index search |
| `dx-step-executor` | Sonnet | Skill delegation loop for autonomous execution |

## Configuration

`/dx-init` generates `.ai/config.yaml` in your project root:

```yaml
project:
  name: "My Project"
  prefix: "myproject"

scm:
  provider: ado
  org: https://myorg.visualstudio.com/
  project: "My Project"
  repo-id: "uuid"
  base-branch: develop

build:
  command: "mvn clean install -PautoInstallPackage"
  test: "mvn test"
  lint-js: "npm run lint:js"
  lint-css: "npm run lint:css"
```

## Customization

### Config overrides

Add an `overrides:` section to `.ai/config.yaml` for simple tweaks:

```yaml
overrides:
  pr-review:
    tone: "direct, no praise"
    severity-threshold: 80
  pr-answer:
    persona: "senior developer, brief responses"
```

### Shared rules

`/dx-init` installs shared rules to `.ai/rules/`. Edit these to customize behavior for both local dx skills and automation agents:

| File | What it controls |
|------|-----------------|
| `.ai/rules/pr-review.md` | PR review criteria and comment format |
| `.ai/rules/pr-answer.md` | PR answer tone and response categories |
| `.ai/rules/pragmatism.md` | Pragmatism filter for plans and questions |
| `.ai/rules/plan-format.md` | Implementation plan template |

Precedence: `.ai/rules/<topic>.md` > `config.yaml overrides` > plugin defaults.

### Skill shadowing

Create a skill with the same name in your project's `.claude/skills/` to override any plugin skill entirely.

## AEM Projects

Pair with the [aem](https://github.com/yourorg/claude-aem) plugin for AEM-specific tools (component verification, dialog inspection, QA automation).

## License

MIT
