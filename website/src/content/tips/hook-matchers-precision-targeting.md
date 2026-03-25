---
title: "Hook Matchers: Precision Targeting"
category: "Hooks — Guardrails"
focus: "Claude Code"
tags: ["Matchers","Wildcards","Patterns"]
overview: 'Hook matchers let you target specific operations. "Bash" matches all Bash calls. "Bash(git commit*)" matches only git commits. "Bash(git push --force*)" matches only force pushes. Wildcards give you precision without false positives.'
screenshot: null
week: 8
weekLabel: "Skills — Advanced"
order: 36
slackOneLiner: "🤖 Tip #36 — Hook matchers give you precision targeting — match only `git push --force`, not every Bash call. Glob-style wildcards, no regex."
keyPointsTitle: "Matcher Syntax"
actionItemsTitle: "Matchers for Every Risk"
keyPoints:
  - |
    Tool name plus optional argument pattern in parentheses
    - `"Bash"` — matches ALL Bash tool calls (too broad for most uses)
    - `"Bash(git commit*)"` — matches Bash calls starting with "git commit" (perfect for branch protection)
    - `"Bash(git push --force*)"` — matches only force pushes (precise, no false positives)
  - |
    MCP and other tool matchers
    - `"mcp__*figma*"` — matches any MCP tool with "figma" in the name
    - `"Edit"` — matches all Edit tool calls (good for file validation)
    - `"Write(*.env*)"` — catches secret file creation
  - |
    Wildcard rules
    - `*` matches anything (including nothing)
    - Pattern matches tool name and optionally arguments in parentheses
    - No regex — just glob-style wildcards
actionItems:
  - |
    A matcher for every risk level
    - `Bash(rm -rf*)` — catch destructive deletions
    - `Bash(git reset --hard*)` — catch history destruction
    - `Write(*.env*)` — catch secret file creation
    - `Bash(curl*|*wget*)` — catch network calls
  - "List the 3 most dangerous commands for your project — write a matcher for each and you have a safety net"
  - "Start specific, not broad — `Bash(git commit*)` is better than `Bash` because it avoids false positives on harmless commands"
  - "Test matchers by asking the AI to run the matched command — verify the hook fires and the error message is clear"
---
