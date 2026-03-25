---
title: "Plugin MCP Registration"
category: "Plugins — Full Package"
focus: "Claude Code"
tags: ["Plugin MCP",".mcp.json","Prefix"]
overview: "Plugins can register their own MCP servers via .mcp.json alongside plugin.json. These servers are scoped to the plugin and their tools get auto-prefixed: mcp__plugin_<plugin>_<server>__<tool>. This prevents name collisions between plugins."
screenshot: null
week: 8
weekLabel: "Skills — Advanced"
order: 38
slackOneLiner: "🤖 Tip #38 — Plugin MCP servers get auto-prefixed tool names to prevent collisions — always use the full prefix in skills and agents."
keyPointsTitle: "How Auto-Prefixing Works"
actionItemsTitle: "Getting the Prefix Right"
keyPoints:
  - "**Registration** — Place a .mcp.json file alongside your plugin.json. The MCP servers defined there are automatically started when the plugin loads."
  - "**Auto-prefix format** — Plugin MCP tools get the prefix `mcp__plugin_<plugin-name>_<server-name>__<tool-name>`, preventing name collisions between plugins."
  - "**Why it matters** — Two plugins could both register a server named 'api'. Without prefixing they'd collide. With prefixing they coexist: `mcp__plugin_pluginA_api__call` vs `mcp__plugin_pluginB_api__call`."
  - |
    **Our plugin MCP servers**
    - AEM (stdio) — JCR content queries and component inspection
    - Chrome DevTools (stdio) — browser automation and screenshots
    - Figma (HTTP) — design extraction and token mapping
    - axe (Docker) — accessibility testing and compliance
actionItems:
  - |
    **Always use the full prefix in skills and agents**
    - Plugin server: `mcp__plugin_dx-aem_AEM__getNodeContent`
    - Project-level server: `mcp__ado__getWorkItem`
    - WRONG: `mcp__AEM__getNodeContent` (missing plugin prefix)
  - "**The common mistake** — Using the shorthand `mcp__AEM__getNodeContent` instead of the full `mcp__plugin_dx-aem_AEM__getNodeContent`. The shorthand doesn't match the actual registered tool names, causing 'tool not found' failures."
  - "**Copy, don't guess** — When writing skills that call MCP tools, copy the exact tool name from Claude Code's tool list. Never guess the prefix format."
  - "**Verify your setup** — Check .mcp.json in your installed plugins and match the server names to the prefixed tool names you see in Claude Code."
---
