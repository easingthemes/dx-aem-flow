# dx-hub-dispatch — example and troubleshooting

## Example: Copilot CLI without vscode-automator

```
/dx-hub-dispatch 2471234 brand-a-site
```
`launcher: auto` finds no vscode-automator tools → writes `state/2471234/launch/brand-a-site.sh` and prints `bash '<path>'` to start it. With `hub.launcher: terminal` the hub opens a Terminal.app window for it instead.

## Troubleshooting

### VS Code terminals not opening
**Cause:** vscode-automator MCP server not running in this session, or macOS Accessibility permission not granted.
**Fix:** The dispatch already fell back to `print` and listed one `bash '<script>'` line per repo — run those. To get terminals opened for you: register vscode-automator in the hub's `.mcp.json` (Claude Code) and grant your terminal app Accessibility permission, or set `hub.launcher: terminal` (macOS Terminal.app, works from any host).

### "Project selection cancelled" from ADO
**Cause:** an ADO call without `project`.
**Fix:** set `repos[].ado-project` for every repo (or `scm.project`). Dispatch passes a project on every call and reads the ticket's own `System.TeamProject` after the first fetch.

### Claude not starting in terminal
**Cause:** `hub.terminal-delay` too short — Claude CLI takes time to initialize.
**Fix:** Increase `hub.terminal-delay` in `.ai/config.yaml` (try `8` or `10`).

### Copilot CLI: "Unknown command" in a repo terminal
**Cause:** the skill was typed without its plugin prefix.
**Fix:** use `/dx-core:<skill>` in the delegation prompt (see Launch terminals). Run `copilot` in that repo and check the plugin is enabled if the prefixed name also fails.

### Wrong repo detected
**Cause:** the title, area path and tags name no repo or keyword, and the FE/BE guess picked the wrong repos.
**Fix:** add `keywords: [<product or brand words>]` to the repo in `repos[]`, or re-run with explicit repo names: `/dx-hub-dispatch <id> <repo-name>`.

### Raw ticket not found in repo
**Cause:** Pre-seed step failed (directory permissions or path mismatch).
**Fix:** Check that repo paths in config are correct. The raw file should be at `<repo>/.ai/specs/<id>-<slug>/raw-story.md`.
