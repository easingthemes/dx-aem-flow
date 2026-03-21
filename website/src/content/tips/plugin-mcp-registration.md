---
title: "Plugin MCP Registration"
category: "Plugins — Full Package"
focus: "Claude Code"
tags: ["Plugin MCP",".mcp.json","Prefix"]
overview: "Plugins can register their own MCP servers via .mcp.json alongside plugin.json. These servers are scoped to the plugin and their tools get auto-prefixed: mcp__plugin_<plugin>_<server>__<tool>. This prevents name collisions between plugins."
codeLabel: "Plugin MCP"
screenshot: null
week: 8
weekLabel: "Skills — Advanced"
order: 38
slackText: |
  🤖 Agentic AI Tip #38 — Plugin MCP Registration
  
  Plugins don't just bundle skills — they can bring their own MCP servers along.
  
  *How it works:*
  Place a `.mcp.json` file alongside your `plugin.json`. The MCP servers defined there are automatically started when the plugin loads.
  
  *The auto-prefix:*
  Plugin MCP tools get a prefix that prevents name collisions:
  `mcp__plugin_<plugin-name>_<server-name>__<tool-name>`
  
  So the AEM server in the dx-aem plugin becomes:
  `mcp__plugin_dx-aem_AEM__getNodeContent`
  
  Not: `mcp__AEM__getNodeContent` (that would be a project-level server)
  
  *Why this matters:*
  Two plugins could both register a server named "api". Without prefixing, they'd collide. With prefixing, they coexist:
  • `mcp__plugin_pluginA_api__call`
  • `mcp__plugin_pluginB_api__call`
  
  *Our plugins register 4 MCP servers:*
  • AEM (stdio) — JCR content queries
  • Chrome DevTools (stdio) — browser automation
  • Figma (HTTP) — design extraction
  • axe (Docker) — accessibility testing
  
  💡 Try it: Check `.mcp.json` in your installed plugins. Match the server names to the prefixed tool names you see in Claude Code.
  
  #AgenticAI #Day38
---

```
# dx-aem/.mcp.json
{
  "mcpServers": {
    "AEM": {
      "type": "stdio",
      "command": "npx",
      "args": ["aem-mcp-server"]
    }
  }
}

# Tool name becomes:
# mcp__plugin_dx-aem_AEM__getNodeContent
# NOT: mcp__AEM__getNodeContent
```
