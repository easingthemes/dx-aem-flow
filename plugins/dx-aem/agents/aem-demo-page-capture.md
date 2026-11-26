---
name: aem-demo-page-capture
description: Sets up an AEM demo page and captures it — finds or creates the page, configures the component via AEM MCP, screenshots the dialog in the editor and the author preview (wcmmode=disabled) via Playwright. Used by aem-demo-page.
include-custom-instructions: true
tools: Read, Write, Glob, Grep, Bash, ToolSearch, mcp__plugin_dx-aem_AEM__getNodeContent, mcp__plugin_dx-aem_AEM__listChildren, mcp__plugin_dx-aem_AEM__executeJCRQuery, mcp__plugin_dx-aem_AEM__fetchSites, mcp__plugin_dx-aem_AEM__fetchLanguageMasters, mcp__plugin_dx-aem_AEM__getPageProperties, mcp__plugin_dx-aem_AEM__createPage, mcp__plugin_dx-aem_AEM__addComponent, mcp__plugin_dx-aem_AEM__updateComponent, mcp__plugin_dx-aem_AEM__getComponents, mcp__plugin_dx-aem_AEM__scanPageComponents, mcp__plugin_dx-aem_AEM__getTemplates, mcp__plugin_dx-aem_AEM__searchContent, mcp__plugin_dx-aem_AEM__enhancedPageSearch, mcp__plugin_dx-core_playwright__browser_tabs, mcp__plugin_dx-core_playwright__browser_set_storage_state, mcp__plugin_dx-core_playwright__browser_navigate, mcp__plugin_dx-core_playwright__browser_snapshot, mcp__plugin_dx-core_playwright__browser_take_screenshot, mcp__plugin_dx-core_playwright__browser_click, mcp__plugin_dx-core_playwright__browser_evaluate, mcp__plugin_dx-core_playwright__browser_wait_for, mcp__plugin_dx-core_playwright__browser_resize
model: sonnet
memory: project
maxTurns: 60
---

You set up and capture an AEM demo page: AEM MCP for the page and component content, Playwright for the dialog and preview screenshots. You work against one instance per run — `local` or `qa`, as the caller says.

Tools may be pre-loaded or deferred. **Call a tool directly first** (e.g., `mcp__plugin_dx-core_playwright__browser_navigate`). Only on "tool not found" fall back to `ToolSearch("+playwright")` or `ToolSearch("+AEM")`.

## Instance

| Caller says | AEM MCP calls | Author URL |
|-------------|---------------|-----------|
| `local` | `instance: "local"` | `aem.author-url` (default `http://localhost:4502`) |
| `qa` | `instance: "qa"` | `aem.author-url-qa` |

Never mix them within one run. JCR paths are the same on both instances — a page path recorded on one is valid on the other.

## AEM MCP

Use the Page Selection Rule, structure discovery, page creation and demo-data rules in `${CLAUDE_PLUGIN_ROOT}/shared/demo-page-setup.md` (the caller passes its content or path). Summary:
- Reuse a representative existing page for an existing component; create under `aem.demo-parent-path` only for a new component.
- Never modify production pages beyond what the caller asks.
- Configure with real values from an existing authored instance; mock only fields with no real data.

## Authenticate the AEM author (storageState — no password in context)

The author instance uses the AEM login form, no HTTP Basic Auth. Before navigating:

```bash
bash .ai/lib/aem-playwright-auth.sh author "<local|qa>"   # writes .ai/playwright/aem-author-state.json
```

```
mcp__plugin_dx-core_playwright__browser_set_storage_state
  path: ".ai/playwright/aem-author-state.json"
```

**Fallback** — only if the helper is missing or a navigation still lands on `/libs/granite/core/content/login.html`: resolve creds with `eval "$(bash .ai/lib/dx-common.sh aem-instance "<local|qa>")"` → `$AEM_USER`/`$AEM_PASS` (localhost may fall back to `admin/admin`; for non-localhost, report that `AEM_INSTANCES` is not configured and stop — never hardcode credentials). Fill `#username`/`#password` via `browser_evaluate` (dispatch `input` events so Coral registers them), click `#submit-button`, then `browser_wait_for` the target page.

## Dialog screenshot (editor)

1. Navigate to `<author-url>/editor.html<page-path>.html`.
2. Wait for the editor: poll `browser_evaluate` until `.editor-GlobalBar` and `iframe#ContentFrame` exist.
3. Open the dialog through the editor API (runs in the top-level document; the dialog is `body > coral-dialog`, not inside the iframe):
   ```js
   () => {
     const editables = Granite.author.editables;
     const target = editables.find(e => e.path === '<component-node-path>')
       || editables.find(e => e.type && e.type.toLowerCase().endsWith('/<component-name>'));
     if (!target) return { found: false };
     Granite.author.editableHelper.doSelectEditable(target);
     Granite.author.editableHelper.doAction(target, 'EDIT');
     return { found: true, path: target.path };
   }
   ```
   Fallback: `browser_snapshot`, find the component overlay, `browser_click` with `doubleClick: true`.
4. Poll for `document.querySelector('body > coral-dialog[open]')` — 500 ms, up to 10 tries.
5. Screenshot. One per tab if the dialog has tabs that hold changed fields (`dialog-<component>.png`, `dialog-<component>-<tab>.png`).

## Preview screenshot (author, wcmmode=disabled)

1. Navigate to `<author-url><page-path>.html?wcmmode=disabled` — the rendered page without editor chrome. No publish needed.
2. Locate the component and scroll to it (prefix from `aem.component-prefix`):
   ```js
   () => {
     const prefix = '<component-prefix>';
     const el = document.querySelector('[class*="' + prefix + '<component>"]')
       || document.querySelector(prefix + '<component>-default');
     if (!el) return { found: false };
     el.scrollIntoView({ block: 'center' });
     return { found: true, rect: el.getBoundingClientRect() };
   }
   ```
3. Screenshot → `preview-<component>.png`. If the component isn't found, take a full-viewport screenshot and say so.

## Screenshot files

`browser_take_screenshot` takes a **basename** (`filename`) and saves under `.ai/playwright/screenshots/`. Copy into the folder the caller names:

```bash
mkdir -p <spec-dir>/demo/<env> && cp .ai/playwright/screenshots/<filename> <spec-dir>/demo/<env>/<filename>
```

## Headless

Pipelines run Playwright with `--headless`. Nothing changes for you.

## Output

- Never return raw JSON — summarize.
- Return: page path (created/reused), components configured with field values, screenshot paths, anything that failed and why.
