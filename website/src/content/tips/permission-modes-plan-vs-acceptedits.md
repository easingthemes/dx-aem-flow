---
title: "Permission Modes: plan vs acceptEdits"
category: "Agents — AI Personas"
focus: "Claude Code"
tags: ["Permissions","plan","acceptEdits","Safety"]
overview: "Agents have two permission modes. \"plan\" means read-only — the agent can explore but can't change anything. \"acceptEdits\" means the agent can modify files autonomously. Default is read-only. Choose explicitly based on trust level."
codeLabel: "Permission modes"
screenshot: null
week: 6
weekLabel: "Skills — Recipe Book"
order: 26
slackText: |
  🤖 Agentic AI Tip #26 — Permission Modes: plan vs acceptEdits
  
  How much do you trust the agent? That's what permission modes answer.
  
  *plan (read-only):*
  The agent can read files, search code, and analyze — but cannot modify anything. Perfect for:
  • Code review (read and report, don't change)
  • Research (explore codebase, don't touch)
  • Analysis (understand architecture, don't refactor)
  
  *acceptEdits (autonomous):*
  The agent can read AND write files, run commands, make changes. Needed for:
  • Implementation (the whole point is to write code)
  • Bug fixes (needs to edit the broken code)
  • Automation (needs to run builds and tests)
  
  *Why this matters:*
  An agent with `acceptEdits` running in your working directory can modify files you're actively editing. If something goes wrong, you're dealing with merge conflicts against AI changes.
  
  *Safety pattern:* Combine `acceptEdits` with `isolation: "worktree"` — the agent works on a copy of the repo, not your active files. If it messes up, just delete the worktree.
  
  *Our practice:* Only 1 agent out of 13 has `acceptEdits` — the step executor. All others are read-only.
  
  💡 Try it: Check your agent definitions. Any agent with `acceptEdits` that doesn't need it? Switch it to `plan`.
  
  #AgenticAI #Day26
---

```
# Read-only agent (safe exploration)
---
permissionMode: plan
---
# Can: Read, Glob, Grep, Search
# Cannot: Edit, Write, Bash

# Autonomous agent (trusted executor)
---
permissionMode: acceptEdits
---
# Can: Read, Edit, Write, Bash
# Full autonomy within its scope
```
