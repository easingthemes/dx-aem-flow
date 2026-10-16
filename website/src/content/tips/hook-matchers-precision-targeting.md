---
title: "Hook Matchers: Precision Targeting"
category: "Hooks — Guardrails"
focus: "Claude Code"
tags: ["Matchers","Wildcards","Patterns"]
overview: 'Hook matchers pick the tool; the `if` field picks the arguments. "Bash" matches every Bash call. Add `"if": "Bash(git commit*)"` and the hook only runs for git commits. Put `Bash(git commit*)` in the matcher itself and it silently matches nothing.'
screenshot: null
week: 8
weekLabel: "Skills — Advanced"
order: 36
slackOneLiner: "🤖 Tip #36 — `matcher` selects the tool, `if` selects the arguments. `\"matcher\": \"Bash\"` + `\"if\": \"Bash(git push --force*)\"` hits only force pushes."
keyPointsTitle: "Matcher Syntax"
actionItemsTitle: "Matchers for Every Risk"
keyPoints:
  - |
    `matcher` matches the tool NAME only — three ways it is read
    - `""`, `"*"` or omitted — every tool
    - Only letters, digits, `_`, `-`, spaces, `,` and `|` — exact names: `"Bash"`, `"Edit|Write"`
    - Anything else — an unanchored JavaScript regex: `"mcp__.*figma.*"`, `"^Notebook"`
  - |
    The trap: permission-rule syntax in `matcher`
    - `"Bash(git commit*)"` contains `(`, `)` and `*`, so it is read as a regex — "Bash" followed by "git commi" — and no tool name contains that
    - The hook never fires and nothing warns you. `claude plugin validate` accepts it too
    - Our own branch guard shipped this way for months
  - |
    The `if` field — argument filtering, permission rule syntax
    - `"matcher": "Bash"` + `"if": "Bash(git commit*)"` — fires on Bash, spawns the script only for git commits
    - `"matcher": "Edit"` + `"if": "Edit(**/.claude-plugin/**)"` — only validate plugin file edits
    - Evaluated before the hook process spawns; one rule per handler
    - Best-effort, and other tools (Copilot CLI) ignore it — so the script should re-check its input too
actionItems:
  - |
    A filter for every risk level (all with `"matcher": "Bash"` unless noted)
    - `"if": "Bash(rm -rf*)"` — catch destructive deletions
    - `"if": "Bash(git reset --hard*)"` — catch history destruction
    - `"matcher": "Write"` + `"if": "Write(*.env*)"` — catch secret file creation
  - "List the 3 most dangerous commands for your project — write an `if` rule for each and you have a safety net"
  - "Never put parentheses in `matcher` — the tool name goes there, the argument pattern goes in `if`"
  - "Test every guard by asking the AI to run the matched command — a hook you have not watched fire is a hook you do not have"
---
