---
title: "Your First MCP: Chrome DevTools"
category: "MCP — System Integration"
focus: "Claude Code"
tags: ["Chrome","DevTools","Screenshots"]
overview: "The easiest MCP to start with is Chrome DevTools. One line in your .mcp.json, zero API keys needed. The AI can then take screenshots, navigate pages, click elements, inspect DOM, read console logs, and analyze network requests. Visual verification becomes possible."
screenshot: null
week: 7
weekLabel: "Skills — Advanced"
order: 31
slackOneLiner: "🤖 Tip #31 — Chrome DevTools MCP: zero config, zero API keys — the AI can now see your browser, take screenshots, and verify UI visually."
keyPointsTitle: "What It Unlocks"
actionItemsTitle: "Get Started in 2 Minutes"
keyPoints:
  - "**Zero-config setup** — Add one entry to .mcp.json with command 'npx' and args 'chrome-devtools-mcp@latest'. No API keys, no authentication, no server to manage."
  - |
    **Full browser capabilities**
    - Take screenshots of any page
    - Navigate to URLs, click elements, fill forms
    - Inspect DOM structure and computed styles
    - Read console logs and monitor network requests
  - "**Visual verification workflow** — AI implements a component, takes a screenshot to verify it renders, compares against a Figma reference, and fixes visual differences. All without leaving the terminal."
  - "**The fundamental unlock** — Turns 'I can't see the browser' into 'Let me check how it looks.' This is the key enabler for UI development with AI — visual verification without tab-switching."
actionItems:
  - |
    **Add Chrome DevTools MCP to your .mcp.json**
    - "command": "npx"
    - "args": ["chrome-devtools-mcp@latest"]
  - "**Restart Claude Code** — MCP servers are loaded at startup, so restart after adding the config"
  - "**Test it** — Ask the AI to take a screenshot of any localhost page and describe what it sees"
  - |
    **Where it shines**
    - Bug verification — AI follows repro steps and screenshots each one
    - Figma comparison — screenshot prototype, compare against Figma reference
    - Responsive testing — screenshot at different viewport widths
---
