---
title: "PreToolUse: Block Before It Happens"
category: "Hooks — Guardrails"
focus: "Claude Code"
tags: ["PreToolUse","Block","Safety"]
overview: "PreToolUse hooks fire before the AI executes a tool call. If the hook exits with non-zero, the tool call is blocked. This is how you prevent dangerous operations: committing on protected branches, force-pushing, deleting production resources. Prevention beats recovery."
screenshot: null
week: 7
weekLabel: "Skills — Advanced"
order: 33
slackOneLiner: "🤖 Tip #33 — PreToolUse hooks block dangerous operations before they happen. Instructions get forgotten; hooks are structural."
keyPointsTitle: "How Prevention Works"
actionItemsTitle: "Patterns to Implement"
keyPoints:
  - "PreToolUse fires before any tool call — if the hook exits with code 1, the tool call is blocked. The AI gets the error message and must find another approach."
  - "**Branch protection example** — hook matches `Bash(git commit*)`, script checks current branch, blocks if it's main/master/development/develop with a clear message."
  - "**Why a hook instead of instructions** — instructions get forgotten in long sessions. Context windows compress. Conventions drift. Hooks are structural and can't be overridden by context loss."
actionItems:
  - |
    Common PreToolUse patterns for real risks
    - Block `git push --force` to any branch
    - Block `rm -rf` on project directories
    - Block MCP calls to production environments
    - Validate file paths before write operations
  - "Add a branch protection hook — test it by asking the AI to commit on `main` and watch it get blocked gracefully"
  - "List the 3 most dangerous commands for your project and write a PreToolUse matcher for each"
  - "Keep hook scripts simple — check one thing, exit 0 (allow) or exit 1 (block with message). Complex scripts slow down every tool call."
---
