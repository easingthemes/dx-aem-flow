---
title: "PostToolUse: Enrich After It Happens"
category: "Hooks — Guardrails"
focus: "Claude Code"
tags: ["PostToolUse","Cache","Validate"]
overview: "PostToolUse hooks fire after a tool completes. They can't block — the action already happened — but they can cache results, validate outputs, log events, and trigger follow-up actions. Example: automatically save Figma screenshots to disk after every Figma API call."
screenshot: null
week: 7
weekLabel: "Skills — Advanced"
order: 34
slackOneLiner: "🤖 Tip #34 — PostToolUse hooks enrich after the fact — cache expensive results, validate outputs, log actions. Prevention is PreToolUse; enrichment is PostToolUse."
keyPointsTitle: "What PostToolUse Can Do"
actionItemsTitle: "Hooks to Build First"
keyPoints:
  - "**Auto-cache expensive results** — every time the AI calls the Figma screenshot tool, a PostToolUse hook saves the image to disk. Next time you need it, it's already cached — no API call needed."
  - "**Validate file edits** — after any Edit tool call to a plugin file (YAML, JSON, markdown), a hook checks the file is still valid. Catches YAML syntax errors, missing required fields, and accidental deletions."
  - "**Log subagent completions** — after the Agent tool completes, a hook logs the agent name, model used, and duration. Useful for tracking cost and identifying slow agents."
actionItems:
  - "**Cannot block, only observe** — the action already happened. If you need to prevent something, use PreToolUse instead."
  - "**Gets tool result as context** — your script can inspect the output and take different actions based on success or failure."
  - "Create a PostToolUse hook that logs every Bash command to a file — after a session, review what commands the AI ran"
  - "Add a validation hook for Edit calls on config files (YAML, JSON) — catch corruption immediately instead of discovering it later"
  - "Use the matcher to target specific tools — `Edit` for file validation, `mcp__*figma*` for Figma caching"
---
