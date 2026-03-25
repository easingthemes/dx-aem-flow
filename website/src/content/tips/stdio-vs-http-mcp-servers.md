---
title: "stdio vs HTTP MCP Servers"
category: "MCP — System Integration"
focus: "Claude Code · CLI"
tags: ["stdio","HTTP","Config"]
overview: "MCP servers come in two flavors. stdio servers are spawned as a process per session — the AI runs a command and communicates via stdin/stdout. HTTP servers run continuously and the AI sends HTTP requests. Choose stdio for heavy tools (AEM, Chrome), HTTP for lightweight services (Figma)."
screenshot: null
week: 6
weekLabel: "Skills — Recipe Book"
order: 28
slackOneLiner: "🤖 Tip #28 — MCP servers come in stdio (process per session) and HTTP (always running) — pick based on isolation needs and startup cost."
keyPointsTitle: "How Each Type Works"
actionItemsTitle: "When to Use Which"
keyPoints:
  - |
    **stdio (standard I/O)**
    - AI spawns a process and communicates via stdin/stdout
    - New process per session means clean state every time
    - Best for heavy tools needing isolation (AEM, Chrome DevTools)
    - No port conflicts, but has startup time on first use
  - |
    **HTTP (always running)**
    - Server runs continuously, AI sends HTTP requests
    - Always running means instant responses
    - Best for lightweight services (Figma desktop app)
    - Fast and shared across sessions, but must be running before you start
  - |
    **Config format difference**
    - stdio uses 'command' and 'args' fields
    - HTTP uses 'type: http' and 'url' fields pointing to the running endpoint
actionItems:
  - |
    **Decision guide**
    - Needs browser/process access? → stdio
    - Desktop app exposing an API? → HTTP
    - Need fresh state per session? → stdio
    - Need shared state across sessions? → HTTP
    - Worried about port conflicts? → stdio
  - |
    **stdio config example**
    - "command": "npx", "args": ["aem-mcp-server", "-t", "stdio"]
  - |
    **HTTP config example**
    - "type": "http", "url": "http://127.0.0.1:3845/mcp"
  - "**Check your .mcp.json** — Identify which of your servers are stdio vs HTTP and whether the choice matches the decision guide above"
---
