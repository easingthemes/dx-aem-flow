---
title: "Skill Frontmatter: The YAML That Controls Everything"
category: "Skills — Recipe Book"
focus: "Claude Code · CLI"
tags: ["Frontmatter","YAML","Metadata"]
overview: "The YAML block at the top of a skill file isn't just metadata — it controls how the skill behaves. The description field determines when the skill triggers. allowed-tools controls permissions. argument-hint shows what parameters to pass. Get the frontmatter right and the skill works. Get it wrong and it fails silently."
screenshot: null
week: 3
weekLabel: "Context — The Secret Sauce"
order: 13
slackOneLiner: "🤖 Tip #13 — The YAML block at the top of a skill controls everything: triggering, permissions, parameters. Get it wrong and the skill fails silently."
keyPointsTitle: "Every Field Explained"
actionItemsTitle: "Audit Your Skills Now"
keyPoints:
  - "**name** — The slash command name (`/my-skill`). This is what users type to invoke the skill."
  - "**description** — The most critical field. The AI uses this to decide when to invoke the skill. Write it like a search query: 'Generate implementation plan from requirements' not 'This skill generates plans.'"
  - "**allowed-tools** — Which tools the skill can use without asking permission. Without this in Copilot CLI, every single tool call prompts for approval. Game-changing for automation."
  - "**argument-hint** — Shows in autocomplete. `\"<ticket-id>\"` tells users what to pass before they even read the docs."
  - "**disable-model-invocation** — Advanced field that makes the skill a 'coordinator' that dispatches subagents instead of thinking itself. Used for multi-step pipelines."
actionItems:
  - |
    Audit your skill descriptions for trigger quality
    - Rewrite any that say "This skill does X" to instead say "Do X from Y"
    - The description is search text, not documentation — write it like a query
    - Open any existing skill file and study how the description reads as trigger text
  - |
    Check for silent frontmatter failures
    - Validate YAML syntax (proper indentation, no tabs)
    - Verify field names are spelled correctly (allowed-tools, not allowedTools)
    - Test that the skill actually picks up the frontmatter by checking tool permissions
  - "**The silent failure trap** — If you misspell a field or use wrong YAML syntax, the skill doesn't error. It ignores the frontmatter and treats the whole file as instructions. You won't know until the skill behaves unexpectedly."
---
