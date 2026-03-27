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
keyPointsTitle: "Hook Events"
actionItemsTitle: "When to Use Each"
keyPoints:
  - "Hooks are shell commands, HTTP endpoints, or LLM prompts that run automatically when the AI takes specific actions — think git hooks, but for AI tool usage. Declarative safety that can't be overridden by context loss."
  - "**SessionStart** — fires once when AI session begins. Check Node version, verify MCP connections, validate config files."
  - "**PreToolUse** — fires BEFORE a tool call. Block dangerous operations, validate parameters. Can REJECT the tool call — the AI must find another approach."
  - "**PostToolUse** — fires AFTER a tool call. Cache results, validate outputs, log actions. Can provide feedback to Claude via `additionalContext`."
  - "**Stop** — fires when the AI finishes. Can block termination to force continuation (check `stop_hook_active` to prevent infinite loops)."
  - |
    Additional events (20+ total)
    - **SubagentStart/Stop** — observe or block subagent lifecycle
    - **UserPromptSubmit** — validate or enrich user prompts before processing
    - **PostToolUseFailure** — catch tool errors and provide recovery guidance
    - **FileChanged** — react to watched file changes (e.g., `.envrc`)
    - **PermissionRequest** — auto-approve or deny permission dialogs
    - See [official docs](https://code.claude.com/docs/en/hooks) for the full list
actionItems:
  - |
    Real examples from our project
    - PreToolUse blocks `git commit` on protected branches (development, main) — uses `if` field for precision
    - PostToolUse saves Figma screenshots to disk automatically
    - PostToolUse validates plugin file edits — uses `if: "Edit(**/.claude-plugin/**)"` to skip non-plugin edits
    - PostToolUse logs Chrome DevTools screenshots asynchronously (`async: true`)
  - "Look at your project's hooks: `.claude/hooks/` or plugin `hooks.json` — if none exist, start with a branch protection hook"
  - "Start with PreToolUse for safety — it's the most valuable hook type because it prevents mistakes structurally instead of relying on AI instructions"
  - "Key difference: PreToolUse can block (exit **2** for blocking error), PostToolUse can observe and enrich. Exit 1 is a non-blocking error (verbose mode only)"
  - "Use `statusMessage` to show spinner text while hooks run, and `async: true` for observational hooks that don't need to block"
---
