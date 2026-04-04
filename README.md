# dx-aem-flow

[![Version](https://img.shields.io/github/v/release/easingthemes/dx-aem-flow?label=version)](https://github.com/easingthemes/dx-aem-flow/releases)
[![Release](https://github.com/easingthemes/dx-aem-flow/actions/workflows/release.yml/badge.svg)](https://github.com/easingthemes/dx-aem-flow/actions/workflows/release.yml)
[![Website](https://github.com/easingthemes/dx-aem-flow/actions/workflows/deploy-website.yml/badge.svg)](https://github.com/easingthemes/dx-aem-flow/actions/workflows/deploy-website.yml)
[![semantic-release](https://img.shields.io/badge/semantic--release-angular-e10079?logo=semantic-release)](https://github.com/semantic-release/semantic-release)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Enterprise AI development platform for teams shipping on Azure DevOps and Atlassian. 71+ skills that run identically across **Claude Code**, **GitHub Copilot CLI**, and **VS Code Chat** — from ticket to PR, fully autonomous. Deep AEM specialization built in.

## Why This Exists

Enterprise teams run complex sprints across multiple repos, multiple IDEs, and multiple team members. They need a system that handles the full lifecycle — requirements analysis, implementation planning, code generation, testing, verification, documentation, and PR creation — with governance at every step. Without re-explaining the project every session.

KAI is a structured development workflow built as a plugin system for enterprise teams. It encodes your entire sprint lifecycle — requirements, planning, execution, review, PR — into **skills** that orchestrate multi-agent pipelines across every major AI platform. A single command like `/dx-req-all` pulls the ticket from Azure DevOps or Jira, validates readiness against your DoR, distills developer requirements, researches the codebase with parallel subagents, and generates a team summary. Each skill chains specialized agents (Opus for deep review, Sonnet for execution, Haiku for lookups), gathers context from multiple sources (tickets, config, codebase, Figma designs, live AEM content), and writes structured output that the next skill picks up automatically.

**What makes it different:**
- **Every AI platform** — same 71+ skills work identically in Claude Code, GitHub Copilot CLI, and VS Code Chat. Same plugins, same config, same results — regardless of which IDE your team uses.
- **Enterprise governance** — DoR validation, 6-phase verification gate (compile, lint, test, secret scan, architecture review, AI code review), autonomous PR review, and branch protection. Ship with confidence.
- **AEM full-flow** — purpose-built AEM tooling covering Figma → component → dialog inspection → JCR content → editorial QA → browser automation → demo capture. Includes the [AEM MCP server](https://www.npmjs.com/package/aem-mcp-server) for live dialog and JCR access. The complete AEM development lifecycle, config-driven for your project.
- **Config-driven, not prompt-driven** — your build commands, branch names, and conventions live in one config file. Every skill reads it. No hardcoded values, no repeated instructions.
- **Persistent memory between steps** — each skill writes structured output to local files. The next skill picks it up automatically. Sessions can end and resume without losing context.
- **Autonomous mode** — the same skills that run locally also run unattended as ADO pipeline agents, triggered by webhooks. Tag a ticket, get a verified bugfix with a PR.

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

**45 skills, 6 agents.** Works with any tech stack.

### [dx-hub](plugins/dx-hub/) — Multi-Repo Orchestration

Hub directory management for coordinating work across multiple consumer repos — init, config, status.

**3 skills.**

### [dx-aem](plugins/dx-aem/) — AEM Full-Flow

The complete AEM development lifecycle: component dialog inspection, JCR content, page authoring, editorial QA with browser automation, snapshot/verify lifecycle, and demo capture. Includes the [AEM MCP server](https://www.npmjs.com/package/aem-mcp-server) for live JCR and dialog access. Purpose-built for AEM Cloud and on-premise projects.

**12 skills, 6 agents.** Requires dx plugin.

### [dx-automation](plugins/dx-automation/) — Autonomous Agents

Autonomous AI agents (DoR checker, DoD checker, DoD fixer, PR reviewer, PR answerer, BugFix agent, QA agent, DevAgent, DOCAgent) running 24/7 as ADO pipelines triggered by AWS Lambda webhooks.

**11 skills.** Requires dx plugin.

## Client-Specific Plugins

Client-specific plugins can live alongside these plugins for project-specific enrichment (market data, brand config, etc.). See the [authoring guide](https://easingthemes.github.io/dx-aem-flow/contributing/authoring/) for how to create them.

## Quick Start

Three ways to initialize — all produce the same project structure:

### Claude Code

```bash
# 1. Install plugins
/plugin marketplace add easingthemes/dx-aem-flow
/plugin install dx-core@dx-aem-flow

# 2. Initialize (interactive — detects your project, asks a few questions)
/dx-init

# 3. Work on a story
/dx-req-all 2416553        # Fetch story, distill requirements, research codebase
/dx-plan                    # Generate implementation plan
/dx-step-all                # Execute all steps autonomously
/dx-step-build              # Build & deploy
/dx-step-verify             # 6-phase verification
/dx-pr                      # Create pull request
```

### GitHub Copilot CLI

```bash
# 1. Install plugins (same format, same skills)
/plugin install easingthemes/dx-aem-flow/dx-core

# 2. Initialize (same interactive flow)
/dx-init

# 3. Work on a story — same skills, same agents
@DxReqAll 2416553          # Full requirements workflow
@DxPlanExecutor             # Generate and execute plan
@DxStepAll                  # Execute all steps
@DxCodeReview               # Code review
@DxCommit pr                # Commit and create PR
```

### Standalone scaffold (any agent or no agent)

Bootstrap the project config without installing plugins first. Works with any AI coding agent — Claude Code, Copilot CLI, Codex, or others:

```bash
# From a clone of this repo:
node cli/bin/dx-scaffold.js /path/to/your-project --all

# Flags: --aem (AEM-specific files), --all (everything)
```

Auto-detects git remote, SCM provider, project type, and base branch. Generates config, rules, agents, and `AGENTS.md` — edit `.ai/config.yaml` to set your actual values. See [cli/README.md](cli/README.md) for details.

## Agent Compatibility

These plugins work across the AI coding agent ecosystem at three levels:

| Level | Agents | What Works |
|-------|--------|------------|
| **Full workflow** | Claude Code, Copilot CLI | Plugin install, all 71+ skills, agent orchestration, hooks |
| **Agents + rules** | VS Code Chat, Copilot coding agent, Codex CLI | `.github/agents/`, `AGENTS.md`, rules, MCP servers |
| **Rules + MCP** | Cursor, Windsurf, Amazon Q, Cline, Continue | Coding conventions from `.claude/rules/`, MCP server configs |

The scaffold generates `AGENTS.md` (read by Codex CLI, Windsurf, Copilot coding agent) and `.github/agents/` (read by VS Code Chat, Copilot CLI) so agent profiles work even without plugin installation.

## Documentation

Full documentation: [KAI Website](https://easingthemes.github.io/dx-aem-flow/)

- [Learn](https://easingthemes.github.io/dx-aem-flow/learn/intro/) — AI fundamentals, skills, agents, hooks
- [Workflows](https://easingthemes.github.io/dx-aem-flow/workflows/local/) — Step-by-step guides
- [Reference](https://easingthemes.github.io/dx-aem-flow/reference/skills/) — Skills, agents, config schema
- [Architecture](https://easingthemes.github.io/dx-aem-flow/architecture/overview/) — System design
- [Setup](https://easingthemes.github.io/dx-aem-flow/setup/claude-code/) — Installation guides

## License

MIT
