---
title: "argument-hint: Making Skills Discoverable"
category: "Skills — Advanced"
focus: "Claude Code · CLI"
tags: ["argument-hint","Autocomplete","UX"]
overview: 'When you type / in Claude Code, you see a list of skills. The argument-hint field tells users what to pass before they even read the docs. "/dx-req <ticket-id>" is instantly clear. Without it, users have to guess what the skill expects.'
codeLabel: "UX difference"
screenshot: null
week: 4
weekLabel: "Context — The Secret Sauce"
order: 17
slackText: |
  🤖 Agentic AI Tip #17 — argument-hint: Making Skills Discoverable
  
  Small UX detail that makes a big difference: `argument-hint`.
  
  When you type `/` in Claude Code or Copilot CLI, you see a list of available skills. Without `argument-hint`, you see:
  ```
  /fetch-ticket
  ```
  "What do I pass to this? A URL? An ID? A name?"
  
  With `argument-hint: "<ticket-id>"`, you see:
  ```
  /fetch-ticket <ticket-id>
  ```
  Instantly clear.
  
  *Best practices for argument-hint:*
  • Use angle brackets for required args: `"<ticket-id>"`
  • Use square brackets for optional: `"[--verbose]"`
  • Be specific: `"<ADO-work-item-id>"` not `"<id>"`
  • Match what users actually type: `"<component-name>"` not `"<ComponentNameInPascalCase>"`
  
  *Why this matters more than you think:*
  A skill that nobody knows how to invoke is a skill that nobody uses. discoverability = adoption. The 10 seconds you spend on argument-hint saves every user 30 seconds of confusion.
  
  💡 Try it: Add `argument-hint` to all your custom skills. Check the autocomplete in Claude Code — it looks much more professional.
  
  #AgenticAI #Day17
---

```
---
# Without argument-hint
name: fetch-ticket
description: Fetch a work item
---
# User sees: /fetch-ticket
# "What do I pass?"

---
# With argument-hint
name: fetch-ticket
description: Fetch a work item
argument-hint: "<ticket-id>"
---
# User sees: /fetch-ticket <ticket-id>
# Instantly clear!
```
