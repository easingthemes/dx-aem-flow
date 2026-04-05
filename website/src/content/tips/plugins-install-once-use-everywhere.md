---
title: "Plugins: Install Once, Use Everywhere"
category: "Plugins — Full Package"
focus: "All Tools"
tags: ["Plugins","Marketplace","Skills","Agents","MCP"]
overview: "Plugins are installable bundles of skills, agents, rules, and MCP servers. One command adds them. They work in both Claude Code and Copilot CLI. Think of them like VS Code extensions — but for your terminal AI."
screenshot: null
week: 11
weekLabel: "Plugins & Mastery"
order: 52
slackOneLiner: "🤖 Tip #52 — Plugins are installable bundles of skills, agents, rules, and MCP servers — like VS Code extensions for your terminal AI."
keyPointsTitle: "What Plugins Give You"
actionItemsTitle: "How to Install and Use"
keyPoints:
  - "**What's in a plugin** — Skills (slash commands like /dx-plan, /aem-verify), agents (specialized AI personas), rules (convention templates for .claude/rules/), and MCP servers (external tool connections to ADO, AEM, Figma)."
  - "**Cross-platform** — Works in both Claude Code and Copilot CLI. Install once, both tools discover skills, agents, rules, and MCP servers automatically."
  - "**No build step** — Plugins are pure Markdown + shell scripts. Install, init, use. No compilation or bundling needed."
  - "**Auto-discovery** — After install, everything is automatic. Skills show up as /commands, agents are available for dispatch, rules load based on file paths, and MCP servers connect on their own."
  - "**Public marketplaces** — Adobe publishes AEM Edge Delivery skills. You can create your own marketplace in any GitHub repo."
actionItems:
  - "**Browse Adobe's skills** — Run `/plugin marketplace add adobe/skills` to register, then `/plugin list` to see what's available."
  - |
    **Install from a marketplace**
    - `/plugin marketplace add owner/repo` — register a marketplace
    - `/plugin list --marketplace` — browse available plugins
    - `/plugin install plugin-name@marketplace` — install what you need
    - `/plugin marketplace update marketplace-name` — update all installed plugins
  - |
    **Know the cross-platform differences**
    - Agents — Claude Code uses plugin agents/, Copilot uses .github/agents/
    - Rules — Claude Code uses native paths:, Copilot uses applyTo: env var
    - Hooks — Claude Code supports 18 events + prompt, Copilot supports 8 events
  - "**Start small** — Install one plugin, run its init skill, and explore the slash commands it adds to your terminal."
---
