---
title: "Multi-Provider: ADO + Jira"
category: "Mastery"
focus: "Claude Code"
tags: ["ADO","Jira","Multi-Provider"]
overview: "Our skills work with both Azure DevOps and Jira. A single config value — tracker.provider — switches the entire pipeline between ADO MCP calls and Jira MCP calls. Write skills once, deploy to any organization regardless of their project management tool."
codeLabel: "Provider switch"
screenshot: null
week: 10
weekLabel: "Agents — AI Personas"
order: 49
slackText: |
  🤖 Agentic AI Tip #49 — Multi-Provider: ADO + Jira
  
  Some teams use Azure DevOps. Others use Jira. Our skills work with both.
  
  *How it works:*
  One config value in `.ai/config.yaml`:
  ```yaml
  tracker:
    provider: ado  # or "jira"
  ```
  
  Skills check this value and route to the correct MCP backend:
  • `ado` → `mcp__ado__wit_get_work_item`
  • `jira` → `mcp__atlassian__get_issue`
  
  *Why this matters:*
  Write the skill logic once. The business logic (requirements analysis, planning, implementation) is the same regardless of whether the ticket lives in ADO or Jira. Only the API calls differ.
  
  *The abstraction layer:*
  Field names differ between providers. ADO calls it "Acceptance Criteria," Jira calls it "Description." Our `shared/provider-config.md` maps these fields so skills can reference generic names.
  
  *For teams considering this pattern:*
  Start with one provider. Get the skills working perfectly. Then add the second provider as an abstraction layer. Don't try to build both at once.
  
  💡 Try it: Check your project's `.ai/config.yaml` for the `tracker.provider` value. If you switch orgs, just change this one line.
  
  #AgenticAI #Day49
---

```
# .ai/config.yaml
tracker:
  provider: ado  # or "jira"

# Skills check the provider:
# if ado → use mcp__ado__*
# if jira → use mcp__atlassian__*

# Same skill, different backend:
/dx-req 12345
# → ADO: mcp__ado__wit_get_work_item
# → Jira: mcp__atlassian__get_issue
```
