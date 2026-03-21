---
title: "Four Instruction Files: CLAUDE.md, AGENTS.md, and More"
category: "Context — The Secret Sauce"
focus: "All Tools"
tags: ["CLAUDE.md","AGENTS.md","copilot-instructions","Instructions"]
overview: "Each tool reads different instruction files — and some read multiple. CLAUDE.md (Claude Code primary), AGENTS.md (Copilot coding agent, open format), .github/copilot-instructions.md (legacy Copilot), plus .github/instructions/*.instructions.md for path-scoped rules. Rules in .claude/rules/ can be shared via an env var."
codeLabel: "Instruction file matrix"
screenshot: null
week: 2
weekLabel: "Meet Your AI Tools"
order: 8
slackText: |
  🤖 Agentic AI Tip #8 — Four Instruction Files: Who Reads What
  
  The instruction file landscape has expanded. Here's the current state:
  
  *CLAUDE.md* — Claude Code's primary file. Also read by Copilot coding agent (the cloud autonomous agent that works on GitHub issues). Supports @import for recursive includes.
  
  *AGENTS.md* — The new open format (Aug 2025). Read by Copilot CLI, VS Code Chat, and the coding agent. Placed at root or nested per-directory.
  
  *.github/copilot-instructions.md* — The original Copilot format. Still works. Repo-wide scope.
  
  *.github/instructions/*.instructions.md* — Path-scoped with `applyTo:` frontmatter. Like .claude/rules/ but for Copilot. Can exclude specific agents with `excludeAgent:`.
  
  *The sharing trick:*
  Your `.claude/rules/` files can be read by Copilot CLI too! Set this env var:
  ```
  COPILOT_CUSTOM_INSTRUCTIONS_DIRS=".claude/rules"
  ```
  Now BOTH tools read the same rules. No duplication needed for conventions.
  
  *Still needed:*
  Dual frontmatter (`paths:` + `applyTo:`) in rule files so path-matching works in both tools.
  
  💡 Try it: Check which instruction files your project has. Ensure each tool can find what it needs. Use the env var trick to share .claude/rules/.
  
  #AgenticAI #Day8
---

```
# Who reads what:
CLAUDE.md              → Claude Code ✅
                         Copilot coding agent ✅
AGENTS.md              → Copilot CLI + Chat ✅
                         Copilot coding agent ✅
.github/copilot-       → Copilot CLI + Chat ✅
  instructions.md
.claude/rules/         → Claude Code ✅
                         Copilot CLI ✅ (via env)

# Share rules with Copilot CLI:
COPILOT_CUSTOM_INSTRUCTIONS_DIRS=".claude/rules"
```
