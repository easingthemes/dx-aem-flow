---
name: aem-page-search
description: Find AEM pages that use a specific component. Returns page paths with clickable author URLs. Use when you need to find where a component is used on the AEM instance.
argument-hint: "[component-name] (e.g., hero, banner, accordion)"
allowed-tools: ["read", "edit", "search", "write", "agent", "AEM/*", "chrome-devtools-mcp/*"]
---

You find every AEM page that uses a given component and return clickable author URLs.

## 1. Parse Input

The argument is a component name. Read `.ai/config.yaml` for:
- `aem.resource-type-pattern` — to build the full resource type
- `aem.component-prefix` — to normalize the name
- `aem.content-paths` — to scope the search
- `aem.author-url` — for building author URLs (defaults to `http://localhost:4502`)
- `aem.author-url-qa` — for QA/stage author URLs (if configured)

Build the full resource type: substitute `<name>` in `aem.resource-type-pattern` with the component name.

If no argument provided, ask the user for the component name.

## 2. Load AEM MCP Tools

```
ToolSearch query: "+AEM search"
```

This loads `mcp__plugin_dx-aem_AEM__searchContent`, `mcp__plugin_dx-aem_AEM__enhancedPageSearch`, and `mcp__plugin_dx-aem_AEM__scanPageComponents`.

## 3. Search AEM Content

Search each configured content path using `mcp__plugin_dx-aem_AEM__searchContent`:

```
path: {content-path}           # e.g., /content/mysite/en
fulltext: {component_name}
limit: 20
```

**Always also search Experience Fragments** (components often live on XF, not pages):
```
path: /content/experience-fragments/{site-segment}
fulltext: {component_name}
limit: 20
```
Derive the XF path from the content path pattern.

### If initial search returns 0 results

Try multiple strategies before concluding 0 pages:

1. **Exact resourceType JCR query:**
   ```sql
   SELECT * FROM [nt:unstructured] WHERE [sling:resourceType] = '<resource-type>' AND ISDESCENDANTNODE('/content')
   ```

2. **LIKE query** (catches path prefix variations):
   ```sql
   SELECT * FROM [nt:unstructured] WHERE [sling:resourceType] LIKE '%/components/%/<name>' AND ISDESCENDANTNODE('/content')
   ```

3. **Enhanced page search** by component name as keyword

4. **Scan known pages** using `scanPageComponents` on likely pages (homepage, test pages)

**Never report "0 pages found" after trying only one query.** Try at least strategies 1-3.

## 4. Extract Page Paths

AEM returns full JCR paths like:
```
/content/mysite/en/products/hero-page/jcr:content/root/.../hero
```

Strip everything from `jcr:content` onward to get the page path:
```
/content/mysite/en/products/hero-page
```

Deduplicate — multiple component instances on the same page should produce one entry.

## 5. Build Author URLs

Use the QA author URL if configured (`aem.author-url-qa`), otherwise fall back to `aem.author-url`.

Format: `<author-url>/editor.html{pagePath}.html`

Extract a human-readable page name from the last path segment.

## 6. Verify (optional, for top 1-2 pages)

If time permits, use `mcp__plugin_dx-aem_AEM__scanPageComponents` on the first found page to:
- Confirm the component is actually there (search can have false positives)
- Get the component's authored properties as bonus context

## 7. Present Results

```markdown
## AEM Pages: <component_name>

**Resource type:** `<resource-type>`
**Total found:** <count> pages

### <Site/Section Name>
| Page | Author URL |
|------|-----------|
| <page-name> | [Open in Author](<author-url>/editor.html<path>.html) |

### Experience Fragments
| Fragment | Author URL |
|----------|-----------|
| <fragment> | [Open in Author](<author-url>/editor.html<path>.html) |

### Not Found
- <paths searched with zero results>
```

## Rules

- **Load tools first** — call `ToolSearch("+AEM")` before any MCP calls
- **Config first** — read `.ai/config.yaml` for content paths and author URLs before any AEM query
- **Config-driven paths** — search ONLY configured content paths. Don't add extras.
- **Multiple strategies** — never conclude "0 pages" after a single query
- **Clickable URLs** — every page must have a clickable author URL
- **Don't forget XF** — many components live on Experience Fragments, not regular pages
- **Deduplicate** — same page path should appear once even if component is used multiple times
- **Handle AEM unavailable** — if MCP calls fail, report "AEM author not reachable" and return what was found in docs
- **Keep it compact** — return the table, not raw JSON

## Examples

1. `/aem-page-search hero` — Searches configured content paths for pages using the hero component. Finds 12 regular pages and 3 experience fragments. Returns a table with page paths and clickable author URLs for each.

2. `/aem-page-search productlisting` — Searches across all configured markets (gb, de, fr). Finds the component on 5 PLP pages and 2 experience fragments. Groups results by content type (Pages vs Experience Fragments) with author editor links.

3. `/aem-page-search card` (no results from first query) — Initial JCR query returns 0 results. Falls back to alternative search strategies: searches by resource type variation, checks experience fragment paths separately. Finds 4 pages on second attempt using the full resource type path.

## Troubleshooting

- **"AEM author not reachable"**
  **Cause:** AEM instance is not running or MCP connection failed.
  **Fix:** Start AEM locally or verify `aem.author-url` in `.ai/config.yaml`. The skill requires a live AEM instance — it cannot search pages offline.

- **0 pages found but component is definitely used**
  **Cause:** The component resource type doesn't match what was searched, or the content paths in config don't cover the right directories.
  **Fix:** Check the exact `sling:resourceType` in the component's `.content.xml`. Also verify `aem.content-paths` in `.ai/config.yaml` includes the paths where the component is authored (e.g., `/content/brand-a/gb/en/`).

- **Duplicate entries in results**
  **Cause:** The same page appears in multiple search strategies.
  **Fix:** This shouldn't happen — the skill deduplicates by page path. If you see duplicates, report it as a bug. The table should show each page path only once.
