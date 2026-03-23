# Demo Page Setup

This reference covers the page selection rule for all AEM skills that need a page to demo, verify, or document a component. The process follows the same conventions across `aem-verify`, `aem-doc-gen`, `aem-fe-verify`, and `aem-qa-handoff`.

## Page Selection Rule (applies to ALL AEM skills)

**New pages are ONLY created for new components.** For updates to existing components (enhancements, a11y fixes, bug fixes), find the best representative existing page that already has the component and reuse it.

| Scenario | Action |
|----------|--------|
| **New component** (not on any page) | Create new demo page under `aem.demo-parent-path` |
| **Existing component update** | Find best existing page with the component, reuse it |
| **A11y / bug fix** | Find best existing page with the component, reuse it |
| **Multiple components affected** | Find best page per component (may be same page or different pages) |
| **No pages found** (shouldn't happen for existing components) | Fall back to creating a new page |

### Finding the best representative page

1. Search for pages using the component (via `searchContent`, `enhancedPageSearch`, or `scanPageComponents`)
2. **Prefer:** production content pages over demo/test pages
3. **Prefer:** pages where the component is prominently used (not deeply nested or hidden)
4. **Prefer:** pages in the same market/brand as the story scope
5. Skip pages under `/demo/`, `/test-specs/`, or similar AI-created paths — these are fallbacks, not representative

### When to reuse vs create

- **Reuse** means using the page as-is for screenshots, QA URLs, and verification. Do NOT modify production pages.
- **Create** means making a new page under `aem.demo-parent-path` with the component added and configured.

## Check for Existing Demo Page

1. Read `aem.demo-parent-path` from `.ai/config.yaml` (e.g., `/content/brand-a/ca/en/ca/en/demo`)
2. Determine `<slug>` from spec directory name
3. Check if `<demo-parent-path>/<slug>` exists:
   ```
   mcp__plugin_dx-aem_AEM__getPageProperties
     pagePath: "<demo-parent-path>/<slug>"
   ```
4. If exists → reuse. Verify component is present via `scanPageComponents`.
5. If not → follow the Page Selection Rule above: for existing components, find a representative page first. Only create if the component is truly new.

## Page Structure Discovery

### From existing pages

1. Find pages using the component (try multiple search strategies):
   - Exact resourceType query via `searchContent`
   - LIKE query: `%/components/%/<name>`
   - `enhancedPageSearch` with component name
   - `scanPageComponents` on known pages
2. From the first production page found (skip demo/test pages):
   - Get language root (check `jcr:language` property walking up, or `fetchLanguageMasters`)
   - Get template (`jcr:content/cq:template`)
   - Get container chain (parent `sling:resourceType` from root to component)

### For new components (no existing pages)

1. Read `explain.md` or `raw-story.md` for target brand/site
2. Find a similar component in the same `componentGroup`
3. Query where THAT component is used
4. Use its page structure
5. Last resort: `fetchSites` → first site → find language root

### Language root caveat

Some sites have duplicated country/lang segments: `/content/brand/ca/en/ca/en/...`. The language root is the FULL path before content pages start. **Always verify** — do not assume fixed depth.

## Page Creation

1. Ensure demo parent path exists — create folder page if missing
2. Create page: `<demo-parent-path>/<slug>` using discovered template
3. Recreate container chain (e.g., section → responsivegrid)
4. Add component to correct container
5. Cache structure in `<spec-dir>/demo/page-structure.md`

## Demo Data Configuration

**Priority: real data from existing instances.**

1. Find a page with an authored instance of the component
2. `getNodeContent` (depth 5) on that instance to extract properties
3. Copy authored data properties to demo component via `updateComponent`
4. Skip JCR internals (`jcr:*`, `sling:*`, `cq:*`)
5. Mock only missing fields (new fields with no existing values):
   - Text: "Test <fieldLabel>"
   - Boolean: `true`
   - Select: first option

**If component already has data:** skip configuration.

## AEM Login Handling

When navigating Chrome to the demo page, check for login redirect. If URL contains `/libs/granite/core/content/login.html`:

```js
(() => {
  const u = document.getElementById('username');
  const p = document.getElementById('password');
  if (!u || !p) return { onLoginPage: false };
  u.value = 'admin'; p.value = 'admin';
  u.dispatchEvent(new Event('input', { bubbles: true }));
  p.dispatchEvent(new Event('input', { bubbles: true }));
  return { filled: true };
})()
```

Then click submit and re-navigate to the demo page.
