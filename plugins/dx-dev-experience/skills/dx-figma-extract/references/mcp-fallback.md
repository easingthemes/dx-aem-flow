# MCP Fallback Strategy

The skill uses the **official Figma desktop MCP** (`mcp__plugin_dx-dev-experience_figma__*`) which requires the Figma desktop app running with Dev Mode MCP enabled (port 3845).

## If desktop MCP fails (node not found, connection refused)

1. Print: `Desktop Figma MCP unavailable — ensure the Figma desktop app is open with the correct file active.`
2. **Do NOT fall back to `mcp__claude_ai_Figma__*`** (the remote/cloud MCP). The desktop MCP is preferred because:
   - No rate limits (cloud has 6/month on free, 200/day on Pro)
   - Assets served locally (downloadable via hook)
   - No OAuth required
3. Ask the user to open the file in Figma desktop and retry.

## Error Handling

- **Figma MCP not available:** Print `⚠️ Figma MCP not available — skipping extraction. Ensure Figma desktop app is running with the file open.` and STOP.
- **get_design_context fails:** Try `get_screenshot` + `get_metadata` as fallback. Save whatever is available.
- **get_screenshot fails:** Continue without screenshot, note in figma-extract.md.
- **get_variable_defs fails:** Continue without tokens, note in figma-extract.md.
