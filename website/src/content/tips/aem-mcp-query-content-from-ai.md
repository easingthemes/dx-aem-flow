---
title: "AEM MCP: Query Content from AI"
category: "Real-World Workflows"
focus: "Claude Code"
tags: ["AEM","JCR","MCP"]
overview: "The AEM MCP server lets the AI query Adobe Experience Manager's content repository directly. Find components on pages, inspect dialog fields, search content trees, check page properties. No more switching between the AI terminal and AEM's CRXDE."
screenshot: null
week: 9
weekLabel: "Agents — AI Personas"
order: 42
slackOneLiner: "🤖 Tip #42 — AEM MCP gives the AI direct access to JCR — query components, inspect dialogs, search content, no CRXDE needed."
keyPointsTitle: "What the AI Can Query"
actionItemsTitle: "Setup and Tool Names"
keyPoints:
  - |
    **Core tools**
    - getNodeContent — read any JCR node
    - scanPageComponents — list all components on a page
    - searchContent — find pages/components/assets by query
    - getPageProperties — page metadata
    - getComponents — available components for a template
  - "**Real workflow examples** — 'Find all pages using the hero component' returns page paths with author URLs. 'What fields does the hero dialog have?' returns field names, types, and constraints directly from the dialog definition."
  - "**Multi-instance support** — Query local:4502 and qa-author in the same session. Compare component state across environments without switching browser tabs."
  - "**Fallback chain pattern** — The agent first tries an exact resourceType query. If that returns nothing, it falls back to a LIKE query. If that fails too, it uses explore subagents. Three levels of resilience, no human intervention."
actionItems:
  - "**Try it** — If you have AEM running locally, add the AEM MCP server and ask the AI to list all components on your homepage"
  - |
    **Key MCP tool names to know**
    - mcp__plugin_dx-aem_AEM__searchContent — find content by query
    - mcp__plugin_dx-aem_AEM__getNodeContent — read any JCR node
    - mcp__plugin_dx-aem_AEM__scanPageComponents — list components on a page
  - "**Configure AEM_INSTANCES** — Environment variable supports multiple AEM instances (local, QA, staging) for cross-environment comparison"
  - "**No more CRXDE tab-switching** — The AI reads JCR content directly while analyzing code. Component definitions, dialog configs, and content structures are all accessible from the terminal."
---
