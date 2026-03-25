---
title: "Model Selection: More Models Than You Think"
category: "Meet Your AI Tools"
focus: "All Tools"
tags: ["Opus $$$","Sonnet $$","Haiku $","Multi-Model"]
overview: "Claude Code uses Anthropic models (Opus/Sonnet/Haiku). Copilot CLI and VS Code Chat support Claude, GPT-5.x, Gemini, Grok, and fine-tuned models — switch mid-session with /model. Each model family has strengths. Copilot agents support model fallback chains: model: [claude-sonnet-4-6, gpt-5.4] — if one fails, try the next."
screenshot: null
week: 2
weekLabel: "Meet Your AI Tools"
order: 6
slackOneLiner: "🤖 Tip #6 — Which tool you use determines your model options. Claude Code = Anthropic only. Copilot = Claude + GPT-5.x + Gemini + Grok. Tier wisely."
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
    - Anthropic: Claude Opus 4.6, Sonnet 4.6, Haiku 4.5
    - OpenAI: GPT-5.4, GPT-5.3-Codex, GPT-5.2, GPT-5.1-Codex, GPT-5 mini
    - Google: Gemini 2.5 Pro, Gemini 3.1 Pro, Gemini 3 Flash
    - xAI: Grok Code Fast 1
    - Fine-tuned: Raptor mini, Goldeneye
    - Switch mid-session with /model — each model family has strengths
  - "Copilot agent fallback chains — specify `model: [claude-sonnet-4-6, gpt-5.4]` in agent config. If Claude is down, fall back to GPT automatically. Claude Code doesn't support this."
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
