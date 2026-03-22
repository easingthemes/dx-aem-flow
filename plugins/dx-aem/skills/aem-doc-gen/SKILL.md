---
name: aem-doc-gen
description: Generate AEM demo documentation — find or create docs page with configured component, capture dialog and website screenshots on QA, write authoring guide. Extends /aem-demo for automated pipeline use. Invoked by /dx-agent-all Phase 7 and /dx-req-dod.
argument-hint: "[ADO Work Item ID (optional — uses most recent if omitted)]"
context: fork
agent: aem-demo-capture
allowed-tools: ["read", "edit", "search", "write", "agent", "AEM/*", "chrome-devtools-mcp/*"]
---

**Platform note:** This skill uses `context: fork` + `agent: aem-demo-capture` for isolated execution. If subagent dispatch is unavailable (e.g., VS Code Chat), you may run inline but AEM MCP tools (`AEM/*`, `chrome-devtools-mcp/*`) must be available. If they are not, inform the user: "AEM doc generation requires AEM and Chrome DevTools MCP servers. Please use Claude Code or Copilot CLI."

You generate AEM component demo documentation from completed spec files. You find or create a docs page, configure the component, capture dialog and website screenshots, and write an authoring guide with Authoring and Website sections.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir <work-item-id-if-provided>)
```

If the script exits with error, ask the user for the work item ID.

Read `.ai/config.yaml` for:
- `aem.author-url` (defaults to `http://localhost:4502`)
- `aem.author-url-qa` — QA author URL
- `aem.publish-url` (defaults to `http://localhost:4503`)
- `aem.publish-url-qa` — QA publisher URL
- `aem.resource-type-pattern` — component resource type pattern
- `aem.demo-parent-path` — parent path for all AI-created demo pages (e.g., `/content/brand-a/ca/en/ca/en/demo`)

## 2. Determine Environment

- If `PIPELINE_MODE=true` (check via Bash: `echo "$PIPELINE_MODE"`) or caller passes `--qa`: use `aem.author-url-qa` and `aem.publish-url-qa`
- Otherwise: use `aem.author-url` and `aem.publish-url`
- Fall back to local URLs if QA URLs are not configured

Set `$AUTHOR_URL` and `$PUBLISH_URL` for the rest of the flow.

## 3. Read Source Files

Read these files from `$SPEC_DIR` (all optional):

- `explain.md` — what was implemented (to identify the component)
- `implement.md` — plan steps (component names, file paths)
- `aem-after.md` — post-deployment component state (dialog fields, properties, pages)
- `aem-before.md` — pre-development baseline (fallback if aem-after.md missing)

## 4. Identify Component

Determine the target component name from spec files, in order of priority:

1. `aem-after.md` — component name in header
2. `implement.md` — step titles mentioning a component name
3. `explain.md` — requirements referencing a specific component

If no component can be identified, print "Cannot identify target component — provide a component name" and STOP.

## 5. Check Existing Output

1. Check if `demo/authoring-guide.md` exists in the spec directory
2. If it exists and component name matches → print `demo already up to date — skipping` and STOP
3. If outdated or not found → continue

## 6. Check AEM Availability

Test AEM connectivity:

```bash
curl -sf -o /dev/null -w "%{http_code}" "$AUTHOR_URL/libs/granite/core/content/login.html" || echo "unreachable"
```

For QA URLs, also try with Basic Auth. Read credentials from `.claude/rules/qa-basic-auth.md` (or from `.ai/config.yaml` `aem.qa-basic-auth`):
```bash
curl -sf -o /dev/null -w "%{http_code}" -u "$QA_USER:$QA_PASS" "$AUTHOR_URL/libs/granite/core/content/login.html" || echo "unreachable"
```

If unreachable:
- Print: `AEM instance at <url> is not available — generating text-only guide (no screenshots).`
- Skip to step 11 (write guide without screenshots)

## 7. Find Existing Pages

Use the aem-inspector agent to query AEM for pages using this component's resourceType:

```
Find all pages using component <component-name> (resourceType: <resource-type>). Return the first 5 page paths with full author URLs.
```

Save the list for the authoring guide. These are existing production/content pages — useful reference for editors.

## 8. Page Structure Discovery

Check `$SPEC_DIR/demo/page-structure.md` cache first. If cached and still valid, use it.

If not cached, discover from the first existing page (from step 7) or from `aem-after.md`:

Use the aem-inspector agent:
```
Discover page structure from <page-path>:
- Language root (handle doubled country/lang/country/lang pattern)
- Template used by the page
- Container chain from jcr:content/root to the component
Save findings to $SPEC_DIR/demo/page-structure.md
```

## 9. Create or Reuse Demo Page

Read `aem.demo-parent-path` from `.ai/config.yaml`. If not set, fall back to `<language-root>/demo`.

**Reuse the page from aem-verify if it exists:** Check `aem-after.md` for a "Test Page" or "Demo Page" path. If found, reuse that page — do NOT create a second page.

If no existing demo page: create at `<demo-parent-path>/<feature-title-slug>`.

Use the aem-inspector agent:
```
Create a demo page at <demo-parent-path>/<slug> using template <template>.
Recreate the container chain: <chain from page-structure.md>.
Add component <component-name> and configure it with real data from an existing authored instance (search via AEM MCP). Use aem-after.md or implement.md values only as fallback for fields with no real data.
```

If the page already exists, reuse it (idempotent). Same JCR path works on both local and QA — just use the appropriate author URL.

## 10. Dialog Screenshot (Author)

Use the aem-demo-capture agent:

1. Navigate to `$AUTHOR_URL/editor.html<docs-page-path>.html`
2. QA Basic Auth handled by agent if URL is non-localhost
3. Handle AEM login redirect if needed
4. Open the component dialog via Granite API
5. Screenshot the dialog → save as `$SPEC_DIR/demo/dialog-<component>.png`
6. Close dialog

## 11. Publish + Website Screenshot

**Skip if AEM was unavailable (step 6) or if `$PUBLISH_URL` is not configured.**

### 11a. Activate the docs page

Use the aem-inspector agent:
```
Publish the page at <docs-page-path> using mcp__plugin_dx-aem_AEM__activatePage.
```

### 11b. Wait for publisher

Poll the publisher URL for a 200 response, up to 60s timeout:

```bash
for i in $(seq 1 12); do
  STATUS=$(curl -sf -o /dev/null -w "%{http_code}" -u "$QA_USER:$QA_PASS" "$PUBLISH_URL<docs-page-path>.html" 2>/dev/null)
  [ "$STATUS" = "200" ] && break
  sleep 5
done
```

If still not available after 60s, skip website screenshot and note in guide.

### 11c. Capture rendered component

Use the aem-demo-capture agent in publisher view mode:

1. Navigate to `$PUBLISH_URL<docs-page-path>.html`
2. QA Basic Auth handled by agent if URL is non-localhost
3. Locate the component by CSS class/custom element tag
4. Scroll to component
5. Screenshot → save as `$SPEC_DIR/demo/rendered-<component>.png`

## 12. Write Authoring Guide

Write `$SPEC_DIR/demo/authoring-guide.md`:

```markdown
# <Component Name> — Authoring Guide

## Existing Pages

| # | Page | Author URL |
|---|------|------------|
| 1 | <page-path> | <full author URL> |
| 2 | ... | ... |
...up to 5

## Authoring

### What Changed

<1-3 sentences explaining what's new in plain English, no code references.
Pull from explain.md and implement.md.>

### How to Use

<Per-field descriptions from aem-after.md dialog fields.
For each field: what it does, when to use it, any conditional visibility.>

### Tips

- <Any conditional visibility: "Enable X to reveal additional fields">
- <Any gotchas: "Leave blank to use the default value">
- <Any recommendations: "Use short titles (under 50 characters) for best display">

### Dialog Screenshot

![Dialog](dialog-<component>.png)
**Author URL:** <author editor URL to docs page>

## Website

### Rendered Component

![Website](rendered-<component>.png)
**Publisher URL:** <publisher URL to docs page>
```

**Writing principles (same as `/aem-demo`):**
- No JCR properties, no code paths, no Java class names
- Write for someone who authors pages in AEM, not a developer
- Focus on what they see in the dialog and what each field controls
- Mention any show/hide behavior

If AEM was unavailable (step 6), omit the Screenshots and Website sections and add a note: "Screenshots unavailable — AEM instance was not reachable during documentation generation."

If publisher screenshot failed (step 11), omit the Website section and add a note: "Website screenshot unavailable — publisher did not respond within timeout."

## 13. Present Summary

```markdown
## aem-doc-gen complete

**Component:** <name>
**Docs Page:** <page path>
**Environment:** <local / QA>
**Output:**
- `demo/authoring-guide.md`
- `demo/dialog-<component>.png` (if captured)
- `demo/rendered-<component>.png` (if captured)
- `demo/page-structure.md` (if discovered)
**Existing Pages:** <count> found
**Author URL:** <url>
**Publisher URL:** <url>
**AEM:** <connected / unavailable>
```

## Examples

1. `/aem-doc-gen hero 2416553` — Finds the spec directory for story #2416553, discovers `demo/authoring-guide.md` from a prior `/aem-demo` run. Connects to AEM, locates or creates a docs page with the hero component configured, captures dialog and rendered screenshots on QA, and writes the enhanced authoring guide with field descriptions, screenshots, and publisher URLs.

2. `/aem-doc-gen card` (no prior demo) — No existing `demo/authoring-guide.md` found. Runs the full flow: finds the card component on AEM, captures dialog structure, takes screenshots, and generates the authoring guide from scratch. Saves to the most recent spec directory.

3. `/aem-doc-gen productlisting 2416553` (AEM unavailable) — AEM author is not reachable. Degrades gracefully to text-only mode: reads dialog XML from source, generates an authoring guide without screenshots. Notes "AEM unavailable — screenshots not captured" in the output.

## Troubleshooting

- **"No spec directory found"**
  **Cause:** No spec directory exists for the given work item ID.
  **Fix:** Run `/dx-req <id>` first to create the spec directory, or provide the correct work item ID.

- **Screenshots captured but images are dark or empty**
  **Cause:** The component requires specific content/configuration to render, or the page hasn't fully loaded.
  **Fix:** Pre-configure the component on the demo page with sample content, then re-run. The skill will capture whatever is currently rendered.

- **"AEM unavailable — screenshots not captured"**
  **Cause:** AEM author instance is not running or not reachable.
  **Fix:** Start AEM or check `aem.author-url` in `.ai/config.yaml`. The text-only guide is still useful — re-run with AEM available to add screenshots later.

## Rules

- **Read config for all AEM URLs** — never hardcode `localhost:4502` or component paths
- **QA by default in pipeline** — when `PIPELINE_MODE=true`, always use QA URLs
- **Degrade gracefully** — text-only guide if AEM unavailable, still valuable
- **Re-use agents** — aem-demo-capture for screenshots, aem-inspector for page creation and JCR operations
- **Idempotent** — check existing before regenerating; reuse docs page if it exists
- **Non-technical audience** — authoring guide is for content editors, not developers
- **Don't block on screenshots** — if dialog won't open or component isn't found, write guide from spec files only and note the issue
- **Cache page structure** — write `demo/page-structure.md` to avoid re-discovery on subsequent runs
- **Publish wait** — retry loop polling publisher URL, max 60s. Not a fixed sleep.
