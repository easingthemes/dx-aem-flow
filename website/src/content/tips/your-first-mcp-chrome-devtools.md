---
title: "Your First MCP: Chrome DevTools"
category: "MCP — System Integration"
focus: "Claude Code"
tags: ["Chrome","DevTools","Screenshots"]
overview: "The easiest MCP to start with is Chrome DevTools. One line in your .mcp.json, zero API keys needed. The AI can then take screenshots, navigate pages, click elements, inspect DOM, read console logs, and analyze network requests. Visual verification becomes possible."
codeLabel: "Zero-config MCP"
screenshot: null
week: 7
weekLabel: "Skills — Advanced"
order: 31
slackText: |
  🤖 Agentic AI Tip #31 — Your First MCP: Chrome DevTools
  
  If you're going to set up one MCP server, make it Chrome DevTools. Zero config, zero API keys, instant value.
  
  *Setup:*
  Add this to your `.mcp.json`:
  ```json
  {
    "mcpServers": {
      "chrome-devtools": {
        "command": "npx",
        "args": ["chrome-devtools-mcp@latest"]
      }
    }
  }
  ```
  
  *What you can do:*
  • 📸 *Take screenshots* — "screenshot localhost:3000"
  • 🧭 *Navigate pages* — "open localhost:3000/login"
  • 🖱️ *Click elements* — "click the submit button"
  • 🔍 *Inspect DOM* — "what's the HTML structure of the nav?"
  • 📋 *Read console* — "are there any console errors?"
  • 🌐 *Monitor network* — "what API calls does the page make?"
  
  *Real workflow:*
  1. AI implements a component
  2. AI takes a screenshot to verify it renders
  3. AI compares screenshot against Figma reference
  4. AI fixes visual differences
  
  This turns "I can't see the browser" into "Let me check how it looks." Visual verification without leaving the terminal.
  
  💡 Try it: Add the config above, restart Claude Code, and ask it to take a screenshot of any localhost page.
  
  #AgenticAI #Day31
---

```
# Add to .mcp.json:
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["chrome-devtools-mcp@latest"]
    }
  }
}

# Then in Claude Code:
"Take a screenshot of localhost:4502
 and check if the hero renders"
```
