---
title: "AEM MCP: Query Content from AI"
category: "Real-World Workflows"
focus: "Claude Code"
tags: ["AEM","JCR","MCP"]
overview: "The AEM MCP server lets the AI query Adobe Experience Manager's content repository directly. Find components on pages, inspect dialog fields, search content trees, check page properties. No more switching between the AI terminal and AEM's CRXDE."
codeLabel: "AEM MCP in action"
screenshot: null
week: 9
weekLabel: "Agents — AI Personas"
order: 42
slackText: |
  🤖 Agentic AI Tip #42 — AEM MCP: Query Content from AI
  
  If you work with Adobe Experience Manager, this MCP server is a game-changer.
  
  *What AEM MCP gives you:*
  • `getNodeContent` — read any JCR node (component definitions, configs)
  • `scanPageComponents` — list all components on a page
  • `searchContent` — find content by query (pages, components, assets)
  • `getPageProperties` — read page metadata
  • `getComponents` — list available components for a template
  
  *Real workflows:*
  "Find all pages that use the hero component" → AEM MCP searches JCR → returns page paths with author URLs.
  
  "What fields does the hero dialog have?" → AEM MCP reads the dialog definition → returns field names, types, and constraints.
  
  "Compare the component on local vs QA" → AEM MCP supports multi-instance. Query local:4502 and qa-author in the same session.
  
  *The fallback chain pattern:*
  Our agent first tries an exact resourceType query. If that returns nothing, it falls back to a LIKE query. If that fails too, it uses explore subagents. Three levels of resilience, no human intervention.
  
  💡 Try it: If you have AEM running locally, add the AEM MCP server and ask the AI to list all components on your homepage.
  
  #AgenticAI #Day42
---

```
# Find pages using a component:
mcp__plugin_dx-aem_AEM__searchContent
  query: "hero" resourceType

# Get component dialog fields:
mcp__plugin_dx-aem_AEM__getNodeContent
  path: "/apps/brand-a/components/hero"

# List all components on a page:
mcp__plugin_dx-aem_AEM__scanPageComponents
  path: "/content/brand-a/gb/en"
```
