---
title: "How to Select an Agent: Three UIs, One Concept"
category: "Meet Your AI Tools"
focus: "All Tools"
tags: ["Agent Selection","/agents","Dropdown","Auto-Dispatch"]
overview: "Each tool selects agents differently. VSCode Chat: dropdown menu at the bottom — pick an agent, it becomes your assistant. Copilot CLI: /agents command shows a numbered list — arrow keys to select. Claude Code: /agents lists all 34 agents with plugin prefix, model tier, and memory. But most of the time, you don't pick manually — skills auto-dispatch to the right agent."
screenshot: "/images/tldr/agents-selection.png"
week: 1
weekLabel: "Meet Your AI Tools"
order: 4
slackOneLiner: "🤖 Tip #4 — You have dozens of agents available across three tools, but most of the time skills auto-dispatch to the right one for you."
keyPointsTitle: "Selection in Each Tool"
keyPoints:
  - "VSCode Chat — Dropdown menu at the bottom of the Chat panel. Click the agent name, pick from the list (DxPRReview, DxCodeReview, AEMComponent, etc.). Also shows 'Configure Custom Agents...' to manage .agent.md files."
  - "Copilot CLI — Type `/agents` in the terminal. Get a numbered list of all agents (plugin agents AND .github/agents/ agents). Arrow keys to navigate, Enter to select. The selected agent stays active for your session."
  - "Claude Code — Type `/agents` for the full inventory. Shows the richest info: agent name with plugin prefix (`dx-aem:aem-inspector`), model tier (`sonnet`), and memory type (`project memory`). All 34 agents across installed plugins visible at once."
actionItemsTitle: "Auto-Dispatch vs Manual Selection"
actionItems:
  - "Auto-dispatch is the real pattern — Most of the time, you don't manually select agents. Skills auto-dispatch. Running `/dx-pr-review` automatically routes to the `dx-pr-reviewer` agent (Sonnet, with ADO MCP tools). The skill knows which agent is right for the job."
  - "Manual selection is for exploration — Use `/agents` to discover what's available, learn agent capabilities, and experiment. For actual workflows, let skills handle the routing."
  - "Run `/agents` in both Claude Code and Copilot CLI — compare the lists (Claude Code shows 13 plugin agents, Copilot shows 25 .github agents)"
  - |
    Know the selection method per tool
    - VSCode Chat — dropdown at bottom of Chat panel
    - Copilot CLI — `/agents` command, arrow keys + Enter
    - Claude Code — `/agents` command, shows plugin prefix + model tier
---
