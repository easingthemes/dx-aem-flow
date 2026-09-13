# Agent Plugins Standard Alignment (was: Open Plugins)

**Re-anchored 2026-09-13.** These items were written against the Open Plugins
spec (`open-plugins.com` / `vercel-labs/open-plugin-spec`, v1.0.0, Vercel Labs).
That effort was absorbed into **Agent Plugins 1.0**, published 2026-08-06 at
[github.com/agentplugins/agent-plugins-spec](https://github.com/agentplugins/agent-plugins-spec),
governed by a TSC of core maintainers from Amazon, Cursor, Microsoft, OpenAI and
Vercel, with Google joining. Launch clients: ChatGPT, Codex, Cursor, GitHub
Copilot, Kiro, VS Code. GitHub shipped "Agent Plugins 1.0" GA in VS Code, Copilot
CLI, the Copilot SDK and the Copilot app on 2026-08-12.

**What changed that matters to the items below:**

| Surface | Open Plugins (Vercel) | Agent Plugins 1.0 |
|---------|----------------------|-------------------|
| Manifest location | `.plugin/plugin.json` | **root `plugin.json`** |
| Layout | `.plugin/` + `commands/` + `rules/*.mdc` + `outputStyles/` | root `plugin.json` + optional `skills/` + optional `mcp.json` (+ `schemas/`) |
| Required fields | (v1.0.0 set) | **`$schema` and `name` only** |
| Design stance | configurable | "a minimal, genuinely portable interoperability floor" — "fixed conventions and flat layouts over configurable indirection" |
| Status | self-declared canonical v1.0.0, no tagged release | status page still reads **Working Draft** |

**Honest consequence, not a conclusion:** the five Vercel-spec surfaces tracked
below — `.plugin/plugin.json`, `.mdc` rules, a `commands/` directory,
`${PLUGIN_ROOT}`, `outputStyles/` — do **not appear** in the minimal Agent
Plugins floor, so they read as **retire / re-scope candidates rather than pending
work**. This has *not* been confirmed against the full spec text; the spec
document was not read end to end. Each item below therefore carries the same
Done-when: read the surface's treatment in
`agentplugins/agent-plugins-spec` and then retire or keep it — explicitly, with
the spec section cited. Do not retire any of them on the strength of this summary.

## Vendor-Neutral Manifest

**Added:** 2026-03-26
**Problem:** Open Plugins defines a vendor-neutral `.plugin/plugin.json` alongside vendor-specific dirs (`.claude-plugin/`, `.cursor-plugin/`). Our plugins only have `.claude-plugin/plugin.json`, limiting cross-tool discoverability (Cursor, Codex).
**Scope:** All 4 plugins — `plugins/dx-core/`, `plugins/dx-aem/`, `plugins/dx-hub/`, `plugins/dx-automation/`. Each needs a `.plugin/plugin.json` added.
**Done-when:** Each plugin dir has both `.plugin/plugin.json` (vendor-neutral) and `.claude-plugin/plugin.json` (Claude-specific), and both contain consistent metadata.
**Approach:** Copilot CLI (v1.0.14) now supports `.plugin/` manifest directories. `vercel-labs/open-plugin` repo is now accessible (updated 2026-04-03). Next step: verify Claude Code also supports `.plugin/` discovery, then add vendor-neutral manifests to all 4 plugins.


**Re-anchor (2026-09-13):** Done-when replaced. Before any work here, read this
surface's treatment in
[agentplugins/agent-plugins-spec](https://github.com/agentplugins/agent-plugins-spec)
and record the verdict (**retire** / **keep, re-scoped**) with the spec section
that supports it. The Vercel-era Done-when above is retained as history only —
do not act on it until the verdict is written.

## Rules File Extension (.md → .mdc)

**Added:** 2026-03-26
**Problem:** Open Plugins spec uses `.mdc` extension for rules files (Cursor convention). Our plugins use `.md`. Cursor and other tools may not discover `.md` rules.
**Scope:** `plugins/*/rules/*.md` across all 4 plugins.
**Done-when:** Rules files use `.mdc` extension, or investigation confirms `.md` is equally supported across tools.
**Approach:** `.mdc` is Cursor's convention (MDX-like with frontmatter). Investigate whether Claude Code accepts `.mdc` before renaming. May need dual files or a single extension that all tools accept.


**Re-anchor (2026-09-13):** Done-when replaced. Before any work here, read this
surface's treatment in
[agentplugins/agent-plugins-spec](https://github.com/agentplugins/agent-plugins-spec)
and record the verdict (**retire** / **keep, re-scoped**) with the spec section
that supports it. The Vercel-era Done-when above is retained as history only —
do not act on it until the verdict is written.

## Commands Directory Separation

**Added:** 2026-03-26
**Problem:** Open Plugins defines a separate `commands/` directory for slash commands, distinct from `skills/`. Our plugins use skills for both. This may affect discoverability in non-Claude tools.
**Scope:** All plugin `skills/` directories. Some skills are user-invoked commands (e.g., `dx-init`, `dx-help`), others are agent-only.
**Done-when:** Decision made on whether to adopt `commands/` separation or keep current unified `skills/` approach. Document rationale.
**Approach:** Low priority. Claude Code treats skills as commands already. Only worth splitting if another tool requires the `commands/` convention. Monitor adoption.


**Re-anchor (2026-09-13):** Done-when replaced. Before any work here, read this
surface's treatment in
[agentplugins/agent-plugins-spec](https://github.com/agentplugins/agent-plugins-spec)
and record the verdict (**retire** / **keep, re-scoped**) with the spec section
that supports it. The Vercel-era Done-when above is retained as history only —
do not act on it until the verdict is written.

## PLUGIN_ROOT Variable Naming

**Added:** 2026-03-26
**Problem:** Open Plugins uses `${PLUGIN_ROOT}` for path expansion. Our plugins use `${CLAUDE_PLUGIN_ROOT}` (Claude Code convention). Cross-tool plugins would need the generic name.
**Scope:** Any skill, hook, or config file referencing `${CLAUDE_PLUGIN_ROOT}`.
**Done-when:** Grep for `CLAUDE_PLUGIN_ROOT` returns zero results AND `PLUGIN_ROOT` is used everywhere, OR investigation confirms both are supported.
**Approach:** Wait for Claude Code to support `${PLUGIN_ROOT}` as an alias. Changing now would break Claude Code.


**Re-anchor (2026-09-13):** Done-when replaced. Before any work here, read this
surface's treatment in
[agentplugins/agent-plugins-spec](https://github.com/agentplugins/agent-plugins-spec)
and record the verdict (**retire** / **keep, re-scoped**) with the spec section
that supports it. The Vercel-era Done-when above is retained as history only —
do not act on it until the verdict is written.

## Output Styles Support

**Added:** 2026-03-26
**Problem:** Open Plugins defines an `outputStyles/` directory for custom output formatting. Our plugins don't use this. Could be useful for consistent formatting across tools.
**Scope:** New directory in each plugin, referenced in plugin.json.
**Done-when:** Decision made on whether output styles add value for our use case. If yes, at least one style implemented.
**Approach:** Low priority. Research what output styles look like in practice once the spec repo goes public.


**Re-anchor (2026-09-13):** Done-when replaced. Before any work here, read this
surface's treatment in
[agentplugins/agent-plugins-spec](https://github.com/agentplugins/agent-plugins-spec)
and record the verdict (**retire** / **keep, re-scoped**) with the spec section
that supports it. The Vercel-era Done-when above is retained as history only —
do not act on it until the verdict is written.

## Plugin Logo / Icon

**Added:** 2026-03-26
**Problem:** Plugins show a generic puzzle-piece icon in VS Code Chat Customizations. No `logo` field in `plugin.json` is recognized yet.
**Scope:** All 4 plugins — `plugins/dx-core/`, `plugins/dx-aem/`, `plugins/dx-hub/`, `plugins/dx-automation/`. Each has `assets/logo.png` (256x256, rendered from `website/public/kai-logo.svg`) and `"logo": "./assets/logo.png"` in `plugin.json`.
**Done-when:** VS Code renders the KAI logo in the Chat Customizations panel instead of the generic puzzle-piece icon.
**Spec rename note (2026-09-13):** the field name came from the Open Plugins spec, now succeeded by Agent Plugins 1.0 (see the file header). This item is otherwise unchanged — it is gated on VS Code, not on the spec, and [vscode#304758](https://github.com/microsoft/vscode/issues/304758) is still the tracking issue.
**Approach:** Tracked in [microsoft/vscode#304758](https://github.com/microsoft/vscode/issues/304758) — assigned to Connor Peet, milestone "On Deck". Field name will be `logo` (per Open Plugins spec). Our plugins are already prepared — the field is silently ignored until VS Code ships support. When it lands, verify the logo renders correctly and adjust dimensions if needed.
**Upstream check (2026-07-01):** STILL OPEN — [vscode#304758](https://github.com/microsoft/vscode/issues/304758) remains Open (assignee connor4312, milestone "On Deck", no date). Not shipped. Note the VS Code field is expected to be `icon`; keep our prepared `logo`/`icon` assets ready.

## Monitor Spec Finalization

**Added:** 2026-03-26
**Updated:** 2026-04-06 — `vercel-labs/open-plugin` repo now accessible (last updated 2026-04-03). Vercel actively using the spec for their own `vercel-plugin` (34 skills). Copilot CLI now supports `.plugin/` manifest directories alongside `.claude-plugin/`. Spec appears to be stabilizing.
**Problem:** The Open Plugins GitHub repo (`vercel-labs/open-plugin`) was returning 404. The spec was only on the website. Until the repo is public, the spec may change significantly.
**Scope:** All alignment items above depend on spec stability.
**Done-when (re-anchored 2026-09-13):** [`github.com/agentplugins/agent-plugins-spec`](https://github.com/agentplugins/agent-plugins-spec) has a **tagged release** and its status page no longer reads *Working Draft*. *(Superseded Done-when, kept as history: "`github.com/vercel-labs/open-plugin` is public and has a tagged release" — that repo was renamed to `vercel-labs/open-plugin-spec` and the effort has since been absorbed into Agent Plugins 1.0, so the old URL is dead and the old check can never pass.)*
**Approach:** Periodic check (monthly). Once public, review the full spec and re-evaluate all items above. The Agent Skills layer (SKILL.md) is already stable and adopted — the packaging layer is the uncertain part.
**Upstream check (2026-07-01):** Repo **renamed** `vercel-labs/open-plugin` → **[vercel-labs/open-plugin-spec](https://github.com/vercel-labs/open-plugin-spec)** (old URL 404s). The document self-declares **canonical v1.0.0**, but there is still **NO git tagged release** ("No releases published") — so the Done-when is not met. In-spec now: `.plugin/plugin.json` (host MUST check), `commands/` dir, `${PLUGIN_ROOT}` env var (no `CLAUDE_PLUGIN_ROOT` alias), `.mdc` as the *default* rules extension, and `outputStyles/`. **CANNOT CONFIRM** that Claude Code or Copilot CLI actually discover `.plugin/` or honor `${PLUGIN_ROOT}` yet — no primary source shows host conformance. Hold all alignment items until a tagged release + confirmed host support. See [2026-07-01-upstream-dependency-check.md](../research/2026-07-01-upstream-dependency-check.md).

**Re-anchor (2026-09-13):** The spec this item watched is now **Agent Plugins
1.0** (`agentplugins/agent-plugins-spec`, published 2026-08-06, TSC of Amazon /
Cursor / Microsoft / OpenAI / Vercel maintainers with Google joining; launch
clients ChatGPT, Codex, Cursor, GitHub Copilot, Kiro, VS Code; GitHub shipped GA
across VS Code, Copilot CLI, the Copilot SDK and the Copilot app on 2026-08-12).
Status still reads **Working Draft**, so the watch stays open — but it is now
pointed at a live repo instead of a dead one. On the next check, also read the
five surfaces above (`.plugin/plugin.json`, `.mdc`, `commands/`, `${PLUGIN_ROOT}`,
`outputStyles/`) against the spec text and record retire-or-keep for each; the
minimal-floor design stance suggests they are gone, but that is unconfirmed.
