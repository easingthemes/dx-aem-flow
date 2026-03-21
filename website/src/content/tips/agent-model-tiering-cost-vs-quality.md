---
title: "Agent Model Tiering: Cost vs Quality"
category: "Agents — AI Personas"
focus: "Claude Code"
tags: ["Opus","Sonnet","Haiku","Cost"]
overview: "Every agent gets exactly the model it needs — no more, no less. Our code reviewer uses Opus ($15/M tokens) because judgment quality matters. Our step executor uses Sonnet ($3/M tokens) for implementation. Our file resolver uses Haiku ($0.25/M tokens) for speed. Wrong tier = wasted money or poor quality."
codeLabel: "Our model distribution"
screenshot: null
week: 5
weekLabel: "Skills — Recipe Book"
order: 23
slackText: |
  🤖 Agentic AI Tip #23 — Agent Model Tiering: Cost vs Quality
  
  We run 13 agents across 3 plugins. Only ONE uses Opus. Here's why.
  
  *Opus ($15/M tokens) — 1 agent:*
  `dx-code-reviewer` — Reviews code with confidence scoring. Needs deep reasoning to distinguish real bugs from style preferences. Worth the cost because a bad review wastes more human time than the tokens cost.
  
  *Sonnet ($3/M tokens) — 8 agents:*
  `dx-pr-reviewer`, `dx-step-executor`, `aem-inspector`, etc. — These need good judgment AND they need to take actions (read files, run commands, edit code). Sonnet is the sweet spot.
  
  *Haiku ($0.25/M tokens) — 4 agents:*
  `dx-file-resolver`, `dx-doc-searcher`, `aem-file-resolver`, `aem-page-finder` — Pure lookups. "Find files matching this pattern." No reasoning needed, just fast execution.
  
  *The math:*
  If a pipeline spawns all 13 agents, using Opus for all of them costs ~60x more than our tiered approach. For a team running 50 pipelines/day, that's the difference between $500/month and $30,000/month.
  
  💡 Try it: Review your agent definitions. Is any agent using a model tier higher than it needs?
  
  #AgenticAI #Day23
---

```
# 13 agents across 3 plugins:
# Opus (1):  dx-code-reviewer
# Sonnet (8): dx-pr-reviewer,
#   dx-step-executor, aem-inspector,
#   aem-demo-capture, aem-bug-executor,
#   dx-figma-markup, dx-figma-styles
# Haiku (4):  dx-file-resolver,
#   dx-doc-searcher, aem-file-resolver,
#   aem-page-finder
```
