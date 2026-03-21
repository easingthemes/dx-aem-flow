# Demo Page Setup for FE Verification

This reference covers creating or reusing a demo page for frontend visual verification. The process follows the same conventions as `aem-verify` and `aem-inspector`.

## Check for Existing Demo Page

1. Read `aem.demo-parent-path` from `.ai/config.yaml` (e.g., `/content/brand-a/ca/en/ca/en/demo`)
2. Determine `<slug>` from spec directory name
3. Check if `<demo-parent-path>/<slug>` exists:
   ```
   mcp__plugin_dx-aem_AEM__getPageProperties
     pagePath: "<demo-parent-path>/<slug>"
   ```
4. If exists → reuse. Verify component is present via `scanPageComponents`.
5. If not → create following steps below.

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
