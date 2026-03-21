---
title: "MCP Secrets: Two Different Approaches"
category: "MCP — System Integration"
focus: "Claude Code · CLI"
tags: ["Secrets","Environment Variables","Config"]
overview: "MCP servers often need API keys. Claude Code reads env vars from .claude/settings.local.json (gitignored). Copilot CLI does NOT read this file — it only sees shell environment variables from ~/.bashrc. Same secret, two different config locations."
codeLabel: "Same secret, two configs"
screenshot: null
week: 6
weekLabel: "Skills — Recipe Book"
order: 30
slackText: |
  🤖 Agentic AI Tip #30 — MCP Secrets: Two Different Approaches
  
  MCP servers need API keys, passwords, and URLs. Where you put them depends on which AI tool you're using.
  
  *Claude Code:*
  `.claude/settings.local.json` (per-project, gitignored):
  ```json
  { "env": { "AXE_API_KEY": "your-key" } }
  ```
  Clean, project-scoped, won't leak to git.
  
  *Copilot CLI:*
  Only reads shell environment variables. Does NOT read `settings.local.json`.
  ```bash
  # In ~/.bashrc
  export AXE_API_KEY="your-key"
  ```
  
  *The common mistake:*
  You configure secrets in `settings.local.json`, MCP works perfectly in Claude Code. Then you switch to Copilot CLI and MCP connections fail. No error tells you "I can't read settings.local.json" — the env var is just empty.
  
  *Best practice for teams using both tools:*
  1. Put secrets in `~/.bashrc` (or `~/.zshrc`) — works for both tools
  2. Optionally also add to `settings.local.json` for Claude Code's per-project isolation
  
  *Security reminder:* Never commit API keys. Both `settings.local.json` and `~/.bashrc` are outside git. Keep it that way.
  
  💡 Try it: Run `echo $AXE_API_KEY` in your terminal. If it's empty, your Copilot CLI MCP servers can't see it.
  
  #AgenticAI #Day30
---

```
# Claude Code — settings.local.json
{
  "env": {
    "AXE_API_KEY": "your-key-here",
    "AEM_INSTANCES": "http://admin:admin@localhost:4502"
  }
}

# Copilot CLI — ~/.bashrc only!
export AXE_API_KEY="your-key-here"
export AEM_INSTANCES="http://..."
```
