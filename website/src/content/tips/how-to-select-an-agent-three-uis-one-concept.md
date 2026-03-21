---
title: "How to Select an Agent: Three UIs, One Concept"
category: "Meet Your AI Tools"
focus: "All Tools"
tags: ["Agent Selection","/agents","Dropdown","Auto-Dispatch"]
overview: "Each tool selects agents differently. VSCode Chat: dropdown menu at the bottom — pick an agent, it becomes your assistant. Copilot CLI: /agents command shows a numbered list — arrow keys to select. Claude Code: /agents lists all 34 agents with plugin prefix, model tier, and memory. But most of the time, you don't pick manually — skills auto-dispatch to the right agent."
codeLabel: "Three selection methods"
screenshot: "/images/tldr/agents-selection.png"
week: 1
weekLabel: "Meet Your AI Tools"
order: 4
slackText: |
  🤖 Agentic AI Tip #4 — How to Select an Agent: Three UIs, One Concept
  
  You have dozens of agents available. How do you pick one? It depends on the tool.
  
  *VSCode Chat — dropdown menu:*
  At the bottom of the Chat panel, click the agent name. A dropdown shows all available agents: DxPRReview, DxCodeReview, AEMComponent, etc. Pick one, and it becomes your active assistant with its own tools and persona. You'll also see "Configure Custom Agents..." to manage .agent.md files.
  
  *Copilot CLI — /agents command:*
  Type `/agents` in the terminal. You get a numbered list of all agents — plugin agents AND .github/agents/ agents. Use arrow keys to navigate, Enter to select. The selected agent stays active for your session. You also see warnings if any .agent.md files have unsupported fields.
  
  *Claude Code — /agents command:*
  Type `/agents` for the full inventory. Claude Code shows the richest info: agent name with plugin prefix (`dx-aem:aem-inspector`), model tier (`sonnet`), and memory type (`project memory`). You see all 34 agents across installed plugins.
  
  *But here's the real pattern:*
  Most of the time, you don't manually select agents. *Skills auto-dispatch.* When you run `/dx-pr-review`, the skill automatically routes to the `dx-pr-reviewer` agent (Sonnet, with ADO MCP tools). The skill knows which agent is right for the job.
  
  Manual selection is for exploration. Auto-dispatch is for workflows.
  
  💡 Try it: Run `/agents` in both Claude Code and Copilot CLI. Compare the lists — Claude Code shows 13 plugin agents, Copilot shows 25 .github agents.
  
  #AgenticAI #Day4
---

```
# VSCode Chat — dropdown at bottom:
# Click agent name → pick from list
# Shows: DxPRReview, DxCodeReview...
# "Configure Custom Agents..." link

# Copilot CLI — /agents command:
/agents
# → numbered list, Enter to select
# Shows plugin + .github agents

# Claude Code — /agents command:
/agents
# → full list with details:
# dx-aem:aem-inspector · sonnet
# dx-core:dx-code-reviewer
#   · opus · project memory

# Auto-dispatch (most common):
/dx-pr-review    # skill picks agent
# → routes to dx-pr-reviewer agent
```
