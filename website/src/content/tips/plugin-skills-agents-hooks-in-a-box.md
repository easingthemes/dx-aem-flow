---
title: "Plugin = Skills + Agents + Hooks in a Box"
category: "Plugins — Full Package"
focus: "Claude Code"
tags: ["Plugin","Bundle","Reusable"]
overview: "A plugin bundles skills, agents, hooks, MCP configs, and rules into a single installable package. Install once, available in every project. Our three plugins (dx-core, dx-aem, dx-automation) contain 74 skills, 13 agents, and 4 hooks — all distributed from a single source."
codeLabel: "Plugin anatomy"
screenshot: null
week: 8
weekLabel: "Skills — Advanced"
order: 37
slackText: |
  🤖 Agentic AI Tip #37 — Plugin = Skills + Agents + Hooks in a Box
  
  Once you have a collection of skills, agents, and hooks that work together, the next step is packaging them as a plugin.
  
  *A plugin contains:*
  • `plugin.json` — manifest (name, version, description)
  • `skills/` — your skill collection
  • `agents/` — your agent definitions
  • `hooks/` — event-driven automation
  • `.mcp.json` — MCP server registrations
  • `rules/` — auto-loading conventions
  
  *Why plugin instead of just files?*
  1. *Install once, use everywhere* — add to any project with one command
  2. *Versioned* — track changes, roll back if needed
  3. *Shared* — team uses the same skills without copy-pasting
  4. *Encapsulated* — MCP servers, hooks, and rules bundled together
  5. *Updateable* — bump version, sync to all projects
  
  *Our setup:*
  Three plugins, 74 skills, 13 agents, distributed to 4 consumer repos:
  • `dx-core` — universal development workflow
  • `dx-aem` — AEM-specific tools
  • `dx-automation` — autonomous CI/CD agents
  
  💡 Try it: Look at an installed plugin's structure. Open plugin.json to see the manifest. Understand what's bundled.
  
  #AgenticAI #Day37
---

```
# Plugin structure:
dx-core/
├── .claude-plugin/
│   └── plugin.json    # manifest
├── .mcp.json          # MCP servers
├── hooks/hooks.json   # hooks
├── skills/            # 53 skills
├── agents/            # 7 agents
└── rules/             # path-scoped rules
```
