---
title: "Model Selection: More Models Than You Think"
category: "Meet Your AI Tools"
focus: "All Tools"
tags: ["Opus $$$","Sonnet $$","Haiku $","Multi-Model"]
overview: "Claude Code uses Anthropic models (Opus/Sonnet/Haiku). Copilot CLI and VSCode Chat support Claude, GPT, AND Gemini — switch mid-session with /model. Each model family has strengths. Copilot agents support model fallback chains: model: [claude-sonnet, gpt-4o] — if one fails, try the next."
screenshot: null
week: 2
weekLabel: "Meet Your AI Tools"
order: 6
slackOneLiner: "🤖 Tip #6 — Which tool you use determines your model options. Claude Code = Anthropic only. Copilot = Claude + GPT + Gemini. Tier wisely."
keyPointsTitle: "The Model Landscape"
keyPoints:
  - "The model landscape is wider than you think — which tool you use determines your options."
  - |
    Claude Code — Anthropic models only
    - Opus ($$$): deep reasoning, architecture, code review (1M context)
    - Sonnet ($$): everyday coding, PR review, implementation
    - Haiku ($): fast lookups, file search, simple transforms
    - Switch with /model or /fast for Sonnet quick-mode
  - |
    Copilot CLI & VSCode Chat — multi-model
    - Claude Sonnet 4.6, Claude Haiku 4.5
    - GPT-4o, GPT-5.3-Codex
    - Gemini 2.5 Pro, Gemini 3 Pro
    - Switch mid-session with /model — each model family has strengths
  - "Copilot agent fallback chains — specify `model: [claude-sonnet-4, gpt-4o]` in agent config. If Claude is down, fall back to GPT automatically. Claude Code doesn't support this."
actionItemsTitle: "Tier Wisely, Save 10x"
actionItems:
  - "The tiering principle — use the cheapest model that can do the job. Our 13 agents use 3 tiers: 1 Opus agent (code review), 8 Sonnet agents (execution), 4 Haiku agents (lookups). This saves 10x vs using Opus for everything."
  - |
    Match model to task
    - Deep reasoning/architecture → Opus
    - Everyday coding/implementation → Sonnet
    - Fast lookups/simple transforms → Haiku
  - "In Copilot CLI, run /model to see all available models — try the same prompt with Claude and GPT to compare approaches"
  - "Review your agent definitions and ensure each uses the cheapest model tier that produces good results"
---
