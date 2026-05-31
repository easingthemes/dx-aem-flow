# AEM Login for Chrome DevTools Agents — Autonomous Auth — 2026-05-30

How to let the Chrome DevTools MCP agents (`aem-doc-gen`, `aem-editorial-guide-capture`, `aem-bug-executor`, `aem-fe-verify`, `aem-verify`) log into **AEM QA** autonomously, reusing the credentials already in `AEM_INSTANCES`, **without the model ever handling the password**.

> No secrets or client hostnames in this doc. Placeholders: `<qa-author-host>` for the QA author host, `<aem-user>`/`<aem-pass>` for the AEM_INSTANCES `qa` credentials.

---

## TL;DR

- **Root cause of the original failure:** the agents hardcoded the AEM author **form login** as `admin/admin`. On QA the username is the AEM user from `AEM_INSTANCES` (e.g. `admin`) but the **password is not `admin`** — so login failed. Verified: `j_validate` → HTTP 200 with the `AEM_INSTANCES` `qa` password.
- **Two independent auth layers — not interchangeable:**
  - **HTTP Basic Auth** = the website/reverse-proxy gate. Creds = `QA_BASIC_AUTH_*` / `aem.qa-basic-auth`. *Always worked — leave untouched.*
  - **AEM form login** = the AEM author app (`/libs/granite/core/content/login.html`). Creds = `AEM_INSTANCES`. *This is the only thing that needed fixing.*
- **Why the model is forced to courier the secret:** our `.mcp.json` runs `chrome-devtools-mcp` with `--isolated` (throwaway profile every run) → every run hits the login page → the model must fill the form → the password must enter the model's context → the interactive permission classifier (correctly) blocks that. The env var is **not** the problem; the page sandbox can't read env, so the model becomes the courier.
- **Key finding:** AEM form login works **programmatically over HTTP** (no browser, no CSRF token needed for the login itself) once `_charset_=utf-8` is included:
  ```
  POST <qa-author-host>/libs/granite/core/content/login.html/j_security_check
       _charset_=utf-8 & j_username=<aem-user> & j_password=<aem-pass>
    → 302  +  Set-Cookie: login-token=…; Path=/; HttpOnly; Secure; SameSite=Lax
  GET  <qa-author-host>/aem/start.html  (with that cookie)  → 200  ✅
  ```
- **Recommended solution (build tomorrow):** a thin **launch wrapper** around `chrome-devtools-mcp` that, server-side, obtains the `login-token` via the HTTP POST above and injects it into Chrome via **CDP `Network.setCookie`** (CDP can set HttpOnly cookies; page JS cannot). The agent then just `navigate_page`s and is already authenticated. Fully autonomous, no manual login, no persisted-profile dependency, secret never in the model/transcript, works headless/CI and in any permission mode. This is the direct analog of how **AEM MCP** receives `-I ${AEM_INSTANCES}` and authenticates server-side.

---

## 1. How AEM MCP handles creds (the model to copy)

`plugins/dx-aem/.mcp.json`:
```json
"AEM": { "command": "npx", "args": ["-y", "aem-mcp-server", "-t", "stdio", "-I", "${AEM_INSTANCES}"] }
```
`AEM_INSTANCES` format: `name:url:user:pass` comma-separated (e.g. `local:http://localhost:4502:admin:admin,qa:<qa-author-host>:<aem-user>:<aem-pass>`). The AEM MCP server is an **HTTP client** — it uses those creds server-side (Basic Auth to AEM's API). It never needs a browser and never exposes the password to the model. **This is the property we want for the browser path.**

## 2. Why the current Chrome setup forces the secret through the model

`plugins/dx-aem/.mcp.json`:
```json
"chrome-devtools-mcp": { "command": "npx", "args": ["chrome-devtools-mcp@latest", "--headless", "--isolated", "--viewport=1440x900"] }
```
- `--isolated` → fresh throwaway profile each run → no saved login → login page every run.
- `chrome-devtools-mcp` tools (`evaluate_script`, etc.) run **in the browser page sandbox** → cannot read `process.env` → the only way the *model* can fill the form is to embed the literal password in the tool call.
- The interactive auto-mode permission classifier blocks the model from acquiring/printing the secret. In **pipeline mode** (`PIPELINE_MODE`, broad `allowedTools`/bypass via `pipeline-agent.js`) this is *not* blocked — so the existing form-fill already works autonomously there. The gap is **local/interactive** runs.

## 3. chrome-devtools-mcp credential capabilities (research)

From the project docs/README — relevant flags:

| Flag | Purpose |
|------|---------|
| `--user-data-dir` | Persistent profile (default `$HOME/.cache/chrome-devtools-mcp/chrome-profile`). Cookies persist across runs. |
| `--isolated` | Temporary profile, auto-cleaned (what we currently use — the problem). |
| `--browser-url` / `-u` | Attach to an already-running, debuggable Chrome (e.g. `http://127.0.0.1:9222`). |
| `--ws-endpoint` / `-w`, `--ws-headers` | Attach via WebSocket; `--ws-headers` sets headers for the **CDP connection** (not the target site). |
| `--auto-connect` | Auto-attach to a locally running browser (Chrome 144+). |
| `--proxy-server`, `--accept-insecure-certs`, `--executable-path`, `--channel`, `--headless`, `--viewport`, `--log-file` | Launch/network options. |

**Conclusion:** chrome-devtools-mcp has **no feature to inject site-login credentials** from env or flags. The documented "authenticated site" patterns (persistent `--user-data-dir`, or `--browser-url` to your own Chrome) both assume a **prior manual login** — rejected here because we want full autonomy. Therefore the login must be performed by **our own code** (a wrapper), server-side.

Sources:
- [chrome-devtools-mcp README (GitHub)](https://github.com/ChromeDevTools/chrome-devtools-mcp)
- [chrome-devtools-mcp (npm)](https://www.npmjs.com/package/chrome-devtools-mcp)
- [Issue #140 — automatic connection to existing Chrome session](https://github.com/ChromeDevTools/chrome-devtools-mcp/issues/140)
- [Automating authenticated websites with Chrome DevTools MCP + Claude Code (raf.dev)](https://raf.dev/blog/chrome-debugging-profile-mcp/)
- [Chrome DevTools MCP authentication (Scalified)](https://scalified.com/blog/chrome-devtools-mcp-authentication)

## 4. Verified AEM login flow (basis for the wrapper)

All tested live against the QA author (secrets kept in-subshell, token redacted):

1. **HTTP login works** with `_charset_=utf-8` + `j_username` + `j_password` → `302` + `Set-Cookie: login-token=…; HttpOnly; Secure; SameSite=Lax`.
2. **Cookie authenticates** — `GET /aem/start.html` with the jar → `200`.
3. No CSRF token required for the login POST itself (CSRF applies to later authenticated writes).
4. The earlier `curl` attempt that returned 302-without-cookie was missing `_charset_=utf-8`.

Also confirmed: the QA author login page is the standard Granite form — `#username`, `#password`, `#submit-button` — and is reachable without a Basic Auth prompt in this environment.

## 5. Recommended architecture — launch wrapper + CDP cookie injection

`.mcp.json` points `chrome-devtools-mcp` at a wrapper instead of `npx` directly. Wrapper responsibilities (server-side; `AEM_INSTANCES` stays in-process):

1. Parse `AEM_INSTANCES` (reuse `dx-common.sh aem-instance <name>`), select instance(s) (`qa` when `PIPELINE_MODE`/non-localhost target, else `local`).
2. `POST .../j_security_check` (with `_charset_=utf-8`) → capture `login-token` per host.
3. Launch Chrome with remote debugging; inject the cookie via **CDP `Network.setCookie`** (domain = AEM host, `httpOnly:true`, `secure:true`).
4. Hand the authenticated browser to `chrome-devtools-mcp` via `--browser-url` (drop `--isolated`); pipe stdio to the client.

Agent flow afterward: `navigate_page` → already logged in. The existing form-login blocks in the agents become a **dead-cookie fallback** only.

### Feasibility / cost
- **Zero npm dependencies possible:** Node 22+ has global `fetch` (the HTTP login) and global `WebSocket` (CDP over the DevTools WS, `Network.setCookie`). No `puppeteer`/`ws`/`chrome-remote-interface` needed.
- **Chrome binary:** reuse the Chrome that `chrome-devtools-mcp` already installs (puppeteer cache) — self-contained, no extra install. (Decision deferred — see open items.)
- **Cookie refresh:** the wrapper re-logs-in on each MCP launch, so an expired `login-token` self-heals; no persisted-profile staleness.
- **Lifecycle:** wrapper owns the Chrome process; `chrome-devtools-mcp` attaches via `--browser-url`. Alternative: seed the cookie into a persistent `--user-data-dir` via a throwaway CDP session, then launch the MCP on that profile (avoids managing two processes but relies on cookie flush-to-disk timing — less deterministic).

## 6. Current working-tree state (edits already applied this session)

These were applied while exploring the form-login fix. Under the wrapper architecture they remain useful — the `aem-instance` parser is consumed by the wrapper, and the form-login changes become the fallback path. **Nothing committed.** Decide tomorrow whether to keep, trim to fallback-only, or revert.

- **`plugins/dx-core/data/lib/dx-common.sh`** — new `aem_instance <name> [url|user|pass]` subcommand (parses `AEM_INSTANCES`, right-anchored so URL colons don't break it) + CLI dispatch + usage. *Keep — the wrapper uses it.*
- **Form-login now resolves from `AEM_INSTANCES`** (was `admin/admin`, localhost-only fallback) in: `plugins/dx-aem/agents/aem-editorial-guide-capture.md`, `plugins/dx-aem/agents/aem-bug-executor.md`, `plugins/dx-aem/shared/demo-page-setup.md`, `plugins/dx-aem/skills/aem-editorial-guide/SKILL.md`, `plugins/dx-aem/skills/aem-fe-verify/SKILL.md`, and Copilot mirrors `plugins/dx-aem/templates/agents/AEMEditorialGuide.agent.md.template` + `AEMVerify.agent.md.template`. *Becomes fallback-only under the wrapper.*
- **Basic Auth left untouched / reverted** everywhere (the `aem-editorial-guide-capture` "QA/Stage Authentication" section, the `aem-doc-gen` curl checks, `env-vars.md` QA_BASIC_AUTH rows, and `qa-basic-auth.md.template`). Added "two distinct auth layers" notes only.
- **`.mcp.json` not yet changed** — the wrapper rewire is the tomorrow task.

## 7. Open decisions for tomorrow

1. Chrome binary: reuse chrome-devtools-mcp's bundled Chrome vs system Chrome (`--channel`/`--executable-path`).
2. Wrapper lifecycle: own-Chrome + `--browser-url` (deterministic) vs persistent-profile cookie-seed (simpler process model).
3. Where the wrapper lives + how `.mcp.json` references it (`${CLAUDE_PLUGIN_ROOT}/scripts/…`), and the consumer-repo path (`.ai/lib/…`) installed by `aem-init`.
4. Whether to pre-auth all instances at launch or only the one the run targets.
5. Trim the form-login edits to a clearly-labelled fallback once the wrapper lands.
6. End-to-end verification: launch via wrapper → `navigate_page` to an authored page → `take_screenshot`, with no secret in the transcript.

## 8. Side note — unexpected settings change

During the session, `"defaultMode": "bypassPermissions"` appeared in `.claude/settings.json` (git was clean at session start; the file was not edited by intent). It was **reverted**. Worth confirming what introduced it — `bypassPermissions` should not be committed to project settings.
