---
title: "VSCode Chat Agent Mode: Not What You Remember"
category: "Meet Your AI Tools"
focus: "VSCode · CLI"
tags: ["Agent Mode","Plan Mode","Ask Mode"]
overview: "Forget what you knew about VSCode Chat — Agent mode (GA Feb 2025) transformed it into a full autonomous agent. It now edits files, runs terminal commands, uses MCP tools, and self-heals on errors. Three modes: Agent (autonomous), Plan (thinks first), Ask (Q&A only). Edit mode is being deprecated — merged into Agent."
screenshot: null
week: 1
weekLabel: "Meet Your AI Tools"
order: 2
slackOneLiner: "🤖 Tip #2 — VSCode Chat Agent mode (GA Feb 2025) is a full autonomous agent now — edits files, runs commands, self-heals. Not what you remember."
keyPointsTitle: "Agent Mode — What Changed"
keyPoints:
  - "If you tried VSCode Chat a year ago and dismissed it — try again. Agent mode (GA Feb 2025) is a full autonomous agent now."
  - |
    What Agent mode can do
    - Edit files across your workspace autonomously
    - Run terminal commands (builds, tests, installs)
    - Use MCP server tools (AEM, Chrome DevTools, Figma, ADO)
    - Self-heal — monitors errors and fixes them automatically
  - |
    Three built-in modes
    - Agent — full autonomy: edits, runs, iterates
    - Plan — structured thinking before coding
    - Ask — Q&A only, no file modifications
  - "Permission levels — confirm each action, auto-approve edits, or full autopilot. You control the trust level."
actionItemsTitle: "Chat vs CLI — When to Use Which"
actionItems:
  - |
    What Chat has that CLIs don't
    - Inline diffs in the editor (visual review)
    - Language server integration (symbols, references, diagnostics)
    - File/selection attachment with drag & drop
    - Interactive handoff buttons between agents
  - |
    What CLIs have that Chat doesn't
    - Subagent orchestration with worktree isolation
    - Persistent cross-session memory
    - Full plugin hook system
    - 1M token context (Claude Code)
  - "Quick test — open Chat, switch to Agent mode, ask it to 'fix any lint errors in this file and run the build'. Compare with doing the same in your terminal agent."
---
