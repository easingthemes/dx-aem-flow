---
title: "What is MCP? Works Everywhere Now"
category: "MCP — System Integration"
focus: "All Tools"
tags: ["MCP","GA in VSCode","All Platforms"]
overview: "MCP (Model Context Protocol) is now GA in ALL three tools — Claude Code, Copilot CLI, AND VSCode Chat (since July 2025). Same protocol, different config files: .mcp.json for CLIs, .vscode/mcp.json for VSCode. Agents can even declare MCP servers inline in their frontmatter. One protocol, every tool."
codeLabel: "MCP on all platforms"
screenshot: null
week: 6
weekLabel: "Skills — Recipe Book"
order: 27
slackText: |
  🤖 Agentic AI Tip #27 — What is MCP? Works Everywhere Now
  
  MCP (Model Context Protocol) went from "Claude Code only" to *GA on all platforms* in 2025. This changes everything.
  
  *The analogy:* MCP is like USB for AI. Plug in a server, AI gets new tools. One protocol, every platform.
  
  *Where MCP works (2025+):*
  • *Claude Code* — native since day 1 (`.mcp.json`)
  • *Copilot CLI* — full support (`.mcp.json`, same format)
  • *VSCode Chat* — GA since July 2025 (`.vscode/mcp.json`)
  • *Copilot coding agent* — MCP servers in cloud environments
  • *Copilot agents* — inline `mcp-servers:` in .agent.md frontmatter
  
  *Config file differences:*
  • CLIs: `.mcp.json` with `"mcpServers": {}`
  • VSCode: `.vscode/mcp.json` with `"servers": {}`
  Root key is different! Copy-paste will break.
  
  *Our 6 MCP servers:*
  • ADO — work items, PRs, builds, wiki
  • AEM — JCR content, components, pages
  • Chrome DevTools — screenshots, navigation, DOM
  • Figma — designs, tokens, screenshots
  • axe — accessibility audits
  • GitHub MCP — built into Copilot
  
  *Before MCP:* "I can't see websites." *After MCP:* 📸 screenshot in 2 seconds.
  
  💡 Try it: Add Chrome DevTools MCP to both `.mcp.json` AND `.vscode/mcp.json`. Test in Claude Code, Copilot CLI, and VSCode Chat.
  
  #AgenticAI #Day27
---

```
# Claude Code / Copilot CLI:
# .mcp.json
{ "mcpServers": {
    "chrome": { "command": "npx",
      "args": ["chrome-devtools-mcp"] }
}}

# VSCode Chat:
# .vscode/mcp.json
{ "servers": {
    "chrome": { "command": "npx",
      "args": ["chrome-devtools-mcp"] }
}}

# Copilot agent inline MCP:
# .github/agents/MyAgent.agent.md
# mcp-servers:
#   chrome:
#     command: npx chrome-devtools-mcp
```
