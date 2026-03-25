---
title: "Four Instruction Files: CLAUDE.md, AGENTS.md, and More"
category: "Context — The Secret Sauce"
focus: "All Tools"
tags: ["CLAUDE.md","AGENTS.md","copilot-instructions","Instructions"]
overview: "Each tool reads different instruction files — and some read multiple. CLAUDE.md (Claude Code primary), AGENTS.md (Copilot coding agent, open format), .github/copilot-instructions.md (legacy Copilot), plus .github/instructions/*.instructions.md for path-scoped rules. Rules in .claude/rules/ can be shared via an env var."
screenshot: null
week: 2
weekLabel: "Meet Your AI Tools"
order: 8
slackOneLiner: "🤖 Tip #8 — Four instruction files exist across platforms. Know who reads what — and use the env var trick to share rules without duplication."
keyPointsTitle: "Who Reads What"
actionItemsTitle: "Cross-Platform Sharing"
keyPoints:
  - "**CLAUDE.md** — Claude Code's primary file. Also read by Copilot coding agent (the cloud autonomous agent that works on GitHub issues). Supports @import for recursive includes."
  - "**AGENTS.md** — the new open format (Aug 2025). Read by Copilot CLI, VS Code Chat, and the coding agent. Placed at root or nested per-directory."
  - "**.github/copilot-instructions.md** — the original Copilot format. Still works. Repo-wide scope."
  - "**.github/instructions/*.instructions.md** — path-scoped with `applyTo:` frontmatter. Like .claude/rules/ but for Copilot. Can exclude specific agents with `excludeAgent:`."
actionItems:
  - |
    The sharing trick — no duplication needed
    - Set `COPILOT_CUSTOM_INSTRUCTIONS_DIRS=".claude/rules"` as an env var
    - Now BOTH Claude Code and Copilot CLI read the same rules
    - Still need dual frontmatter (`paths:` + `applyTo:`) for path-matching in both tools
  - "Check which instruction files your project has — ensure each tool can find what it needs"
  - "Set `COPILOT_CUSTOM_INSTRUCTIONS_DIRS=\".claude/rules\"` so Copilot CLI reads your existing Claude Code rules"
  - "Use dual frontmatter (`paths:` for Claude Code + `applyTo:` for Copilot) in all rule files for cross-platform path-matching"
---
