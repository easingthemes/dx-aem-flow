---
title: "Consumer Sync: One Source, Many Projects"
category: "Plugins — Full Package"
focus: "Claude Code"
tags: ["Sync","Multi-Repo","Version"]
overview: "We maintain plugins in one source repo and sync to 4 consumer projects. A sync script handles distribution. But version bumping requires updating 4 files — 3 plugin.json files + 1 marketplace.json. Forgetting one causes version mismatch nightmares."
codeLabel: "Multi-repo sync"
screenshot: null
week: 9
weekLabel: "Agents — AI Personas"
order: 41
slackText: |
  🤖 Agentic AI Tip #41 — Consumer Sync: One Source, Many Projects
  
  Building a plugin is half the battle. Distributing it across multiple projects is the other half.
  
  *Our setup:*
  • 3 plugins developed in one source location
  • 4 consumer repos that use these plugins
  • A sync script that handles distribution
  
  *The sync script handles:*
  • Copying skills, agents, rules, hooks
  • Respecting per-repo config differences
  • Preserving local overrides
  • Reporting what changed
  
  *The version bump trap:*
  When bumping plugin versions, you must update 4 files:
  1. `dx-core/plugin.json`
  2. `dx-aem/plugin.json`
  3. `dx-automation/plugin.json`
  4. `.claude-plugin/marketplace.json` (consumer repo root)
  
  Miss #4 and the consumer repo thinks it has an old version. This causes "already up to date" messages when you try to reinstall.
  
  *Lessons learned:*
  • Always read the consumer's local config before applying changes — branch names, paths, and feature flags vary per project
  • Test sync on one consumer before syncing all four
  • Diff the result after sync — catch accidental deletions
  
  💡 Try it: If you maintain a plugin used in multiple projects, write a checklist for version bumps. Include ALL files that need updating.
  
  #AgenticAI #Day41
---

```
# Version lives in 4 files:
# 1. dx-core/plugin.json
# 2. dx-aem/plugin.json
# 3. dx-automation/plugin.json
# 4. .claude-plugin/marketplace.json

# Sync to consumers:
./scripts/sync-consumers.sh
# → Customer-Brand-A
# → Customer-Brand-B
# → Platform-Core
# → AEM-Platform-Core
```
