---
title: "The Dual Frontmatter Trap"
category: "Skills — Advanced"
focus: "Claude Code · CLI"
tags: ["paths","applyTo","Gotcha"]
overview: "Rules files need BOTH paths: (for Claude Code) and applyTo: (for Copilot CLI) in their frontmatter. If you only add one, the rule silently doesn't load in the other tool. No error, no warning — just missing context."
screenshot: null
week: 5
weekLabel: "Skills — Recipe Book"
order: 21
slackOneLiner: "🤖 Tip #21 — Rules that work in one AI tool but not the other? You're missing dual frontmatter. Claude Code reads `paths:`, Copilot CLI reads `applyTo:` — you need both."
keyPointsTitle: "The Silent Failure"
actionItemsTitle: "Fix and Prevent"
keyPoints:
  - "**The problem** — Claude Code reads `paths:` from rule frontmatter. Copilot CLI reads `applyTo:`. They ignore each other's field completely. A rule with only one field silently doesn't load in the other tool."
  - "**Why this is dangerous** — There's no error message, no warning. The rule just doesn't load. You think the AI is ignoring your conventions, but actually it never received them."
  - "**Silent failures waste hours** — Teams have spent hours debugging why the AI ignores their coding conventions, only to discover the rule file was missing one frontmatter field."
actionItems:
  - |
    Always use dual frontmatter in rule files
    - `paths: ["**/*.scss"]` — for Claude Code
    - `applyTo: "**/*.scss"` — for Copilot CLI
    - Both fields, same glob pattern, every rule file
  - "**Audit right now** — Grep your `.claude/rules/` directory for files that have `paths:` but not `applyTo:` (or vice versa). Fix them immediately."
  - "**Automate the check** — Add a CI check or validation script that flags rule files missing either `paths:` or `applyTo:`. We caught 12 missing fields this way. Prevent the trap from recurring."
---
