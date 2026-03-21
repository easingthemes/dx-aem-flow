---
title: "Parallel Agents: Three Ways to Run Concurrent Work"
category: "Agents — AI Personas"
focus: "Claude Code"
tags: ["Parallel","/fleet","Concurrent"]
overview: "Three approaches to parallel work: Claude Code spawns multiple Agent calls in one message. Copilot CLI has /fleet — run the same task across multiple subagents and converge results. VSCode Chat has #runSubagent for context-isolated sub-tasks. Each tool has its own parallelism model."
codeLabel: "Three parallelism models"
screenshot: null
week: 5
weekLabel: "Skills — Recipe Book"
order: 25
slackText: |
  🤖 Agentic AI Tip #25 — Parallel Agents: Three Ways to Run Concurrent Work
  
  Each tool has its own approach to parallelism:
  
  *Claude Code — multiple Agent tool calls:*
  Put multiple Agent calls in one message → they run concurrently. Each gets its own context. Our `/dx-step-verify` runs lint + secrets + architecture in parallel, cutting time by ~60%.
  
  *Copilot CLI — /fleet:*
  `/fleet "review each module for security issues"`
  Spawns N parallel subagents, one per subtask. Results converge back. Think MapReduce for code tasks. Great for code review across many modules.
  
  *VSCode Chat — #runSubagent:*
  `#runSubagent "research the modal API"`
  Creates a context-isolated sub-task. The subagent works independently, returns results to your main conversation. Your context stays clean.
  
  *When to use which:*
  • Claude Code: best for heterogeneous tasks (lint agent + test agent + build agent — different tools, same time)
  • /fleet: best for homogeneous tasks (same task across N targets)
  • #runSubagent: best for delegation (one-off heavy research)
  
  *Don't parallelize:*
  Dependent tasks — if step 2 needs step 1's output. Parallel agents can't see each other's work.
  
  💡 Try it: In Copilot CLI, try `/fleet "summarize each file in src/components/"` — watch the parallel magic.
  
  #AgenticAI #Day25
---

```
# Claude Code — multiple Agent calls:
Agent → run linting
Agent → run tests     # same message!
Agent → run build     # same message!

# Copilot CLI — /fleet:
/fleet "review each module for
 security issues"
→ spawns N parallel subagents
→ converges results

# VSCode Chat — #runSubagent:
#runSubagent "research the auth API"
```
