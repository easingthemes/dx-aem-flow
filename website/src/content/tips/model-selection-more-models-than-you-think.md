---
title: "Model Selection: More Models Than You Think"
category: "Meet Your AI Tools"
focus: "All Tools"
tags: ["Opus $$$","Sonnet $$","Haiku $","Multi-Model"]
overview: "Claude Code uses Anthropic models (Opus/Sonnet/Haiku). Copilot CLI and VS Code Chat support Claude, GPT, Gemini and more — switch mid-session with /model. Each model family has strengths. Copilot agents support model fallback chains: model: [claude-opus-5.5, claude-sonnet-5.5] — if one fails, try the next."
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
    Copilot CLI & VS Code Chat — multi-provider
    - Anthropic: Claude Opus 5.5, Sonnet 5.5, Haiku 5.5
    - OpenAI: GPT-6.1 Sol, GPT-6 Astra, GPT-6 Luna
    - Google: Gemini 4 Argon
    - The list changes monthly — models get added and retired, so check /model rather than memorizing it (as of Oct 2026)
    - Switch mid-session with /model — each model family has strengths
  - "Copilot agent fallback chains — specify `model: [claude-opus-5.5, claude-sonnet-5.5]` in agent config. If the first is unavailable, the next one is used — and the chain can mix providers. Claude Code doesn't support this."
actionItemsTitle: "Tier Wisely, Save 10x"
actionItems:
  - "The tiering principle — use the cheapest model that can do the job. Our agents use 3 tiers: Opus (code review), Sonnet (execution), Haiku (lookups). This saves 10x vs using Opus for everything."
  - |
    Match model to task
    - Deep reasoning/architecture → Opus
    - Everyday coding/implementation → Sonnet
    - Fast lookups/simple transforms → Haiku
  - "In Copilot CLI, run /model to see all available models — try the same prompt with Claude and GPT to compare approaches"
  - "Review your agent definitions and ensure each uses the cheapest model tier that produces good results"
---
