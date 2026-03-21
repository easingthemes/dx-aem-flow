---
title: "Three Levels of Autonomous AI: Review, Coding Agent, Pipeline"
category: "Real-World Workflows"
focus: "All Tools"
tags: ["PR Review","Coding Agent","Autonomous","CI/CD"]
overview: "Three levels of autonomous AI: (1) Our custom PR reviewer via ADO webhooks + Lambda — confidence-scored findings. (2) GitHub's Copilot coding agent — assign an issue, it creates a PR. (3) Our full automation pipeline — PR review + DoD checks + bug fixes running 24/7. Each level adds autonomy and risk."
codeLabel: "Three autonomy levels"
screenshot: null
week: 9
weekLabel: "Agents — AI Personas"
order: 44
slackText: |
  🤖 Agentic AI Tip #44 — Three Levels of Autonomous AI
  
  Autonomous AI isn't binary — there are levels. Here's how we've structured ours:
  
  *Level 1: Autonomous PR Review*
  ADO webhook triggers Lambda → AI analyzes diff → posts structured comments.
  • Confidence scoring: ≥90% = MUST-FIX, ≥80% = SUGGESTION, <80% = skip
  • Includes fix patches — author can accept with one click
  • Cost: ~$0.15-0.50 per review (Sonnet tier)
  
  *Level 2: Copilot Coding Agent (GitHub)*
  Assign a GitHub issue to Copilot → it spins up a GitHub Actions environment, creates a branch, writes code, runs tests, opens a draft PR.
  • Reads AGENTS.md AND CLAUDE.md for project context
  • Supports custom .agent.md agents and MCP servers
  • Available on: Pro, Pro+, Business, Enterprise plans
  
  *Level 3: Full Automation Pipeline (ours)*
  ADO webhook → work item router → agent selection → complete workflow.
  DoR validation → Dev implementation → 6-phase verification → PR creation → AI review.
  • Runs 24/7 on AWS Lambda
  • Token budgets per run (prevent runaway costs)
  • Dead letter queue for failed jobs
  • Capability gating per project
  
  Each level adds autonomy — and risk. Start with Level 1 (review only), graduate to Level 3 once you trust the system.
  
  💡 Try it: Start with AI PR review. It's low-risk (read-only) and high-value (instant feedback on every PR).
  
  #AgenticAI #Day44
---

```
# Level 1: Autonomous PR Review
# ADO webhook → Lambda → AI review
# Posts comments with ≥80% confidence

# Level 2: Copilot Coding Agent
# Assign GitHub issue to Copilot
# → Spins up Actions environment
# → Writes code, runs tests
# → Opens draft PR

# Level 3: Full Automation Pipeline
# Webhook → Router → Agent selection
# DoR check → Dev → Verify → PR → Review
# Running 24/7 on Lambda
```
