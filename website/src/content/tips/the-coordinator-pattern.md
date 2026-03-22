---
title: "The Coordinator Pattern"
category: "Skills — Advanced"
focus: "Claude Code"
tags: ["Coordinator","disable-model-invocation","Orchestration"]
overview: "Some skills shouldn't think — they should just dispatch. The coordinator pattern uses disable-model-invocation to create skills that orchestrate subagents without accumulating context. Each step runs in its own agent with its own context window. Perfect for multi-step pipelines."
codeLabel: "Coordinator skill"
screenshot: null
week: 4
weekLabel: "Context — The Secret Sauce"
order: 18
slackText: |
  🤖 Agentic AI Tip #18 — The Coordinator Pattern
  
  This is one of the most powerful advanced patterns, and it's counter-intuitive: *a skill that doesn't think.*
  
  The problem: Multi-step pipelines (fetch → analyze → plan → implement) accumulate context. By step 4, the AI is carrying the weight of steps 1-3 in its context window. Quality degrades.
  
  The solution: A "coordinator" skill with `disable-model-invocation: true`. It doesn't reason — it just dispatches subagents:
  
  ```
  Step 1: Spawn agent → extract Figma design
  Step 2: Spawn agent → generate prototype
  Step 3: Spawn agent → verify against reference
  ```
  
  Each step gets a *fresh context window*. Step 3 doesn't carry the weight of step 1's output.
  
  *Why disable-model-invocation?*
  Without it, the coordinator would try to "think" about the instructions — wasting tokens on reasoning that isn't needed. With it, the skill is a pure dispatcher.
  
  *Real example:* Our `/dx-figma-all` skill orchestrates 3 sub-skills. Each runs as a separate agent. Total pipeline: 0 context bloat.
  
  💡 Try it: Look at any multi-step skill you've built. Could the steps run independently? If yes, make it a coordinator.
  
  #AgenticAI #Day18
---

```
---
name: dx-figma-all
disable-model-invocation: true
---

# Step 1: Extract
Invoke Skill("dx-figma-extract")

# Step 2: Prototype
Invoke Skill("dx-figma-prototype")

# Step 3: Verify
Invoke Skill("dx-figma-verify")
```
