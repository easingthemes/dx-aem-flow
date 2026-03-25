---
title: "MCP Tool Naming: Three Formats, One Gotcha"
category: "MCP — System Integration"
focus: "Claude Code"
tags: ["Naming","Prefix","Cross-Platform"]
overview: "MCP tool names differ by platform. Claude Code: mcp__plugin_dx-aem_AEM__getNodeContent (double underscore). Copilot: ado/wit_get_work_item (slash format). VSCode: same as Copilot. Plugin tools get an extra prefix. Get the format wrong = silent failure."
screenshot: null
week: 6
weekLabel: "Skills — Recipe Book"
order: 29
slackOneLiner: "🤖 Tip #29 — MCP tool names look different in each platform — get the format wrong and tools silently fail to resolve."
keyPointsTitle: "The Three Naming Formats"
actionItemsTitle: "Cross-Platform Survival Guide"
keyPoints:
  - |
    **Claude Code format (double underscore)**
    - Pattern: mcp__plugin_<plugin>_<server>__<tool>
    - Example: mcp__plugin_dx-aem_AEM__getNodeContent
    - Project-level servers skip the plugin prefix: mcp__ado__wit_get_work_item
  - |
    **Copilot CLI and VSCode format (slash)**
    - Pattern: server/tool
    - Example: AEM/getNodeContent, ado/wit_get_work_item
    - Same format for both platforms
  - "**The gotcha** — Agent templates that need to work in both Claude Code and Copilot must include both naming formats in the tools section. Unrecognized names are silently ignored, so having both doesn't cause errors."
actionItems:
  - |
    **Include both formats in cross-platform templates**
    - Claude Code: mcp__plugin_dx-aem_AEM__getNodeContent
    - Copilot CLI: AEM/getNodeContent
  - "**Debugging in Claude Code** — Use ToolSearch(\"+AEM\") to find the real prefixed name. If a tool 'doesn't exist,' the naming format is the first thing to check."
  - "**Debugging in Copilot CLI** — MCP tools appear as server/tool in tool lists. Compare against what your agent file references."
  - "**Comparison test** — Look at a Claude Code agent file vs a .github/agents/ file side by side. The naming difference becomes immediately obvious."
---
