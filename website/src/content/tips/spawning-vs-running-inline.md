---
title: "Spawning vs Running Inline"
category: "Agents — AI Personas"
focus: "Claude Code"
tags: ["Spawn","Inline","Context Isolation"]
overview: "When you run a skill inline, it shares your context — everything in your conversation. When you spawn an agent, it gets its own isolated context. Spawned agents don't bloat your window. Their results come back as a summary. Use inline for simple tasks, spawned for heavy ones."
screenshot: null
week: 5
weekLabel: "Skills — Recipe Book"
order: 24
slackOneLiner: "🤖 Tip #24 — Inline execution shares your context; spawned agents get their own. Use inline for small tasks, spawned for heavy ones to keep your context clean."
keyPointsTitle: "Two Execution Modes"
actionItemsTitle: "When to Use Which"
keyPoints:
  - "**Inline execution** — The AI runs the task in your current conversation. Everything it reads, every file it analyzes, stays in your context window. Good for small tasks. Bad for large ones — context fills up and quality degrades."
  - "**Spawned agent** — The AI creates a new subprocess with its own context window. It does its work, then returns a summary to you. Your context stays clean and focused."
  - "**Hidden benefit — model tier mixing** — Spawned agents can use a different model tier. Your main session runs on Opus for deep reasoning, but the spawned file searcher uses Haiku for cost efficiency. Mixed tiers in one workflow."
actionItems:
  - |
    Choose execution mode by task weight
    - **Inline** → quick questions, small edits, simple searches
    - **Spawned** → code review, implementation, research, multi-file analysis
  - "**Try the difference** — Next time you ask AI to 'find all usages of X,' notice how your context grows. Then try spawning an Explore agent instead to keep your context clean."
  - "**Configure model tiers** — Set spawned agents to appropriate tiers: Haiku for file search, Sonnet for implementation, Opus for review. Match cost to complexity."
---
