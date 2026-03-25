---
title: "allowed-tools: Kill the Permission Spam"
category: "Skills — Recipe Book"
focus: "Copilot CLI"
tags: ["Permissions","allowed-tools","Automation"]
overview: 'Without allowed-tools in your skill frontmatter, Copilot CLI asks for permission before every single tool call. "Can I read this file? Can I run this command? Can I edit this?" It makes automation impossible. Add allowed-tools and the listed tools run automatically.'
screenshot: null
week: 3
weekLabel: "Context — The Secret Sauce"
order: 14
slackOneLiner: "🤖 Tip #14 — Add allowed-tools to your skill frontmatter and stop clicking 'Yes' 13 times per skill run."
keyPointsTitle: "The Problem and the Fix"
actionItemsTitle: "Permission Levels by Skill Type"
keyPoints:
  - "**The problem** — By default, Copilot CLI asks permission before every tool call. A skill that reads 5 files, runs a build, and edits 3 files triggers 13 permission prompts. It completely breaks the flow."
  - "**The fix** — Add allowed-tools to your skill's YAML frontmatter. Listed tools run automatically with no prompts. Unlisted tools still ask for permission — so you get automation where you want it and safety where you need it."
  - "**Cross-tool compatibility** — Claude Code has its own permission system (acceptEdits mode), but allowed-tools works in both Claude Code and Copilot CLI. Adding it doesn't break anything."
actionItems:
  - |
    **Choose the right permission level for each skill**
    - Research only → allowed-tools: [read, grep, glob]
    - Code modification → allowed-tools: [read, edit, write, grep, glob]
    - Full automation → allowed-tools: [read, edit, write, bash, grep, glob]
    - With MCP → add mcp to any of the above
  - "**Be intentional** — read, grep, glob are safe for research skills. Add edit and write for skills that modify code. Add bash for skills that run commands. Add mcp for skills that use MCP servers."
  - "**Try it now** — Add allowed-tools to an existing skill and re-run it. The difference is immediate — no more clicking 'Yes' for every operation."
---
