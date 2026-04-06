---
name: aem-doctor
description: Check health of AEM project infrastructure — verifies component definitions, OSGi configs, dispatcher rules, and content structure against expected state. Use to diagnose configuration drift or after making infrastructure changes.
argument-hint: "[components|osgi|dispatcher|content|code|all]"
allowed-tools: ["read", "edit", "search", "write", "agent", "AEM/*", "chrome-devtools-mcp/*"]
---

You are a diagnostic tool for AEM project infrastructure. You check local files, AEM instance state, and project conventions, then print a status table with warnings.

**This skill is read-only. Never modify, fix, or deploy anything.**

## 1. Read Configuration

Read `.ai/config.yaml` for:
- `aem.component-path` — component definitions root (e.g., `/apps/myproject/components/content/`)
- `aem.resource-type-pattern` — expected resource type format
- `aem.author-url` — AEM instance URL (defaults to `http://localhost:4502`)
- `aem.frontend-dir` — frontend source directory
- `aem.brands` — configured brands (if multi-brand)
- `build.command` — project build command

Also read the component index if it exists — check `.ai/project/component-index.md` first, fall back to `.ai/component-index.md`.

## 2. Determine Scope

Parse the argument:
- `components` — check component definitions only
- `osgi` — check OSGi configurations only
- `dispatcher` — check dispatcher rules only
- `content` — check AEM content structure only
- `code` — check Java code for anti-patterns only
- `all` or no argument — check everything

## 3. Run Checks

### 3a. Component Definition Integrity

For each component in the component path:

**Verify structure:**
```bash
# Find all component .content.xml files
find <component-path-in-repo> -name ".content.xml" -path "*components*"
```

Check each component has:
- `.content.xml` with valid `jcr:primaryType` and `componentGroup`
- `_cq_dialog/.content.xml` (dialog definition) — warn if missing
- At least one `.html` (HTL template) — warn if missing
- `sling:resourceSuperType` reference is valid (if set)

**Cross-reference with component index:**
If the component index exists (`.ai/project/component-index.md` or `.ai/component-index.md`), verify:
- All indexed components still exist on disk
- No new (unindexed) components have been added
- Resource types match between index and `.content.xml`

### 3b. OSGi Configuration Integrity

Search for OSGi config directories:
```bash
find . -path "*/osgiconfig/*" -name "*.cfg.json" -o -name "*.config" | head -30
```

Check:
- Config files are valid JSON (for `.cfg.json`)
- Environment-specific configs exist for expected runmodes (dev, qa, stage, prod)
- No duplicate PIDs across runmodes at the same level
- Factory configs have unique suffixes

### 3c. Dispatcher Configuration

Search for dispatcher config:
```bash
find . -path "*/dispatcher/*" -type f | head -20
```

If dispatcher config exists, check:
- Rewrite rules reference valid content paths
- Filter rules allow configured component resource types
- Cache rules are consistent across farms
- Client headers are properly forwarded

### 3d. AEM Content Structure (requires running AEM)

If AEM MCP is available, verify:

**Sites exist:**
```
mcp__plugin_dx-aem_AEM__fetchSites
```
Compare against configured content paths in `.ai/config.yaml`.

**Templates exist:**
```
mcp__plugin_dx-aem_AEM__getTemplates
```
Verify templates referenced by components are available.

**Components registered:**
For a sample of components from the index, verify they exist on AEM:
```
mcp__plugin_dx-aem_AEM__getComponents
  path: "<component-path>/<sample-component>"
```

### 3e. Frontend Build Integrity

If `aem.frontend-dir` is configured:

**Check that all components with dialog definitions have frontend files:**
- For each component with a `_cq_dialog`, check if a matching JS/SCSS file exists in the frontend dir
- Warn on components with dialogs but no frontend code (may be intentional for server-side-only components)

**Check brand coverage** (if multi-brand):
- For each brand in `aem.brands`, verify brand-specific overrides directory exists
- Check for orphaned brand files (brand override without a base component)

### 3f. Code Anti-Pattern Scan

Scan Java source files for patterns that cause issues in AEM as a Cloud Service. Each check is a targeted grep — report matches with file and line number.

**Detect via grep patterns** in project Java source (`**/core/**/src/main/**/*.java`):

| Anti-Pattern | Grep Pattern | Severity |
|---|---|---|
| Scheduler API (runs on all cluster instances) | `implements Runnable` in files with `Scheduler.PROPERTY_SCHEDULER` | ⚠ warn |
| Static ResourceResolver (stale sessions) | `private static ResourceResolver` | ✗ error |
| Administrative resolver (removed in Cloud Service) | `getAdministrativeResourceResolver` | ✗ error |
| ResourceResolver not in try-with-resources | `getServiceResourceResolver` in files WITHOUT `try (ResourceResolver` | ⚠ warn |
| Path-bound servlet (bypasses ACLs) | `sling.servlet.paths` | ⚠ warn |
| Mutable state in OSGi service | `@Component` class with non-final `private.*Map\|List\|Set\|int\|long\|boolean` fields that aren't `@Reference`/`@Inject`/`@OSGiService`/`@ValueMapValue` | ⚠ warn |
| Deprecated SCR annotations | `import org.apache.felix.scr.annotations` | ⚠ warn |
| Hardcoded AEM paths | String literals matching `/content/dam/`, `/content/` followed by a specific site name, or `/apps/` | ⚠ warn |
| JCR Session direct access | `.adaptTo(Session.class)` outside test files | ⚠ warn |
| Absolute resource type in HTL | `resourceType='/apps/` in `*.html` files | ⚠ warn |

**How to scan:** Run greps in parallel. For each hit, report the file path and line. Skip test files (`**/test/**`) for all checks except the HTL check. Keep output concise — list up to 5 matches per pattern, then `+N more`.

## 4. Print Results

Use this exact format with status indicators:

- `✓` — check passed
- `⚠` — warning (works but attention needed)
- `✗` — error (broken or missing)

```
=== AEM Project Doctor ===

Component Definitions                              Status
─────────────────────────────────────────────────────────
<component-name>                                   ✓ complete
  .content.xml                                     ✓ valid
  _cq_dialog/.content.xml                          ✓ present
  HTL template                                     ✓ found
<component-name>                                   ⚠ incomplete
  _cq_dialog/.content.xml                          ✗ MISSING
...

OSGi Configurations                                Status
─────────────────────────────────────────────────────────
<pid>.cfg.json                                     ✓ valid JSON
  Runmodes: dev, qa, stage, prod                   ✓ all present
...

Dispatcher                                         Status
─────────────────────────────────────────────────────────
Rewrite rules                                      ✓ valid
Cache rules                                        ✓ consistent
...

AEM Instance (<author-url>)                        Status
─────────────────────────────────────────────────────────
Sites configured                                   ✓ N sites found
Templates available                                ✓ N templates
Components registered                              ✓ N/M registered
...

Frontend                                           Status
─────────────────────────────────────────────────────────
Component coverage                                 ✓ N/M have FE files
Brand overrides                                    ✓ N brands, no orphans
...

Code Anti-Patterns                                 Status
─────────────────────────────────────────────────────────
Scheduler API (use Sling Jobs)                     ✓ none found
Static ResourceResolver                            ✗ 2 hits
  MyService.java:15, AnotherService.java:42
Administrative resolver                            ✓ none found
...

Summary: X passed, Y warnings, Z errors
```

For each warning or error, add a one-line explanation below the status line:
```
  _cq_dialog/.content.xml                          ✗ MISSING
    Component has no authoring dialog — intentional?
```

## 5. Summary

End with a summary line:
- If all green: `All checks passed.`
- If warnings: `N warnings — review items marked ⚠`
- If errors: `N errors — items marked ✗ need attention`

## Error Handling

- If AEM is not reachable, skip content structure checks: `⚠ AEM not reachable at <author-url>. Skipping instance checks.`
- If no dispatcher config found, skip: `⚠ No dispatcher configuration found. Skipping.`
- If no OSGi configs found, skip: `⚠ No OSGi configurations found. Skipping.`
- Never fail silently — always report what was skipped and why.

## Examples

1. `/aem-doctor` — Runs all health checks: verifies 45 component definitions match source XML, validates OSGi configs exist, checks dispatcher rules for proper cache headers, confirms content structure paths are accessible, and scans Java code for anti-patterns. Reports 2 warnings (missing dispatcher rule, stale OSGi config) and 0 errors.

2. `/aem-doctor code` — Runs only the code anti-pattern scan. Greps Java source for deprecated APIs, static ResourceResolvers, path-bound servlets, and other Cloud Service anti-patterns. Reports 1 warning (deprecated SCR annotation in LegacyService.java) and 0 errors.

3. `/aem-doctor` (AEM not running) — Checks local file structure (component definitions, OSGi configs, dispatcher rules) and code anti-patterns successfully. Skips AEM instance checks with warning: "AEM not reachable at http://localhost:4502. Skipping instance checks." Reports local-only results.

4. `/aem-doctor` (after failed deployment) — Detects 3 errors: component dialog XML has invalid field type, OSGi config references non-existent PID, and content path returns 404. Each error includes the file path and suggested fix action.

## Troubleshooting

- **"AEM not reachable — skipping instance checks"**
  **Cause:** AEM author is not running or the URL in config is wrong.
  **Fix:** Start AEM or update `aem.author-url` in `.ai/config.yaml`. Local file checks still run — only live instance checks are skipped.

- **False positives on dispatcher rules**
  **Cause:** The project uses a non-standard dispatcher configuration layout.
  **Fix:** Review the reported paths. If the dispatcher config is in an unusual location, the check may not find it. This is a warning, not an error.

- **Component definition mismatch warnings**
  **Cause:** Source XML was edited but not deployed, or the AEM instance has a different version of the component.
  **Fix:** Deploy the latest code with `mvn clean install -PautoInstallPackage` and re-run `/aem-doctor` to verify the definitions match.

## Rules

- **Read-only** — never modify, fix, or deploy anything
- **Config-driven** — read all paths and URLs from `.ai/config.yaml`
- **Graceful degradation** — skip checks that aren't applicable (no AEM, no dispatcher, etc.)
- **Actionable output** — every warning/error should suggest what to do
- **Efficient** — check local files first, AEM instance checks last (they're slower)
