---
title: "What is MCP? Works Everywhere Now"
category: "MCP — System Integration"
focus: "All Tools"
tags: ["MCP","GA in VSCode","All Platforms"]
overview: "MCP (Model Context Protocol) is now GA in ALL three tools — Claude Code, Copilot CLI, AND VSCode Chat (since July 2025). Same protocol, different config files: .mcp.json for CLIs, .vscode/mcp.json for VSCode. Agents can even declare MCP servers inline in their frontmatter. One protocol, every tool."
screenshot: null
week: 6
weekLabel: "Skills — Recipe Book"
order: 27
slackOneLiner: "🤖 Tip #27 — MCP is like USB for AI — plug in a server, AI gets new tools. Now GA on all three platforms."
keyPointsTitle: "The Protocol & Platforms"
actionItemsTitle: "Config & Our Servers"
keyPoints:
  - "MCP (Model Context Protocol) — the analogy is USB for AI. Plug in a server, AI gets new tools. One protocol, every platform."
  - |
    Where MCP works (2025+)
    - Claude Code — native since day 1 (`.mcp.json`)
    - Copilot CLI — full support (`.mcp.json`, same format)
    - VSCode Chat — GA since July 2025 (`.vscode/mcp.json`)
    - Copilot coding agent — MCP servers in cloud environments
    - Copilot agents — inline `mcp-servers:` in .agent.md frontmatter
  - |
    Config file differences — root key matters, copy-paste will break
    - CLIs: `.mcp.json` with `"mcpServers": {}`
    - VSCode: `.vscode/mcp.json` with `"servers": {}`
  - "Before MCP — 'I can't see websites.' After MCP — screenshot in 2 seconds. The capability gap between tools has collapsed."
actionItems:
  - |
    Our 6 MCP servers — each adds a distinct capability
    - ADO — work items, PRs, builds, wiki
    - AEM — JCR content, components, pages
    - Chrome DevTools — screenshots, navigation, DOM
    - Figma — designs, tokens, screenshots
    - axe — accessibility audits
    - GitHub MCP — built into Copilot
  - "Add Chrome DevTools MCP to both `.mcp.json` AND `.vscode/mcp.json` — test in Claude Code, Copilot CLI, and VSCode Chat"
  - "Remember the root key difference — `mcpServers` for CLIs, `servers` for VSCode. Don't copy-paste between them without changing the key"
  - "For Copilot agents, try inline `mcp-servers:` in the .agent.md frontmatter — no separate config file needed"
---
