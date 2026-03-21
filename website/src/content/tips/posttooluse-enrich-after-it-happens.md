---
title: "PostToolUse: Enrich After It Happens"
category: "Hooks — Guardrails"
focus: "Claude Code"
tags: ["PostToolUse","Cache","Validate"]
overview: "PostToolUse hooks fire after a tool completes. They can't block — the action already happened — but they can cache results, validate outputs, log events, and trigger follow-up actions. Example: automatically save Figma screenshots to disk after every Figma API call."
codeLabel: "PostToolUse patterns"
screenshot: null
week: 7
weekLabel: "Skills — Advanced"
order: 34
slackText: |
  🤖 Agentic AI Tip #34 — PostToolUse: Enrich After It Happens
  
  While PreToolUse prevents, PostToolUse enriches. It fires after a tool completes and is perfect for caching, validation, and logging.
  
  *Pattern 1: Auto-cache expensive results*
  Every time the AI calls the Figma screenshot tool, a PostToolUse hook saves the image to disk. Next time you need it, it's already cached — no API call needed.
  
  *Pattern 2: Validate file edits*
  After any Edit tool call to a plugin file (YAML, JSON, markdown), a hook checks the file is still valid. Catches YAML syntax errors, missing required fields, and accidental deletions.
  
  *Pattern 3: Log subagent completions*
  After the Agent tool completes, a hook logs the agent name, model used, and duration. Useful for tracking cost and identifying slow agents.
  
  *What PostToolUse CANNOT do:*
  It cannot block the tool call — the action already happened. If you need to prevent something, use PreToolUse.
  
  *Pro tip:* PostToolUse hooks get the tool result as context. Your script can inspect the output and take different actions based on success/failure.
  
  💡 Try it: Create a PostToolUse hook that logs every Bash command to a file. After a session, review what commands the AI ran.
  
  #AgenticAI #Day34
---

```
# Auto-cache Figma screenshots
{
  "event": "PostToolUse",
  "matcher": "mcp__*figma*get_screenshot*",
  "command": "./scripts/cache-figma.sh"
}

# Validate plugin file edits
{
  "event": "PostToolUse",
  "matcher": "Edit",
  "command": "./scripts/validate-edit.sh"
}
```
