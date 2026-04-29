# Platform State Update — 2026-04-25

Snapshot of the four supported AI coding agent platforms (Claude Code, Copilot CLI, Codex CLI, Gemini CLI) covering releases approximately 2026-03-25 → 2026-04-25.

Goal: capture which gaps tracked in `docs/todo/` are now closed in latest releases and what new features should be reflected in plugin setup. Companion to [agent-standards-landscape-2026.md](agent-standards-landscape-2026.md).

---

## TL;DR

- **Three of the four tools shipped major plugin/hook/subagent infrastructure in the last month.** Many gaps tracked for months are now closed.
- **Biggest unblock: Copilot CLI v1.0.14 → v1.0.36** in 30 days closed our two highest-impact gaps — project `.mcp.json` discovery (#23) and Stop/SubagentStop events (#19; reopens #22 hook porting).
- **Convergence is happening on `agentskills.io`.** Claude Code, Codex, and Gemini all now claim spec compliance. Gemini explicitly added a `.agents/skills/` alias for cross-tool sharing.
- **Manifests are still divergent** (`.claude-plugin/` vs `.codex-plugin/` vs `.cursor-plugin/` vs `gemini-extension.json`). No standardization in flight; we will keep multiple sibling manifests.

---

## 1. Releases by tool

### Copilot CLI — v1.0.14 → v1.0.36 (22 stable releases)

| Version | Date | Headline |
|---|---|---|
| v1.0.15 | 04-01 | postToolUseFailure hook; MCP OAuth device-code flow; camelCase config keys |
| v1.0.16 | 04-02 | PermissionRequest hook; MCP servers reload after login |
| v1.0.17 | 04-03 | Built-in skills bundled; MCP OAuth HTTPS redirect URIs |
| v1.0.18 | 04-04 | **Notification hook** (agent_completion, permission_prompt, elicitation) + Critic agent |
| v1.0.21 | 04-07 | `copilot mcp` command; PascalCase event names get snake_case payloads |
| v1.0.22 | 04-09 | Plugin sub-agent depth/concurrency limits; **plugins persist across sessions**; Anthropic BYOK bearer-token; `.vscode/mcp.json` removed as MCP source |
| v1.0.23 | 04-10 | `--mode/--autopilot/--plan` flags; remote tab steers via Tasks API |
| v1.0.24 | 04-10 | preToolUse hook respects `modifiedArgs`/`updatedInput`/`additionalContext` |
| v1.0.25 | 04-13 | Install MCP from registry; ACP MCP server provisioning; `/env` command |
| v1.0.26 | 04-14 | **`PLUGIN_ROOT`/`COPILOT_PLUGIN_ROOT`/`CLAUDE_PLUGIN_ROOT` env vars in plugin hooks**; BYOM image data fixed |
| v1.0.27 | 04-15 | `/ask` quick-question; `copilot plugin marketplace update` |
| v1.0.29 | 04-16 | Claude Opus 4.7 support; `COPILOT_AGENT_SESSION_ID` env in shells/MCP |
| v1.0.32 | 04-17 | `auto` model selection; document file attachments to prompts |
| v1.0.33 | 04-20 | Sub-agents inherit session model; usage warnings at 50/95% |
| v1.0.35 | 04-23 | **HTTP hook support**; `--name`/`--resume=<name>`; MCP-server names with spaces; pattern-specific instruction files no longer inline body each turn; multiple grep/glob paths |
| v1.0.36 | 04-24 | preToolUse `matcher` regex now actually filters; `/keep-alive` GA; `~/.claude/` no longer sourced as Copilot config |

### Claude Code — v2.1.109 → v2.1.119 (9 releases)

Headline: Opus 4.7 xhigh released, MCP tool hooks added, agent `mcpServers` frontmatter support, forked subagents via worktrees.

Notable additions:
- **v2.1.111**: Opus 4.7 xhigh tier
- **v2.1.113**: Stall timeout extended to 10 min for subagents
- **v2.1.116+**: Parallel MCP startup
- **v2.1.117**: Agent `mcpServers` frontmatter; forked subagents (`CLAUDE_CODE_FORK_SUBAGENT=1`); marketplace enforcement
- **v2.1.118**: MCP tool hooks (`"type": "mcp_tool"`)
- **v2.1.119**: Parallel startup confirmed for plugin install resolution

Hook field `once` added for one-shot per-session firing.

### Codex CLI — v0.122 → v0.125 (4 releases)

| Date | Version | Headline |
|---|---|---|
| 2026-04-20 | 0.122.0 | Standalone installs; `/side` quick-question; Plan Mode; AGENTS.md discovery refactored; plugin marketplace tabs/inline toggles; deny-read globs |
| 2026-04-23 | 0.123.0 | Built-in `amazon-bedrock` provider; `/mcp verbose`; plugin `.mcp.json` accepts both `mcpServers` and top-level maps; default model bumped (gpt-5.4) |
| 2026-04-23 | 0.124.0 | **Hooks stabilized** (config.toml + managed requirements.toml, observe MCP/`apply_patch`/Bash); TUI reasoning shortcuts; multi-environment per-turn |
| 2026-04-24 | 0.125.0 | App-server Unix socket transport; **remote plugin install + marketplace upgrade**; permission profiles persist across sessions; rollout tracing for multi-agent |

Earlier in window: plugin system became first-class with sub-agent addressing, thread search, `userpromptsubmit` hook, `@plugin-creator` skill.

### Gemini CLI — v0.35 → v0.39 (+ v0.40 preview)

- **v0.36.0** (04-01) — multi-registry architecture and tool filtering for subagents; subagent enabled-by-default re-enabled
- **v0.37.0** (04-08) — `maxActionsPerTask` for browser; MCP discovery fixes
- **v0.38.0** (04-14) — `/skills reload`; `web_fetch` allowed in plan mode with `ask_user`
- **v0.39.0** (04-23) — `/memory inbox` for reviewing extracted skills, plan-policy consolidation
- **v0.40.0-preview** — `invoke_subagent` unified tool, bundled ripgrep, `/skills` post-submit prompt, MCP resource list/read tools, `gemini gemma` local-model setup
- **v0.41.0-nightly** — skill-creator integrated into skill-extraction agent

---

## 2. Gap closure scorecard

### Now closed / actionable

| TODO | Item | Tool | Status | Action |
|------|------|------|--------|--------|
| #23 | Project MCP not loaded | Copilot CLI | **CLOSED** v1.0.12 (issue #2198) | Remove `--additional-mcp-config` workaround from setup docs |
| #19 | Stop/SubagentStop hooks | Claude Code + Copilot | **CLOSED** | Port Stop guard to `.github/hooks/hooks.json` |
| #22 | Hook porting | Copilot CLI | **UNBLOCKED** | Stop event now exists; finish remaining ports |
| #33 | Hook `if` field | Claude Code | **CLOSED + enhanced** | Adopt `if` filters; new `once` field |
| #37 | Skill `effort` field | Claude Code | **STABLE** | Roll out across model-tiered skills |
| #38 | AEM `paths` field | Claude Code | **STABLE** | Apply to AEM skills |

### New features from latest releases

| Feature | Tool | Version | Where to apply |
|---------|------|---------|----------------|
| Opus 4.7 xhigh tier | Claude Code | v2.1.111 | `dx-step-verify`, `dx-pr-review`, `dx-plan` |
| Agent `mcpServers` frontmatter | Claude Code | v2.1.117 | `dx-aem` agents (isolate AEM/Chrome access) |
| MCP tool hooks (`type: "mcp_tool"`) | Claude Code | v2.1.118 | `dx-automation` ADO/Jira automation |
| Forked subagents (`CLAUDE_CODE_FORK_SUBAGENT=1` env var, `/fork` slash command) | Claude Code | v2.1.117 | Pilot with `dx-ticket-analyze`, `aem-page-finder`. Env var = session-wide blanket inheritance; `/fork` = surgical per-call inheritance (prefer for coordinators that mix context-heavy verifiers with stateless searchers). |
| Hook `once` field | Claude Code | recent | One-shot init scripts |
| HTTP hooks | Copilot CLI | v1.0.35 | `dx-automation` Lambda webhooks |
| `${PLUGIN_ROOT}` / `${COPILOT_PLUGIN_ROOT}` env vars | Copilot CLI | v1.0.26 | Replace path-derivation hacks in hook scripts |
| `agentStop` / `subagentStop` events | Copilot CLI | recent | Port Stop guard |
| Notification hook | Copilot CLI | v1.0.18 | Stop-event substitute, agent_completion signals |
| `auto` model + `continueOnAutoMode` | Copilot CLI | v1.0.32–33 | Long autonomous runs |
| `--name`/`--resume=<name>` named sessions | Copilot CLI | v1.0.35 | Multi-repo hub UX |
| `/env` and `--list-env` | Copilot CLI | v1.0.25, v1.0.29 | `dx-doctor`/`aem-doctor` env verification |
| `COPILOT_AGENT_SESSION_ID` env | Copilot CLI | v1.0.29 | Spec-dir correlation in automation |
| Custom agents `skills:` field | Copilot CLI | v1.0.22 | Eager-load skill content into coordinator agents |
| `.codex-plugin/plugin.json` | Codex CLI | 0.122 | Add manifest per plugin |
| Codex hooks in `config.toml` / `requirements.toml` | Codex CLI | 0.124 | Mirror Stop/PreTool/PostTool hooks |
| Codex slash commands | Codex CLI | 0.122 | Wire `/dx-init`, `/aem-init` natively |
| Gemini extension `gemini-extension.json` | Gemini CLI | 0.36+ | Build per-plugin extension |
| Gemini `.agents/skills/` alias | Gemini CLI | recent | Share skill tree with Codex |

### Still open / blocked

| TODO | Item | Tool | Why blocked |
|------|------|------|-------------|
| #4 | Agent `handoffs:` execution | Copilot CLI | Issues #561, #1377 still open |
| #16 | Plugin `:skill` resolution | Claude Code | No fix announced — keep prefix convention |
| #2 | AGENTS.md parity in Claude Code | Claude Code | Issue #6235 (3K upvotes), Anthropic prioritizing CLAUDE.md |
| #20 | `shared/` path resolution | Copilot CLI | No public issue/release-note — re-test on v1.0.36 |
| #21 retest | Attachment download | Copilot CLI | v1.0.32 added document attachments — may have regressed; retest |
| #5 | MCP prefix normalization | All | LLM still maps; cosmetic only |
| #17 | `updatedMCPToolOutput` inline image | Claude Code | Could not verify status — may need bug filing |

### Watch-list reaching GA

| Feature | Tool | State | Impact |
|---------|------|-------|--------|
| `MULTI_TURN_AGENTS` | Copilot CLI | Still experimental, actively iterated (v1.0.35) | High — replaces re-spawn-per-step |
| `ASK_USER_ELICITATION` | Copilot CLI | Likely GA via Notification hook | Medium — `dx-init` UX |
| `SUBAGENT_COMPACTION` | Copilot CLI | No release-note movement | Medium |
| `PERSISTED_PERMISSIONS` | Copilot CLI | Still experimental (#2820) | Low |

---

## 3. Recommended plugin-update sequence

### Tier 1 — Do now (high value, low risk)

1. Update `docs/todo/TODO.md`: mark #19 and #23 **Done**, refresh #22 status.
2. Port Stop guard to `.github/hooks/hooks.json` using `agentStop` event.
3. Audit `preToolUse` matchers in all `plugins/*/hooks/hooks.json` — Copilot v1.0.36 fixed regex matching; previously-loose patterns may now over-filter.
4. Remove `--additional-mcp-config` workaround from `website/src/pages/setup/copilot-cli.mdx`.
5. Add Opus 4.7 xhigh to `CLAUDE.md` § "Model Tier Strategy" — apply to `dx-step-verify`, `dx-pr-review`.

### Tier 2 — Adopt new features

6. Add agent `mcpServers` frontmatter to `dx-aem` agents.
7. Adopt MCP tool hooks (`"type": "mcp_tool"`) in `dx-automation`.
8. Replace path derivation in hook scripts with `${COPILOT_PLUGIN_ROOT}` / `${PLUGIN_ROOT}`.
9. Pilot HTTP hooks for `dx-automation` Lambda webhooks.
10. Pilot forked subagents (`CLAUDE_CODE_FORK_SUBAGENT=1`) with read-heavy skills.

### Tier 3 — New platform support

11. Codex first-class support — supersedes the `.codex/INSTALL.md` symlink hack:
    - Generate `.codex-plugin/plugin.json` per plugin
    - Mirror MCP config to `~/.codex/config.toml` `[mcp_servers.*]`
    - Mirror hooks to `requirements.toml`
    - Update `cli/lib/scaffold.js` to emit `.agents/skills/`
12. Gemini CLI extension support — currently only a 52-byte `GEMINI.md`:
    - Generate proper `gemini-extension.json` per plugin
    - Use `.agents/skills/` alias to share skills with Codex
    - Map hooks: `PreToolUse` → `BeforeTool`, `PostToolUse` → `AfterTool`, `Stop` → `AfterAgent`, `PreCompact` → `PreCompress`
    - Map model tiers to `gemini-3-pro-preview` / `gemini-3-flash-preview`
13. Update CLAUDE.md "Plugin MCP Tool Naming" table — add Codex (TOML, scheme TBD) and Gemini (`mcp_<server>_<tool>`) rows.

### Tier 4 — Watch / file

14. File or check status of `updatedMCPToolOutput` inline image replacement (#17).
15. Re-test #20 (`shared/` path resolution) and #21 (attachment download) on Copilot v1.0.36.
16. Open issue with agentskills.io to clarify whether `model`/`effort`/`context`/`paths` are core or extension fields (Codex only honors `name`/`description`).

---

## 4. Source links

- Copilot CLI: [releases](https://github.com/github/copilot-cli/releases) · key issues #561 (open), #1377 (open), #2198 (closed), #1157 (closed), #2253 (closed)
- Claude Code: [releases](https://github.com/anthropics/claude-code/releases) · [hooks docs](https://code.claude.com/docs/en/hooks) · issue #6235 (open)
- Codex CLI: [changelog](https://developers.openai.com/codex/changelog) · [skills](https://developers.openai.com/codex/skills) · [AGENTS.md](https://developers.openai.com/codex/guides/agents-md) · [subagents](https://developers.openai.com/codex/subagents)
- Gemini CLI: [releases](https://github.com/google-gemini/gemini-cli/releases) · [skills](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/skills.md) · [hooks](https://github.com/google-gemini/gemini-cli/blob/main/docs/hooks/index.md) · [extensions](https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions/reference.md)
- Standards: [agentskills.io](https://agentskills.io/specification) · [agents.md](https://agents.md/)

## 5. Related docs in this repo

- [Agent standards landscape](agent-standards-landscape-2026.md) — the foundational research this update extends
- [`docs/reference/allowed-tools-compatibility.md`](../reference/allowed-tools-compatibility.md) — the `allowed-tools` frontmatter field across platforms (Copilot CLI v0.0.403 → v1.0.12 detail; full v1.0.14 → v1.0.36 release map lives here)
- [`docs/todo/TODO.md`](../todo/TODO.md) — master tracker; rows #81–94 are follow-ups from this snapshot
- [`docs/todo/todo-copilot-cli.md`](../todo/todo-copilot-cli.md) and [`todo-cross-platform.md`](../todo/todo-cross-platform.md) — per-topic detail files
