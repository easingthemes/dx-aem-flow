---
title: "@ Mentions and Agent Mode Context"
category: "Context — The Secret Sauce"
focus: "VSCode Chat"
tags: ["@file","@workspace","#runSubagent","Agent Mode"]
overview: "In VSCode Chat, @ mentions feed context: @workspace, @terminal, @vscode. In Agent mode, the AI also auto-discovers context — it reads files, searches code, and checks diagnostics on its own. New: #runSubagent creates context-isolated sub-tasks. In Copilot CLI, use #file and drag-and-drop for context."
codeLabel: "Context feeding"
screenshot: null
week: 2
weekLabel: "Meet Your AI Tools"
order: 9
slackText: |
  🤖 Agentic AI Tip #9 — @ Mentions and Agent Mode Context
  
  How you feed context to AI depends on the mode and tool.
  
  *VSCode Chat — Ask/Plan mode (manual context):*
  • `@workspace` — searches your codebase
  • `@terminal` — includes terminal output
  • `@vscode` — knows about editor settings and commands
  • Drag & drop files into chat
  • Select code → "Add to Chat"
  
  *VSCode Chat — Agent mode (auto-discovers):*
  In Agent mode, the AI doesn't wait for you to feed context. It *actively searches* — reads files, runs searches, checks LSP diagnostics, even runs terminal commands. You just describe the task, it finds what it needs.
  
  *New: #runSubagent*
  Creates a context-isolated sub-task within VSCode Chat. The subagent gets a fresh context, does its work, and returns results — similar to Claude Code's spawned agents.
  
  *Copilot CLI:*
  • `#file:path/to/file.js` to include a file
  • Drag & drop from file explorer
  • CLI auto-reads relevant files in agentic mode
  
  *Claude Code:*
  Automatically discovers context. Read, Grep, Glob tools let it explore the codebase. CLAUDE.md provides persistent project context.
  
  💡 Try it: In VSCode Agent mode, just describe what you want. Don't manually @ mention anything. Watch how the AI finds context on its own.
  
  #AgenticAI #Day9
---

```
# VSCode Chat — @ mentions:
@workspace "find Modal usages"
@terminal "why did this fail?"
@vscode "how to configure font size?"

# Agent mode — auto-discovers context:
"Fix the auth bug"
→ AI reads files, checks LSP, runs tests

# Sub-task with isolated context:
#runSubagent "research the modal API"

# Copilot CLI — context:
#file:src/auth.js "explain this"
```
