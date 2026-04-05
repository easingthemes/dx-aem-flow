---
title: "Agent Model Tiering: Cost vs Quality"
category: "Agents — AI Personas"
focus: "Claude Code"
tags: ["Opus","Sonnet","Haiku","Cost"]
overview: "Every agent gets exactly the model it needs — no more, no less. Our code reviewer uses Opus ($15/M tokens) because judgment quality matters. Our PR reviewer uses Sonnet ($3/M tokens) for implementation. Our file resolver uses Haiku ($0.25/M tokens) for speed. Wrong tier = wasted money or poor quality."
screenshot: null
week: 5
weekLabel: "Skills — Recipe Book"
order: 23
slackOneLiner: "🤖 Tip #23 — Only ONE of our agents uses Opus — model tiering cuts costs dramatically without sacrificing quality where it matters."
keyPointsTitle: "Three Tiers, Three Roles"
actionItemsTitle: "The Cost Math"
keyPoints:
  - "**Opus ($15/M tokens)** — `dx-code-reviewer` reviews code with confidence scoring. Needs deep reasoning to distinguish real bugs from style preferences. Worth the cost because a bad review wastes more human time than the tokens cost."
  - "**Sonnet ($3/M tokens)** — `dx-pr-reviewer`, `aem-inspector`, `aem-editorial-guide-capture`, `aem-bug-executor`, `aem-fe-verifier`. Need good judgment AND they take actions (read files, run commands, edit code). Sonnet is the sweet spot for execution."
  - "**Haiku ($0.25/M tokens)** — `dx-file-resolver`, `dx-doc-searcher`, `dx-figma-components`, `dx-figma-markup`, `dx-figma-styles`, `aem-file-resolver`, `aem-page-finder`. Pure lookups. 'Find files matching this pattern.' No reasoning needed, just fast execution."
actionItems:
  - "**The math** — Using Opus for all agents costs dramatically more than our tiered approach. For a team running pipelines daily, the savings are substantial."
  - |
    **Use this tiering guide**
    - Opus — deep reasoning, judgment calls, confidence scoring
    - Sonnet — implementation, actions, file editing, running commands
    - Haiku — lookups, file search, pattern matching, simple queries
  - "**Start cheap, upgrade when needed** — Begin with Haiku for new agents and upgrade only when quality isn't sufficient. It's easier to move up than to justify staying expensive."
  - "**Review your agents** — Check if any agent is using a model tier higher than it needs. A file-finder on Sonnet is burning 12x what it should cost."
---
