---
title: "VSCode Chat Agent Mode: Not What You Remember"
category: "Meet Your AI Tools"
focus: "VSCode · CLI"
tags: ["Agent Mode","Plan Mode","Ask Mode"]
overview: "Forget what you knew about VSCode Chat — Agent mode (GA Feb 2025) transformed it into a full autonomous agent. It now edits files, runs terminal commands, uses MCP tools, and self-heals on errors. Three modes: Agent (autonomous), Plan (thinks first), Ask (Q&A only). Edit mode is being deprecated — merged into Agent."
codeLabel: "Three modes"
screenshot: null
week: 1
weekLabel: "Meet Your AI Tools"
order: 2
slackText: |
  🤖 Agentic AI Tip #2 — VSCode Chat Agent Mode: Not What You Remember
  
  If you tried VSCode Chat a year ago and dismissed it as "just autocomplete" — try again. Everything changed.
  
  *Agent mode (GA Feb 2025):*
  • Edits files across your workspace autonomously
  • Runs terminal commands (builds, tests, installs)
  • Uses MCP server tools (AEM, Chrome DevTools, Figma, ADO)
  • Self-heals — monitors errors and fixes them automatically
  • Permission levels: confirm each action, auto-approve all, or full autopilot
  
  *Three built-in modes:*
  • *Agent* — full autonomy: edits, runs, iterates
  • *Plan* — structured thinking before coding
  • *Ask* — Q&A only, no file modifications
  
  *What's gone:* Edit mode is being deprecated and merged into Agent mode.
  
  *What Chat has that CLIs don't:*
  • Inline diffs in the editor (visual review)
  • Language server integration (symbols, references, diagnostics)
  • File/selection attachment with drag & drop
  • Interactive handoff buttons between agents
  
  *What CLIs have that Chat doesn't:*
  • Subagent orchestration with worktree isolation
  • Persistent cross-session memory
  • Full plugin hook system
  • 1M token context (Claude Code)
  
  💡 Try it: Open VSCode Chat, switch to Agent mode, and ask it to "fix any lint errors in this file and run the build."
  
  #AgenticAI #Day2
---

```
# Three modes in VSCode Chat:

# Agent — full autonomy
"Fix the auth bug, run tests, and
 update the changelog"
→ edits files, runs terminal, iterates

# Plan — think before coding
"Plan how to refactor the modal system"
→ structured plan, then executes

# Ask — Q&A only (no changes)
"How does the routing work?"
→ explains, no file modifications
```
