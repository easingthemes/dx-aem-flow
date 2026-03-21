---
title: "Hooks: Event-Driven Automation"
category: "Hooks — Guardrails"
focus: "Claude Code"
tags: ["Hooks","Events","Automation"]
overview: "Hooks are code that runs when the AI does something. SessionStart fires when a session begins. PreToolUse fires before the AI calls a tool. PostToolUse fires after. Stop fires when the AI finishes. They're your guardrails — preventing mistakes, enriching results, validating actions."
codeLabel: "Hook examples"
screenshot: null
week: 7
weekLabel: "Skills — Advanced"
order: 32
slackText: |
  🤖 Agentic AI Tip #32 — Hooks: Event-Driven Automation
  
  Hooks are the safety net you didn't know you needed.
  
  *What are hooks?*
  Shell commands that run automatically when the AI takes specific actions. Think of them as git hooks, but for AI tool usage.
  
  *Four hook events:*
  
  *SessionStart* — fires once when AI session begins
  → Check Node version, verify MCP connections, validate config
  
  *PreToolUse* — fires BEFORE a tool call
  → Block dangerous operations, validate parameters
  → Can REJECT the tool call (the AI can't proceed)
  
  *PostToolUse* — fires AFTER a tool call
  → Cache results, validate outputs, log actions
  
  *Stop* — fires when the AI finishes
  → Cleanup, reporting, notifications
  
  *Real examples from our project:*
  • PreToolUse blocks `git commit` on protected branches (development, main)
  • PostToolUse saves Figma screenshots to disk automatically
  • PostToolUse validates plugin file edits (prevents YAML corruption)
  
  *The power:* Hooks are declarative safety. Instead of hoping the AI remembers not to commit on main, you *prevent* it structurally.
  
  💡 Try it: Look at your project's hooks (if any): `.claude/hooks/` or plugin `hooks.json`. If none exist, start with a branch protection hook.
  
  #AgenticAI #Day32
---

```
# hooks.json
[
  {
    "event": "PreToolUse",
    "matcher": "Bash(git commit*)",
    "command": "./scripts/check-branch.sh"
  },
  {
    "event": "PostToolUse",
    "matcher": "Edit",
    "command": "./scripts/validate-edit.sh"
  }
]
```
