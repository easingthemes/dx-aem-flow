---
title: "What is an Agent? Two Formats, One Concept"
category: "Agents — AI Personas"
focus: "Claude Code"
tags: ["Agent",".agent.md","Plugin Agent","13+25"]
overview: "An agent is a persona with specific tools and model. Two formats exist: Claude Code plugin agents (model tiering, worktree isolation, memory) and Copilot .agent.md files (multi-model, handoffs, MCP inline config). We maintain 13 plugin agents + 25 Copilot agents. Same concepts, different capabilities."
codeLabel: "Two agent formats"
screenshot: null
week: 5
weekLabel: "Skills — Recipe Book"
order: 22
slackText: |
  🤖 Agentic AI Tip #22 — What is an Agent? Two Formats, One Concept
  
  An agent is a persona — model + tools + constraints. But today there are *two formats*:
  
  *Claude Code plugin agents* (`agents/*.md`):
  • `model:` — Opus/Sonnet/Haiku (explicit tier)
  • `permissionMode:` — plan (read-only) or acceptEdits
  • `isolation: worktree` — agent gets its own repo copy
  • `memory:` — persistent across sessions
  • `maxTurns:` — safety cap
  
  *Copilot agents* (`.github/agents/*.agent.md`):
  • `tools:` — read, edit, search, execute, codebase
  • `handoffs:` — interactive buttons to chain agents (VS Code)
  • `mcp-servers:` — inline MCP config in YAML
  • `model:` — fallback chain: `[claude-sonnet, gpt-4o]`
  • `allowed-tools:` — auto-approve these tools
  
  We maintain *both*: 13 plugin agents for Claude Code, 25 Copilot agents in .github/agents/. Generated from shared templates by our init script.
  
  *Tool name differences:*
  • Claude Code: `Read, Glob, Bash, Edit`
  • Copilot: `read, codebase, execute, edit`
  Templates include both — unrecognized names are ignored per platform.
  
  💡 Try it: Open `.github/agents/` and a plugin `agents/` directory side by side. Compare the frontmatter fields.
  
  #AgenticAI #Day22
---

```
# Claude Code (plugin agent):
---
name: dx-code-reviewer
model: opus
permissionMode: plan
isolation: worktree
maxTurns: 50
---

# Copilot (.github/agents/):
---
name: DxCodeReview
tools: [read, codebase, search]
handoffs:
  - label: "Create PR"
    agent: DxCommit
allowed-tools: [read, edit, execute]
---
```
