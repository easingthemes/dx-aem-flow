---
title: "The Coordinator Pattern"
category: "Skills — Advanced"
focus: "Claude Code"
tags: ["Coordinator","Orchestration"]
overview: "Some skills shouldn't think — they should just dispatch. The coordinator pattern makes a skill that orchestrates subagents without accumulating context. Each step runs in its own agent with its own context window. Perfect for multi-step pipelines."
screenshot: null
week: 4
weekLabel: "Context — The Secret Sauce"
order: 18
slackOneLiner: "🤖 Tip #18 — The most powerful advanced pattern is counter-intuitive: a skill that doesn't think, just dispatches subagents with fresh context windows."
keyPointsTitle: "The Context Problem"
actionItemsTitle: "Build a Coordinator"
keyPoints:
  - "**The problem** — Multi-step pipelines (fetch, analyze, plan, implement) accumulate context. By step 4, the AI carries the weight of steps 1-3 in its context window. Quality degrades as context fills up."
  - "**The solution** — A 'coordinator' skill that does no work itself — it just dispatches subagents. Each step gets a fresh context window. Step 3 doesn't carry the weight of step 1's output."
  - "**Not `disable-model-invocation`** — that flag does not stop the model from reasoning. It hides the skill from the model's listing and blocks every Skill-tool call to it, including from another skill or subagent. Use it only on an entry point a human types and nothing chains to."
actionItems:
  - "**Real example** — `/dx-figma-all` orchestrates 3 sub-skills: extract Figma design, generate prototype, verify against reference. Each runs as a separate agent. Total pipeline: zero context bloat."
  - |
    Create a coordinator skill
    - Each step invokes a sub-skill via `Skill("dx-sub-skill")`
    - Sub-skills communicate through spec files, not shared context
  - "**When to use it** — If your multi-step skill's steps can run independently with just file I/O between them, make it a coordinator. Keep monolithic skills only when steps truly depend on shared in-memory context."
  - "**Test sub-skills first** — Each sub-skill must work standalone before wiring them into a coordinator. Independent testability is the whole point of the pattern."
---
