---
title: "Parallel Agents: Three Ways to Run Concurrent Work"
category: "Agents — AI Personas"
focus: "Claude Code"
tags: ["Parallel","/fleet","Concurrent"]
overview: "Three approaches to parallel work: Claude Code spawns multiple Agent calls in one message. Copilot CLI has /fleet — run the same task across multiple subagents and converge results. VSCode Chat has #runSubagent for context-isolated sub-tasks. Each tool has its own parallelism model."
screenshot: null
week: 5
weekLabel: "Skills — Recipe Book"
order: 25
slackOneLiner: "🤖 Tip #25 — Each tool has its own parallelism model: Claude Code uses multiple Agent calls, Copilot CLI uses /fleet, VSCode Chat uses #runSubagent."
keyPointsTitle: "Three Parallelism Models"
actionItemsTitle: "When to Use Which"
keyPoints:
  - "**Claude Code** — Multiple Agent tool calls in one message run concurrently, each with its own context. Our `/dx-step-verify` runs lint + secrets + architecture checks in parallel, cutting verification time by ~60%."
  - "**Copilot CLI /fleet** — Spawns N parallel subagents, one per subtask. Results converge back. Think MapReduce for code tasks. Great for homogeneous work like code review across many modules."
  - "**VSCode Chat #runSubagent** — Creates a context-isolated sub-task. The subagent works independently, returns results to your main conversation. Your context stays clean. Best for one-off heavy research or delegation."
  - "**Don't parallelize dependent tasks** — If step 2 needs step 1's output, run them sequentially. Parallel agents can't see each other's work."
actionItems:
  - |
    **Match the model to the task type**
    - Heterogeneous (different tools) — Claude Code multiple Agent calls
    - Homogeneous (same task, N targets) — Copilot CLI /fleet
    - Delegation (one-off research) — VSCode Chat #runSubagent
  - "**Try /fleet** — In Copilot CLI, run `/fleet \"summarize each file in src/components/\"` to see parallel agent execution in action."
  - "**Look for parallel opportunities** — Check if any of your sequential skill steps could run in parallel. Independent verification checks (lint, secrets, architecture) are prime candidates."
  - "**Keep dependencies sequential** — Map your skill steps as a dependency graph. Only parallelize steps with no data dependencies between them."
---
