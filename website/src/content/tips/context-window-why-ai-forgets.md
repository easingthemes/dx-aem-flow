---
title: 'Context Window: Why AI "Forgets"'
category: "Context — The Secret Sauce"
focus: "All Tools"
tags: ["1M Tokens","200K Tokens","Fresh Sessions"]
overview: "Every AI model has a fixed context window — Claude Opus holds ~1M tokens, GPT-5.x models ~128K–200K, Gemini 2.5 Pro ~1M. When your conversation exceeds this, older messages get compressed or dropped. This is why long sessions degrade. Start fresh for new tasks. Don't try to do everything in one conversation."
screenshot: null
week: 3
weekLabel: "Context — The Secret Sauce"
order: 11
slackOneLiner: "🤖 Tip #11 — AI gets confused late in long sessions because it literally can't see older messages anymore. Start fresh for new tasks."
keyPointsTitle: "How Context Windows Work"
keyPoints:
  - |
    Context window sizes vary by model
    - Claude Opus: ~1M tokens (~750K words)
    - Claude Sonnet: ~200K tokens (~150K words)
    - GPT-5.x models: ~128K–200K tokens depending on variant
    - Gemini 2.5 Pro: ~1M tokens
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
    - Compact your context when sessions get long — it summarizes and frees space (but loses nuance)
  - "Watch your token usage — start a new session when you switch to a different task"
  - "Move important conventions and decisions into CLAUDE.md so they survive across sessions"
  - "Compact context when a session gets long but you're not ready to start fresh — it summarizes and frees space"
---
