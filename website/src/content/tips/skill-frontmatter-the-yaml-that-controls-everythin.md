---
title: "Skill Frontmatter: The YAML That Controls Everything"
category: "Skills — Recipe Book"
focus: "Claude Code · CLI"
tags: ["Frontmatter","YAML","Metadata"]
overview: "The YAML block at the top of a skill file isn't just metadata — it controls how the skill behaves. The description field determines when the skill triggers. allowed-tools controls permissions. argument-hint shows what parameters to pass. Get the frontmatter right and the skill works. Get it wrong and it fails silently."
codeLabel: "Real skill frontmatter"
screenshot: null
week: 3
weekLabel: "Context — The Secret Sauce"
order: 13
slackText: |
  🤖 Agentic AI Tip #13 — Skill Frontmatter: The YAML That Controls Everything
  
  The YAML block at the top of a skill file is more important than the instructions below it. Here's what each field does:
  
  *name:* The slash command name (`/my-skill`)
  
  *description:* This is critical — it's what the AI uses to decide when to invoke the skill. Write it like a search query: "Generate implementation plan from requirements" not "This skill generates plans."
  
  *allowed-tools:* Which tools the skill can use without asking permission. Without this in Copilot CLI, every single tool call prompts you for approval. Game-changing for automation.
  
  *argument-hint:* Shows in autocomplete. `"<ticket-id>"` tells users what to pass.
  
  *disable-model-invocation:* Advanced — makes the skill a "coordinator" that dispatches subagents instead of thinking itself.
  
  *The silent failure trap:*
  If you misspell a field or use wrong YAML syntax, the skill doesn't error — it just ignores the frontmatter and treats the whole file as instructions. You won't know something is wrong until the skill behaves unexpectedly.
  
  💡 Try it: Open any existing skill file and read the frontmatter. Notice how the description is written — that's the trigger text.
  
  #AgenticAI #Day13
---

```
---
name: dx-plan
description: Generate implementation
  plan from requirements
argument-hint: "<ticket-id>"
allowed-tools:
  - read
  - write
  - glob
  - grep
  - bash
---
```
