# TODO: Research-only MCP servers for plugin-improvement work

Servers used by the *maintainer* to research how to improve the plugins — never
shipped inside any `plugins/*/` directory, so they have zero effect on the
marketplace or on what consumers install.

## X (Twitter) MCP for content research

**Added:** 2026-07-01
**Problem:** The maintainer wants to search/read X (Twitter) content — posts, the full-archive search, trends/news — while researching plugin improvements, and to do it from the Claude Code mobile/web app (no local `.env` available). Two things need settling: (1) *where* the server config lives so it never leaks into the shipped plugins, and (2) *how* the auth token is supplied in a cloud session that has no local environment file.

**Key findings (researched 2026-06-30, official docs):**
- X publishes a hosted MCP server at `https://api.x.com/mcp`. Read-only content access needs only an **App-only Bearer token** (`Authorization: Bearer <token>` header); the OAuth 2.0 / `@xdevplatform/xurl` bridge is only for writes/user-context. Requires an X Developer account + App — the real gate is X's API access tier (archive/search generally needs a paid tier).
- A plugin's contents are **exactly its own `plugins/<name>/` directory** (confirmed by `marketplace.json` `source: "./plugins/<name>"` and the plugins reference: `.mcp.json` lives at *plugin root*). A **repo-root `.mcp.json`** is Claude Code's project-scoped dev config and is completely independent — committing it cannot reach the marketplace or any installed plugin.
- Repo-root `.mcp.json` is currently in `.gitignore` (line ~38) by project **convention** (per-developer credentialed dev wiring), not for any technical safety reason.
- `.mcp.json` supports `${VAR}` / `${VAR:-default}` expansion, and `headers` is a valid expansion location — so the token can be referenced by name only, never written into the file.
- **Claude Code on the web (mobile app)** has **no dedicated secrets store yet** and does **not** read GitHub Actions repo secrets. Secrets are supplied as **environment variables in the environment configuration** (claude.ai/code → environment settings, `.env` format, `KEY=value`, no quotes), injected into the session process env. Docs warn these are visible to anyone who can edit the environment.
- Separate path: if run via `anthropics/claude-code-action` in a GitHub workflow, *that* context uses GitHub repo secrets (`${{ secrets.X_BEARER_TOKEN }}` → `env:`), and the same `.mcp.json` expansion applies.

**Scope:**
- `/.mcp.json` (repo root) — add `xapi` server block with `${X_BEARER_TOKEN}` placeholder in the Authorization header; un-ignore (`!.mcp.json` in `.gitignore` or `git add -f`).
- `.gitignore` — decide whether to un-ignore root `.mcp.json` (breaks existing per-dev convention) or keep ignored and configure locally only.
- Claude Code web environment settings — add `X_BEARER_TOKEN` env var (mobile/web path).
- Do **not** touch `plugins/*/.mcp.json`.

**Done-when:** Root `.mcp.json` contains an `xapi` HTTP server pointing at `https://api.x.com/mcp` with `Bearer ${X_BEARER_TOKEN}`; `X_BEARER_TOKEN` is set in the web environment settings; a mobile/web session lists `mcp__xapi__*` tools and can run an X search. No X-related config appears under any `plugins/*/` path (`grep -rl "api.x.com" plugins/` returns nothing).

**Approach:**
1. Obtain an X Developer App + App-only Bearer token on a tier that includes search/archive.
2. Add the `xapi` block (below) to repo-root `.mcp.json`; keep only `${X_BEARER_TOKEN}` in the file.
3. Choose visibility: commit the placeholder-only file (un-ignore) **or** keep it gitignored and add locally. For a personal read-only research token, committing the placeholder is acceptable.
4. Add `X_BEARER_TOKEN=<token>` in claude.ai/code environment settings (mobile/web).
5. Approve the project-scoped MCP server once when prompted.

```json
{
  "mcpServers": {
    "xapi": {
      "type": "http",
      "url": "https://api.x.com/mcp",
      "headers": { "Authorization": "Bearer ${X_BEARER_TOKEN}" }
    }
  }
}
```

**Caveats:** No encrypted secrets vault on web yet — the env var is readable by anyone who can edit the environment; use a read-only token and rotate if the environment is shared. A committed project-scoped `.mcp.json` triggers a one-time approval prompt per the MCP trust model.
