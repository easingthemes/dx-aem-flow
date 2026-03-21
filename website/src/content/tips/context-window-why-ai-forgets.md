---
title: 'Context Window: Why AI "Forgets"'
category: "Context — The Secret Sauce"
focus: "All Tools"
tags: ["1M Tokens","200K Tokens","Fresh Sessions"]
overview: "AI models have a fixed context window — Opus holds 1M tokens, Sonnet 200K. When your conversation exceeds this, older messages get compressed or dropped. This is why long sessions degrade. Start fresh for new tasks. Don't try to do everything in one conversation."
codeLabel: ""
screenshot: null
week: 3
weekLabel: "Context — The Secret Sauce"
order: 11
slackText: |
  🤖 Agentic AI Tip #11 — Context Window: Why AI "Forgets"
  
  Ever notice the AI gets confused late in a long session? It's not a bug — it's a fundamental constraint.
  
  *Context windows:*
  • Opus: ~1M tokens (~750K words)
  • Sonnet: ~200K tokens (~150K words)
  • GPT-4: ~128K tokens (~95K words)
  
  When your conversation fills the window, older messages get compressed or dropped. The AI literally can't see them anymore.
  
  *Symptoms of context overflow:*
  • AI repeats work it already did
  • AI "forgets" decisions you agreed on
  • AI contradicts its earlier responses
  • Code quality degrades as the session goes on
  
  *How to manage it:*
  1. *Start fresh* for new tasks — don't chain unrelated work in one session
  2. *Use subagents* for expensive operations — they get their own context
  3. *Put conventions in CLAUDE.md* — re-loaded automatically, never forgotten
  4. *Use the /compact command* in Claude Code — it summarizes and frees space (but loses nuance)
  
  The mental model: context window = short-term memory. CLAUDE.md = long-term memory. Write down what matters.
  
  💡 Try it: Check Claude Code's token usage display. Start a new session when you switch to a different task.
  
  #AgenticAI #Day11
---

