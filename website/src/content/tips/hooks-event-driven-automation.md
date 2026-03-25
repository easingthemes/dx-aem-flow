---
title: "Hooks: Event-Driven Automation"
category: "Hooks — Guardrails"
focus: "Claude Code"
tags: ["Hooks","Events","Automation"]
overview: "Hooks are code that runs when the AI does something. SessionStart fires when a session begins. PreToolUse fires before the AI calls a tool. PostToolUse fires after. Stop fires when the AI finishes. They're your guardrails — preventing mistakes, enriching results, validating actions."
screenshot: null
week: 7
weekLabel: "Skills — Advanced"
order: 32
slackOneLiner: "🤖 Tip #32 — Hooks are shell commands that fire on AI events — think git hooks, but for AI tool usage. Your structural safety net."
keyPointsTitle: "Four Hook Events"
actionItemsTitle: "When to Use Each"
keyPoints:
  - "Hooks are shell commands that run automatically when the AI takes specific actions — think git hooks, but for AI tool usage. Declarative safety that can't be overridden by context loss."
  - "**SessionStart** — fires once when AI session begins. Check Node version, verify MCP connections, validate config files."
  - "**PreToolUse** — fires BEFORE a tool call. Block dangerous operations, validate parameters. Can REJECT the tool call — the AI must find another approach."
  - "**PostToolUse** — fires AFTER a tool call. Cache results, validate outputs, log actions. Cannot block — the action already happened."
  - "**Stop** — fires when the AI finishes. Cleanup, reporting, notifications."
actionItems:
  - |
    Real examples from our project
    - PreToolUse blocks `git commit` on protected branches (development, main)
    - PostToolUse saves Figma screenshots to disk automatically
    - PostToolUse validates plugin file edits (prevents YAML corruption)
  - "Look at your project's hooks: `.claude/hooks/` or plugin `hooks.json` — if none exist, start with a branch protection hook"
  - "Start with PreToolUse for safety — it's the most valuable hook type because it prevents mistakes structurally instead of relying on AI instructions"
  - "Remember the key difference — PreToolUse can block (exit 1), PostToolUse can only observe and enrich"
---
