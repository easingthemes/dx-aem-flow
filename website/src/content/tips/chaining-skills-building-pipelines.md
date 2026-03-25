---
title: "Chaining Skills: Building Pipelines"
category: "Skills — Advanced"
focus: "Claude Code"
tags: ["Pipeline","Chaining","Workflow"]
overview: "Individual skills are building blocks. The real power comes from chaining them into pipelines. req → plan → execute → verify → PR. Each step reads the previous step's output. You can run the full pipeline or any individual step."
screenshot: null
week: 4
weekLabel: "Context — The Secret Sauce"
order: 20
slackOneLiner: "🤖 Tip #20 — Individual skills are useful. Chained into pipelines — req, plan, step, verify, PR — they're transformative."
keyPointsTitle: "The Pipeline Flow"
actionItemsTitle: "Choose Your Workflow"
keyPoints:
  - "**A real pipeline** — `/dx-req 12345` (full requirements) → `/dx-plan` (implementation plan) → `/dx-step` (execute step 1, 2, ...) → `/dx-step-verify` (6-phase verification) → `/dx-pr` (creates the pull request). Ticket to PR in one flow."
  - "**Modularity is intentional** — Each skill is independent. Want to code manually? Skip `/dx-step`, use `/dx-plan` as a guide. Already coded? Jump straight to `/dx-step-verify`. The pipeline is a suggestion, not a requirement."
  - "**File convention enables chaining** — Each skill writes to `.ai/specs/<id>/` and the next skill reads from the same location. No data passing needed, no APIs, no coupling between skills."
actionItems:
  - "**Start with three skills** — Pick a small ticket and run `/dx-req <id>`, then review the output before running `/dx-plan`, then `/dx-step`. Get comfortable with the flow before automating."
  - |
    Choose your workflow style
    - **Full automation** → `/dx-agent-all` for simple stories
    - **Guided** → Run each skill individually, review between steps
    - **Hybrid** → Use AI for requirements and planning, code manually, then `/dx-step-verify` and `/dx-pr`
  - "**The coordinator shortcut** — `/dx-agent-all` runs the entire pipeline as a single command using the coordinator pattern. Great for simple stories. Use individual steps for complex ones where you want to review each output."
  - "**Review early, save time** — Check each output in `.ai/specs/` before moving to the next step. Catching issues early saves re-work later."
---
