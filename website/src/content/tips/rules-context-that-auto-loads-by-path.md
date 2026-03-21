---
title: "Rules: Context That Auto-Loads by Path"
category: "Context — The Secret Sauce"
focus: "Claude Code · CLI"
tags: [".claude/rules/","Path-Scoped","Auto-Load"]
overview: "Rules are markdown files that load automatically when you work on matching files. A SCSS rule only loads for .scss files. A JavaScript rule only loads for .js files. This keeps context relevant and prevents noise from unrelated conventions."
codeLabel: "Path-scoped rule"
screenshot: null
week: 2
weekLabel: "Meet Your AI Tools"
order: 10
slackText: |
  🤖 Agentic AI Tip #10 — Rules: Context That Auto-Loads by Path
  
  CLAUDE.md is global — loaded every session. But some conventions only apply to specific file types. That's what rules are for.
  
  *How rules work:*
  Put a markdown file in `.claude/rules/` with path patterns in the frontmatter. When you work on a matching file, the rule auto-loads into context.
  
  Example: A SCSS rule that only activates for stylesheets:
  ```
  ---
  paths: ["**/*.scss"]
  ---
  Use node-sass syntax. Variables in _variables.scss.
  Mobile-first breakpoints. Never use !important.
  ```
  
  *Why this matters:*
  Without path-scoped rules, you'd dump every convention into CLAUDE.md. JavaScript conventions would pollute SCSS sessions. AEM backend rules would confuse frontend work.
  
  *Real-world example from our project:*
  We have separate rules for JavaScript (ESLint Airbnb), SCSS (node-sass, sass-lint), accessibility (WCAG 2.1 AA), and naming conventions. Each only loads when relevant.
  
  *Dual frontmatter gotcha:* For Copilot CLI, you also need `applyTo:` in the YAML. Without it, the rule only works in Claude Code.
  
  💡 Try it: Create a rule for your most common file type. Add 3-5 conventions. Watch the AI follow them automatically.
  
  #AgenticAI #Day10
---

```
# .claude/rules/fe-styles.md
---
paths: ["**/*.scss"]
applyTo: "**/*.scss"
---

Use node-sass syntax (not dart-sass).
Variables in _variables.scss partial.
Mobile-first breakpoints.
Never use !important.
```
