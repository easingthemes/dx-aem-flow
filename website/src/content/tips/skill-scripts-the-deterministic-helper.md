---
title: "Skill Scripts: The Deterministic Helper"
category: "Skills — Recipe Book"
focus: "Claude Code · CLI"
tags: ["Bash Scripts","Deterministic","Hybrid"]
overview: "AI is non-deterministic — same prompt, different results. But some operations must be exact every time: detecting Node version, checking environment, copying files. Put those in bash scripts alongside your skill. The AI runs the script for the deterministic part and reasons about the results."
codeLabel: "Hybrid approach"
screenshot: null
week: 4
weekLabel: "Context — The Secret Sauce"
order: 16
slackText: |
  🤖 Agentic AI Tip #16 — Skill Scripts: The Deterministic Helper
  
  Here's a pattern that most people miss: not everything in a skill should be AI-driven.
  
  AI is non-deterministic — ask the same question twice, get slightly different answers. That's fine for reasoning, but terrible for operations that must be exact: checking Node versions, detecting project structure, copying files to specific locations.
  
  *The solution:* Put deterministic operations in bash scripts alongside your skill.
  
  ```
  skills/my-skill/
  ├── SKILL.md          ← AI reasoning
  └── scripts/
      └── detect-env.sh ← exact every time
  ```
  
  In SKILL.md, tell the AI to run the script first:
  "Run `scripts/detect-env.sh` and use its output to decide the next step."
  
  *Real examples from our codebase:*
  • `detect-env.sh` — checks Node version, OS, installed tools
  • `validate-config.sh` — verifies .ai/config.yaml structure
  • `upload-component-js.sh` — copies build artifacts to exact paths
  
  The AI handles the thinking (what to do, why). Scripts handle the doing (exact commands, exact paths).
  
  💡 Try it: If you have a skill with complex bash commands inline, extract them to a script file. Reliability goes up immediately.
  
  #AgenticAI #Day16
---

```
# skills/my-skill/
#   SKILL.md       ← AI instructions
#   scripts/
#     detect-env.sh  ← deterministic

# In SKILL.md:
Run scripts/detect-env.sh to detect
the current environment, then use the
output to decide which build to run.
```
