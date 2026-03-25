---
title: 'Context Window: Why AI "Forgets"'
category: "Context — The Secret Sauce"
focus: "All Tools"
tags: ["1M Tokens","200K Tokens","Fresh Sessions"]
overview: "AI models have a fixed context window — Opus holds 1M tokens, Sonnet 200K. When your conversation exceeds this, older messages get compressed or dropped. This is why long sessions degrade. Start fresh for new tasks. Don't try to do everything in one conversation."
screenshot: null
week: 3
weekLabel: "Context — The Secret Sauce"
order: 11
slackOneLiner: "🤖 Tip #11 — AI gets confused late in long sessions because it literally can't see older messages anymore. Start fresh for new tasks."
keyPointsTitle: "How Context Windows Work"
keyPoints:
  - |
    Context window sizes
    - Opus: ~1M tokens (~750K words)
    - Sonnet: ~200K tokens (~150K words)
    - GPT-4: ~128K tokens (~95K words)
  - "When your conversation fills the window, older messages get compressed or dropped — the AI literally can't see them anymore."
  - |
    Symptoms of context overflow
    - AI repeats work it already did
    - AI 'forgets' decisions you agreed on
    - AI contradicts its earlier responses
    - Code quality degrades as the session goes on
  - "The mental model — context window = short-term memory. CLAUDE.md = long-term memory. Write down what matters."
actionItemsTitle: "How to Manage It"
actionItems:
  - |
    Prevention strategies
    - Start fresh for new tasks — don't chain unrelated work in one session
    - Use subagents for expensive operations — they get their own context
    - Put conventions in CLAUDE.md — re-loaded automatically, never forgotten
    - Use the /compact command in Claude Code — it summarizes and frees space (but loses nuance)
  - "Check Claude Code's token usage display — start a new session when you switch to a different task"
  - "Move important conventions and decisions into CLAUDE.md so they survive across sessions"
  - "Use /compact when a session gets long but you're not ready to start fresh — it summarizes and frees space"
---
