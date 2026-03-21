---
title: "Hook Matchers: Precision Targeting"
category: "Hooks — Guardrails"
focus: "Claude Code"
tags: ["Matchers","Wildcards","Patterns"]
overview: 'Hook matchers let you target specific operations. "Bash" matches all Bash calls. "Bash(git commit*)" matches only git commits. "Bash(git push --force*)" matches only force pushes. Wildcards give you precision without false positives.'
codeLabel: "Matcher precision"
screenshot: null
week: 8
weekLabel: "Skills — Advanced"
order: 36
slackText: |
  🤖 Agentic AI Tip #36 — Hook Matchers: Precision Targeting
  
  A hook that fires on every Bash command is useless — too noisy. A hook that fires on `git push --force` only is perfect.
  
  *Matcher syntax:*
  
  `"Bash"` — matches ALL Bash tool calls
  → Too broad for most uses
  
  `"Bash(git commit*)"` — matches Bash calls starting with "git commit"
  → Perfect for branch protection
  
  `"Bash(git push --force*)"` — matches only force pushes
  → Precise, no false positives
  
  `"mcp__*figma*"` — matches any MCP tool with "figma" in the name
  → Catches all Figma operations
  
  `"Edit"` — matches all Edit tool calls
  → Good for file validation hooks
  
  *The wildcard rules:*
  • `*` matches anything (including nothing)
  • The pattern matches the tool name and optionally the arguments in parentheses
  • No regex — just glob-style wildcards
  
  *A matcher for every risk level:*
  • `Bash(rm -rf*)` — catch destructive deletions
  • `Bash(git reset --hard*)` — catch history destruction
  • `Write(*.env*)` — catch secret file creation
  • `Bash(curl*|*wget*)` — catch network calls
  
  💡 Try it: List the 3 most dangerous commands for your project. Write a matcher for each. You now have a safety net.
  
  #AgenticAI #Day36
---

```
# Match ALL Bash calls
"matcher": "Bash"

# Match only git commits
"matcher": "Bash(git commit*)"

# Match only force pushes
"matcher": "Bash(git push --force*)"

# Match any MCP tool with "figma"
"matcher": "mcp__*figma*"

# Match Edit tool (any file)
"matcher": "Edit"
```
