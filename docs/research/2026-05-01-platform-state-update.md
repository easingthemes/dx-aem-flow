# Platform State Update — 2026-05-01

Six-day delta to [2026-04-25-platform-state-update.md](2026-04-25-platform-state-update.md). Covers Claude Code, Copilot CLI, and VS Code releases shipped 2026-04-25 → 2026-05-01.

---

## TL;DR

- **Copilot CLI 1.0.40 introduces breaking opt-in env-var gates.** Repo-level hooks (`.github/hooks/hooks.json`) and workspace MCP (`.mcp.json`) now require `GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS=1` and `GITHUB_COPILOT_PROMPT_MODE_WORKSPACE_MCP=1` respectively. Without them, our entire Copilot setup is silently inert.
- **Claude Code 2.1.121 generalized `PostToolUse.updatedToolOutput` to all tools** — was MCP-only. This effectively unblocks TODO #17 (`updatedMCPToolOutput` inline image replacement).
- **VS Code 1.118 adds dedicated context for skills (experimental)** — VS Code Chat now supports skill-isolated subagents, closing the `context: fork` "Ignored" gap in `cli-vs-chat.mdx`.
- **Copilot CLI 1.0.37 made location-based permission persistence the default** — closes the `PERSISTED_PERMISSIONS` watch-list item.

---

## 1. Releases by tool

### Claude Code — v2.1.119 → v2.1.126 (7 releases)

| Version | Date | Headline |
|---|---|---|
| v2.1.119 | 04-23 | `/config` settings persist to `~/.claude/settings.json` with override precedence; `--from-pr` accepts GitLab/Bitbucket/GHE; `PostToolUse[Failure]` inputs include `duration_ms`; OTel adds `stop_reason`, `gen_ai.response.finish_reasons`, `user_system_prompt` |
| v2.1.121 | 04-28 | **`PostToolUse.updatedToolOutput` works for all tools (was MCP-only)**; MCP `alwaysLoad` skips deferral; `claude plugin prune` removes orphaned auto-installed deps; `/skills` filter; subagent + SDK-MCP reconfigs connect in parallel |
| v2.1.122 | 04-28 | `ANTHROPIC_BEDROCK_SERVICE_TIER` (default/flex/priority); `/resume` finds sessions by PR URL; `/mcp` now shows claude.ai connectors hidden by duplicate manual servers; structured-output Vertex/Bedrock fix |
| v2.1.123 | 04-29 | OAuth 401-loop fix when `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1` |
| v2.1.126 | 05-01 | **`claude project purge [path]`** wipes all CC state; `--dangerously-skip-permissions` extended to `.claude/`/`.git/`/`.vscode/`/shell-config writes; OTel `claude_code.skill_activated` event with `invocation_trigger` (`user-slash`/`claude-proactive`/`nested-skill`); managed-domain sandbox-block precedence fix |

**Hook catalog clarification** — verified against current hooks docs:

- Verified events: `SessionStart`, `Setup`, `SessionEnd`, `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `StopFailure`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, **`PostToolBatch`** (new — fires after parallel tool calls resolve), `PermissionRequest`, `PermissionDenied`, `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `FileChanged`, `ConfigChange`, `CwdChanged`, `InstructionsLoaded`, `WorktreeCreate`, `WorktreeRemove`, `PreCompact`, `PostCompact`, `Elicitation`, `ElicitationResult`, `Notification`.
- Handler types: `command`, `http`, `mcp_tool`, `prompt`, `agent`.
- **`once` field** — applies to skill/agent frontmatter hooks only, NOT settings.json hooks. Resolves the ambiguity in the 04-25 snapshot.
- **`asyncRewake`** — new field for command hooks: runs in background, wakes Claude on exit-code-2 (failure).
- **Important naming correction** — Claude Code uses `Stop`/`SubagentStop`. Only Copilot CLI uses `agentStop`. The 04-25 snapshot conflated the two.

### Copilot CLI — v1.0.36 → v1.0.40 (4 stable releases; 1.0.38 not published)

| Version | Date | Headline |
|---|---|---|
| v1.0.37 | 04-27 | **Location-based permission persistence is now default** (closes `PERSISTED_PERMISSIONS` watch); `copilot completion <bash\|zsh\|fish>`; markdown render in `/ask`; session-picker sort cycling |
| v1.0.39 | 04-28 | `ctrl+x → b` moves running tasks to background; ACP slash commands `/compact`, `/context`, `/usage`, `/env`; `/remote on/off` toggle |
| v1.0.40 | 05-01 | **`GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS` and `GITHUB_COPILOT_PROMPT_MODE_WORKSPACE_MCP` opt-in env-var gates**; MCP OAuth `client_credentials` (headless); subagents respect own model for tool search; `/clear`/`/new` reset custom-agent selection; `/research` uses orchestrator/subagent model; autopilot capped at 5 continuations (`--max-autopilot-continues`); skills appear as slash commands in ACP clients (Zed); ADO auto-detect with GitHub MCP auto-disable; CA certs loaded async at startup |

**v1.0.40 breaking change in detail.** The previously-default behavior of auto-loading `.github/hooks/hooks.json` (repo hooks) and project-root `.mcp.json` (workspace MCP) now requires the user to explicitly opt in via env vars. This is presumably a security tightening — `prompt mode` is the term Copilot uses for "untrusted repo content fed to the LLM," and hooks/MCP-from-repo are the most exfiltration-prone surfaces.

For users on v1.0.40+ with our plugins, both env vars must be exported to retain prior behavior:

```bash
export GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS=1
export GITHUB_COPILOT_PROMPT_MODE_WORKSPACE_MCP=1
```

### VS Code — 1.118 (released 04-29)

Headline items:

- **Remote control of Copilot CLI sessions** from web/mobile — pairs with Copilot CLI `/keep-alive` (1.0.36) and `/remote` (1.0.39). Steer ongoing sessions from another device.
- **Semantic indexing universal** — `githubTextSearch` agent tool added for grep across orgs; semantic search rolled out to all workspaces.
- **Dedicated Context for Skills (experimental)** — skill-isolated subagents in VS Code Chat. Previously `context: fork` was "Ignored" per `cli-vs-chat.mdx`; now experimental support exists.
- **Chronicle (experimental)** — local SQLite chat history; `/chronicle:standup`, `/chronicle:tips`, `/chronicle [query]`.
- **Token efficiency** — 93% prompt-cache reuse per request; up to 20% token savings via deferred-tool semantic matching.
- **VS Code Agents app** — `insiders.vscode.dev/agents` runs Claude agents alongside Copilot CLI. New deployment surface.

---

## 2. Gap closure scorecard (delta from 04-25)

### Newly closed

| TODO | Item | Tool | Status | Evidence |
|------|------|------|--------|----------|
| #17 | `updatedMCPToolOutput` not replacing inline image | Claude Code | **Likely closed** — re-test required | v2.1.121 generalized `PostToolUse.updatedToolOutput` to all tools |
| watch | `PERSISTED_PERMISSIONS` | Copilot CLI | **CLOSED** | v1.0.37 made location-based permission persistence default |
| `cli-vs-chat.mdx` row | VS Code `context: fork` "Ignored" | VS Code Chat | **PARTIALLY CLOSED** | VS Code 1.118 adds dedicated context for skills (experimental) |

### Newly opened / changed

| Item | Tool | Trigger | Action |
|------|------|---------|--------|
| Repo hooks + workspace MCP gated behind env vars | Copilot CLI v1.0.40 | 05-01 release | Update `/dx-init` and `/aem-init` to export both env vars; document in `setup/copilot-cli.mdx`; add to doctor checks |
| `PostToolBatch` hook event | Claude Code | Documented in current hooks reference | Add to hook authoring tables |
| `asyncRewake` command-hook field | Claude Code | Documented in current hooks reference | Document alongside `async` in `CLAUDE.md` |
| `claude_code.skill_activated` OTel event | Claude Code v2.1.126 | New event | Wire into `dx-automation` telemetry if desired |
| `auto-init` ADO auto-detect | Copilot CLI v1.0.40 | New | If GitHub MCP auto-disables on ADO repos, audit `mcp__github__` references in dx-automation |

### Still open / blocked (unchanged since 04-25)

- #4 Agent `handoffs:` execution (Copilot CLI)
- #16 Plugin `:skill` resolution (Claude Code)
- #2 AGENTS.md parity in Claude Code (issue #6235)
- #20 `shared/` path resolution (Copilot CLI)
- #5 MCP prefix normalization

---

## 3. Recommended actions (this snapshot)

### Tier 1 — Required fixes (user-facing breakage)

1. **`website/src/pages/setup/copilot-cli.mdx`** — add a v1.0.40 callout explaining the two new env-var gates with shell-export examples. The "Project .mcp.json Auto-Loaded (v1.0.12+)" highlight is now conditionally false.
2. **`CLAUDE.md` § Hook System — Platform Separation table** — annotate `.github/hooks/hooks.json` row with v1.0.40 env-var gating. Also rename "agentStop" reference to clarify it is the Copilot-side event name only.
3. **`/dx-init` step 9i (Copilot setup)** — emit `export GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS=1` and `GITHUB_COPILOT_PROMPT_MODE_WORKSPACE_MCP=1` into the user's shell profile (with confirmation) when Copilot ≥ 1.0.40 is detected.

### Tier 2 — Doc updates (low-risk)

4. **`website/src/pages/learn/cli-vs-chat.mdx`** — update `context: fork` row from "Ignored" → "Experimental (1.118+)" and `Hooks` row to mention 1.118 capability changes.
5. **`docs/todo/TODO.md`** — re-test #17 against v2.1.121 generalized `updatedToolOutput` and add a new row for "Document v1.0.40 env-var gating in setup docs."
6. **`docs/todo/todo-copilot-cli.md`** — add v1.0.40 prompt-mode section.

### Tier 3 — New-feature adoption (later)

7. Pilot `claude_code.skill_activated` OTel event in `dx-automation` for skill-usage analytics.
8. Consider `PostToolBatch` for replacing some `async: true` post-hooks where batch correlation is helpful.
9. Re-test #20 `shared/` path resolution and #91 attachment download on Copilot v1.0.40.

---

## 4. Source links

- Claude Code: [releases](https://github.com/anthropics/claude-code/releases) · [hooks docs](https://code.claude.com/docs/en/hooks)
- Copilot CLI: [releases](https://github.com/github/copilot-cli/releases)
- VS Code: [1.118 update notes](https://code.visualstudio.com/updates)

## 5. Related docs

- [Platform State Update — 2026-04-25](2026-04-25-platform-state-update.md) — prior snapshot
- [Agent standards landscape](agent-standards-landscape-2026.md)
- [`docs/todo/TODO.md`](../todo/TODO.md)
