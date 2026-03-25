---
title: "Skill Scripts: The Deterministic Helper"
category: "Skills — Recipe Book"
focus: "Claude Code · CLI"
tags: ["Bash Scripts","Deterministic","Hybrid"]
overview: "AI is non-deterministic — same prompt, different results. But some operations must be exact every time: detecting Node version, checking environment, copying files. Put those in bash scripts alongside your skill. The AI runs the script for the deterministic part and reasons about the results."
screenshot: null
week: 4
weekLabel: "Context — The Secret Sauce"
order: 16
slackOneLiner: "🤖 Tip #16 — Not everything in a skill should be AI-driven. Put deterministic operations in bash scripts alongside SKILL.md — exact results every time."
keyPointsTitle: "AI + Scripts Hybrid"
actionItemsTitle: "Extract and Structure"
keyPoints:
  - "**The problem** — AI is non-deterministic. Ask the same question twice, get slightly different answers. Fine for reasoning, terrible for operations that must be exact: checking Node versions, detecting project structure, copying files."
  - "**The solution** — Put deterministic operations in bash scripts alongside your skill in a `scripts/` subdirectory. The AI handles the thinking (what to do, why). Scripts handle the doing (exact commands, exact paths)."
  - "**Directory structure** — `skills/my-skill/SKILL.md` for AI reasoning, `skills/my-skill/scripts/detect-env.sh` for exact operations. In SKILL.md, tell the AI: 'Run scripts/detect-env.sh and use its output to decide the next step.'"
actionItems:
  - "**Identify extraction candidates** — Look for skills with complex inline bash commands — multi-line shell blocks, piped commands, file operations. These are your extraction targets."
  - |
    Structure the hybrid approach
    - `skills/my-skill/SKILL.md` — AI reasoning and decision-making
    - `skills/my-skill/scripts/detect-env.sh` — deterministic operations
    - In SKILL.md: "Run scripts/detect-env.sh and use its output to decide the next step"
  - "**Real examples** — `detect-env.sh` checks Node version, OS, installed tools. `validate-config.sh` verifies .ai/config.yaml structure. `upload-component-js.sh` copies build artifacts to exact paths."
  - "**Always chmod +x** — Make all script files executable. The AI will fail to run them otherwise. Add this to your skill-creation checklist."
---
