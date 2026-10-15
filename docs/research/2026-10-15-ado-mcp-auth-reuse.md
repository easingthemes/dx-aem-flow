# ADO MCP auth reuse in `fetch-raw-story.js`

**Date:** 2026-10-15
**Status:** Research only — no decision yet. Options A/B/C need a hands-on test on a developer machine (TODO #248).
**Context:** Developers run dx skills locally. They have **only the dx plugins** — no `az` CLI, no PAT by default.

## Problem

`plugins/dx-core/data/lib/fetch-raw-story.js` (installed as `.ai/lib/fetch-raw-story.js`, called by `/dx-req` step 2) spawns its own `npx -y @azure-devops/mcp <org>` over stdio instead of using Claude Code's MCP connection. Every run opens a browser for login.

## Root cause (verified in `@azure-devops/mcp@2.10.0`, `dist/auth.js`)

- Default auth is `interactive` (`dist/index.js`: `defaultAuthenticationType = isGitHubCodespaceEnv() ? "azcli" : "interactive"`).
- `OAuthAuthenticator` builds an MSAL `PublicClientApplication` (clientId `0d50963b-7bb9-4fe7-94c7-a99af00b5136`) with **no `cachePlugin`** — token cache is in-memory only.
- `accountId` is in-memory too. While it is `null`, `getToken()` goes straight to `acquireTokenInteractive` → `open(url)` → browser.
- Only the org→tenant mapping persists on disk (`~/.ado_orgs.cache`, 1-week TTL). No token is persisted.
- Windows: `NativeBrokerPlugin` (WAM) may show an account picker instead of a browser — still interactive per process.

So **one login per process**. The claims in `fetch-raw-story.js:14-18` and `dx-req/SKILL.md:122` ("MSAL token cache from Claude Code's MCP session is reused — no second prompt") are **false**: Claude Code's ADO MCP is a separate process holding its token in its own memory.

Other auth modes the server supports (`--authentication`): `interactive | azcli | env | envvar | pat`.
- `envvar` — reads `ADO_MCP_AUTH_TOKEN`, sends it as `Bearer` (`getBearerHandler`). Already used by `dx-automation/data/scripts/pipeline-agent.js:66`.
- `pat` — reads `PERSONAL_ACCESS_TOKEN` = base64(`email:pat`).
- `azcli` / `env` — `DefaultAzureCredential` dev chain (az CLI, azd, Azure PowerShell). **Not usable: developers have no `az`.**

## When a developer sees a browser (local, not pipeline)

1. Claude Code's own ADO MCP (`.mcp.json` from `/dx-init`, no `--authentication`) — first login of the session.
2. Every `fetch-raw-story.js` run — new process, empty cache, new login (one per run; one `McpClient` per run, line 77).
3. Re-run of the same story — logs in even when the result is `SKIPPED`, because the idempotency check happens after the fetch (line 135).
4. `/dx-estimate` batch — parallel subagents (`dx-estimate/SKILL.md:46`), each with its own `/dx-req` → **N browser tabs at once**. Most likely the "called several times in a row" case.
5. Model retries / `--force` re-runs after an error.

Callers of the script: `/dx-req` directly; `/dx-agent-all` phase 1 and `/dx-estimate` via `/dx-req`.

## Options (no `az`)

### A) Shared ADO MCP daemon — recommended default

Script connects to one long-lived local `@azure-devops/mcp` process (unix socket / Windows named pipe) instead of spawning a new one.
- First call starts the daemon detached (with a start lock), daemon logs in once; later calls hit `acquireTokenSilent` because `accountId` is now set.
- Idle timeout (e.g. 60 min) shuts it down.
- Parallel callers (`/dx-estimate` batch) share it → one browser.
- Optional: a stdio shim in `.mcp.json` routes Claude Code's own ADO MCP through the same daemon → **one login for everything**. Needs multiplexing of several clients (JSON-RPC id remap, per-client `initialize`).

Pros: official MS auth, no token on disk, no client-ID question.
Cons: one login per work session/day, not per 90 days. ~150 lines (spawn, socket, idle timeout, id remap).
To test: Windows named pipe + lock behaviour; does WAM broker work from a detached process; hermetic test with a fake MCP server (no network).

### B) Script does its own login + refresh-token cache

Zero-dep auth-code + PKCE loopback in the script; access + refresh token in `~/.cache/dx/ado-token.json` (chmod 600); MCP spawned with `--authentication envvar`. Lock file around the interactive step so parallel runs wait for the first.

Pros: login about once per 90 days.
Cons: refresh token in plaintext on disk (no Keychain/DPAPI without deps); needs a public client ID — borrowing `0d50963b-…` (ADO MCP) works but is not guaranteed by MS; clean path is the team registering its own Entra app (needs admin); Conditional Access can shorten/block refresh tokens.

### C) PAT opt-in

If the developer sets `PERSONAL_ACCESS_TOKEN`, script and `.mcp.json` use `--authentication pat`. Trivial; PAT lifecycle is a burden and many orgs restrict PATs. Add-on only.

### Rejected / not applicable

- `azcli` mode or `az account get-access-token` — developers have no `az`.
- Sharing Claude Code's MCP token directly — locked in that process's memory.
- Batching IDs into one run (`--ids`) — helps one batch only, not across runs. Could still ride along with A.

## Independent fixes (any option)

- Correct the false auth comments in `fetch-raw-story.js:14-18` and `dx-req/SKILL.md:122`.
- Pin the MCP version in the script like `pipeline-agent.js` (`ADO_MCP_VERSION`, default `2.10.0`) — `npx -y` without a version pulls latest on every run.

## Upstream

Web search found no issue or fix for persistent token cache in `microsoft/azure-devops-mcp`. General pattern from Azure Identity: persistent cache needs a persistence plugin plus an authentication record.

- [Azure SDK issue: token cache + AuthenticationRecord](https://github.com/Azure/azure-sdk-for-net/issues/38431)
- [Example of a Node identity persistence plugin in an MCP server](https://glama.ai/mcp/servers/@anoopt/outlook-meetings-scheduler-mcp-server/blob/d77d3ed54269f4538706c36db625d82775edeec2/src/auth.ts)
- [Azure CLI issue: cached tokens not found, login every command](https://github.com/Azure/azure-cli/issues/13276)
