---
title: "PreToolUse: Block Before It Happens"
category: "Hooks — Guardrails"
focus: "Claude Code"
tags: ["PreToolUse","Block","Safety"]
overview: "PreToolUse hooks fire before the AI executes a tool call. If the hook exits with non-zero, the tool call is blocked. This is how you prevent dangerous operations: committing on protected branches, force-pushing, deleting production resources. Prevention beats recovery."
codeLabel: "Branch protection"
screenshot: null
week: 7
weekLabel: "Skills — Advanced"
order: 33
slackText: |
  🤖 Agentic AI Tip #33 — PreToolUse: Block Before It Happens
  
  The most valuable type of hook: preventing mistakes before they happen.
  
  *How it works:*
  When the AI is about to run a tool (like Bash with `git commit`), the PreToolUse hook fires first. If the hook exits with code 1, the tool call is *blocked*. The AI gets the error message and must find another approach.
  
  *Real example — branch protection:*
  ```json
  {
    "event": "PreToolUse",
    "matcher": "Bash(git commit*)",
    "command": "./scripts/check-branch.sh"
  }
  ```
  
  The script checks the current branch. If it's `main`, `master`, `development`, or `develop`, it blocks the commit with a clear message.
  
  *Why a hook instead of just telling the AI "don't commit on main"?*
  Because instructions get forgotten in long sessions. Context windows compress. Conventions drift. But hooks are *structural* — they can't be overridden by context loss.
  
  *Other PreToolUse patterns:*
  • Block `git push --force` to any branch
  • Block `rm -rf` on project directories
  • Block MCP calls to production environments
  • Validate file paths before write operations
  
  💡 Try it: Add a branch protection hook. Test it by asking the AI to commit on `main`. Watch it get blocked gracefully.
  
  #AgenticAI #Day33
---

```
# scripts/check-branch.sh
#!/bin/bash
BRANCH=$(git branch --show-current)
if [[ "$BRANCH" =~ ^(main|master|development|develop)$ ]]; then
  echo "BLOCKED: Cannot commit on $BRANCH"
  exit 1
fi
exit 0
```
