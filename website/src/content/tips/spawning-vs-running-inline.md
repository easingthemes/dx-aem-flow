---
title: "Spawning vs Running Inline"
category: "Agents — AI Personas"
focus: "Claude Code"
tags: ["Spawn","Inline","Context Isolation"]
overview: "When you run a skill inline, it shares your context — everything in your conversation. When you spawn an agent, it gets its own isolated context. Spawned agents don't bloat your window. Their results come back as a summary. Use inline for simple tasks, spawned for heavy ones."
codeLabel: "The difference"
screenshot: null
week: 5
weekLabel: "Skills — Recipe Book"
order: 24
slackText: |
  🤖 Agentic AI Tip #24 — Spawning vs Running Inline
  
  This is a key concept that affects both quality and cost.
  
  *Inline execution:*
  The AI runs the task in your current conversation. Everything it reads, every file it analyzes, stays in your context window. Good for small tasks. Bad for large ones — your context fills up and quality degrades.
  
  *Spawned agent:*
  The AI creates a new subprocess with its own context window. It does its work, then returns a summary to you. Your context stays clean.
  
  *When to use which:*
  
  Inline (simple, fast):
  • "What does this function do?"
  • "Add a null check here"
  • Quick searches, small edits
  
  Spawned (heavy, isolated):
  • Code review (reads many files)
  • Implementation (lots of edits)
  • Research (explores entire codebase)
  • Anything that generates lots of output
  
  *The hidden benefit:*
  Spawned agents can use a different model tier. Your main session runs on Opus, but the spawned file searcher uses Haiku. Mixed tiers in one workflow.
  
  💡 Try it: Next time you ask the AI to "find all usages of X," notice how your context grows. Try spawning an Explore agent instead — your context stays clean.
  
  #AgenticAI #Day24
---

```
# Inline — shares your context
"Read auth.js and explain it"
# Context grows, everything stays

# Spawned — isolated context
Agent tool → dx-code-reviewer
  prompt: "Review the auth module"
# Gets own context, returns summary
# YOUR context stays clean
```
