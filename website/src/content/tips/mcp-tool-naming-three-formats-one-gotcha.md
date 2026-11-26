---
title: "MCP Tool Naming: Three Formats, One Gotcha"
category: "MCP — System Integration"
focus: "Claude Code"
tags: ["Naming","Prefix","Cross-Platform"]
overview: "MCP tool names differ by platform. Claude Code: mcp__plugin_dx-aem_AEM__getNodeContent (double underscore). Copilot CLI registers <server>-<tool>: ado-wit_work_item. VS Code Chat and Codex CLI register the bare name: getNodeContent. Gemini CLI uses a single underscore: mcp_aem_getnodecontent. Plugin tools get an extra prefix in Claude Code only."
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
    - Project-level servers skip the plugin prefix: mcp__ado__wit_work_item
  - |
    **Copilot CLI (server, hyphen, tool)**
    - Pattern: <server>-<tool>
    - Example: ado-wit_work_item, AEM-getNodeContent
    - Seen on Copilot CLI v1.0.116: a tool search for the Claude name finds nothing, so the model has to know the mapping.
  - |
    **VS Code Chat and Codex CLI (bare name)**
    - Pattern: tool
    - Example: getNodeContent, wit_work_item
    - No server prefix at all. Codex constrains tool names to letters, digits, underscore and hyphen, so a dotted prefix is not even legal there.
  - |
    **Gemini CLI format (single underscore)**
    - Pattern: mcp_<server>_<tool>, lowercased
    - Example: mcp_aem_getnodecontent
    - The server name must not contain an underscore. If two servers expose the same tool name, Gemini promotes it to serverAlias__tool with a double underscore.
  - "**The gotcha** — Write the Claude Code prefixed name. In an agent or skill file these names are prose hints to the model, not literal function calls, so the LLM usually maps a prefixed name onto whatever is registered locally. Where a skill must find a tool before using it (checking that a server is connected, say), state the host mapping once — mcp__<server>__<tool> on Claude Code, <server>-<tool> on Copilot CLI — instead of hoping the model guesses it."
actionItems:
  - |
    **Write one format: the Claude Code prefix**
    - In skill and agent files: mcp__plugin_dx-aem_AEM__getNodeContent
    - Other platforms resolve it from the tools and mcpServers declarations — adding a new MCP server needs no per-platform edit
  - "**Debugging in Claude Code** — Use ToolSearch(\"+AEM\") to find the real prefixed name. If a tool 'doesn't exist,' the naming format is the first thing to check."
  - "**Debugging in Copilot CLI** — MCP tools appear as <server>-<tool> in tool lists (ado-wit_work_item). Compare against what your agent file references."
  - "**Comparison test** — Look at a Claude Code agent file vs a .github/agents/ file side by side. The naming difference becomes immediately obvious."
---
