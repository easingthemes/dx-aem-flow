---
title: "SessionStart: Validate on Every Launch"
category: "Hooks — Guardrails"
focus: "Claude Code"
tags: ["SessionStart","Validation","Environment"]
overview: "SessionStart hooks fire once when you start a Claude Code session. They're perfect for environment validation: check Node version, verify MCP servers are reachable, validate config files. Catch problems in the first 2 seconds instead of 20 minutes into a failed pipeline."
screenshot: null
week: 7
weekLabel: "Skills — Advanced"
order: 35
slackOneLiner: "🤖 Tip #35 — SessionStart hooks validate your environment the moment you start a session. Catch problems in 2 seconds, not 15 minutes."
keyPointsTitle: "What to Validate"
actionItemsTitle: "Setup & Best Practices"
keyPoints:
  - "SessionStart fires once when a session begins — validate everything upfront so environment issues don't surface as mysterious failures deep in a workflow."
  - |
    What to check in a SessionStart hook
    - **Node version** — our project needs v10, not v18
    - **MCP server connectivity** — can we reach AEM? Figma? ADO?
    - **Config files** — does `.ai/config.yaml` exist and have required fields?
    - **Git state** — are you on a feature branch? Any uncommitted changes?
    - **Dependencies** — is `node_modules/` present?
  - "The output appears as a banner with status indicators — you see the state of your world before typing the first command."
actionItems:
  - "**Matcher is empty** — `\"matcher\": \"\"` means 'always fire.' SessionStart doesn't match tools, it matches session creation."
  - "Create a SessionStart hook that checks your Node version — just that one check. You'll be surprised how often you're on the wrong version."
  - "Add MCP connectivity checks next — a lightweight call to each server catches 'connection refused' before you burn tokens"
  - "Keep SessionStart hooks fast (under 3 seconds) — they run on every session start and slow hooks delay your first prompt"
---
