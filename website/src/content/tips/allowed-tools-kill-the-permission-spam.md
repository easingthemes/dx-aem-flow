---
title: "allowed-tools: Kill the Permission Spam"
category: "Skills — Recipe Book"
focus: "Copilot CLI"
tags: ["Permissions","allowed-tools","Automation"]
overview: 'Without allowed-tools in your skill frontmatter, Copilot CLI asks for permission before every single tool call. "Can I read this file? Can I run this command? Can I edit this?" It makes automation impossible. Add allowed-tools and the listed tools run automatically.'
codeLabel: "Before vs after"
screenshot: null
week: 3
weekLabel: "Context — The Secret Sauce"
order: 14
slackText: |
  🤖 Agentic AI Tip #14 — allowed-tools: Kill the Permission Spam
  
  If you've used Copilot CLI and felt like you were clicking "Yes" every 3 seconds, this tip is for you.
  
  By default, Copilot CLI asks permission before every tool call:
  "May I read this file?" → Yes
  "May I run this command?" → Yes
  "May I edit this file?" → Yes
  
  For a skill that reads 5 files, runs a build, and edits 3 files, that's *13 permission prompts*. It completely breaks the flow.
  
  *The fix:* Add `allowed-tools` to your skill's frontmatter:
  ```yaml
  ---
  allowed-tools: [read, edit, bash, grep, glob]
  ---
  ```
  
  Listed tools run automatically — no prompts. Unlisted tools still ask.
  
  *Be intentional about what you allow:*
  • `read, grep, glob` — safe for research skills
  • `+ edit, write` — for skills that modify code
  • `+ bash` — for skills that run commands
  • `+ mcp` — for skills that use MCP servers
  
  Claude Code has its own permission system (`acceptEdits` mode), but `allowed-tools` works in both tools.
  
  💡 Try it: Add `allowed-tools: [read, grep, glob]` to an existing skill and re-run it. Feel the difference.
  
  #AgenticAI #Day14
---

```
# Without allowed-tools:
# "May I read package.json?" [Y/n]
# "May I run npm test?" [Y/n]
# "May I edit src/index.js?" [Y/n]
# 😤

# With allowed-tools:
---
allowed-tools: [read, edit, bash, grep]
---
# Tools run automatically ✓
```
