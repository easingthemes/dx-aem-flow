---
title: "Consumer Sync: One Source, Many Projects"
category: "Plugins — Full Package"
focus: "Claude Code"
tags: ["Sync","Multi-Repo","Version"]
overview: "We maintain plugins in one source repo and sync to 4 consumer projects. A sync script handles distribution. But version bumping requires updating 4 files — 3 plugin.json files + 1 marketplace.json. Forgetting one causes version mismatch nightmares."
screenshot: null
week: 9
weekLabel: "Agents — AI Personas"
order: 41
slackOneLiner: "🤖 Tip #41 — Distributing plugins across multiple projects requires a sync script and a version bump checklist — miss one file and you get 'already up to date' lies."
keyPointsTitle: "The Distribution Challenge"
actionItemsTitle: "The Sync Playbook"
keyPoints:
  - "**The challenge** — Building a plugin is half the battle. Distributing it across multiple projects is the other half. We maintain 4 plugins in one source repo, synced to 4 consumer repos."
  - "**Sync script responsibilities** — Copies skills, agents, rules, and hooks. Respects per-repo config differences. Preserves local overrides. Reports what changed after each sync."
  - "**The version bump trap** — When bumping plugin versions, you must update 5 files: dx-core/plugin.json, dx-hub/plugin.json, dx-aem/plugin.json, dx-automation/plugin.json, AND .claude-plugin/marketplace.json in the consumer repo root. Miss the marketplace.json and the consumer thinks it has an old version."
  - "**Lessons learned** — Always read the consumer's local config before applying changes (branch names, paths, feature flags vary per project). Test sync on one consumer before syncing all four."
actionItems:
  - |
    **Version bump checklist**
    - Update each plugin's plugin.json (version field)
    - Update .claude-plugin/marketplace.json in each consumer repo
    - Run sync script
    - Diff the result to verify no accidental deletions
    - Test `/plugin list` in a consumer to confirm version match
  - "**Test before you ship** — Sync on one consumer project before distributing to all. Catch issues early with a single test target rather than debugging across four repos."
  - "**Diff after every sync** — Review the diff to catch accidental deletions. A sync script that removes a file you customized locally is a silent breakage."
  - "**Respect local overrides** — Each consumer may have different branch names, paths, and feature flags. Your sync script must read local config before applying changes, not blindly overwrite."
---
