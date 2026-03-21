---
title: "MCP Tool Naming: Three Formats, One Gotcha"
category: "MCP — System Integration"
focus: "Claude Code"
tags: ["Naming","Prefix","Cross-Platform"]
overview: "MCP tool names differ by platform. Claude Code: mcp__plugin_dx-aem_AEM__getNodeContent (double underscore). Copilot: ado/wit_get_work_item (slash format). VSCode: same as Copilot. Plugin tools get an extra prefix. Get the format wrong = silent failure."
codeLabel: "Three naming formats"
screenshot: null
week: 6
weekLabel: "Skills — Recipe Book"
order: 29
slackText: |
  🤖 Agentic AI Tip #29 — MCP Tool Naming: Three Formats, One Gotcha
  
  MCP tool names look different in each tool. This is the #1 debugging headache.
  
  *Claude Code format (double underscore):*
  `mcp__plugin_<plugin>_<server>__<tool>`
  • `mcp__plugin_dx-aem_AEM__getNodeContent`
  • `mcp__ado__wit_get_work_item` (project-level, no plugin prefix)
  
  *Copilot CLI & VSCode format (slash):*
  `'server/tool'`
  • `'AEM/getNodeContent'`
  • `'ado/wit_get_work_item'`
  
  *In .agent.md files:*
  ```yaml
  tools:
    - read
    - 'ado/wit_get_work_item'
    - 'AEM/scanPageComponents'
  ```
  
  *The cross-platform trap:*
  Our agent templates need to work in both Claude Code and Copilot. The tools section must include both naming formats. Unrecognized names are silently ignored — so having both doesn't cause errors.
  
  *Debugging tip:*
  • Claude Code: use `ToolSearch("+AEM")` to find the real prefixed name
  • Copilot CLI: MCP tools appear as `server/tool` in tool lists
  • If a tool "doesn't exist," check the format first
  
  💡 Try it: Compare the tool names in a Claude Code agent file vs a .github/agents/ file. Notice the different format.
  
  #AgenticAI #Day29
---

```
# Claude Code format:
mcp__plugin_dx-aem_AEM__getNodeContent
mcp__ado__wit_get_work_item

# Copilot CLI / VSCode format:
'AEM/getNodeContent'
'ado/wit_get_work_item'

# In Copilot .agent.md tools:
tools:
  - read
  - 'ado/wit_get_work_item'
  - 'AEM/scanPageComponents'
```
