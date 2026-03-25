---
title: "Three Levels of Autonomous AI: Review, Coding Agent, Pipeline"
category: "Real-World Workflows"
focus: "All Tools"
tags: ["PR Review","Coding Agent","Autonomous","CI/CD"]
overview: "Three levels of autonomous AI: (1) Our custom PR reviewer via ADO webhooks + Lambda — confidence-scored findings. (2) GitHub's Copilot coding agent — assign an issue, it creates a PR. (3) Our full automation pipeline — PR review + DoD checks + bug fixes running 24/7. Each level adds autonomy and risk."
screenshot: null
week: 9
weekLabel: "Agents — AI Personas"
order: 44
slackOneLiner: "🤖 Tip #44 — Autonomous AI isn't binary — three levels from read-only PR review to full 24/7 automation pipeline."
keyPointsTitle: "Three Autonomy Levels"
actionItemsTitle: "Choosing Your Level"
keyPoints:
  - "**Level 1 — Autonomous PR Review** — ADO webhook triggers Lambda, AI analyzes the diff and posts structured comments with confidence scoring (>=90% MUST-FIX, >=80% SUGGESTION, <80% skip). Includes fix patches the author can accept with one click. Cost ~$0.15-0.50 per review."
  - "**Level 2 — Copilot Coding Agent** — Assign a GitHub issue to Copilot, it spins up a GitHub Actions environment, creates a branch, writes code, runs tests, and opens a draft PR. Reads both AGENTS.md and CLAUDE.md for context. Supports custom .agent.md agents and MCP servers."
  - "**Level 3 — Full Automation Pipeline** — ADO webhook triggers work item router, selects the right agent, runs complete workflow: DoR validation, dev implementation, 6-phase verification, PR creation, AI review. Runs 24/7 on AWS Lambda with token budgets and dead letter queues."
actionItems:
  - |
    **Start with Level 1** — It's read-only (low risk) and high-value (instant feedback on every PR)
    - No code changes, just structured review comments
    - Confidence scoring filters noise automatically
    - Cheapest to run, easiest to trust
  - |
    **Match level to team trust**
    - Level 1 → read-only review, no code changes
    - Level 2 → code changes but human merges the PR
    - Level 3 → full autonomy with guardrails
  - |
    **Safety controls for Levels 2-3**
    - Token budgets per run prevent runaway costs
    - Capability gating limits what each project allows
    - Dead letter queue catches failed jobs for human review
    - Set up alerting before enabling any autonomous code generation
---
