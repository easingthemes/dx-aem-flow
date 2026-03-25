---
title: "What is an Agent? Two Formats, One Concept"
category: "Agents — AI Personas"
focus: "Claude Code"
tags: ["Agent",".agent.md","Plugin Agent","13+25"]
overview: "An agent is a persona with specific tools and model. Two formats exist: Claude Code plugin agents (model tiering, worktree isolation, memory) and Copilot .agent.md files (multi-model, handoffs, MCP inline config). We maintain 13 plugin agents + 25 Copilot agents. Same concepts, different capabilities."
screenshot: null
week: 5
weekLabel: "Skills — Recipe Book"
order: 22
slackOneLiner: "🤖 Tip #22 — An agent is a persona (model + tools + constraints), and two formats exist — Claude Code plugin agents and Copilot .agent.md files."
keyPointsTitle: "Two Agent Formats"
actionItemsTitle: "Choosing & Creating Agents"
keyPoints:
  - "An agent is a persona — model + tools + constraints. Same concept in both formats, different capabilities and frontmatter fields."
  - |
    Claude Code plugin agents (`agents/*.md`) — deep platform integration
    - `model:` — explicit tier (Opus/Sonnet/Haiku)
    - `permissionMode:` — plan (read-only) or acceptEdits
    - `isolation: worktree` — agent gets its own repo copy
    - `memory:` — persistent across sessions
    - `maxTurns:` — safety cap
  - |
    Copilot agents (`.github/agents/*.agent.md`) — multi-model and interactive
    - `tools:` — read, edit, search, execute, codebase
    - `handoffs:` — interactive buttons to chain agents (VS Code)
    - `mcp-servers:` — inline MCP config in YAML
    - `model:` — fallback chain: `[claude-sonnet, gpt-4o]`
    - `allowed-tools:` — auto-approve these tools
actionItems:
  - "We maintain both — 13 plugin agents for Claude Code, 25 Copilot agents in `.github/agents/`. Generated from shared templates by the init script."
  - |
    Tool name differences between platforms
    - Claude Code: `Read, Glob, Bash, Edit`
    - Copilot: `read, codebase, execute, edit`
    - Templates include both — unrecognized names are ignored per platform
  - |
    Know which format to use
    - Need model tiering or worktree isolation — Claude Code plugin agent
    - Need handoffs or multi-model fallback — Copilot .agent.md
  - "When adding a new agent, create both formats from shared templates so all platforms are covered"
---
