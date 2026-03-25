---
title: "Multi-Provider: ADO + Jira"
category: "Mastery"
focus: "Claude Code"
tags: ["ADO","Jira","Multi-Provider"]
overview: "Our skills work with both Azure DevOps and Jira. A single config value — tracker.provider — switches the entire pipeline between ADO MCP calls and Jira MCP calls. Write skills once, deploy to any organization regardless of their project management tool."
screenshot: null
week: 10
weekLabel: "Agents — AI Personas"
order: 49
slackOneLiner: "🤖 Tip #49 — One config value (tracker.provider) switches the entire skill pipeline between ADO and Jira — write once, deploy anywhere."
keyPointsTitle: "How the Abstraction Works"
actionItemsTitle: "Provider Mapping Details"
keyPoints:
  - "**Single config switch** — One value in .ai/config.yaml (tracker.provider: ado or jira) routes all skills to the correct MCP backend. No code changes, no skill duplication."
  - "**Business logic stays the same** — Requirements analysis, planning, and implementation logic is identical regardless of where the ticket lives. Only the API calls to fetch and update tickets differ between providers."
  - "**Field name abstraction** — ADO calls it 'Acceptance Criteria,' Jira calls it 'Description.' The shared/provider-config.md file maps these fields so skills can reference generic names like 'acceptance criteria' everywhere."
  - "**Practical adoption strategy** — Start with one provider and get all skills working perfectly. Then add the second provider as an abstraction layer. Don't try to build both at once."
actionItems:
  - |
    **Provider mapping examples**
    - ADO: mcp__ado__wit_get_work_item, mcp__ado__wit_update_work_item
    - Jira: mcp__atlassian__get_issue, mcp__atlassian__update_issue
  - "**Quick switch** — Check your .ai/config.yaml for the tracker.provider value. Changing this one line switches the entire pipeline."
  - "**Customize field mappings** — Review shared/provider-config.md if your Jira instance uses custom field names that differ from the defaults"
  - "**Test both paths** — After adding a second provider, run /dx-req <ticket-id> with each provider setting to verify field mapping works correctly"
---
