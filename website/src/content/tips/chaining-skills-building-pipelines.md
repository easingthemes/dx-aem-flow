---
title: "Chaining Skills: Building Pipelines"
category: "Skills — Advanced"
focus: "Claude Code"
tags: ["Pipeline","Chaining","Workflow"]
overview: "Individual skills are building blocks. The real power comes from chaining them into pipelines. fetch → explain → research → plan → execute → verify → PR. Each step reads the previous step's output. You can run the full pipeline or any individual step."
codeLabel: "Complete pipeline"
screenshot: null
week: 4
weekLabel: "Context — The Secret Sauce"
order: 20
slackText: |
  🤖 Agentic AI Tip #20 — Chaining Skills: Building Pipelines
  
  Individual skills are useful. Chained skills are transformative.
  
  Here's a real pipeline that takes a ticket from ADO to a pull request:
  
  ```
  /dx-req-fetch 12345     → fetches the story
  /dx-req-explain         → distills dev requirements
  /dx-req-research        → finds affected files
  /dx-plan                → generates implementation plan
  /dx-step                → executes step 1
  /dx-step                → executes step 2...
  /dx-step-verify         → 6-phase verification
  /dx-pr                  → creates the pull request
  ```
  
  *Key insight:* You don't have to run the full pipeline. Each skill is independent:
  • Already know the requirements? Skip `/dx-req-explain`
  • Want to code manually? Skip `/dx-step`, just use `/dx-plan` as a guide
  • Already coded? Jump straight to `/dx-step-verify`
  
  This modularity is intentional. The pipeline is a *suggestion*, not a requirement. Use what helps, skip what doesn't.
  
  *The coordinator version:* `/dx-agent-all` runs the entire pipeline as a single command using the coordinator pattern. Great for simple stories. Use individual steps for complex ones.
  
  💡 Try it: Pick a small ticket and run the first three skills: fetch, explain, research. Review each output before moving forward.
  
  #AgenticAI #Day20
---

```
# Full pipeline for a feature:
/dx-req-fetch 12345
/dx-req-explain
/dx-req-research
/dx-plan
/dx-step          # execute step 1
/dx-step          # execute step 2
/dx-step-verify
/dx-pr
```
