---
name: dx-axe
description: Run accessibility testing on a URL using the axe MCP Server — analyze violations, get remediation guidance, apply fixes, and verify. Use when asked to check accessibility, run a11y audit, or fix WCAG issues.
argument-hint: "<URL to test> [--fix] [--standard wcag2aa|wcag21aa|best-practice]"
---

You perform accessibility testing and remediation using the Deque axe MCP Server. You follow a strict analyze → remediate → fix → verify workflow.

## 1. Parse Arguments

Extract from `$ARGUMENTS`:
- **URL** (required) — the page URL to test
- **--fix** flag — if present, automatically apply remediation fixes to source code after analysis
- **--standard** — WCAG standard to test against (default: `wcag2aa`)

If no URL is provided, ask the user for one.

## 2. Load axe MCP Tools

Use ToolSearch to discover the axe MCP Server tools:

```
ToolSearch query: "+axe analyze"
```

Look for tools matching `axe_mcp_server__analyze` and `axe_mcp_server__remediate` (or similar naming with `axe` prefix).

If not found, tell the user:

> **axe MCP Server not available.** See setup guide: `docs/dx-axe.md` in the plugin repo.
> Quick checklist: Docker running? `AXE_API_KEY` exported? Image pulled (`docker pull dequesystems/axe-mcp-server:latest`)? Plugin reinstalled after setup?

Then STOP.

## 3. Resolve URL for axe

The axe MCP Server runs inside Docker. URLs must be reachable from the container.

### Local AEM (`localhost`)

Replace `localhost` with `host.docker.internal` in the URL passed to axe — inside Docker, `localhost` is the container itself:

| User provides | Pass to axe |
|---------------|-------------|
| `http://localhost:4502/...` | `http://host.docker.internal:4502/...` |
| `http://admin:admin@localhost:4502/...` | `http://admin:admin@host.docker.internal:4502/...` |

If the URL has no credentials and the host is `localhost:4502`, embed `admin:admin` (AEM default local credentials):

```
http://admin:admin@host.docker.internal:4502/content/...?wcmmode=disabled
```

### Remote AEM (QA / Stage)

Read `.ai/config.yaml` for `aem.qa-basic-auth`. If the URL matches a QA/Stage host (`aem.author-url-qa`, `aem.publish-url-qa`) and has no credentials, embed them:

```yaml
# .ai/config.yaml
aem:
  qa-basic-auth:
    username: "<user>"
    password: "<pass>"
```

```
https://<user>:<pass>@qa.example.com/content/...
```

If `qa-basic-auth` is not configured and the URL looks like a QA/Stage host, warn the user that auth may be needed.

### Public URLs

Pass through unchanged.

## 4. Wait for Client-Side Rendering

Many AEM pages render content client-side (Handlebars templates, lazy-loaded components). If axe analyzes a page before JS rendering completes, it audits an empty shell — results will be meaningless (false 100% pass).

**Before running axe analyze**, use Chrome DevTools MCP to check if the page has rendered:

1. Try calling Chrome DevTools tools directly first (e.g., `mcp__plugin_dx-aem_chrome-devtools-mcp__navigate_page`). If "tool not found", fall back to `ToolSearch query: "+chrome-devtools navigate"`. Do NOT start with ToolSearch — if tools are pre-loaded, ToolSearch returns nothing
2. Navigate to the URL (use the original URL with `localhost`, not the Docker-rewritten one)
3. Wait up to 15s for meaningful content:
   ```
   mcp__plugin_dx-aem_chrome-devtools-mcp__evaluate_script
     function: |
       () => {
         const text = document.body?.innerText?.trim();
         return { length: text?.length, hasContent: text?.length > 200 };
       }
   ```
4. If `hasContent` is false after 15s, warn the user:
   > **Page appears to be stuck loading.** Axe results may be incomplete. Check for JS errors or missing dependencies.

**If Chrome DevTools MCP is not available**, skip this check and proceed — axe may still get usable results if the page is server-rendered.

## 5. Analysis Phase

Run the `analyze` tool with the resolved URL (Docker-safe):

```
axe_mcp_server__analyze
  url: "<resolved URL>"
```

Parse the results. For each violation found, record:
- **Rule ID** (e.g., `color-contrast`, `image-alt`, `button-name`)
- **Impact** — critical, serious, moderate, minor
- **Description** — what the issue is
- **Affected elements** — CSS selectors or HTML snippets
- **WCAG criteria** — which success criteria are violated

Print a summary table:

```markdown
### Accessibility Analysis: <URL>

| # | Rule ID | Impact | Elements | WCAG |
|---|---------|--------|----------|------|
| 1 | color-contrast | serious | `.header-title` | 1.4.3 |
| 2 | image-alt | critical | `img.hero-banner` | 1.1.1 |

**Total:** N violations (X critical, Y serious, Z moderate)
```

If zero violations → print "No accessibility violations found." and STOP.

## 6. Remediation Phase

For **each violation** found in the analysis, call the `remediate` tool:

```
axe_mcp_server__remediate
  ruleId: "<rule-id>"
  element: "<affected HTML element or selector>"
  description: "<issue description>"
```

Collect the remediation guidance for each violation. Print the guidance:

```markdown
### Remediation Guidance

#### 1. [rule-id] — [impact]
**Element:** `<selector>`
**Fix:** <remediation guidance from axe>

#### 2. [rule-id] — [impact]
...
```

If `--fix` flag was NOT provided, print the guidance and STOP. Tell the user:
> Run `/dx-axe <URL> --fix` to automatically apply these fixes to your source code.

## 7. Fix Phase (only with --fix)

For each remediation:

1. **Find the source file** — use Grep/Glob to locate the affected HTML element in the codebase (HTL templates, JS components, SCSS files)
2. **Apply the fix** — follow the remediation guidance from axe. Use Edit tool to modify the source
3. **Log what was changed** — track file path, line, and what was modified

Common fix patterns:
- Missing `alt` text → add `alt` attribute to `<img>` tags in HTL/HTML
- Color contrast → update CSS custom properties or SCSS variables
- Missing labels → add `aria-label` or `<label>` elements
- Keyboard access → add `tabindex`, key event handlers
- Missing roles → add ARIA `role` attributes
- Focus management → add `:focus-visible` styles

**Rules for fixing:**
- Follow the project's existing accessibility patterns (check `.claude/rules/accessibility.md`)
- Use existing SCSS mixins for focus states if available
- Prefer semantic HTML fixes over ARIA workarounds
- Do NOT fix issues in third-party/vendor code — flag them instead

## 8. Verification Phase

After applying fixes:

1. Tell the user to rebuild if needed:
   > Rebuild required to see changes. Run your build command or ensure `watch:new` is running.

2. Re-run `analyze` on the same URL:

```
axe_mcp_server__analyze
  url: "<resolved URL>"
```

3. Compare results:

```markdown
### Verification Results

| Metric | Before | After |
|--------|--------|-------|
| Critical | X | Y |
| Serious | X | Y |
| Moderate | X | Y |
| Minor | X | Y |
| **Total** | **X** | **Y** |

**Resolved:** N of M violations fixed
**Remaining:** [list any remaining violations with rule IDs]
```

4. If violations remain, explain what couldn't be fixed and why (e.g., third-party component, requires design change, needs content author action).

## 9. Save Report (if in a spec directory context)

If running within a dx workflow (spec directory exists):

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir $ARGUMENTS 2>/dev/null)
```

If `$SPEC_DIR` exists, save the report as `$SPEC_DIR/a11y-report.md` with:
- URL tested
- Date
- Standard used
- Full violation table
- Remediation actions taken (if --fix)
- Verification results (if --fix)

## Enforcement Rules

- **NEVER** skip the `remediate` tool when fixing — always get axe's guidance first
- **NEVER** manually guess accessibility fixes without consulting the remediate tool
- **ALWAYS** use `analyze` → `remediate` → fix → `analyze` workflow
- **ALWAYS** re-run analysis after fixes to verify
- **ALWAYS** rewrite `localhost` → `host.docker.internal` for URLs passed to axe
- If axe MCP Server is unavailable, do NOT fall back to manual a11y checking — inform the user and stop
