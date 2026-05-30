# MCP Gateway / Single-Wrapper Analysis — 2026-05-30

**Question raised:** Does it make sense to wrap all of our MCP servers (ADO, Atlassian,
Figma, axe, AEM, Chrome DevTools) behind **one custom MCP server** that routes only the
tools we need, combines multiple tools into one via params, and — most importantly —
injects secret env vars (the recurring pain being Chrome DevTools MCP logging into AEM QA)?

**TL;DR — recommendation:** **Don't build a monolithic gateway over all six servers.** Two
of the three motivations are already solved by the harness, and a full wrapper fights our
core "independently-installable plugin" design. **Do** build a *small, targeted* custom MCP
server inside `dx-aem` that solves the parts the harness can't: (a) **server-side AEM auth +
composite task-level tools** (the real Chrome/AEM-QA pain), and (b) a single place to inject
AEM secrets that works identically on every platform. Fix the Chrome `--isolated` session
problem first — it's a config bug, not a missing gateway. Keep ADO/Atlassian/Figma/axe
direct.

Grounded in: official Claude Code MCP docs (Tool Search, `${VAR}` expansion, `headersHelper`,
`alwaysLoad`, elicitation), the Q1-2026 MCP-gateway ecosystem survey, and Anthropic's
"too many tools" guidance. Sources at the bottom.

---

## 1. The three motivations, judged separately

The proposal bundles three distinct goals. They have very different answers, so separate them:

| Motivation | Verdict | Why |
|------------|---------|-----|
| **Reduce tool/context bloat** ("route only tools we need") | ❌ Already solved | Claude Code **Tool Search is on by default** (Opus 4.8 supports `tool_reference`). MCP tool *definitions are deferred* — only names load at startup, schemas load on demand. Adding servers has near-zero context cost. A custom router duplicates a built-in feature. |
| **Combine multiple calls into one** ("composite tools via params") | ✅ Genuinely useful | This is the legit "build task-level tools, not an API mirror" best practice. But it only pays off for **multi-step flows we actually repeat** (AEM-QA login → navigate → snapshot → screenshot). Not worth it for ADO/Jira/Figma, which we already call atomically. |
| **Inject secrets the model never sees + same config every platform** | ✅ Real win, but scoped | A server process can hold credentials and inject them downstream, so secrets never enter context and config is identical across Claude Code / Copilot CLI / Gemini / Cursor. **This is the strongest argument — but it only matters for the server with the secret problem (AEM/Chrome), not all six.** |

So the honest framing: **one of the three reasons is obsolete, and the other two only apply
to the AEM/Chrome corner of the stack.** That single observation kills the "wrap everything"
version and points at a narrow, high-value build.

---

## 2. What the harness already does for us (so we don't rebuild it)

From the official Claude Code MCP docs — features that pre-empt a gateway:

- **Tool Search (default).** Defers all MCP tool defs; loads only what a task needs. The
  classic gateway justification ("GitHub MCP alone is 42k tokens", "Cursor caps at 40 tools")
  **does not apply to us on Claude Code.** Per-server tool counts show in `/mcp`.
- **`alwaysLoad: true`** (v2.1.121+) — per-server or per-tool opt-out of deferral for the
  handful of tools needed every turn. Fine-grained context control without a router.
- **`${VAR}` / `${VAR:-default}` expansion** in `command`, `args`, `env`, `url`, `headers`
  of `.mcp.json`. Secrets stay out of the file; values come from the environment.
- **`headersHelper`** — runs a script at connect time and merges its stdout JSON into the
  connection headers. This is the *supported* way to do Kerberos / short-lived tokens / SSO
  for **HTTP** servers without the model ever seeing the credential.
- **OAuth 2.1** with `/mcp`, `--callback-port`, `--client-id/--client-secret` (stored in the
  OS keychain), `oauth.scopes` pinning, `authServerMetadataUrl` override.
- **Elicitation — form mode.** A server can pop a username/password dialog mid-task and pass
  the answer back. Relevant to AEM login (interactive, not automated).
- **`MAX_MCP_OUTPUT_TOKENS` / `anthropic/maxResultSizeChars`** for large tool output.

**Caveat that actually motivates a gateway:** Tool Search, `headersHelper`, keychain OAuth
are **Claude-Code-only**. Copilot CLI and Gemini have *neither* tool deferral *nor* a
dynamic-header mechanism — they read bare shell env vars and load every tool. Our whole value
prop is cross-platform. So the one durable argument for a custom server is: **it gives every
platform the secret-injection + tool-shaping that only Claude Code has natively.** That's a
real gap — but again, only worth closing where the pain is (AEM/Chrome), not stack-wide.

---

## 3. The MCP-gateway ecosystem (Q1 2026) — what's out there

If we ever do want aggregation, we would **not** build it from scratch — the ecosystem has
~17 tools (agentgateway, Bifrost, Cloudflare Portals, IBM ContextForge, Kong, MCPJungle,
**MetaMCP**, **mcp-proxy**, **Supergateway**, Unla, Portkey, …). Relevant patterns:

- **Aggregator pattern** (most common): one endpoint fronts many backend servers, presents a
  unified tool catalog, centralizes auth / routing / audit / allow-lists. Good for
  *enterprise governance* (RBAC, audit trails, SSO) — **none of which is our problem.**
- **MetaMCP** — proxy that aggregates servers into one, with middlewares, namespaces, tool
  filtering. But it enforces a **strict 1:1 endpoint↔namespace mapping** and needs **two
  instances** (local for file/binary access, networked for the rest) — non-trivial ops.
- **mcp-proxy / Supergateway** — lightweight: STDIO↔HTTP/SSE bridging, basic tool filtering.
  Closest to "just shape the toolset," but **docs don't cover secret injection** — we'd still
  script auth ourselves.

**Takeaway:** off-the-shelf gateways solve *enterprise* concerns (audit, RBAC, SSO across a
fleet) and add real deployment complexity. We're a 4-plugin dev toolkit, not a regulated
fleet. The cost/benefit only flips if we later centralize MCP for a team behind one endpoint.

---

## 4. Why a full "wrap all six" monolith is the wrong shape *for us*

Beyond "two of three motivations are already solved," a stack-wide wrapper actively fights
our architecture:

1. **Breaks independent plugin installability.** Core design: dx-core, dx-aem,
   dx-automation, dx-hub install separately; a non-AEM project pulls *only* dx-core. A single
   gateway server would have to live somewhere and bundle config for servers a given project
   doesn't even have (no AEM, no Figma). That's the opposite of the plugin split.
2. **Single point of failure + serialized startup.** Six healthy servers become one process
   whose crash takes down ADO *and* Jira *and* AEM. Today a flaky Figma localhost server
   can't break work-item access.
3. **Loses `list_changed` / upstream tool updates.** `aem-mcp-server` and
   `chrome-devtools-mcp@latest` ship new tools on `npx ... @latest`; we'd consume them for
   free today. Behind a hand-maintained router, every new upstream tool needs a manual
   passthrough edit.
4. **Re-implements deferral worse than Tool Search.** Our router's "route only needed tools"
   is a static, hand-curated version of what Tool Search does dynamically per task.
5. **Cross-platform name mapping already works.** Our `mcp__plugin_<plugin>_<server>__<tool>`
   convention is *prose hints*; the LLM maps to bare names on Copilot/VS Code and
   `mcp_<server>_<tool>` on Gemini. A wrapper would *change* every tool name and force a
   rewrite of 200+ skill/agent references (cf. TODO #5).

---

## 5. The actual pain: Chrome DevTools MCP can't stay logged into AEM QA

This is **not a "we need a gateway" problem** — it's two fixable issues in
`plugins/dx-aem/.mcp.json`:

```jsonc
"chrome-devtools-mcp": {
  "type": "stdio",
  "command": "npx",
  "args": ["chrome-devtools-mcp@latest", "--headless", "--isolated", "--viewport=1440x900"]
}
```

- **`--isolated` is the root cause.** It launches a **fresh, throwaway Chrome profile every
  run** — no cookies, no session persist. So *every* AEM-QA session starts at the login form.
  That's by design for hermetic browsing, but it's exactly wrong for an authenticated QA
  target.
- **No credentials are passed anywhere.** There is no `AEM_QA_USER` / `AEM_QA_PASS` plumbing;
  any login today must be hand-driven via `navigate → snapshot → fill → click`, and it
  evaporates on the next run.

**Fix ladder (cheapest first):**

| Option | What | Effort | Persists session? | Secret-safe? |
|--------|------|--------|-------------------|--------------|
| **A. Persistent profile** | Drop `--isolated`; add a `--user-data-dir=${AEM_CHROME_PROFILE}`. Log in once; the AEM auth cookie survives across runs. | Trivial (config) | ✅ until cookie expiry | ✅ (no creds in context) |
| **B. Login as a skill step** | Keep isolated; add a reusable `aem-qa-login` step that reads `${AEM_QA_USER}/${AEM_QA_PASS}` from env and scripts the form. | Low | ❌ re-runs each session | ⚠️ creds typed via tool args (in transcript) |
| **C. Pre-seed auth cookie** | Mint an AEM login-token / `cookie` and inject via `evaluate_script` or a profile seed. | Medium | ✅ | ✅ |
| **D. Composite tool in a thin dx-aem MCP** | A custom `aem_qa_session(url)` tool that, server-side, launches Chrome with the persistent profile, performs login using env creds the **model never sees**, and returns a ready page handle. Wraps Chrome DevTools' low-level tools into one task-level call. | Medium-high | ✅ | ✅✅ (creds confined to server process) |

**Recommended:** start with **A** (one-line config win, solves 80% immediately). Graduate to
**D** only if we want login fully automated + secret-isolated + identical across Copilot/Gemini
(the platforms with no Tool Search / `headersHelper`). D is the *only* part of the original
"custom wrapper" idea that earns its keep — and it wraps **one** server, not six.

---

## 6. Recommendation — tiered, do the cheap wins first

1. **Now (config-only):**
   - Switch Chrome to a persistent profile (Option A). Add `AEM_CHROME_PROFILE` to the config
     template + the secrets tip (#30). This alone fixes the stated AEM-QA pain.
   - Standardize secret docs: every secret declared once with `${VAR}` expansion in `.mcp.json`,
     documented in **both** pickup locations (`.claude/settings.local.json` *and* shell export)
     per the existing two-approaches tip. No new mechanism needed.
   - Confirm Tool Search assumptions are documented (it's the reason we *don't* need a router).

2. **If automated, secret-isolated AEM login is required (targeted build):**
   - Add **one thin custom MCP server to `dx-aem`** exposing a few **composite task-level
     tools** over Chrome+AEM: `aem_qa_session`, `aem_capture_page`, maybe `aem_login`. It
     holds creds server-side and shells out to `chrome-devtools-mcp` / CDP. Scope: AEM only.
     Keep ADO/Atlassian/Figma/axe direct.
   - This delivers cross-platform parity (Copilot/Gemini get the same secret-safe login Claude
     Code could fake with `headersHelper`).

3. **Do NOT (unless team-fleet governance becomes a goal):**
   - Build or adopt a stack-wide aggregator (MetaMCP/Kong/etc.). Revisit only if we need
     central audit/RBAC/SSO across many users behind one endpoint — at which point **adopt
     off-the-shelf, don't hand-roll**.

**One-line answer to the original question:** Wrapping *all* MCPs into one custom server is
not worth it — Tool Search already kills the context argument and a monolith breaks our
independent-plugin design. But a *small* AEM-scoped custom server with composite tools that
inject AEM creds server-side is the right fix for the Chrome-QA login pain — and even that is
second to the one-line `--isolated`→persistent-profile change.

---

## Sources

- [Connect Claude Code to tools via MCP — official docs](https://code.claude.com/docs/en/mcp) (scopes, `${VAR}` expansion, `headersHelper`, OAuth, `alwaysLoad`, Tool Search, elicitation, output limits)
- [MCP Aggregation, Gateway, and Proxy Tools: State of the Ecosystem (Q1 2026) — Hey, It Works!](https://www.heyitworks.tech/blog/mcp-aggregation-gateway-proxy-tools-q1-2026)
- [metatool-ai/metamcp — Aggregator/Gateway/Middleware](https://github.com/metatool-ai/metamcp)
- [adamwattis/mcp-proxy-server](https://github.com/adamwattis/mcp-proxy-server)
- [Top 5 Enterprise MCP Gateway Solutions in 2026 — Maxim](https://www.getmaxim.ai/articles/top-5-enterprise-mcp-gateway-solutions-in-2026/)
- [The MCP Context Window Problem — Junia](https://www.junia.ai/blog/mcp-context-window-problem)
- [MCP Tool Overload: Why More Tools Make Your Agent Worse — DEV](https://dev.to/nebulagg/mcp-tool-overload-why-more-tools-make-your-agent-worse-5a49)
- [MCP Tool Governance: Security Meets Context Efficiency — Kong](https://konghq.com/blog/engineering/mcp-tool-governance-security-meets-context-efficiency)
- [Optimising MCP Server Context Usage in Claude Code — Scott Spence](https://scottspence.com/posts/optimising-mcp-server-context-usage-in-claude-code)
- Internal: `CLAUDE.md` (MCP naming + cross-platform table), `website/.../mcp-secrets-two-different-approaches.md` (tip #30), `plugins/dx-aem/.mcp.json`, `plugins/dx-core/.mcp.json`
