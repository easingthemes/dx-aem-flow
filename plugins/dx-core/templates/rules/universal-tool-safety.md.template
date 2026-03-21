---
description: MCP tool constraints and edit discipline — prevents recurring friction patterns
---

# Tool Safety

## MCP Constraints

- **Chrome DevTools MCP is main-agent only.** It is NOT available in subagents (Task tool agents). Always use Chrome DevTools tools directly in the main conversation, never delegate browser automation to a subagent.
- **AEM MCP is environment-agnostic.** It connects to whichever AEM instance is configured (author URL from `.ai/config.yaml`). Pass JCR content paths to MCP tools, not repository URLs. The MCP server handles instance routing internally.

## Edit Discipline

- **Scope edits narrowly.** When editing files, change only what's requested. If a linter or formatter reformats unrelated lines, revert those changes before committing. Never let auto-formatting bleed into unrelated code.
