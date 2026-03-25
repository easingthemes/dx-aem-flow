---
title: "Worktree Isolation: Safe Parallel Work"
category: "Mastery"
focus: "Claude Code"
tags: ["Worktree","Isolation","Safety"]
overview: 'The isolation: "worktree" parameter gives an agent its own copy of the repo. It can make changes, run builds, even break things — without affecting your working directory. Perfect for code review agents that need to explore without risk.'
screenshot: null
week: 10
weekLabel: "Agents — AI Personas"
order: 47
slackOneLiner: "🤖 Tip #47 — Worktree isolation gives agents their own repo copy — they can break things without touching your working directory."
keyPointsTitle: "How Worktrees Protect You"
actionItemsTitle: "Best Use Cases"
keyPoints:
  - "**What it does** — `isolation: \"worktree\"` creates a temporary git worktree, a separate checkout of your repo. The agent works there instead of in your active directory."
  - "**Safety guarantees** — Agent can make experimental changes, run builds that might fail, and explore freely. Your uncommitted work is completely untouched. If anything goes wrong, delete the worktree with zero impact."
  - "**Cleanup behavior** — If the agent makes no changes, the worktree is auto-cleaned. If it made changes, you get the worktree path and branch name to review before deciding what to keep."
actionItems:
  - "**Code review** — Our `dx-code-reviewer` runs in a worktree. It checks out the PR branch, reads the code, maybe even runs the build to verify. Your main workspace stays exactly as you left it."
  - "**Parallel features** — Two agents working on two different features simultaneously, each in their own worktree, while you do a third thing in your main directory."
  - |
    **Best candidates for worktree isolation**
    - Code review agents — need to checkout PR branches
    - Build verification agents — might break things
    - Experimental refactoring — safe to explore without risk
    - Parallel feature work — multiple agents, multiple branches
  - "**Try it now** — Next time you spawn an agent for research or review, add `isolation: \"worktree\"` to feel the safety. Run `git worktree list` to see current worktrees."
---
