# Figma MCP — desktop → remote migration plan (2026-11-10)

Status: **plan, not implemented.** Scope: `dx-core` Figma wiring (`.mcp.json`, `dx-figma-*`
skills, hooks, health check, Copilot agent template) plus docs. dx-automation CI is
touched only to correct the TODO (§6).

Method: grepped the repo, read Figma's official docs (developers.figma.com, help.figma.com),
cloned the official Claude Code plugin (`figma@claude-plugins-official` → `figma/mcp-server-guide`,
v2.2.193) and searched GitHub issues / Figma forum for field reports. Items marked
*(anecdote)* are single user reports, not docs.

## 1. Current state

| Piece | What it does today |
|---|---|
| `plugins/dx-core/.mcp.json` | `figma` → `http://127.0.0.1:3845/mcp` (desktop app, Dev Mode MCP) |
| Tools used | `get_metadata`, `get_design_context`, `get_screenshot`, `get_variable_defs` — only in `dx-figma-extract` |
| `dx-figma-extract/references/mcp-fallback.md` | Forbids remote. Reasons stale: "6/month free", "no OAuth" |
| `hooks/hooks.json` (2 PostToolUse) | Call `.ai/lib/figma-screenshot-hook.sh` to save screenshot + download `localhost:3845` assets |
| `data/lib/mcp-health-check.sh figma` | `curl 127.0.0.1:3845` |
| `templates/agents/DxFigma.agent.md.template`, `dx-figma-all` | "Requires desktop app, port 3845" |
| `website/` | `usage/figma.mdx`, `learn/mcps.mdx`, tip `stdio-vs-http-mcp-servers.md` |

**Found bug (independent of this migration):** `figma-screenshot-hook.sh` does not exist —
not in `data/lib/`, not in git history. The hook's `-f` guard makes it a silent no-op, so
`dx-figma-extract` step 6a/6b ("hook downloads assets / saves PNG",
`.figma-asset-manifest.json`) has never worked from a clean install. Downstream
(`dx-figma-prototype`, `dx-figma-verify`, `aem-fe-verify`, `dx-plan`, `dx-doc-gen`) read
`prototype/figma-reference*.png` and `prototype/assets/`.

## 2. Official facts

| | Desktop `127.0.0.1:3845` | Remote `https://mcp.figma.com/mcp` |
|---|---|---|
| Figma position | "We strongly recommend the remote server" | "Recommended", broadest features |
| Seat | Dev/Full on paid plan | any (but see limits) |
| Needs app open | yes, selection-based | no — needs a **link with node-id** in prompt |
| Auth | none | OAuth (browser), **PAT not accepted** |
| Our 4 tools | ✓ | ✓ same names |
| Extra | — | `download_assets`, `search_design_system`, `get_libraries`, `whoami`, write tools |
| Assets | localhost links, or "download to project" setting | temporary URLs (expire "after a while") |
| Screenshot | image content | URL, or base64 with `enableBase64Response` |
| Headless / CI | no | no |

Rate limits (read tools only; `whoami` etc. exempt; "may change any time"):

| Seat | Starter | Professional / Edu | Organization | Enterprise |
|---|---|---|---|---|
| View / Collab | 20 / month | 20 / month | 20 / month | 20 / month |
| Dev / Full | — | 200/day, 10/min | 200/day, 15/min | 600/day, 20/min |

Limit follows the **plan that owns the file** — a file in Drafts / Starter team gets Starter
limits even with a paid seat *(forum + Figma replies, implied in docs)*.

Official plugin (`figma@claude-plugins-official`): `.mcp.json` server `figma` →
`https://mcp.figma.com/mcp` with header `X-Figma-Plugin-Bundle`, plus 16 skills
(`figma-design-to-code`, `figma-code-connect`, `figma-use`, …). Tool prefix by naming rule:
`mcp__plugin_figma_figma__`. Its `figma-design-to-code` skill says: request a screenshot in
`get_design_context`, follow the response's own asset-download instructions, split
"sparse" responses into parallel child calls.

## 3. Field issues and mitigations

| # | Issue | Source | Mitigation in plan |
|---|---|---|---|
| I1 | Figma only allows catalog clients (DCR `client_name` allowlist). Claude Code, Codex, VS Code, Cursor OK; Claude Desktop 403 | docs + claude-code#74768 | Document supported clients |
| I2 | **Copilot CLI**: first 403 (wrong client name), after 1.0.87 fix token exchange still fails — open | copilot-cli#4906, #4923 | **Keep desktop server as Copilot path** (§4) |
| I3 | Re-auth every restart / reconnect hang after auth (some CC versions) | claude-code#54742, #55943 *(anecdote)* | Troubleshooting doc: restart, `/mcp` → Authenticate |
| I4 | SSH / container / cloud sessions: OAuth callback to localhost | CC MCP docs | Doc `claude mcp login figma` paste-back flow, `ssh -L` |
| I5 | Duplicate servers: plugin + claude.ai connector same URL → **both dropped** (CC 2.1.301, open). Dedup is by URL, so dx-core + official Figma plugin + connector all collide | claude-code#104027, CC docs | Skills resolve Figma tools across known prefixes (§4 R2); doc "disconnect one" |
| I6 | View/Collab seat = 20 calls/month → unusable | docs | Health check runs `whoami` (exempt) and warns on seat/plan |
| I7 | Drafts-owned file → Starter limits | forum | Same `whoami` warning + doc |
| I8 | Asset URLs expire | help center | Download in the same run (§4 R3) |
| I9 | Response >25k tokens truncated in CC | CC docs, forum | Already do `get_metadata` first; add "sparse → child calls"; doc `MAX_MCP_OUTPUT_TOKENS=50000` |
| I10 | VS Code Chat `get_screenshot` failed on remote ("Copilot-Vision-Request header") | forum 2025-10 *(maybe fixed)* | Re-test in spike; fall back to `download_assets` |
| I11 | No CI path: OAuth only, PAT rejected | Figma staff | CI stays out of scope; fix TODO #14 text (§6) |

No reports found of remote output being worse than desktop.

## 4. Target design

**R1 — Two servers in `dx-core/.mcp.json`:**

```json
"figma":         { "type": "http", "url": "https://mcp.figma.com/mcp" },
"figma-desktop": { "type": "http", "url": "http://127.0.0.1:3845/mcp" }
```

- `figma` (remote) is default. Keeps the name → prefix `mcp__plugin_dx-core_figma__` unchanged.
- `figma-desktop` stays for Copilot CLI (I2), enterprise/offline teams, and users without
  Dev seat on remote. Cost: a failed-connect line when the app is closed — same as today.
- Alternative considered: ship no Figma server and depend on the official plugin. Rejected
  as default — Copilot CLI can't use it (I2) and we lose a stable prefix. But we support it (R2).

**R2 — Skills resolve the Figma toolset, not one hard prefix.** Order:
1. `mcp__plugin_dx-core_figma__*` (our remote)
2. `mcp__plugin_figma_figma__*` (official plugin — survives if dedup drops ours, I5)
3. `mcp__claude_ai_Figma__*` (claude.ai connector)
4. `mcp__plugin_dx-core_figma-desktop__*` (desktop)

Same tool names on all four, so the skill body says "call `get_design_context` on the
resolved server". Record which one in `figma-extract.md` (`Source: remote|desktop|…`).
`allowed-tools` / `mcp-server` frontmatter and the Copilot template list both servers.

**R3 — Asset + screenshot saving moves into the skill (drop the dead hook).**
- New `dx-figma-extract/scripts/save-figma-assets.sh <spec-dir> <url>...` — curls each URL
  to `prototype/assets/`, writes `.figma-asset-manifest.json`, works for remote URLs and
  `localhost:3845` URLs. Hermetic `*.test.sh` (local file:// or python http.server fixture,
  no network) — picked up by CI discovery.
- Screenshot: remote `get_screenshot` → URL → same script → `figma-reference[-<vp>].png`.
  Desktop returns image content (no URL, and `download_assets` is remote-only), so the
  desktop path documents "enable *Download assets* in Figma desktop MCP settings" as the
  file route. *(Spike S3 decides final desktop route.)*
- Delete the 2 Figma PostToolUse entries from `hooks.json` and the
  `.ai/.figma-screenshot-target` step; closes the "async screenshot hooks" TODO item for
  Figma and the Copilot "missing hook script" log noise.

**R4 — Call budget.** One extract = 1 metadata + per viewport (context + screenshot) + 1 vars
→ 4 calls single viewport, 6 for desktop+mobile, more on sparse fan-out. Add: abort cleanly
on rate-limit error with a message (seat / file-owner plan / retry tomorrow), never retry in a loop.
Skip re-extraction when `figma-extract.md` is current (already exists).

**R5 — Health check.** `mcp-health-check.sh figma`: curl `https://mcp.figma.com/mcp`
(expect 401/405 = reachable) and `127.0.0.1:3845` (optional). Auth/seat state can't be
checked from bash → `dx-figma-all` pre-flight calls `whoami` (rate-exempt) on the
resolved server and warns on View/Collab seat.

## 5. Spike first (needs a human with a Figma Dev seat — I can't OAuth from here)

| # | Check | Pass |
|---|---|---|
| S1 | `/mcp` → authenticate `plugin:dx-core:figma`; `tools/list` | 4 tools present; record param names (`nodeId`? `fileKey`? URL?) |
| S2 | dx-core + official `figma` plugin both installed | Which prefix survives; do both drop (I5)? |
| S3 | `get_design_context` asset URL host + expiry hint; `get_screenshot` URL vs base64; desktop "download assets" setting | Pick screenshot route for R3 |
| S4 | Run `/dx-figma-extract` on a 2-viewport frame, count calls | ≤ 6 calls, figma-reference-*.png + assets on disk |
| S5 | Copilot CLI latest with remote | Still failing → keep desktop note; fixed → update doc |
| S6 | VS Code Chat `get_screenshot` on remote (I10) | Works / doc workaround |

S1 decides how `get_metadata` / `get_design_context` calls are written (today they pass
`nodeId` only — remote may need `fileKey` too; desktop used the open file).

## 6. Implementation steps (after spike)

1. `.mcp.json` → R1.
2. `dx-figma-extract`: R2 resolve step (new "Resolve Figma server" section), param shape
   from S1, R3 script + test, R4 error handling, frontmatter `compatibility:` text, Rules.
3. Rewrite `references/mcp-fallback.md`: remote → official plugin/connector → desktop;
   troubleshooting (auth, SSH, dedup, rate limits, file owner, large response).
4. `hooks.json`: remove Figma entries. `docs/todo/todo-review-plugin-improvements.md`
   async-hook item: drop Figma part.
5. `mcp-health-check.sh` → R5; `dx-figma-all` pre-flight → `whoami`; `dx-doctor` if it checks Figma.
6. `DxFigma.agent.md.template` prerequisites + tools.
7. Docs: `website/src/pages/usage/figma.mdx` (setup: auth, seat, Copilot note), `learn/mcps.mdx`,
   tip `stdio-vs-http-mcp-servers.md`, `docs/reference/skill-catalog.md` outputs.
8. TODO: correct #14 ("remote MCP doesn't solve CI: OAuth only; option = Framelink
   `figma-developer-mcp` + PAT, pin ≥0.6.3 for CVE-2025-15061, or REST API"); add row for
   this migration with Done-when below.
9. Run: `scripts/validate-*.sh`, the new `*.test.sh`, `bash plugins/dx-core/data/lib/` suites
   touched, `claude plugin validate`.

Commit: `feat(dx-core): default Figma MCP to remote server, keep desktop fallback`.
Not breaking — desktop users keep working via `figma-desktop`.

**Done-when:**
`grep -c 'mcp.figma.com/mcp' plugins/dx-core/.mcp.json` = 1,
`grep -c 'figma-screenshot-hook' plugins/dx-core/hooks/hooks.json` = 0,
`bash plugins/dx-core/skills/dx-figma-extract/scripts/save-figma-assets.test.sh` passes,
and a manual `/dx-figma-extract` on remote leaves `figma-reference.png` + `prototype/assets/*`.

## 7. Open decisions

1. Ship `figma-desktop` alongside (recommended) or remote only?
2. Make the official Figma plugin a recommended companion (gets Figma's skills) — or
   tell users to not install it, to avoid dedup (I5)?
3. Use `search_design_system` / `get_libraries` in `dx-figma-prototype` reuse search — now or later TODO?

## Sources

- https://developers.figma.com/docs/figma-mcp-server/ · /remote-server-installation/ · /local-server-installation/ · /tools-and-prompts/ · /rate-limits-access/ · /mcp-clients-issues
- https://help.figma.com/hc/en-us/articles/32132100833559 · https://help.figma.com/hc/en-us/articles/39252411778583
- https://github.com/figma/mcp-server-guide (official plugin source, v2.2.193)
- https://code.claude.com/docs/en/mcp (OAuth login flow, dedup order)
- https://github.com/anthropics/claude-code/issues/74768 · /54742 · /55943 · /104027 · /105053
- https://github.com/github/copilot-cli/issues/4906 · /4923
- https://forum.figma.com/suggest-a-feature-11/remote-figma-mcp-server-let-a-static-token-authenticate-as-an-alternative-to-oauth-57343
- https://forum.figma.com/report-a-problem-6/figma-mcp-remote-server-image-processing-issue-46293
- https://forum.figma.com/report-a-problem-6/oauth-failure-with-figma-mcp-on-macos-docker-claude-code-52866
- https://modeinspect.com/blog/figma-mcp (file-owner plan gotcha)
