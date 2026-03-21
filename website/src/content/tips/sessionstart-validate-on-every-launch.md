---
title: "SessionStart: Validate on Every Launch"
category: "Hooks — Guardrails"
focus: "Claude Code"
tags: ["SessionStart","Validation","Environment"]
overview: "SessionStart hooks fire once when you start a Claude Code session. They're perfect for environment validation: check Node version, verify MCP servers are reachable, validate config files. Catch problems in the first 2 seconds instead of 20 minutes into a failed pipeline."
codeLabel: "Environment check"
screenshot: null
week: 7
weekLabel: "Skills — Advanced"
order: 35
slackText: |
  🤖 Agentic AI Tip #35 — SessionStart: Validate on Every Launch
  
  Nothing is worse than running a 15-minute pipeline only to discover at step 7 that your Node version was wrong.
  
  SessionStart hooks fix this by validating your environment *the moment you start a session*.
  
  *What to check:*
  • *Node version* — our project needs v10, not v18
  • *MCP server connectivity* — can we reach AEM? Figma? ADO?
  • *Config files* — does `.ai/config.yaml` exist and have required fields?
  • *Git state* — are you on a feature branch? Any uncommitted changes?
  • *Dependencies* — is `node_modules/` present?
  
  *The output appears as a banner:*
  ```
  ✅ Node v10.16.0
  ✅ AEM MCP: localhost:4502 reachable
  ✅ Config: .ai/config.yaml valid
  ⚠️ Uncommitted changes in 3 files
  ```
  
  *Why this matters:*
  Without it, environment issues surface as mysterious failures deep in a workflow. With it, you know the state of your world before typing the first command.
  
  *Matcher is empty:* `"matcher": ""` means "always fire" — SessionStart doesn't match tools, it matches session creation.
  
  💡 Try it: Create a SessionStart hook that checks your Node version. Just that. You'll be surprised how often you're on the wrong version.
  
  #AgenticAI #Day35
---

```
# hooks.json
{
  "event": "SessionStart",
  "matcher": "",
  "command": "./scripts/validate-env.sh"
}

# validate-env.sh
#!/bin/bash
node -v | grep -q "v10" || {
  echo "⚠️ Wrong Node version"
  echo "Run: nvm use 10"
}
```
