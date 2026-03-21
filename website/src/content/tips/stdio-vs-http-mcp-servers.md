---
title: "stdio vs HTTP MCP Servers"
category: "MCP — System Integration"
focus: "Claude Code · CLI"
tags: ["stdio","HTTP","Config"]
overview: "MCP servers come in two flavors. stdio servers are spawned as a process per session — the AI runs a command and communicates via stdin/stdout. HTTP servers run continuously and the AI sends HTTP requests. Choose stdio for heavy tools (AEM, Chrome), HTTP for lightweight services (Figma)."
codeLabel: "Two flavors"
screenshot: null
week: 6
weekLabel: "Skills — Recipe Book"
order: 28
slackText: |
  🤖 Agentic AI Tip #28 — stdio vs HTTP MCP Servers
  
  MCP servers come in two flavors. Choosing the right one matters for reliability and performance.
  
  *stdio (standard I/O):*
  The AI spawns a process and communicates via stdin/stdout.
  ```json
  "command": "npx", "args": ["aem-mcp-server"]
  ```
  • *New process per session* — clean state every time
  • *Best for:* heavy tools that need isolation (AEM, Chrome DevTools)
  • *Pro:* no port conflicts, no "is the server running?" issues
  • *Con:* startup time on first use
  
  *HTTP:*
  The server runs continuously, AI sends HTTP requests.
  ```json
  "type": "http", "url": "http://127.0.0.1:3845/mcp"
  ```
  • *Always running* — instant responses
  • *Best for:* lightweight services (Figma desktop app)
  • *Pro:* fast, shared across sessions
  • *Con:* must be running before you start, port conflicts possible
  
  *Decision guide:*
  • Does it need browser/process access? → stdio
  • Is it a desktop app exposing an API? → HTTP
  • Do you need fresh state per session? → stdio
  • Do you need shared state across sessions? → HTTP
  
  💡 Try it: Check your `.mcp.json` — do you know which of your servers are stdio vs HTTP?
  
  #AgenticAI #Day28
---

```
# stdio — process per session
"AEM": {
  "type": "stdio",
  "command": "npx",
  "args": ["aem-mcp-server", "-t", "stdio"]
}

# HTTP — always-running service
"figma": {
  "type": "http",
  "url": "http://127.0.0.1:3845/mcp"
}
```
