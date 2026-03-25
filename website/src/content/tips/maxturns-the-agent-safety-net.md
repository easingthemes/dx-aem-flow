---
title: "maxTurns: The Agent Safety Net"
category: "Mastery"
focus: "Claude Code"
tags: ["maxTurns","Safety","Loops"]
overview: "Agents can loop. An agent trying to fix a flaky test might retry indefinitely. maxTurns sets a hard cap on how many turns an agent can take before stopping. Set it lower for simple tasks (10-20) and higher for complex ones (50+). Without it, a stuck agent burns tokens forever."
screenshot: null
week: 10
weekLabel: "Agents — AI Personas"
order: 50
slackOneLiner: "🤖 Tip #50 — Set maxTurns on every agent to prevent infinite loops — a stuck agent without it burns tokens into oblivion."
keyPointsTitle: "Why Agents Need Limits"
actionItemsTitle: "Setting the Right Values"
keyPoints:
  - "**The problem** — Without maxTurns, a stuck agent loops forever. Agent tries to fix a test, fails, tries again, tries a different approach, reverts, retries... 200 turns later, you've spent $50 and the test still fails."
  - "**The fix** — `maxTurns` in agent frontmatter sets a hard cap. When the agent hits the limit, it stops and returns what it has. Partial results are better than infinite loops."
  - "**Frequent hits signal a problem** — If an agent frequently hits maxTurns, the task is too complex for one agent. Break it into smaller subtasks or add better instructions to guide the agent more efficiently."
  - "**Critical for autonomous agents** — A Lambda-based agent without maxTurns could run for hours. Set conservative limits and handle partial completion gracefully."
actionItems:
  - |
    **Right-sizing by agent type**
    - Haiku lookup agents — maxTurns 10-15
    - Sonnet implementation agents — maxTurns 40-50
    - Opus review agents — maxTurns 30-50
    - Autonomous pipeline agents — conservative limits (15-30)
  - "**Start conservative** — Begin with lower values and increase only if agents consistently need more turns to complete their tasks. It's cheaper to bump a limit than to burn tokens on a runaway."
  - "**Audit your agents** — Check every agent definition for missing maxTurns. Any agent without one is a potential runaway. Add limits to all of them."
  - "**Handle partial completion** — Design your skills to accept partial results gracefully. A code review that covers 80% of files is better than one that loops forever trying to cover 100%."
---
