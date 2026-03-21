---
title: "Token Budgets and Cost Control"
category: "Mastery"
focus: "All Tools"
tags: ["Tokens","Cost","Budget"]
overview: "AI costs money. Opus costs 60x more than Haiku. A careless pipeline burning Opus tokens for simple lookups can cost $50/day. Track token usage, tier your models, and set budgets. Our autonomous agents have hard token caps per run."
codeLabel: "Cost comparison"
screenshot: null
week: 10
weekLabel: "Agents — AI Personas"
order: 48
slackText: |
  🤖 Agentic AI Tip #48 — Token Budgets and Cost Control
  
  AI tools aren't free, and costs can sneak up on you.
  
  *Token pricing (approximate per 1M tokens):*
  • Opus: $15 input / $75 output
  • Sonnet: $3 input / $15 output
  • Haiku: $0.25 input / $1.25 output
  
  *A typical pipeline run with tiered models:*
  4 Haiku lookups + 2 Sonnet implementations + 1 Opus review ≈ $2.50
  
  *The same pipeline all on Opus:*
  7 Opus calls ≈ $25+
  
  *That's 10x more for the same result.*
  
  *Cost control strategies:*
  1. *Tier your models* — don't use Opus for file searches
  2. *Set maxTurns on agents* — prevents runaway loops
  3. *Use pre-flight checks* — don't burn tokens on doomed pipelines
  4. *Start fresh sessions* — long conversations waste tokens on history
  5. *Use spawned agents* — isolated context instead of growing the main window
  
  *For autonomous agents (CI/CD):*
  We set hard token budgets per Lambda run. If an agent exceeds its budget, it stops and reports what it completed. Better to stop early than to bankrupt the team.
  
  💡 Try it: Check your AI spending for the last week. Identify the most expensive operations and consider if they could use a cheaper model.
  
  #AgenticAI #Day48
---

```
# Cost per 1M tokens (approximate):
# Opus:   $15 input / $75 output
# Sonnet: $3 input / $15 output
# Haiku:  $0.25 input / $1.25 output

# A single pipeline run:
# 4 Haiku lookups:    ~$0.02
# 2 Sonnet steps:     ~$0.50
# 1 Opus review:      ~$2.00
# Total:              ~$2.52

# vs all-Opus:        ~$25+
```
