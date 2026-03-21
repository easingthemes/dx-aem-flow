---
title: "The Dual Frontmatter Trap"
category: "Skills — Advanced"
focus: "Claude Code · CLI"
tags: ["paths","applyTo","Gotcha"]
overview: "Rules files need BOTH paths: (for Claude Code) and applyTo: (for Copilot CLI) in their frontmatter. If you only add one, the rule silently doesn't load in the other tool. No error, no warning — just missing context."
codeLabel: "The trap and the fix"
screenshot: null
week: 5
weekLabel: "Skills — Recipe Book"
order: 21
slackText: |
  🤖 Agentic AI Tip #21 — The Dual Frontmatter Trap
  
  This silent bug has cost teams hours of debugging: rules that work in one AI tool but not the other.
  
  *The problem:*
  Claude Code reads `paths:` from rule frontmatter.
  Copilot CLI reads `applyTo:`.
  They ignore each other's field.
  
  ```yaml
  # ❌ Only loads in Claude Code
  ---
  paths: ["**/*.scss"]
  ---
  
  # ❌ Only loads in Copilot CLI
  ---
  applyTo: "**/*.scss"
  ---
  
  # ✅ Loads in both
  ---
  paths: ["**/*.scss"]
  applyTo: "**/*.scss"
  ---
  ```
  
  *Why this is dangerous:*
  There's no error message. No warning. The rule just... doesn't load. You think the AI is ignoring your conventions, but actually it never received them.
  
  *The fix:* Always include BOTH fields. Yes, it's redundant. Yes, it's annoying. But it's the only way to ensure rules work across both tools.
  
  *Pro tip:* If you're building skills for a team, add a validation script that checks all rule files for dual frontmatter. We caught 12 missing fields this way.
  
  💡 Try it: Grep your `.claude/rules/` directory for files that have `paths:` but not `applyTo:`. Fix them now.
  
  #AgenticAI #Day21
---

```
# ❌ Only works in Claude Code
---
paths: ["**/*.scss"]
---

# ❌ Only works in Copilot CLI
---
applyTo: "**/*.scss"
---

# ✅ Works in both tools
---
paths: ["**/*.scss"]
applyTo: "**/*.scss"
---
```
