---
name: aem-qa-handoff
description: Generate structured testing steps for QA team and post as ADO comment. Reuses test page and screenshots from /aem-doc-gen if available, otherwise creates its own on QA AEM. Use after /aem-doc-gen or after PR merges and code deploys to QA.
argument-hint: "<component-name> <work-item-id> (e.g., hero 2416553)"
context: fork
agent: aem-inspector
compatibility: "Requires AEM MCP (connected to QA instance), Chrome DevTools MCP, and QA AEM deployed."
metadata:
  mcp-server: AEM, chrome-devtools-mcp
  category: aem-verification
allowed-tools: ["read", "edit", "search", "write", "agent", "ado/*", "AEM/*", "chrome-devtools-mcp/*"]
---

**Platform note:** This skill uses `context: fork` + `agent: aem-inspector` for isolated execution. If subagent dispatch is unavailable (e.g., VS Code Chat), you may run inline but AEM MCP tools (`AEM/*`, `chrome-devtools-mcp/*`) must be available. If they are not, inform the user: "QA handoff requires AEM and Chrome DevTools MCP servers. Please use Claude Code or Copilot CLI."

You are the **QA Handoff Agent**. You generate structured testing steps and post them as an ADO comment for the QA team.

**Two modes:**

- **With `/aem-doc-gen` output (recommended):** Reads existing test page, screenshots, and authoring guide. Generates testing steps from that evidence + acceptance criteria. Lightweight — no AEM MCP or Chrome DevTools needed.
- **Without `/aem-doc-gen` output (fallback):** Creates test page on QA AEM, takes screenshots via Chrome DevTools, then generates testing steps. Full mode — requires AEM MCP and Chrome DevTools.

**Recommended flow:**
```
/aem-doc-gen hero 2416553       -> creates QA page, screenshots, authoring guide
/aem-qa-handoff hero 2416553    -> reads doc-gen output, generates testing steps, posts to ADO
```

## Flow

```dot
digraph aem_qa_handoff {
    "Load config and parse arguments" [shape=box];
    "Config valid?" [shape=diamond];
    "STOP: QA URLs not configured" [shape=doublecircle];
    "Determine mode" [shape=box];
    "Load story context" [shape=box];
    "Lightweight mode?" [shape=diamond];
    "Create or reuse test page on QA AEM" [shape=box];
    "QA AEM reachable?" [shape=diamond];
    "STOP: cannot reach QA AEM" [shape=doublecircle];
    "Preview on QA publisher and screenshot" [shape=box];
    "Generate testing steps" [shape=box];
    "Check for existing ADO comment" [shape=box];
    "Existing comment found?" [shape=diamond];
    "Post new comment to ADO" [shape=box];
    "Post update comment to ADO" [shape=box];
    "Write qa-handoff.md and present summary" [shape=doublecircle];

    "Load config and parse arguments" -> "Config valid?";
    "Config valid?" -> "STOP: QA URLs not configured" [label="no"];
    "Config valid?" -> "Determine mode" [label="yes"];
    "Determine mode" -> "Load story context";
    "Load story context" -> "Lightweight mode?";
    "Lightweight mode?" -> "Generate testing steps" [label="yes, skip phases 2-3"];
    "Lightweight mode?" -> "Create or reuse test page on QA AEM" [label="no, full mode"];
    "Create or reuse test page on QA AEM" -> "QA AEM reachable?";
    "QA AEM reachable?" -> "STOP: cannot reach QA AEM" [label="no"];
    "QA AEM reachable?" -> "Preview on QA publisher and screenshot" [label="yes"];
    "Preview on QA publisher and screenshot" -> "Generate testing steps";
    "Generate testing steps" -> "Check for existing ADO comment";
    "Check for existing ADO comment" -> "Existing comment found?";
    "Existing comment found?" -> "Post update comment to ADO" [label="yes"];
    "Existing comment found?" -> "Post new comment to ADO" [label="no"];
    "Post new comment to ADO" -> "Write qa-handoff.md and present summary";
    "Post update comment to ADO" -> "Write qa-handoff.md and present summary";
}
```

## Node Details

### Load config and parse arguments

**Read configuration** from `.ai/config.yaml`:
- `aem.author-url-qa` — QA author URL (e.g., `https://qa-author.brand-a.com`)
- `aem.publish-url-qa` — QA publisher URL (e.g., `https://qa.brand-a.com`)
- `aem.component-path` — component lookup paths
- `aem.demo-parent-path` — where to create test pages
- `scm.project`, `scm.org` — for ADO work item operations

**Parse arguments:** Extract `<component-name>` and `<work-item-id>` from `$ARGUMENTS`.
- If no component name: check `.ai/specs/*-*/implement.md`, `.ai/specs/*-*/aem-after.md` to infer. If unclear, STOP and ask.
- If no work item ID: check `.ai/specs/*-*/raw-story.md` for the most recent story. If unclear, STOP and ask.

### Config valid?

If `aem.author-url-qa` or `aem.publish-url-qa` is not configured, take the "no" path. Otherwise, take the "yes" path.

### STOP: QA URLs not configured

```
BLOCKED: QA URLs not configured. Set `aem.author-url-qa` and `aem.publish-url-qa` in `.ai/config.yaml`.
```
STOP.

### Determine mode

Check for `/aem-doc-gen` output in the spec directory:

1. Check if `<spec-dir>/demo/authoring-guide.md` exists
2. Check if `<spec-dir>/demo/*.png` screenshots exist
3. Check if `<spec-dir>/aem-after.md` exists (from `/aem-verify`)

**If `demo/authoring-guide.md` exists:** Use **lightweight mode**. Skip "Create or reuse test page on QA AEM" and "Preview on QA publisher and screenshot".

**If `demo/authoring-guide.md` does NOT exist:** Use **full mode**. Print:
```
[QAHandoff] No /aem-doc-gen output found. Running in full mode (creating test page + screenshots).
[QAHandoff] Tip: Run /aem-doc-gen first for better results — it creates the test page, screenshots, and authoring guide that DoD also checks for.
```

Print:
```
[QAHandoff] Mode: <lightweight | full>
[QAHandoff] Component: <component-name>
[QAHandoff] Story: #<work-item-id>
[QAHandoff] QA Author: <author-url-qa>
[QAHandoff] QA Publisher: <publish-url-qa>
```

### Load story context

Check for context in order:
1. `.ai/specs/<id>-*/explain.md` — developer requirements
2. `.ai/specs/<id>-*/implement.md` — implementation plan (what changed)
3. `.ai/specs/<id>-*/aem-after.md` — post-development verification (dialog fields, test page)
4. `.ai/specs/<id>-*/demo/authoring-guide.md` — authoring guide with QA page links and screenshots

If available, also fetch the ADO work item for acceptance criteria:
```
mcp__ado__wit_get_work_item
  id: <work-item-id>
```

Extract:
- **Acceptance criteria** — what QA should verify
- **Component changes** — new/modified dialog fields, rendering changes
- **Test page path** — from `aem-after.md` or `authoring-guide.md`
- **QA page URLs** — from `authoring-guide.md` (publisher + author links)
- **Screenshots** — from `demo/*.png` (dialog and website screenshots)

Print:
```
[QAHandoff] Context loaded: <sources found>
[QAHandoff] Acceptance criteria: <count> items
[QAHandoff] Test page: <path from doc-gen or "none">
[QAHandoff] Screenshots: <count from demo/ or "none">
```

### Lightweight mode?

If lightweight mode was selected in "Determine mode", take the "yes" path. If full mode, take the "no" path.

### Create or reuse test page on QA AEM

**All AEM MCP calls in this phase use `instance: "qa"`.**

**Resolve QA basic auth credentials** — follow `.claude/rules/qa-basic-auth.md` credential resolution:
1. Check env vars: `QA_BASIC_AUTH_USER` / `QA_BASIC_AUTH_PASS`
2. Fallback env vars: `QA_BASIC_AUTH_FALLBACK_USER` / `QA_BASIC_AUTH_FALLBACK_PASS`
3. Legacy: `.ai/config.yaml` `aem.qa-basic-auth.username` / `aem.qa-basic-auth.password`

**Verify QA AEM is reachable:**
```
mcp__plugin_dx-aem_AEM__getNodeContent
  path: "/content"
  depth: 1
  instance: "qa"
```

**Check for existing test page:** If `aem-after.md` exists and has a test page path, check if that page exists on QA:
```
mcp__plugin_dx-aem_AEM__getPageProperties
  pagePath: "<test-page-path>"
  instance: "qa"
```
- **If page exists on QA:** Reuse it. Log: "Reusing existing test page on QA." Skip to configuring data.
- **If page does NOT exist on QA:** Continue to create it.

**Find component placement on QA:** Search for existing pages using this component on QA. If pages found, take the first production page (skip demo/test pages), read its language root, template, and container chain.

**Create the test page:**
```
mcp__plugin_dx-aem_AEM__createPage
  parentPath: "<demo-parent-path>"
  pageName: "qa-<spec-slug>"
  title: "QA Test — <component-name> (#<work-item-id>)"
  template: "<template-path>"
  instance: "qa"
```

Then add the component and configure story-relevant demo data.

Print:
```
[QAHandoff] Test page: <test-page-path>
[QAHandoff] Component configured: <field count> fields set
[QAHandoff] Demo data: <configured/partial>
```

### QA AEM reachable?

If the AEM MCP call to `/content` succeeded, take the "yes" path. If it failed, take the "no" path.

### STOP: cannot reach QA AEM

```
BLOCKED: Cannot reach QA AEM instance. Verify the AEM MCP server is configured for QA access.
```
STOP.

### Preview on QA publisher and screenshot

**Navigate to QA publisher with basic auth** — first navigation requires basic auth per `.claude/rules/qa-basic-auth.md`:

Embed credentials in the first URL:
```
mcp__plugin_dx-aem_chrome-devtools-mcp__navigate_page
  url: "https://<qa-username>:<qa-password>@<qa-publish-host><test-page-path>.html"
```

Wait for page to load:
```
mcp__plugin_dx-aem_chrome-devtools-mcp__wait_for
  text: "<expected element or component tag>"
  timeout: 20000
```

**If page returns 401 or login redirect** (embedded creds didn't work), use the fallback:
```
mcp__plugin_dx-aem_chrome-devtools-mcp__evaluate_script
  expression: |
    async () => {
      const creds = btoa('<qa-username>:<qa-password>');
      const resp = await fetch(window.location.href, {
        headers: { 'Authorization': 'Basic ' + creds },
        credentials: 'include'
      });
      if (resp.ok) { location.reload(); return { authenticated: true }; }
      return { authenticated: false };
    }
```

**Take verification screenshot:**
```
mcp__plugin_dx-aem_chrome-devtools-mcp__take_screenshot
  filePath: "<spec-dir>/screenshots/qa-handoff-publisher.png"
```

**Verify component renders:** Visually inspect the screenshot — is the component visible? Does it render without errors? This is NOT a full QA pass — it's a sanity check.

**(Optional) Screenshot the author dialog:** Navigate to QA author (different domain, needs its own basic auth). Open the component dialog via Granite API, wait for dialog, take screenshot.

Print:
```
[QAHandoff] Publisher screenshot: <path>
[QAHandoff] Dialog screenshot: <path or "skipped">
[QAHandoff] Component renders: <yes/no/partial>
```

### Generate testing steps

Build structured testing steps from all available sources.

**In lightweight mode (from `/aem-doc-gen` output):**
1. **Acceptance criteria** from the ADO work item
2. **Component changes** from `implement.md` or `aem-after.md`
3. **Authoring guide** from `demo/authoring-guide.md` — dialog fields, field descriptions, QA page URLs
4. **Screenshots** from `demo/*.png` — visual reference for what QA should see

**In full mode (self-gathered):**
1. **Acceptance criteria** from the ADO work item
2. **Component changes** from `implement.md` or `aem-after.md`
3. **Visual observations** from the Chrome DevTools preview
4. **Dialog field inventory** from `aem-after.md` or AEM MCP inspection

**Testing step structure** — each step must have:
- **Action** — what the tester should do (navigate, click, resize, enter data)
- **Expected result** — what they should see
- **Component/feature** being tested

**Required test categories:**
1. **Publisher rendering** — Navigate to QA publisher URL, verify component is visible and renders correctly
2. **Dialog verification** — Open editor on QA author, open component dialog, verify all fields are present and functional
3. **New/changed fields** — For each field added/modified in this story, verify it appears in dialog, saves correctly, and renders on publisher
4. **Show/hide logic** — If conditional fields were added, test the conditions
5. **Responsive** — Resize to mobile (375px) and tablet (768px), verify layout adapts
6. **Edge cases** — Empty values, maximum length text, special characters (if applicable)

**Map acceptance criteria to steps:** For each acceptance criterion from the ADO work item, create one or more testing steps that verify it.

### Check for existing ADO comment

Search existing comments on the work item for the `[QAHandoff]` signature:
```
mcp__ado__wit_list_work_item_comments
  workItemId: <work-item-id>
```

Scan comment bodies for `[QAHandoff]`. Note: if the work item has many comments, results may be paginated — check all pages (ADO returns newest first, so the `[QAHandoff]` comment is likely on the first page if it was posted recently).

### Existing comment found?

If an existing `[QAHandoff]` comment was found, take the "yes" path. If no existing comment, take the "no" path.

### Post new comment to ADO

Read the template from `dx-aem-flow/dx/plugins/dx-core/data/templates/ado-comments/qa-handoff.md.template` (or use inline knowledge of the template structure).

**ADO markdown note:** Use only basic markdown (headers, lists, bold, links, code blocks). No nested tables, no HTML tags beyond comments. ADO's renderer has quirks with complex markdown.

Fill in all placeholders:
- `<component-name>`, `<work-item-id>`, `<story-title>` — from context
- `<qa-author-url>`, `<qa-publish-url>` — from config
- `<test-page-path>` — from doc-gen output or self-created page
- `<component-resource-type>` — from component lookup
- Testing steps — from "Generate testing steps"
- `<ISO timestamp>` — current time
- `<branch-name>` — from `git branch --show-current`

Post the comment:
```
mcp__ado__wit_add_work_item_comment
  workItemId: <work-item-id>
  text: "<filled-template>"
  format: "markdown"
```

### Post update comment to ADO

Post a short update comment (do NOT edit the original — ADO MCP doesn't support comment editing):

```markdown
### [QAHandoff] Updated

**Previous:** <previous timestamp>
**Changes:** <what changed — new screenshot, updated steps, etc.>

<updated testing steps if different>

---
_[QAHandoff] Update | <ISO timestamp> - Follow the steps above and update the story status after testing._
```

### Write qa-handoff.md and present summary

Write `<spec-dir>/qa-handoff.md` with:
- Test page URLs (author + publisher)
- Screenshot paths (from doc-gen or self-captured)
- Testing steps (same as ADO comment)
- Timestamp
- Mode used (lightweight/full)

Print:
```markdown
## QA Handoff Complete: #<work-item-id> — <component-name>

**Mode:** <lightweight (from /aem-doc-gen) | full (self-gathered)>

**Test Page:**
- Author: <qa-author-url>/editor.html<test-page-path>.html
- Publisher: <qa-publish-url><test-page-path>.html

**Screenshots:** <from doc-gen demo/ or self-captured>

**Testing Steps:** <count> steps posted to ADO #<work-item-id>

**DoD Readiness:**
- AEM authoring guide: <exists (from /aem-doc-gen) | missing — run /aem-doc-gen>
- Technical documentation: <exists (from /dx-doc-gen) | missing — run /dx-doc-gen>
- QA handoff comment: posted

**Next:** QA team can verify using the posted testing steps. Run `/dx-req-dod` to check DoD.
```

## Success Criteria

- [ ] Testing steps posted as ADO comment with `[QAHandoff]` signature
- [ ] Steps cover: publisher rendering, dialog verification, new/changed fields, responsive
- [ ] Steps map to acceptance criteria from the ADO work item
- [ ] `qa-handoff.md` saved in spec directory
- [ ] In lightweight mode: reused doc-gen test page and screenshots (no duplicate AEM work)
- [ ] In full mode: test page exists on QA AEM with component configured + screenshots captured

## Examples

### After /aem-doc-gen (recommended — lightweight mode)
```
/aem-doc-gen hero 2416553
/aem-qa-handoff hero 2416553
```
Reads `demo/authoring-guide.md`, `demo/*.png`, `aem-after.md`. Generates 8 testing steps from acceptance criteria + authoring guide fields. Posts to ADO. No AEM MCP or Chrome DevTools calls needed.

### Without prior /aem-doc-gen (full mode)
```
/aem-qa-handoff hero 2416553
```
No doc-gen output found. Connects to QA AEM, finds/creates test page, takes screenshots via Chrome DevTools, generates testing steps, posts to ADO. Prints tip to run `/aem-doc-gen` first next time.

### Reuse existing test page (full mode with prior /aem-verify)
```
/aem-qa-handoff hero 2416553
```
No `demo/authoring-guide.md` but `aem-after.md` exists with test page path. Checks if page exists on QA, reuses it, takes fresh screenshot, generates testing steps.

## Troubleshooting

### "Cannot reach QA AEM instance" (full mode only)
**Cause:** AEM MCP server not configured for QA access, or QA AEM is down.
**Fix:** Verify AEM MCP has `instance: "qa"` configured. Or run `/aem-doc-gen` first (it handles page creation) and then re-run QA handoff in lightweight mode.

### "QA URLs not configured"
**Cause:** `.ai/config.yaml` missing `aem.author-url-qa` or `aem.publish-url-qa`.
**Fix:** Run `/aem-init` or manually add the QA URLs to config.

### Screenshot shows 401/login page (full mode only)
**Cause:** Basic auth credentials not resolved or expired.
**Fix:** Set `QA_BASIC_AUTH_USER` and `QA_BASIC_AUTH_PASS` environment variables. See `.claude/rules/qa-basic-auth.md`.

### Test page creation fails on QA (full mode only)
**Cause:** QA AEM may have different content structure than local, or template restrictions.
**Fix:** Run `/aem-doc-gen` instead — it handles page creation with more robust discovery. Then re-run QA handoff.

### Component not rendering on QA publisher
**Cause:** Code may not be deployed to QA yet (CI/CD pipeline pending), or dispatcher cache is stale.
**Fix:** Verify the PR has been merged and the CI/CD pipeline to QA has completed. Try appending `?nocache=true` to the URL.

### DoD still fails after QA handoff
**Cause:** DoD checks for `demo/authoring-guide.md` (from `/aem-doc-gen`), not `qa-handoff.md`.
**Fix:** Run `/aem-doc-gen` before `/aem-qa-handoff`. The authoring guide satisfies DoD's "AEM authoring guide" criterion. QA handoff satisfies the communication need (testing steps for QA team).

## Rules

- **Lightweight first** — if `/aem-doc-gen` output exists, use it. Don't duplicate AEM MCP work.
- **Remote QA only** — all AEM MCP calls (full mode) use `instance: "qa"`. Never target localhost.
- **No code modifications** — this skill reads and verifies, never edits source code
- **Idempotent** — reuses existing test pages, checks for existing ADO comments
- **Basic auth once** — first Chrome DevTools navigation embeds credentials, subsequent use clean URLs
- **Evidence-based** — every testing step references what was actually verified (screenshot, dialog inspection, or doc-gen output)
- **Acceptance criteria first** — testing steps must map to story acceptance criteria before adding supplementary checks
- **DoD awareness** — summary prints DoD readiness status and suggests missing steps (`/aem-doc-gen`, `/dx-doc-gen`)
