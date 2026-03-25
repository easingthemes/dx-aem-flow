---
title: "MCP Secrets: Two Different Approaches"
category: "MCP — System Integration"
focus: "Claude Code · CLI"
tags: ["Secrets","Environment Variables","Config"]
overview: "MCP servers often need API keys. Claude Code reads env vars from .claude/settings.local.json (gitignored). Copilot CLI does NOT read this file — it only sees shell environment variables from ~/.bashrc. Same secret, two different config locations."
screenshot: null
week: 6
weekLabel: "Skills — Recipe Book"
order: 30
slackOneLiner: "🤖 Tip #30 — Same API key, two config locations: Claude Code reads settings.local.json, Copilot CLI only sees shell env vars."
keyPointsTitle: "Where Each Tool Reads Secrets"
actionItemsTitle: "Avoiding the Silent Failure"
keyPoints:
  - "**Claude Code** — Secrets go in .claude/settings.local.json (per-project, gitignored). Clean, project-scoped, won't leak to git. Format: { \"env\": { \"AXE_API_KEY\": \"your-key\" } }."
  - "**Copilot CLI** — Only reads shell environment variables. Does NOT read settings.local.json. Secrets must be exported in ~/.bashrc or ~/.zshrc."
  - "**The silent failure trap** — You configure secrets in settings.local.json, MCP works perfectly in Claude Code. Then you switch to Copilot CLI and MCP connections fail silently. No error tells you the env var is empty — it just doesn't work."
actionItems:
  - "**Quick diagnosis** — Run 'echo $AXE_API_KEY' in your terminal. If it's empty, your Copilot CLI MCP servers can't see it."
  - |
    **Cross-tool compatibility** — Set secrets in both locations
    - ~/.bashrc or ~/.zshrc → export AXE_API_KEY="your-key"
    - .claude/settings.local.json → { "env": { "AXE_API_KEY": "your-key" } }
  - "**Security reminder** — Never commit API keys. Both settings.local.json and ~/.bashrc are outside git. Verify that settings.local.json is in your .gitignore."
---
