# GitHub Support

## GitHub as tracker/SCM platform

**Added:** 2026-04-02
**Problem:** dx-core currently supports ADO and Jira as work-item trackers. GitHub Issues/Projects is a widely-used alternative but is not supported — users on GitHub-only workflows cannot use dx skills for ticket analysis, PR linking, or work-item queries.
**Scope:** `plugins/dx-core/` — dx-init (tracker selection), dx-req/dx-ticket-analyze (issue reading), dx-pr (PR linking), config.yaml schema (`tracker:` section), MCP server config, templates.
**Done-when:** `grep -r 'github' plugins/dx-core/skills/dx-init/SKILL.md` shows a GitHub option in the tracker selection step; `.ai/config.yaml` schema supports `tracker.type: github`; at least dx-ticket-analyze can read a GitHub issue.
**Approach:** (TBD) — likely needs: GitHub MCP server in .mcp.json, new `tracker.type: github` config option, skill conditionals for GitHub API shapes (issues vs work items, PR model differences). Consider whether GitHub CLI (`gh`) is sufficient or a dedicated MCP server is needed.
