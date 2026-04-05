---
name: aem-snapshot
description: Snapshot a component's AEM state before development — dialog fields, properties, and pages where it's used. Saves baseline to specs for later comparison. Use before starting implementation on a component.
argument-hint: "[component-name] (e.g., hero, card, banner)"
context: fork
agent: aem-inspector
allowed-tools: ["read", "edit", "search", "write", "agent", "AEM/*", "chrome-devtools-mcp/*"]
---

**Platform note:** This skill uses `context: fork` + `agent: aem-inspector` for isolated execution. If subagent dispatch is unavailable (e.g., VS Code Chat), you may run inline but AEM MCP tools (`AEM/*`, `chrome-devtools-mcp/*`) must be available. If they are not, inform the user: "AEM snapshot requires AEM and Chrome DevTools MCP servers. Please use Claude Code or Copilot CLI."

## Applicability Check (Cross-Repo Dependencies)

Before running, determine if AEM verification is meaningful from the current repo alone.

Read `.ai/config.yaml` for `repos` section. If the project uses multiple repos (e.g., separate BE and FE):

**Backend-only repos:**
- CAN verify: dialog changes, HTL template changes, model/exporter JSON data, component definitions
- CANNOT verify: visual rendering that depends on FE code from another repo
- **Skip if changes require FE code** from a separate frontend repo

**Frontend-only repos:**
- CAN verify: FE-only changes where the BE is already deployed to AEM (styling, JS behavior, FE rendering)
- CANNOT verify: changes that depend on new BE code not yet deployed
- **Skip if changes require BE code** from a separate backend repo not yet deployed to AEM

**How to determine:** Check `.ai/specs/*-*/explain.md` or `.ai/specs/*-*/research.md` for "Repos Required" or "Cross-Repo Scope". If the other repo's changes are a prerequisite, skip.

## Task

Capture a baseline snapshot of the AEM component **$ARGUMENTS** before development begins.

If no component name was provided, check `.ai/specs/*-*/research.md` or `.ai/specs/*-*/explain.md` in the project to infer the component name. If unclear, state what you need and stop.

## Steps

### 1. Locate the component

Read `.ai/config.yaml` for `aem.component-path` to get the component root (e.g., `/apps/myproject/components/content/`).

Check if `<aem.component-path>/$ARGUMENTS` exists on AEM.
If not found, write: "Component not found on AEM. Not deployed yet. Nothing to snapshot." and stop.
Extract: `jcr:title`, `componentGroup`.

### 2. Walk the dialog

Get all dialog fields by walking the dialog tree.

### 2b. Read market/site config for scoping

Read `.ai/config.yaml` `aem.content-paths` (or discover from AEM using `mcp__plugin_dx-aem_AEM__fetchSites`). Use these to **scope page searches** in step 3 — search configured content paths only.

Also check `.ai/project/component-index.md` (or `.ai/component-index.md`) — if the component name appears there, note its resource type pattern.

### 3. Find pages using the component

Find pages using the component — **try multiple queries before concluding 0 pages:**

Read the resource type pattern from `.ai/config.yaml` `aem.resource-type-pattern`. Search configured content paths first (more targeted, faster). Then:

1. Exact resourceType query under configured content paths
2. LIKE query (catches path prefix variations)
3. `searchContent` / `enhancedPageSearch` by component name
4. `scanPageComponents` on known content pages

**Never report "0 pages found" after a single failed query.** Extract page paths (trim after `/jcr:content`). Count total. Limit to 10.

### 4. Get authored config from the most relevant page

For the first page found, read the component node (depth 4) to capture current property values.

### 5. Find the spec directory

Look for the most recently modified `.ai/specs/*-*/` directory using Glob. If none exists, use `.ai/specs/component-$ARGUMENTS/` and create it.

### 6. Write the baseline

Read `shared/provenance-schema.md`. Write `<spec-dir>/aem-before.md` with provenance frontmatter (use `agent: aem-snapshot`, confidence `high`):

```markdown
---
provenance:
  agent: aem-snapshot
  model: <your-model-tier>
  created: <ISO-8601 timestamp>
  confidence: high
  verified: false
---
# AEM Baseline: <title> (`<name>`)

**Captured:** <date>
**Component:** `<aem.component-path>/<name>`
**Resource type:** `<resource-type>`
**Pages using component:** <N>

## Component Definition

- **Title:** <jcr:title>
- **Group:** <componentGroup>

## Dialog Fields (<N> total)

### Tab: <tab-title>

| Field | Type | Label | JCR Property |
|-------|------|-------|-------------|
| ... | ... | ... | ... |

### Multifield: <name> (inside <tab>)

| Field | Type | Label | JCR Property |
|-------|------|-------|-------------|
| ... | ... | ... | ... |

## Current Authored Config

_From: <page-path>_

| Property | Value |
|----------|-------|
| ... | ... |

_(or "No pages found — component not yet authored")_

## Pages Using This Component (<N> total, top 3)

| # | Page Path | Author Link |
|---|-----------|-------------|
| 1 | /content/... | <author-url>/editor.html/content/....html |

## Summary

- **Total fields:** <N>
- **Tabs:** <N>
- **Multifields:** <N>
- **Pages found:** <N>
```

Use the author URL from `.ai/config.yaml` `aem.author-url` (defaults to `http://localhost:4502`).

### 7. Return summary

Return ONLY:
- Component title and group
- Total field count, tab count, multifield count
- Number of pages found
- Top 3 page author links (or "none found")
- Spec dir path where aem-before.md was saved

## Success Criteria

- [ ] `aem-before.md` exists in spec directory
- [ ] All current dialog fields captured
- [ ] Pages using this component listed
- [ ] Snapshot timestamp recorded

## Examples

1. `/aem-snapshot hero` — Connects to AEM author, fetches the hero component dialog structure (12 fields across 3 tabs, 2 multifields), finds 8 pages using the hero component, and saves the baseline to `.ai/specs/<id>-<slug>/aem-before.md`.

2. `/aem-snapshot productlisting 2416553` — Snapshots the productlisting component for story #2416553. Captures dialog fields, current JCR properties on 3 pages, and saves to the story's spec directory. This baseline will be compared by `/aem-verify` after deployment.

3. `/aem-snapshot card` (AEM not reachable) — Attempts to connect to AEM author but gets no response. Reports "AEM not reachable at http://localhost:4502" and saves a partial snapshot from codebase analysis only (dialog XML structure, no live page data).

## Troubleshooting

- **"Component not found in AEM"**
  **Cause:** The component name doesn't match the AEM resource type, or the component isn't deployed yet.
  **Fix:** Check the component's `.content.xml` for the actual `jcr:title` and resource type. Try using the exact folder name from `ui.apps/` (e.g., `productlisting` not `product-listing`).

- **"AEM not reachable"**
  **Cause:** AEM author instance is not running at the configured URL.
  **Fix:** Start AEM locally or update `aem.author-url` in `.ai/config.yaml`. The snapshot can still capture dialog structure from source XML files, but live page data will be missing.

- **No pages found for the component**
  **Cause:** The component is new (not yet placed on any pages) or the content paths in config don't cover where it's used.
  **Fix:** Check `aem.content-paths` in `.ai/config.yaml` to ensure the search paths include where the component is authored. For new components, this is expected — the snapshot will have zero pages in the baseline.
