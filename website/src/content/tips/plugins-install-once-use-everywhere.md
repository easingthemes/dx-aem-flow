---
title: "Plugins: Install Once, Use Everywhere"
category: "Plugins — Full Package"
focus: "All Tools"
tags: ["Plugins","Marketplace","Skills","Agents","MCP"]
overview: "Plugins are installable bundles of skills, agents, rules, and MCP servers. One command adds them. They work in both Claude Code and Copilot CLI. Think of them like VS Code extensions — but for your terminal AI."
codeLabel: "Install from a marketplace"
screenshot: null
week: 15
weekLabel: "Plugins — Full Package"
order: 52
slackText: |
  🤖 Agentic AI Tip #52 — Plugins: Install Once, Use Everywhere

  Plugins are installable bundles of skills, agents, rules, and MCP servers. Think of them like VS Code extensions — but for your terminal AI.

  *What's in a plugin:*
  • Skills — slash commands (/dx-plan, /aem-verify)
  • Agents — specialized AI personas (code reviewer, file resolver)
  • Rules — convention templates (.claude/rules/)
  • MCP servers — external tool connections (ADO, AEM, Figma)

  *Install from a marketplace (GitHub repo):*
  ```
  /plugin marketplace add owner/repo
  /plugin install plugin-name@marketplace
  ```

  *Works in both tools:*
  • Claude Code — native plugin support, hooks, worktree isolation
  • Copilot CLI — same skills + agents, reads same plugin format
  • Install once, both tools discover it automatically

  *Example marketplaces:*
  • adobe/skills — AEM Edge Delivery skills (17 skills)
  • Your own — any GitHub repo with .claude-plugin/marketplace.json

  💡 Try it: Run `/plugin marketplace add adobe/skills` to browse Adobe's public skills. Then `/plugin list` to see what's installed.

  #AgenticAI #Day52
---

```bash
# Add a marketplace (GitHub repo or local path)
/plugin marketplace add adobe/skills
/plugin marketplace add owner/my-plugins

# Browse available plugins
/plugin list --marketplace

# Install what you need
/plugin install aem-eds@adobe-skills
/plugin install dx-core@my-plugins

# Update all installed plugins
/plugin marketplace update my-plugins
```

*What's inside a plugin:*

```
my-plugin/
├── .claude-plugin/plugin.json   # Manifest
├── skills/                      # /slash commands
├── agents/                      # AI personas
├── rules/                       # Convention templates
├── hooks/                       # Guardrails
└── .mcp.json                    # MCP server config
```

After install, everything is auto-discovered. Skills show up as `/commands`, agents are available for dispatch, rules load based on file paths, and MCP servers connect automatically.

*Both platforms, same plugins:*

| Feature | Claude Code | Copilot CLI |
|---------|------------|-------------|
| Skills (/commands) | Native | Native |
| Agents | Plugin agents/ | .github/agents/ |
| Rules (.claude/rules/) | Native (paths:) | Via env var (applyTo:) |
| MCP servers | .mcp.json | .mcp.json |
| Hooks | 18 events + prompt | 8 events |
| Marketplace | /plugin marketplace | /plugin marketplace |

*No build step.* Plugins are pure Markdown + shell scripts. Install → init → use.

💡 Try it: Run `/plugin marketplace add adobe/skills` to see a public marketplace. Then `/plugin list` to see what you get.
