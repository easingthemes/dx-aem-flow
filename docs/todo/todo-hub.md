# Hub TODO

## V2 Rich Status Tracking

**Added:** 2026-03-27
**Problem:** V1 hub status is intentionally minimal (running/done/blocked/failed per repo via status.json). For larger teams and async workflows where the user isn't watching terminals, richer progress tracking would help — knowing which pipeline phase each repo is in, how many steps are done, whether PRs exist, etc.
**Scope:** `plugins/dx-hub/skills/dx-hub-status/SKILL.md`, `plugins/dx-hub/shared/hub-dispatch.md`
**Done-when:** `dx-hub-status <ticket-id>` shows per-repo pipeline phase (requirements/planning/execution/PR), step progress (3/7), and PR links — all derived by reading each repo's `.ai/specs/<id>-*/` directory, not by requiring repos to write to hub.

**Approach:**
- `dx-hub-status` already has repo paths from config — it can glob each repo's spec dir
- Map files to phases: `raw-story.md` → fetched, `explain.md` → requirements, `implement.md` → planned, `step-N-*.md` → executing (count vs total), `pr.md` → PR created
- Read `implement.md` header for total step count, count `step-*.md` files for progress
- Check ADO for linked PRs via MCP
- No changes to non-hub skills needed — purely reads existing spec convention
- Keep V1 status.json for quick running/done/blocked checks, add rich view as `--detail` flag

## Cross-Platform Terminal Automation

**Added:** 2026-03-27
**Problem:** `vscode-automator` uses AppleScript and is macOS-only. Hub dispatch via VS Code terminals only works on macOS. Linux and Windows users cannot use `/dx-hub-dispatch`.
**Scope:** `tools/vscode-automator/server.mjs`, `plugins/dx-hub/skills/dx-hub-dispatch/SKILL.md`
**Done-when:** Hub dispatch works on macOS, Linux, and Windows. Terminal automation uses a cross-platform mechanism (e.g., VS Code extension API, `workbench.action.terminal.sendSequence`, or a platform-abstraction layer in vscode-automator).

**Approach:**
- Option A: VS Code extension that exposes terminal control via MCP (most robust, most work)
- Option B: Use `xdotool` on Linux, PowerShell on Windows as platform backends in vscode-automator
- Option C: Use VS Code's `workbench.action.terminal.sendSequence` command via a VS Code task or keybinding hack
- Evaluate after V1 usage confirms the terminal-dispatch model works well

## Publish vscode-automator as Standalone npm Package

**Added:** 2026-03-27
**Problem:** `vscode-automator` is a local file in `tools/vscode-automator/`. Plugin `.mcp.json` can't reference it with a stable path because the path breaks when the plugin is installed via marketplace into a consumer project. Currently `dx-hub-init` must resolve the path at init time, which is fragile.
**Scope:** `tools/vscode-automator/`, `plugins/dx-hub/skills/dx-hub-init/SKILL.md`, `plugins/dx-hub/shared/hub-dispatch.md`
**Done-when:** `npm info vscode-automator-mcp` returns package metadata, and the hub `.mcp.json` uses `"command": "npx", "args": ["-y", "vscode-automator-mcp"]` — same pattern as `aem-mcp-server` in dx-aem.

**Approach:**
- Add `bin` field to `tools/vscode-automator/package.json` pointing at `server.mjs`
- Set `name: "vscode-automator-mcp"`, add description, keywords, license, repository
- Add a README with usage examples (standalone MCP, Claude Code plugin config, skill usage)
- `npm publish`
- Update `dx-hub-init` Step 5 to use `npx -y vscode-automator-mcp` instead of resolving a local path
- The MCP server is general-purpose (not tied to dx plugins) — useful for demo capture, multi-session orchestration, any VS Code automation via MCP
