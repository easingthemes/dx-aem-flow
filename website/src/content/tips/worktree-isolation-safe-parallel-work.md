---
title: "Worktree Isolation: Safe Parallel Work"
category: "Mastery"
focus: "Claude Code"
tags: ["Worktree","Isolation","Safety"]
overview: 'The isolation: "worktree" parameter gives an agent its own copy of the repo. It can make changes, run builds, even break things — without affecting your working directory. Perfect for code review agents that need to explore without risk.'
codeLabel: "Worktree isolation"
screenshot: null
week: 10
weekLabel: "Agents — AI Personas"
order: 47
slackText: |
  🤖 Agentic AI Tip #47 — Worktree Isolation: Safe Parallel Work
  
  Ever worried about an AI agent messing up your working directory? Worktree isolation solves this completely.
  
  *What it does:*
  `isolation: "worktree"` creates a temporary git worktree — a separate checkout of your repo. The agent works there instead of in your active directory.
  
  *Why this matters:*
  • Agent can make experimental changes safely
  • Your uncommitted work is untouched
  • Agent can run builds that might fail
  • Multiple agents can work on different branches simultaneously
  • If anything goes wrong, delete the worktree — zero impact
  
  *Real use case: Code review*
  Our `dx-code-reviewer` runs in a worktree. It checks out the PR branch, reads the code, maybe even runs the build to verify. Your main workspace stays exactly as you left it.
  
  *Another use case: Parallel feature work*
  Two agents working on two different features simultaneously, each in their own worktree, while you do a third thing in your main directory.
  
  *The cleanup:*
  If the agent makes no changes, the worktree is auto-cleaned. If it made changes, you get the worktree path and branch name to review.
  
  💡 Try it: Next time you spawn an agent for research or review, add `isolation: "worktree"`. Feel the safety.
  
  #AgenticAI #Day47
---

```
# Spawn agent in isolated worktree:
Agent tool:
  subagent_type: "dx-code-reviewer"
  isolation: "worktree"
  prompt: "Review the auth module"

# Agent gets a COPY of the repo
# Can edit, build, test freely
# Your working dir is untouched
# If it messes up → delete worktree
```
