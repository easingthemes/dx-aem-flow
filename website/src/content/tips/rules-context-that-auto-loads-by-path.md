---
title: "Rules: Context That Auto-Loads by Path"
category: "Context — The Secret Sauce"
focus: "Claude Code · CLI"
tags: [".claude/rules/","Path-Scoped","Auto-Load"]
overview: "Rules are markdown files that load automatically when you work on matching files. A SCSS rule only loads for .scss files. A JavaScript rule only loads for .js files. This keeps context relevant and prevents noise from unrelated conventions."
screenshot: null
week: 2
weekLabel: "Meet Your AI Tools"
order: 10
slackOneLiner: "🤖 Tip #10 — Rules auto-load by file path — SCSS conventions only appear for .scss files. Targeted context, zero noise."
keyPointsTitle: "How Path-Scoped Rules Work"
actionItemsTitle: "Creating Effective Rules"
keyPoints:
  - "Rules are markdown files in `.claude/rules/` with path patterns in the frontmatter — when you work on a matching file, the rule auto-loads into context."
  - "**Global vs. scoped** — CLAUDE.md is global (loaded every session), but rules are path-scoped. JavaScript conventions don't pollute SCSS sessions, AEM backend rules don't confuse frontend work."
  - |
    Real-world example — separate rules for each concern
    - JavaScript (ESLint Airbnb conventions)
    - SCSS (node-sass, sass-lint)
    - Accessibility (WCAG 2.1 AA)
    - Naming conventions
    - Each only loads when relevant
actionItems:
  - "**Dual frontmatter gotcha** — for Copilot CLI, you also need `applyTo:` in the YAML. Without it, the rule only works in Claude Code. Use both `paths:` and `applyTo:` for cross-platform compatibility."
  - "Create a rule for your most common file type — add 3-5 conventions and watch the AI follow them automatically"
  - |
    Always include dual frontmatter for cross-platform support
    - `paths: ["**/*.scss"]` — Claude Code
    - `applyTo: "**/*.scss"` — Copilot CLI
  - "Keep rules focused — one topic per file. A 'styles' rule, a 'testing' rule, a 'naming' rule. Easier to maintain and debug."
---
