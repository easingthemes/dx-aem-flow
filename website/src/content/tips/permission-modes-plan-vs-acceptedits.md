---
title: "Permission Modes: plan vs acceptEdits"
category: "Agents — AI Personas"
focus: "Claude Code"
tags: ["Permissions","plan","acceptEdits","Safety"]
overview: "Agents have two permission modes. \"plan\" means read-only — the agent can explore but can't change anything. \"acceptEdits\" means the agent can modify files autonomously. Default is read-only. Choose explicitly based on trust level."
screenshot: null
week: 6
weekLabel: "Skills — Recipe Book"
order: 26
slackOneLiner: "🤖 Tip #26 — How much do you trust the agent? 'plan' = read-only exploration, 'acceptEdits' = autonomous file changes. Default to plan."
keyPointsTitle: "Two Modes, Different Trust Levels"
keyPoints:
  - |
    plan (read-only)
    - The agent can read files, search code, and analyze — but cannot modify anything
    - Perfect for code review (read and report), research (explore codebase), and analysis (understand architecture)
  - |
    acceptEdits (autonomous)
    - The agent can read AND write files, run commands, make changes
    - Needed for implementation (writing code), bug fixes (editing broken code), and automation (running builds and tests)
  - "Risk with acceptEdits — an agent with acceptEdits running in your working directory can modify files you're actively editing. If something goes wrong, you're dealing with merge conflicts against AI changes."
actionItemsTitle: "Safety Patterns in Practice"
actionItems:
  - "Safety pattern — combine acceptEdits with isolation: 'worktree'. The agent works on a copy of the repo, not your active files. If it messes up, just delete the worktree."
  - "Our practice — only 1 agent out of 13 has acceptEdits (the step executor). All others are read-only. Default to plan unless the agent's job is to write code."
  - "Check your agent definitions — any agent with acceptEdits that doesn't need it? Switch it to plan"
  - |
    Choose permission mode by agent role
    - Reviewers, analyzers, searchers → plan
    - Implementers, fixers, automators → acceptEdits + worktree
---
