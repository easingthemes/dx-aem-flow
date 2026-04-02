# GitHub Support

## GitHub as tracker/SCM platform

**Added:** 2026-04-02
**Problem:** dx-core currently supports ADO and Jira as work-item trackers. GitHub Issues/Projects is a widely-used alternative but is not supported — users on GitHub-only workflows cannot use dx skills for ticket analysis, PR linking, or work-item queries.
**Scope:** `plugins/dx-core/` — dx-init (tracker selection), dx-req/dx-ticket-analyze (issue reading), dx-pr (PR linking), config.yaml schema (`tracker:` section), MCP server config, templates.
**Done-when:** `grep -r 'github' plugins/dx-core/skills/dx-init/SKILL.md` shows a GitHub option in the tracker selection step; `.ai/config.yaml` schema supports `tracker.type: github`; at least dx-ticket-analyze can read a GitHub issue.
**Approach:** (TBD) — likely needs: GitHub MCP server in .mcp.json, new `tracker.type: github` config option, skill conditionals for GitHub API shapes (issues vs work items, PR model differences). Consider whether GitHub CLI (`gh`) is sufficient or a dedicated MCP server is needed.

## dx-init: skip ADO-specific files when scm.provider != ado

**Added:** 2026-04-02
**Problem:** dx-init unconditionally copies ADO-specific data files to the consumer project regardless of `scm.provider`. GitHub-only users end up with unusable files: `ado-comments/` templates (6 files), `wiki/` templates (2 files referencing "ADO #"), and `audit.sh` (ADO pipeline + AWS Lambda infra). Additionally, spec templates (`explain.md.template`, `research.md.template`, `dod.md.template`) hardcode "ADO #\<id\>" instead of a provider-neutral format.
**Scope:**
- `plugins/dx-core/skills/dx-init/SKILL.md` — Step 4 (directory + file copy) at lines ~158-162
- `plugins/dx-core/data/templates/ado-comments/` — 6 files, skip entirely when provider != ado
- `plugins/dx-core/data/templates/wiki/` — 2 files, skip entirely when provider != ado
- `plugins/dx-core/data/lib/audit.sh` — skip when provider != ado (it wraps `az pipelines` and `aws lambda`)
- `plugins/dx-core/data/templates/spec/explain.md.template` — replace "ADO #\<id\>" with "#\<id\>"
- `plugins/dx-core/data/templates/spec/research.md.template` — replace "ADO #\<id\>" with "#\<id\>"
- `plugins/dx-core/data/templates/spec/dod.md.template` — replace "ADO #\<id\>" with "#\<id\>"
**Done-when:** Running dx-init with `scm.provider: github` in config produces no files under `.ai/templates/ado-comments/` or `.ai/templates/wiki/`, no `.ai/lib/audit.sh`, and spec templates use "#\<id\>" not "ADO #\<id\>". Verify: `grep -r 'ADO #' .ai/templates/spec/` returns no matches.
**Approach:** Add a provider check early in Step 4 of SKILL.md. Gate the copy of `ado-comments/`, `wiki/`, and `audit.sh` behind `if scm.provider == ado`. For spec templates, replace hardcoded "ADO #\<id\>" with a neutral format that works for any provider.
