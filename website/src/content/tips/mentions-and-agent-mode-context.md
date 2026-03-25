---
title: "@ Mentions and Agent Mode Context"
category: "Context — The Secret Sauce"
focus: "VSCode Chat"
tags: ["@file","@workspace","#runSubagent","Agent Mode"]
overview: "In VSCode Chat, @ mentions feed context: @workspace, @terminal, @vscode. In Agent mode, the AI also auto-discovers context — it reads files, searches code, and checks diagnostics on its own. New: #runSubagent creates context-isolated sub-tasks. In Copilot CLI, use #file and drag-and-drop for context."
screenshot: null
week: 2
weekLabel: "Meet Your AI Tools"
order: 9
slackOneLiner: "🤖 Tip #9 — How you feed context to AI depends on the mode and tool. Agent mode auto-discovers; Ask/Plan mode needs @ mentions."
keyPointsTitle: "How Each Tool Gets Context"
keyPoints:
  - |
    VSCode Chat — Ask/Plan mode (manual context)
    - @workspace — searches your codebase
    - @terminal — includes terminal output
    - @vscode — knows about editor settings and commands
    - Drag & drop files into chat
    - Select code → 'Add to Chat'
  - "VSCode Chat — Agent mode (auto-discovers) — the AI doesn't wait for you to feed context. It actively searches, reads files, runs searches, checks LSP diagnostics, even runs terminal commands. Just describe the task."
  - |
    Copilot CLI context
    - #file:path/to/file.js to include a specific file
    - Drag & drop from file explorer
    - CLI auto-reads relevant files in agentic mode
  - "Claude Code — automatically discovers context via Read, Grep, Glob tools. CLAUDE.md provides persistent project context loaded into every session."
actionItemsTitle: "Context Power Moves"
actionItems:
  - "#runSubagent — creates a context-isolated sub-task within VSCode Chat. The subagent gets a fresh context, does its work, and returns results — similar to Claude Code's spawned agents."
  - "In VSCode Agent mode, just describe what you want without any @ mentions — watch how the AI finds context on its own"
  - "Use #runSubagent for isolated research tasks that shouldn't pollute your main conversation context"
  - "In Copilot CLI, use #file:path to explicitly include files when the auto-discovery misses something"
---
