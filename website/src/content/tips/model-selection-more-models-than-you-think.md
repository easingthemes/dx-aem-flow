---
title: "Model Selection: More Models Than You Think"
category: "Meet Your AI Tools"
focus: "All Tools"
tags: ["Opus $$$","Sonnet $$","Haiku $","Multi-Model"]
overview: "Claude Code uses Anthropic models (Opus/Sonnet/Haiku). Copilot CLI and VSCode Chat support Claude, GPT, AND Gemini — switch mid-session with /model. Each model family has strengths. Copilot agents support model fallback chains: model: [claude-sonnet, gpt-4o] — if one fails, try the next."
codeLabel: "Model options"
screenshot: null
week: 2
weekLabel: "Meet Your AI Tools"
order: 6
slackText: |
  🤖 Agentic AI Tip #6 — Model Selection: More Models Than You Think
  
  The model landscape is wider than you think — and *which tool you use* determines your options.
  
  *Claude Code — Anthropic models:*
  • Opus ($$$): deep reasoning, architecture, code review (1M context)
  • Sonnet ($$): everyday coding, PR review, implementation
  • Haiku ($): fast lookups, file search, simple transforms
  Switch with `/model` or `/fast` for Sonnet quick-mode.
  
  *Copilot CLI & VSCode Chat — multi-model:*
  • Claude Sonnet 4.6, Claude Haiku 4.5
  • GPT-4o, GPT-5.3-Codex
  • Gemini 2.5 Pro, Gemini 3 Pro
  Switch mid-session with `/model`. Each model family has strengths.
  
  *Copilot agent fallback chains:*
  ```yaml
  model: [claude-sonnet-4, gpt-4o]
  ```
  If Claude is down, fall back to GPT automatically. Claude Code doesn't support this.
  
  *The tiering principle still applies:*
  Use the cheapest model that can do the job. Our 13 agents use 3 tiers: 1 Opus agent (code review), 8 Sonnet agents (execution), 4 Haiku agents (lookups). This saves 10x vs using Opus for everything.
  
  💡 Try it: In Copilot CLI, run `/model` to see all available models. Try the same prompt with Claude and GPT — compare the approaches.
  
  #AgenticAI #Day6
---

```
# Claude Code — Anthropic only
/model opus    # deep reasoning
/model sonnet  # everyday coding
/model haiku   # fast lookups

# Copilot CLI — multi-model
/model claude-sonnet-4
/model gpt-4o
/model gemini-2.5-pro

# Copilot agent fallback chain:
# model: [claude-sonnet, gpt-4o]
```
