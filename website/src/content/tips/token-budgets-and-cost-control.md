---
title: "Token Budgets and Cost Control"
category: "Mastery"
focus: "All Tools"
tags: ["Tokens","Cost","Budget"]
overview: "AI costs money. Opus costs 60x more than Haiku. A careless pipeline burning Opus tokens for simple lookups can cost $50/day. Track token usage, tier your models, and set budgets. Our autonomous agents have hard token caps per run."
screenshot: null
week: 10
weekLabel: "Agents — AI Personas"
order: 48
slackOneLiner: "🤖 Tip #48 — AI tools aren't free. A tiered pipeline costs ~$2.50 per run; the same pipeline all-Opus costs $25+. Tier your models."
keyPointsTitle: "What AI Actually Costs"
keyPoints:
  - |
    Token pricing (approximate per 1M tokens)
    - Opus: $15 input / $75 output
    - Sonnet: $3 input / $15 output
    - Haiku: $0.25 input / $1.25 output
  - "A tiered pipeline run — 4 Haiku lookups + 2 Sonnet implementations + 1 Opus review = ~$2.50. The same pipeline all on Opus = $25+. That's 10x more for the same result."
  - "Autonomous agents (CI/CD) — we set hard token budgets per Lambda run. If an agent exceeds its budget, it stops and reports what it completed. Better to stop early than to bankrupt the team."
actionItemsTitle: "How to Control Costs"
actionItems:
  - |
    Cost control strategies
    - Tier your models — don't use Opus for file searches
    - Set maxTurns on agents — prevents runaway loops
    - Use pre-flight checks — don't burn tokens on doomed pipelines
    - Start fresh sessions — long conversations waste tokens on history
    - Use spawned agents — isolated context instead of growing the main window
  - |
    Apply the tiering principle to your pipeline
    - Lookups and file search → Haiku ($)
    - Implementation and execution → Sonnet ($$)
    - Code review and architecture → Opus ($$$)
  - "Check your AI spending for the last week — identify the most expensive operations and consider if they could use a cheaper model"
  - "Set maxTurns on all your agents to prevent runaway token consumption from infinite loops"
---
