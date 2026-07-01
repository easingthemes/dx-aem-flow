# Upstream dependency check — 2026-07-01

Periodic sweep of every open GitHub issue and local TODO that is **blocked on / waiting for** an upstream tool (Claude Code, Copilot CLI, Codex, Gemini CLI, Open Plugins spec, VS Code, ADO MCP). Research done via web (GitHub issue threads, official changelogs/docs) — knowledge-cutoff-independent, primary sources cited inline. Four parallel research agents, one per upstream source.

**Latest upstream versions observed:** Claude Code v2.1.178 · Copilot CLI v1.0.67 (2026-06-30) · Codex CLI v0.142.4 (2026-06-29) · Gemini CLI v0.49.0 (2026-06-25) · ADO MCP `@azure-devops/mcp` v2.8.0 (2026-06-24).

## Headline changes since the last check

- **✅ FIXED upstream — TODO #124 / Copilot PostToolUse matcher bug:** Copilot CLI **v1.0.63** (2026-06-15) now honors `PostToolUse` matchers (e.g. `Edit|Write`) instead of firing every hook on every turn. Our defensive `CLAUDE_TOOL_NAME` guards are now belt-and-suspenders.
- **✅ SHIPPED — TODO #88 / Codex plugins:** native `.codex-plugin/plugin.json` (skills/hooks/MCP/apps) since Mar 2026; marketplaces since ~v0.121. The `.codex/INSTALL.md` symlink hack is superseded.
- **✅ SHIPPED — TODO #89 / Gemini CLI extensions:** full `gemini-extension.json` (`ExtensionConfig`) + auto-discovered `skills/`, hooks, sub-agents. Our 52-byte stub is far behind.
- **✅ SHIPPED — TODO #99 PostToolBatch** (documented stable event) and **TODO #100 `claude_code.skill_activated` OTel** (v2.1.126, `invocation_trigger` = user-slash/claude-proactive/nested-skill).
- **⚠ PARTIAL — GH #16 / TODO #17 `updatedToolOutput`:** v2.1.121 generalized it to all tools, but image-content-block replacement is unconfirmed — needs a live re-test.
- **❌ NO UPSTREAM ISSUE — TODO #103 / ADO MCP truncation:** no issue exists in `microsoft/azure-devops-mcp` for the `wit_get_work_item_attachment` >75 KB base64-truncation bug. We must file it ourselves. Latest ADO MCP is v2.8.0.
- **↔ Open Plugins repo renamed:** `vercel-labs/open-plugin` → **`vercel-labs/open-plugin-spec`**, self-declares v1.0.0 ("canonical") but has **no git tagged release** and no `CLAUDE_PLUGIN_ROOT` alias; host conformance (does CC/Copilot actually read `.plugin/`?) unconfirmed.

---

## Claude Code (anthropics/claude-code)

| Item | Status | Detail |
|------|--------|--------|
| GH #24 / TODO #12 — `plugin:skill` namespace resolution | **STILL OPEN** | Tracked upstream at [#50486](https://github.com/anthropics/claude-code/issues/50486) (Open, `stale`). v2.1.178 namespacing covers only nested `.claude/skills`, not plugin skills. Related: [#22063](https://github.com/anthropics/claude-code/issues/22063), [#15944](https://github.com/anthropics/claude-code/issues/15944), [#43695](https://github.com/anthropics/claude-code/issues/43695). Keep prefix workaround. |
| GH #16 / TODO #17 — `updatedToolOutput` image replacement | **PARTIAL** | v2.1.121 (2026-04-28) generalized `PostToolUse.updatedToolOutput` to all tools; image-content-block replacement not confirmed in docs. Live re-test needed against current (post-Figma) screenshot hook. |
| TODO #99 — `PostToolBatch` hook | **SHIPPED** | Documented in the [hooks reference](https://code.claude.com/docs/en/hooks): no-matcher event, fires once after a parallel-tool batch, supports `decision` (exit 2 halts) + `additionalContext`. |
| TODO #100 — `claude_code.skill_activated` OTel | **SHIPPED** | v2.1.126; `invocation_trigger` ∈ {user-slash, claude-proactive, nested-skill}. Schema matches expectation. |
| TODO #158 — Dynamic Workflows vs CodeAct | **SHIPPED, does NOT moot CodeAct** | v2.1.154 Dynamic Workflows = background orchestration across tens–hundreds of agents, **not** a single-turn program-replaces-tool-orchestration primitive. CodeAct evaluation still stands on its own merits. |

## Copilot CLI (github/copilot-cli) — latest v1.0.67 (2026-06-30)

| Item | Status | Detail |
|------|--------|--------|
| GH #22 — `agent:` skill frontmatter routing | **STILL OPEN** | No shipped fix. Adjacent: [#3532](https://github.com/github/copilot-cli/issues/3532) (skills preload, Open), [#1631](https://github.com/github/copilot-cli/issues/1631) (unknown-field warnings, Open). No single tracker — recommend filing one. |
| GH #21 — `context: fork` | **STILL OPEN** | [#1169](https://github.com/github/copilot-cli/issues/1169) Open, no PR. Subagent config improved (v1.0.62/67) but no skill-driven worktree isolation. |
| GH #20 — subagent skill orchestration | **PARTIAL** | [#1374](https://github.com/github/copilot-cli/issues/1374) **Closed**; [#1180](https://github.com/github/copilot-cli/issues/1180)/[#2150](https://github.com/github/copilot-cli/issues/2150)/[#1506](https://github.com/github/copilot-cli/issues/1506) Open. Skills-from-subagents still not delivered. `MULTI_TURN_AGENTS` real; `SUBAGENT_COMPACTION` unconfirmed. |
| GH #19 / TODO #4 — `handoffs:` execution | **STILL OPEN** | [#561](https://github.com/github/copilot-cli/issues/561) + [#1180](https://github.com/github/copilot-cli/issues/1180) Open. No runtime handoff support. |
| TODO #87 — preToolUse matcher regex | **FIXED (v1.0.36)** | Confirmed in changelog; no regressions through v1.0.67. |
| TODO #124 — PostToolUse matcher on plugin hooks | **FIXED (v1.0.63)** | 2026-06-15: `Edit|Write` matchers honored, no longer fires every turn. Our guards now redundant (keep as defense-in-depth). Upstream bug never got a public issue number from us — the fix landed independently. |
| TODO #20 / #90 — `shared/` path resolution | **STILL OPEN** | [#1090](https://github.com/github/copilot-cli/issues/1090) Open; no fix after v1.0.36. Keep inlining critical logic / use canonical paths. |
| TODO #91 — attachment download | **STABLE/IMPROVED** | v1.0.32 doc attachments; large-file sends (v1.0.60), resume fidelity (v1.0.62/64). No regressions. |
| TODO #102 — ADO auto-disable of GitHub MCP | **CONFIRMED, PRESENT** | Introduced v1.0.46, present through v1.0.67. `dx-automation` `mcp__github__` calls silently no-op on detected ADO repos — audit still warranted. |
| TODO #6 — experimental features | **MIXED** | `MULTI_TURN_AGENTS` confirmed real; `SUBAGENT_COMPACTION` unconfirmed from primary sources. |

## Codex CLI (openai/codex) — latest v0.142.4 (2026-06-29)

| Item | Status | Detail |
|------|--------|--------|
| TODO #88 — first-class plugin support | **SHIPPED** | Native `.codex-plugin/plugin.json` (fields: name/version/description/skills/mcpServers/hooks/apps/interface); `skills/`, `hooks/hooks.json`, `.mcp.json`, `.app.json`, `assets/` at plugin root. Plugins introduced Mar 2026 (app v26.324); marketplaces ~v0.121 (2026-04-15). **Correction to priors:** Codex plugins do **not** bundle agents/subagents (skills/MCP/hooks/apps only), and there is **no documented dotted MCP tool prefix** — servers keyed by TOML `[mcp_servers.<server>]`, tool names constrained to `^[a-zA-Z0-9_-]+$` (dots disallowed). |

## Gemini CLI (google-gemini/gemini-cli) — latest v0.49.0 (2026-06-25)

| Item | Status | Detail |
|------|--------|--------|
| TODO #89 — extension buildout | **SHIPPED** | `gemini-extension.json` (`ExtensionConfig`: name/version/contextFileName/settings[]/mcpServers{}) + auto-discovered `skills/`, hooks, sub-agents; extensions bundle all 7 contribution types. MCP FQN `mcp_<server>_<tool>` confirmed as default — **nuances:** server names must not contain `_`; on cross-server collision Gemini promotes to `serverAlias__tool` (double underscore); "lowercase server" is not enforced (alias used verbatim). |

## Open Plugins spec / VS Code / ADO MCP / Agent Skills

| Item | Status | Detail |
|------|--------|--------|
| TODO #26–#31 — Open Plugins spec | **v1.0.0 doc, no tagged release** | Repo renamed to [vercel-labs/open-plugin-spec](https://github.com/vercel-labs/open-plugin-spec); declares canonical v1.0.0. In-spec: `.plugin/plugin.json` (MUST), `commands/` dir, `${PLUGIN_ROOT}` env var (no `CLAUDE_PLUGIN_ROOT` alias), `.mdc` *default* rules ext, `outputStyles/`. **No git tagged release**; host conformance (CC/Copilot actually reading `.plugin/`) unconfirmed. |
| TODO #32 — plugin logo field | **STILL OPEN** | [microsoft/vscode#304758](https://github.com/microsoft/vscode/issues/304758) Open, assignee connor4312, milestone "On Deck", not shipped. Field will be `icon`. |
| TODO #103 — ADO MCP attachment truncation | **UNTRACKED UPSTREAM** | No issue in `microsoft/azure-devops-mcp` describes the >75 KB base64-truncation bug (closest #392/#1213/#299 are unrelated & closed). Latest ADO MCP v2.8.0 (2026-06-24). **We must file it.** Local `validate-image.sh` mitigation still required. |
| TODO #41 — Agent Skills / OpenSkills standard | **STABILIZED** | Anthropic Agent Skills (SKILL.md) published 2025-12-18; ~32 tools reading the same format by Mar 2026 (Claude Code, Codex, Gemini, Copilot/VS Code, Cursor, Junie, Kiro, Goose…). Our `*/SKILL.md` convention is aligned. "OpenSkills" (openskills.cc) is a catalog, not a competing standard. |

---

## Recommended next actions (post-check)

1. **File 2 upstream issues we now know are untracked:** (a) `microsoft/azure-devops-mcp` — `wit_get_work_item_attachment` base64 truncation >75 KB (TODO #103); (b) `github/copilot-cli` — skill `agent:` frontmatter routing (GH #22).
2. **Newly-unblocked / actionable work:** TODO #88 (Codex `.codex-plugin/` buildout), TODO #89 (Gemini extension buildout), TODO #99/#100 adoption, TODO #17/GH #16 live re-test. TODO #124 can move Mitigated → effectively resolved upstream (keep guards).
3. **Still hard-blocked, no action:** GH #24 (#50486), #21 (#1169), #20 (#1180/#2150/#1506), #19 (#561), TODO #20/#90 (#1090), #32 (vscode#304758).
