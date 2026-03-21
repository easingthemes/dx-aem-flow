---
name: aem-refresh
description: Refresh .ai/project/ seed data files from a local path or remote ADO docs repo. Use when project knowledge files need updating.
argument-hint: "[local-path-to-docs | blank for remote]"
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*", "AEM/*", "chrome-devtools-mcp/*"]
---

You refresh `.ai/project/` data files from an external source. This updates the project knowledge that agents use for component lookups, file resolution, and market-scoped searches.

## Source Resolution (three-source fallback)

### 1. User-provided local path (argument)

If the user passes a local path as argument:
1. Verify the path exists
2. Look for known file structure (see file table below)
3. Copy files to `.ai/project/`

### 2. Remote ADO docs repo

If no argument provided:
1. Read `.ai/config.yaml` → `aem.docs-repo` for the ADO repo URL
2. If set, use `mcp__ado__search_code` or ADO MCP file content tools to fetch each file by path
3. Default source paths in the docs repo (configurable via `aem.docs-repo-paths` in config.yaml):

| Source Path (in docs repo) | Destination | Mandatory |
|---|---|---|
| `docs/components/component-index.md` | `.ai/project/component-index-project.md` | yes |
| `docs/project.yaml` | `.ai/project/project.yaml` | yes |
| `docs/file-patterns.yaml` | `.ai/project/file-patterns.yaml` | yes |
| `docs/content-paths.yaml` | `.ai/project/content-paths.yaml` | no |
| `docs/architecture.md` | `.ai/project/architecture.md` | yes |
| `docs/features.md` | `.ai/project/features.md` | yes |

If `aem.docs-repo-paths` is set in config.yaml, use those paths instead.

### 3. No source available

If neither a local path nor `aem.docs-repo` is configured:
- Report error: "No seed data source available. Pass a local path as argument, or set `aem.docs-repo` in `.ai/config.yaml` via `/aem-init`."
- Do NOT fall back to bundled data — there is no bundled seed data.

## Copy Procedure

For each file in the table:

1. Check if source file exists at the expected path
2. If exists: copy to `.ai/project/` destination
3. If not exists and mandatory: report warning
4. If not exists and optional: skip silently

**Create `.ai/project/` directory if it doesn't exist.**

**Never overwrite `component-index.md`** (the aem-init auto-generated local index). Only write to `component-index-project.md` (the enriched cross-repo index).

## Verification

After copying, report:

```markdown
## Seed Data Refreshed

| File | Lines | Status |
|------|-------|--------|
| component-index-project.md | <N> | Updated (<M> components) |
| project.yaml | <N> | Updated |
| file-patterns.yaml | <N> | Updated |
| content-paths.yaml | <N> | Updated |
| architecture.md | <N> | Updated |
| features.md | <N> | Updated |

**Source:** <local path or ADO repo URL>
```

For `component-index-project.md`, count table rows to report component count (grep for `^|` lines excluding header).

## Rules

- **Never touches config.yaml** — this is data-only refresh. Brand/market/repo config is the user's responsibility (set by `/aem-init`).
- **Never overwrites component-index.md** — only writes to `component-index-project.md`
- **Three-source fallback** — local path → ADO docs repo → error. No bundled data.
- **Report line counts** — always report file sizes after copy for verification
- **Mandatory files** — warn if mandatory files are missing from source
- **Load MCP tools** — if using ADO MCP, call `ToolSearch("select:mcp__ado__search_code")` first

## Examples

1. `/aem-refresh` — Detects local seed data path from plugin config. Copies updated `project.yaml` (45 lines), `file-patterns.yaml` (32 lines), `content-paths.yaml` (18 lines), `architecture.md` (120 lines), and `features.md` (85 lines) to `.ai/project/`. Reports line counts for each file.

2. `/aem-refresh --source /path/to/docs-repo` — Uses the specified local path instead of the default. Finds all 6 seed files, copies them, and reports that `component-index-project.md` was updated with 52 components.

3. `/aem-refresh` (source not found locally, falls back to ADO) — Local path doesn't exist. Falls back to ADO docs repo via MCP, fetches seed files from the remote repository. Downloads and saves each file to `.ai/project/` with line counts reported.

## Troubleshooting

- **"Source path not found and ADO repo not configured"**
  **Cause:** Neither a local seed data path nor an ADO docs repo is configured.
  **Fix:** Run `/aem-init` to configure the seed data source in `.ai/config.yaml`, or provide a path explicitly with `--source`.

- **Mandatory files missing from source**
  **Cause:** The source directory or repo doesn't contain all expected seed files.
  **Fix:** Check the source for `project.yaml`, `file-patterns.yaml`, `content-paths.yaml`, `architecture.md`, and `features.md`. If files are missing from the docs repo, they need to be added there first.

- **Component index not updated**
  **Cause:** `/aem-refresh` only copies `component-index-project.md` — it does not regenerate it from AEM.
  **Fix:** To regenerate the component index from a live AEM instance, run `/aem-init` with the component scan option. `/aem-refresh` only syncs pre-built seed data files.
