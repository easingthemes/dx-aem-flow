# Migration: chrome-devtools-mcp → Playwright MCP (`@playwright/mcp`) — 2026-05-31

Replace the AEM browser-automation layer (`chrome-devtools-mcp`) with Microsoft's **Playwright MCP** (`@playwright/mcp`). Driver: chrome-devtools-mcp has **no native credential support** (see [2026-05-30 autonomous-auth research](2026-05-30-aem-chrome-devtools-autonomous-auth.md) §3), forcing a wrapper+CDP cookie-injection design. Playwright MCP treats both auth layers as first-class config — **Basic Auth via `httpCredentials`, author login via `--storage-state`** — eliminating the wrapper entirely and giving us reusable login scripts.

> Released as **plugin v3.0.0** (BREAKING CHANGE — browser layer swapped, `dx-perf` removed). MCP package pinned to `@playwright/mcp@0.0.75`.

> **Implementation status (2026-05-31):** Migration + reusable auth scripts landed (uncommitted). Tool/server swap complete across all functional files; `dx-perf` removed (TODO #147). Reusable auth: `plugins/dx-aem/data/lib/aem-playwright-auth.sh` (`author` → storageState, `config` → publisher httpCredentials), installed to `.ai/lib/` by aem-init, wired into the 3 agents + shared `demo-page-setup.md` + `aem-qa`/`aem-fe-verify`/`aem-editorial-guide` as the **preferred** path (form-fill kept as fallback). **Publisher default stays URL-embedded Basic Auth** (no config needed); the `httpCredentials` config (§2) is **opt-in** — generate via `aem-playwright-auth.sh config` and add `--config .ai/playwright/config.json` to `.mcp.json` (NOT added by default, to avoid a missing-file launch failure). `validate-structure.sh` passes.

---

## TL;DR

- **Capability parity is near-complete** for everything dx-aem uses. All interaction/snapshot/evaluate/network/console/screenshot/dialog/wait/tab tools map directly. Only losses: **Lighthouse/perf/heap** (unused — `dx-perf` is being removed) and **runtime device-swap** (`emulate` → launch-time `--device`; `browser_resize` covers runtime viewport changes).
- **Auth is strictly better:** publisher Basic Auth = `httpCredentials` (context config, sent only on 401 → safe to leave on for all hosts); AEM author login = `--storage-state` / `browser_set_storage_state` replaying a saved cookie jar (incl. the HttpOnly `login-token`). Secret stays in a Bash/Node helper, never in model context. No CDP, no launch wrapper.
- **The two auth layers stay independent** (per [2026-05-30 doc](2026-05-30-aem-chrome-devtools-autonomous-auth.md) corrections): author = form login / storageState only; publisher = Basic Auth only. `httpCredentials` is context-wide but only transmitted when a host challenges — author never challenges, so it's never sent there.
- **Migration surface: 44 files.** Bodies need real rewriting (tool names differ, some merge), not a prefix swap.
- **Version pinning:** an MCP server's npm version is controlled **only** by the `@version` in `npx` args (no lockfile). A *consumer* cannot pass `@version` to `/plugin install` — plugin pinning is via marketplace source `sha`/`ref` or the `version` field. Pin `@playwright/mcp@0.0.75`.

---

## 1. Server config (`plugins/dx-aem/.mcp.json`)

Server name `playwright` → tool prefix `mcp__plugin_dx-aem_playwright__browser_*`. (Kept in dx-aem to preserve the existing cross-plugin reference pattern — dx-core skills already reference the dx-aem-scoped browser server. Moving ownership to dx-core is a separate future refactor.)

```json
"playwright": {
  "type": "stdio",
  "command": "npx",
  "args": [
    "@playwright/mcp@0.0.75",
    "--headless",
    "--isolated",
    "--viewport-size=1440,900",
    "--caps=storage",
    "--output-dir=.ai/playwright/screenshots"
  ]
}
```

- `--caps=storage` enables `browser_storage_state` / `browser_set_storage_state` / `browser_cookie_*` (needed for runtime author-session loading and HttpOnly cookies).
- `--output-dir=.ai/playwright/screenshots` — `browser_take_screenshot` saves a **basename** here (gitignored); skills `cp` it to the target spec path. It does NOT honor an arbitrary path passed as `filename`.
- `--isolated` retained (clean profile each run); author auth comes from storageState, not a persisted profile.
- **`--config` is deliberately NOT shipped here.** The publisher `httpCredentials` config (§2) is opt-in — a consumer who wants browser-native Basic Auth runs `aem-playwright-auth.sh config` and adds `"--config", ".ai/playwright/config.json"` themselves. Shipping `--config` by default would fail launch on a fresh install where the file doesn't exist yet.

## 2. Auth design (reusable, secret never in model context)

**Publisher Basic Auth** — `.ai/playwright/config.json` (generated from env at `aem-init` time):
```json
{ "browser": { "contextOptions": {
    "httpCredentials": { "username": "<QA_BASIC_AUTH_USER>", "password": "<QA_BASIC_AUTH_PASS>" },
    "viewport": { "width": 1440, "height": 900 },
    "ignoreHTTPSErrors": true
} } }
```
No per-navigation handling — credentials are sent only when a host returns 401 (publisher), never to author/localhost.

**AEM author login** — `bash .ai/lib/aem-author-login.sh <local|qa>`:
1. `dx-common.sh aem-instance <name>` → `$AEM_URL/$AEM_USER/$AEM_PASS` (single source = `AEM_INSTANCES`).
2. `POST <url>/libs/granite/core/content/login.html/j_security_check` with `_charset_=utf-8&j_username&j_password` → `login-token` cookie (verified flow, [2026-05-30 doc](2026-05-30-aem-chrome-devtools-autonomous-auth.md) §4).
3. Write a Playwright `storageState` JSON to `.ai/playwright/aem-author-state.json` (cookie with `httpOnly:true, secure:true`, domain = author host).

Skill/agent flow before author navigation: run the script → `browser_set_storage_state(path: ".ai/playwright/aem-author-state.json")` → `browser_navigate`. Already authenticated; the old form-fill becomes a dead-cookie fallback. Works identically local + CI (CI = a pipeline step runs the script first). `.gitignore` adds `.ai/playwright/`.

## 3. Tool mapping (single source of truth for the rename)

Prefix: `mcp__plugin_dx-aem_chrome-devtools-mcp__X` → `mcp__plugin_dx-aem_playwright__Y`

**Parameters differ too** — the rename is not name-only. chrome-devtools used `uid`/`filePath`; Playwright uses `ref`/`filename`. Missing these causes silent failures `validate-structure.sh` (which only greps the `mcp__` prefix) cannot catch.

| chrome-devtools `X` | playwright `Y` | Param changes (chrome-devtools → playwright) |
|---------------------|----------------|----------------------------------------------|
| `navigate_page` | `browser_navigate` | drop `type`; `url` only |
| `take_screenshot` | `browser_take_screenshot` | **`filePath` → `filename`** (basename, saved under `--output-dir`; `cp` to spec path). Element shot: `element` + `ref` |
| `take_snapshot` | `browser_snapshot` | returns element **`ref`s** (not `uid`s) |
| `evaluate_script` | `browser_evaluate` | `function` (string) or `element`+`ref`; `browser_run_code_unsafe` for full Playwright API |
| `click` | `browser_click` | targets by **`ref`** (not `uid`); double-click via `doubleClick: true` (not `dblClick`) |
| `fill` | `browser_type` | by `ref`; single field |
| `fill_form` | `browser_fill_form` | fields by `ref` |
| `type_text` | `browser_type` | by `ref` |
| `press_key` | `browser_press_key` | `key` |
| `hover` | `browser_hover` | by `ref` |
| `drag` | `browser_drag` (+ `browser_drop`) | start/end by `ref` |
| `upload_file` | `browser_file_upload` | `paths` |
| `handle_dialog` | `browser_handle_dialog` | `accept` / `promptText` |
| `list_console_messages` | `browser_console_messages` | — |
| `get_console_message` | `browser_console_messages` | filter client-side (no single getter) |
| `list_network_requests` | `browser_network_requests` | — |
| `get_network_request` | `browser_network_request` | by `url` |
| `wait_for` | `browser_wait_for` | **`text` / `textGone` / `time`** (no CSS `selector`/`state`) |
| `resize_page` | `browser_resize` | `width` / `height` |
| `list_pages` | `browser_tabs` (list) | merged — `action` param |
| `select_page` | `browser_tabs` (select) | merged — `action` + `index` |
| `new_page` | `browser_tabs` (new) | merged — `action` |
| `close_page` | `browser_tabs` (close) / `browser_close` | merged — `action` |
| `emulate` | `--device` / `--viewport-size` (launch) | no runtime tool; `browser_resize` for viewport |
| `lighthouse_audit`, `performance_*`, `take_heapsnapshot` | — REMOVED | only used by `dx-perf` (removed) |

## 4. Migration surface (44 files)

| Category | Count | Files |
|----------|-------|-------|
| MCP server def | 1 | `plugins/dx-aem/.mcp.json` |
| Automation MCP config | 1 | `plugins/dx-automation/data/mcp/simple-mcp.json` (pins `chrome-devtools-mcp@1.1.1`) |
| Agent `mcpServers:` frontmatter | 3 | aem-fe-verifier, aem-bug-executor, aem-editorial-guide-capture |
| Skill frontmatter | 18 | dx-axe, dx-bug-verify, dx-figma-{verify,all,prototype,extract}; aem-{editorial-guide,snapshot,page-search,verify,doctor,fe-verify,refresh,qa-handoff,component,qa,init,doc-gen} |
| Hook matchers | 1 | `plugins/dx-aem/hooks/hooks.json` (take_screenshot, take_snapshot) |
| Skill/agent bodies w/ tool calls | 10 | dx-axe, dx-simple, dx-bug-verify, dx-figma-verify, aem-fe-verifier, aem-bug-executor, aem-editorial-guide-capture, aem-fe-verify, aem-qa, aem-init |
| Docs / catalogs | 9 | CLAUDE.md (tool-naming table L132), agent-catalog.md, TODO.md, todo-pipeline.md, todo-copilot-cli.md, research/spec docs |

## 5. dx-perf removal

`dx-perf` references chrome-devtools only as an **optional** check; no actual perf-tool calls. Remove the skill entirely; add a TODO to reintroduce perf coverage later (Playwright MCP `--caps=devtools` gives tracing/video but not Lighthouse — a future perf story picks a tool). Update: skill dir, `skill-catalog.md`, `dx-init` references, marketplace/version files if listed, TODO index.

## 6. Phased execution

0. **Scaffold** — `.mcp.json` swap; `aem-init` generates `.ai/playwright/config.json` (+ `.gitignore`); add `aem-author-login.sh`; `hooks.json` matchers; CLAUDE.md tool-naming table.
1. **Frontmatter** — 3 agents (`mcpServers:`) + 18 skills (`tools:`/`allowed-tools:`).
2. **Bodies** — 10 files: apply §3 mapping; rewrite auth blocks to the storageState/httpCredentials flow; convert page-tab calls to `browser_tabs`.
3. **dx-perf** — remove + future TODO.
4. **Automation** — `simple-mcp.json` swap + pipeline-agent wiring; verify CI gets `@playwright/mcp` + a login-script step.
5. **Docs/catalogs** — agent-catalog, todo-*, this doc cross-links.
6. **Release** — BREAKING CHANGE commit → semantic-release → v3.0.0.

## 7. Open items
- Confirm `@playwright/mcp@0.0.75` `--caps`/`--config`/`--storage-state` flag spelling against the pinned version at build time (docs track `latest`).
- `emulate` usages (aem-fe-verifier, aem-bug-executor): confirm they're viewport-only (→ `browser_resize`) vs true device profiles (→ launch `--device`, needs a per-device session).
- Decide whether the publisher `httpCredentials` config is generated by `aem-init` or written on demand by a helper (secrets must stay gitignored either way).
- Whether to move the browser MCP server from dx-aem → dx-core (non-AEM consumers) — deferred.

## Sources
- [microsoft/playwright-mcp README](https://github.com/microsoft/playwright-mcp) · [Playwright MCP — Storage & Auth](https://playwright.dev/mcp/tools/storage) · [Config options](https://playwright.dev/mcp/configuration/options) · [npm @playwright/mcp](https://www.npmjs.com/package/@playwright/mcp)
- [Claude Code — plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) · [plugins reference](https://code.claude.com/docs/en/plugins-reference)
- [2026-05-30 autonomous-auth research](2026-05-30-aem-chrome-devtools-autonomous-auth.md) (verified j_security_check flow; two-auth-layer model)
