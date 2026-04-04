---
title: "Plugin = Skills + Agents + Hooks in a Box"
category: "Plugins — Full Package"
focus: "Claude Code"
tags: ["Plugin","Bundle","Reusable"]
overview: "A plugin bundles skills, agents, hooks, MCP configs, and rules into a single installable package. Install once, available in every project. Our four plugins (dx-core, dx-hub, dx-aem, dx-automation) contain 71 skills, 13 agents, and 4 hooks — all distributed from a single source."
screenshot: null
week: 8
weekLabel: "Skills — Advanced"
order: 37
slackOneLiner: "🤖 Tip #37 — A plugin bundles skills, agents, hooks, MCP configs, and rules into one installable package — install once, use everywhere."
keyPointsTitle: "What's Inside a Plugin"
actionItemsTitle: "Why Plugins Beat Loose Files"
keyPoints:
  - |
    **plugin.json** — The manifest declaring name, version, and description
    - The entry point that Claude Code and Copilot CLI both read
    - Defines what the plugin contains and how to discover it
  - |
    **skills/** — Slash commands that automate workflows
    - Each skill is a directory with a SKILL.md file
    - Triggered by typing /skill-name in the terminal
  - |
    **agents/** — Specialized AI personas with model tiers
    - Each agent has its own system prompt and tool access
    - Can run in isolation with worktree support
  - |
    **hooks/** — Event-driven guardrails and automation
    - Fire on specific events (pre-commit, post-save, etc.)
    - Prevent mistakes before they happen
  - |
    **Supporting files** — MCP configs + rules + templates
    - .mcp.json registers external tool connections
    - rules/ loads conventions based on file paths
actionItems:
  - "**Install once, use everywhere** — Add to any project with one command. Versioned, shared across teams, and updateable by bumping a single version number."
  - "**Encapsulation** — MCP servers, hooks, and rules are bundled together. No scattered config files across your project — everything lives in one installable package."
  - "**Shared distribution** — The whole team uses the same skills without copy-pasting. Roll back if a new version breaks something. Everyone stays in sync."
  - "**Our setup** — Four plugins (dx-core, dx-hub, dx-aem, dx-automation), 71 skills, 13 agents, distributed to 4 consumer repos from a single source."
  - "**Start exploring** — Open an installed plugin's plugin.json to see the manifest, then browse skills/ and agents/ to understand what's available."
---
