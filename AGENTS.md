# AGENTS.md

Cross-tool agent instructions for [dx-aem-flow](https://easingthemes.github.io/dx-aem-flow) — AI-assisted Azure DevOps development workflows.

> This file is the cross-platform equivalent of `CLAUDE.md`. Tools that read AGENTS.md include Codex, Copilot, Cursor, Windsurf, Zed, Jules, Gemini CLI, and others. Claude Code reads `CLAUDE.md` (which contains the full contributor guide); this file provides the essential subset for all other agents.

## What This Is

Four installable plugins for AI-assisted development workflows. Pure Markdown (skills, agents, rules, templates) with shell helper scripts. No build system.

| Plugin | Directory | Purpose | Skills |
|--------|-----------|---------|--------|
| **dx-core** | `plugins/dx-core/` | Platform-agnostic ADO/Jira workflow: requirements, planning, execution, review, PR | 48 (`dx-*`) |
| **dx-hub** | `plugins/dx-hub/` | Multi-repo orchestration | 4 (`dx-hub-*`) |
| **dx-aem** | `plugins/dx-aem/` | AEM-specific verification, QA, demo capture | 12 (`aem-*`) |
| **dx-automation** | `plugins/dx-automation/` | Autonomous AI agents running as ADO pipelines | 11 (`auto-*`) |

## Plugin Structure

Each plugin follows this layout:
```
plugin/
├── .claude-plugin/plugin.json   # Plugin manifest
├── .mcp.json                    # MCP server config
├── agents/                      # Agent definitions (*.md with YAML frontmatter)
├── skills/                      # Skill directories (*/SKILL.md)
├── rules/                       # Default prompt templates
├── hooks/                       # Lifecycle hooks
├── data/                        # Seed files copied to project by init
├── shared/                      # Reference files read by skills at runtime
└── templates/                   # Init-time file templates
```

## Key Conventions

### Config-Driven — Never Hardcode

All project-specific values live in `.ai/config.yaml`. Skills read config at runtime. Never hardcode build commands, branch names, URLs, or org names.

### Spec Directory Convention

Per-ticket output goes to `.ai/specs/<id>-<slug>/` with predictable filenames (`raw-story.md`, `explain.md`, `research.md`, `implement.md`). Skills find each other's output by convention.

### Three-Layer Override System

```
.ai/rules/<topic>.md  >  config.yaml overrides  >  plugin defaults (rules/*.md)
```

### Skill Format (Agent Skills standard)

Skills use the [Agent Skills](https://agentskills.io/specification) open standard:

```yaml
---
name: my-skill
description: One-line with trigger phrases
argument-hint: "<what user passes>"
model: sonnet          # optional — opus | sonnet | haiku
effort: medium         # optional — low | medium | high | max
---
```

Skills live in `plugins/{plugin}/skills/<name>/SKILL.md`.

### Agent Format

```yaml
---
name: dx-my-agent
description: What it does
tools: Read, Write, Glob, Grep, Bash
model: sonnet
---
```

Agents live in `plugins/{plugin}/agents/<name>.md`.

### MCP Servers

Six MCP servers across plugins: ADO, Atlassian, Figma, axe (accessibility), AEM, Chrome DevTools.

## Contributing

- No hardcoded org URLs, project names, paths, build commands, or branch names
- Skill naming: kebab-case with plugin prefix (`dx-req`, `aem-verify`, `auto-deploy`)
- Versioning is automated via semantic-release on push to `main`
- See `CLAUDE.md` for the full contributor guide with architecture details
