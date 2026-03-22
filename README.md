# dx-aem-flow

[![Version](https://img.shields.io/github/v/release/easingthemes/dx-aem-flow?label=version)](https://github.com/easingthemes/dx-aem-flow/releases)
[![Release](https://github.com/easingthemes/dx-aem-flow/actions/workflows/release.yml/badge.svg)](https://github.com/easingthemes/dx-aem-flow/actions/workflows/release.yml)
[![Website](https://github.com/easingthemes/dx-aem-flow/actions/workflows/deploy-website.yml/badge.svg)](https://github.com/easingthemes/dx-aem-flow/actions/workflows/deploy-website.yml)
[![semantic-release](https://img.shields.io/badge/semantic--release-angular-e10079?logo=semantic-release)](https://github.com/semantic-release/semantic-release)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Four plugins for AI-assisted software development: requirements-to-PR workflow for ADO/Jira projects, multi-repo orchestration, AEM component tooling and QA, and autonomous CI agents. Runs locally and in pipelines. Supports Claude Code, Copilot CLI, and VS Code Chat.

## Why This Exists

AI coding assistants are powerful, but without structure they produce inconsistent results. You end up re-explaining your project, your conventions, and your workflow every session.

KAI is a structured development workflow built as a plugin system. It encodes your entire sprint lifecycle — requirements, planning, execution, review, PR — into **skills** that orchestrate multi-agent pipelines. A single command like `/dx-req-all` pulls the ticket from ADO/Jira, validates readiness against your DoR, distills developer requirements, researches the codebase with parallel subagents, and generates a team summary. Each skill chains specialized agents (Opus for deep review, Sonnet for execution, Haiku for lookups), gathers context from multiple sources (tickets, config, codebase, Figma designs, live AEM content), and writes structured output that the next skill picks up automatically. You run a skill, then refine with simple follow-ups — the agent already has the full picture.

**What makes it different:**
- **Config-driven, not prompt-driven** — your build commands, branch names, and conventions live in one config file. Every skill reads it. No hardcoded values, no repeated instructions.
- **Persistent memory between steps** — each skill writes structured output to local files. The next skill picks it up automatically. Sessions can end and resume without losing context.
- **Multi-source context** — skills don't just read source code. They pull ADO/Jira tickets, Figma designs, AEM content, and browser screenshots through MCP integrations.
- **Autonomous mode** — the same skills that run locally also run unattended as ADO pipeline agents, triggered by webhooks. Tag a ticket, get a verified bugfix with a PR.
- **[Superpowers](https://github.com/obra/superpowers) integration** — 6 skills optionally invoke superpowers methodology (brainstorming, TDD, systematic debugging, verification) when installed, with inline fallback when it's not.

## Install

Add the marketplace, then install the plugins you need:

```bash
# Add the marketplace (once)
/plugin marketplace add easingthemes/dx-aem-flow

# Install plugins
/plugin install dx-core@dx-aem-flow   # Core workflow (all projects)
/plugin install dx-hub@dx-aem-flow              # Multi-repo orchestration (optional)
/plugin install dx-aem@dx-aem-flow              # AEM tools (AEM projects)
/plugin install dx-automation@dx-aem-flow        # Autonomous agents (24/7 pipelines)
```

From a local clone:

```bash
/plugin marketplace add /path/to/dx-aem-flow
/plugin install dx-core@dx-aem-flow
```

## Plugins

### [dx-core](plugins/dx-core/) — Development Workflow

Full-stack development workflow for Azure DevOps and Jira projects: requirements gathering, implementation planning, step-by-step execution with testing and review, code review, bug fixes, and PR management.

**43 skills, 6 agents.** Works with any tech stack.

### [dx-hub](plugins/dx-hub/) — Multi-Repo Orchestration

Hub directory management for coordinating work across multiple consumer repos — init, config, status.

**3 skills.**

### [dx-aem](plugins/dx-aem/) — AEM Component Tools

AEM-specific tools: component dialog inspection, page search, snapshot/verify lifecycle, QA automation, and demo capture.

**12 skills, 6 agents.** Requires dx plugin.

### [dx-automation](plugins/dx-automation/) — Autonomous Agents

Autonomous AI agents (DoR checker, DoD checker, DoD fixer, PR reviewer, PR answerer, BugFix agent, QA agent, DevAgent, DOCAgent) running 24/7 as ADO pipelines triggered by AWS Lambda webhooks.

**11 skills.** Requires dx plugin.

## Client-Specific Plugins

Client-specific plugins can live alongside these plugins for project-specific enrichment (market data, brand config, etc.). See the [authoring guide](https://easingthemes.github.io/dx-aem-flow/contributing/authoring/) for how to create them.

## Quick Start

### With Claude Code (interactive)

```bash
# 1. Install
/plugin marketplace add easingthemes/dx-aem-flow
/plugin install dx-core@dx-aem-flow

# 2. Initialize your project
/dx-init

# 3. Work on a story
/dx-req-all 2416553        # Fetch story, distill requirements, research codebase
/dx-plan                    # Generate implementation plan
/dx-step-all                # Execute all steps autonomously
/dx-step-build              # Build & deploy
/dx-step-verify             # 6-phase verification
/dx-pr                      # Create pull request
```

### Without Claude Code (standalone scaffold)

For users who don't have Claude Code, the CLI utility creates the same project structure with default values:

```bash
# From a clone of this repo:
node dx/cli/bin/dx-scaffold.js /path/to/your-project --all

# Flags: --aem (AEM files), --copilot (Copilot agents), --all (both)
```

Auto-detects git remote, SCM provider, project type, and base branch. Outputs ~144 files with TODO placeholders — edit `.ai/config.yaml` afterwards. See [cli/README.md](cli/README.md) for details.

## Documentation

Full documentation: [KAI Website](https://easingthemes.github.io/dx-aem-flow/)

- [Learn](https://easingthemes.github.io/dx-aem-flow/learn/intro/) — AI fundamentals, skills, agents, hooks
- [Workflows](https://easingthemes.github.io/dx-aem-flow/workflows/local/) — Step-by-step guides
- [Reference](https://easingthemes.github.io/dx-aem-flow/reference/skills/) — Skills, agents, config schema
- [Architecture](https://easingthemes.github.io/dx-aem-flow/architecture/overview/) — System design
- [Setup](https://easingthemes.github.io/dx-aem-flow/setup/claude-code/) — Installation guides

## License

MIT
