---
title: "maxTurns: The Agent Safety Net"
category: "Mastery"
focus: "Claude Code"
tags: ["maxTurns","Safety","Loops"]
overview: "Agents can loop. An agent trying to fix a flaky test might retry indefinitely. maxTurns sets a hard cap on how many turns an agent can take before stopping. Set it lower for simple tasks (10-20) and higher for complex ones (50+). Without it, a stuck agent burns tokens forever."
codeLabel: "maxTurns per agent"
screenshot: null
week: 10
weekLabel: "Agents — AI Personas"
order: 50
slackText: |
  🤖 Agentic AI Tip #50 — maxTurns: The Agent Safety Net
  
  Without maxTurns, a stuck agent loops forever, burning tokens into oblivion.
  
  *The scenario:*
  Agent tries to fix a test. Test still fails. Agent tries again. Still fails. Tries a different approach. Fails. Reverts. Tries again... 200 turns later, you've spent $50 and the test still fails.
  
  *The fix:*
  `maxTurns` in agent frontmatter sets a hard cap:
  ```yaml
  maxTurns: 15   # for simple lookups
  maxTurns: 50   # for complex tasks
  ```
  
  When the agent hits the limit, it stops and returns what it has — partial results are better than infinite loops.
  
  *How to set the right value:*
  • File search/lookup: 10-15 turns
  • Implementation with testing: 40-50 turns
  • Code review: 30-50 turns
  • Bug investigation: 30-40 turns
  
  *Pro tip:* If an agent frequently hits maxTurns, the task is too complex for one agent. Break it into smaller subtasks or add better instructions to guide the agent more efficiently.
  
  *For autonomous agents:*
  maxTurns is especially critical. A Lambda-based agent without maxTurns could run for hours. We set conservative limits and handle partial completion gracefully.
  
  💡 Try it: Check your agent definitions for maxTurns. Any missing? Add them. Start conservative — you can always increase.
  
  #AgenticAI #Day50
---

```
# Agent definition:
---
name: dx-file-resolver
model: haiku
maxTurns: 15    # simple lookup
---

---
name: dx-step-executor
model: sonnet
maxTurns: 50    # complex implementation
---

---
name: dx-code-reviewer
model: opus
maxTurns: 50    # thorough review
---
```
