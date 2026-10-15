# TODO — Upstream Changes (October 2026 intake)

From [2026-10-15-upstream-sweep.md](../research/2026-10-15-upstream-sweep.md):
Claude Code v2.1.286–v2.1.301 and Copilot CLI v1.0.90–v1.0.98. Each item's
**Done-when** is checkable in this repo, not against the changelog.

## Fail-closed hooks — `onFailure: "block"` on branch-guard

**Added:** 2026-10-15
**Problem:** Claude Code v2.1.295 added `onFailure: "block"` for command and HTTP hooks: a hook that cannot start, times out or exits oddly now blocks the action. Without it a broken or missing `branch-guard.sh` (bad path, no `bash`, timeout) lets the commit through — a safety hook that fails open. v2.1.288 already made PreToolUse hooks block when matching fails, but not when the script itself fails.
**Scope:** `plugins/dx-core/hooks/hooks.json` (PreToolUse `Bash(git commit*)` → `branch-guard.sh`); `/dx-init` step 9i, which installs the same guard into the consumer's settings; `CLAUDE.md` § Hook Authoring — Key Fields.
**Done-when:** `grep -n '"onFailure": "block"' plugins/dx-core/hooks/hooks.json` hits the branch-guard entry, AND `grep -n "onFailure" CLAUDE.md` hits the Hook Authoring table.
**Approach:** Blocking hooks only — informational hooks (`next-step.sh`, `context-loader.sh`) must stay fail-open. Check that Copilot CLI, which reads the same `hooks.json`, ignores the unknown key instead of rejecting the file.

**Done 2026-10-15:** added to the PreToolUse branch-guard entry in `plugins/dx-core/hooks/hooks.json`. Copilot check against the v1.0.98 binary: its hook validator errors on wrong types, nesting and version, but has no unknown-field rejection; the same handler already carries the Claude-only `statusMessage`; and it already denies a `preToolUse` call when the hook errors ("Denied by preToolUse hook (hook errored)"). The `.github/hooks/` template (Copilot-only) is left unchanged. Not exercised live: the block path itself needs a billed `claude -p` run.

## Test our AEM MCP server against MCP protocol `2026-07-28`

**Added:** 2026-10-15
**Problem:** Claude Code now negotiates MCP protocol `2026-07-28` by default for stdio servers (v2.1.292), connectors (v2.1.295) and as the general default (v2.1.299), and MCP requests no longer follow redirects (v2.1.299). Servers that ignore the new check are remembered for 7 days and connect the older way after a delay. Our AEM MCP server (`plugins/dx-aem/.mcp.json`, HTTP) has never been checked against the new version; an AEM author behind a redirect (login, dispatcher) would now fail.
**Scope:** `plugins/dx-aem/.mcp.json`, `plugins/dx-aem/skills/aem-init/SKILL.md`, `plugins/dx-aem/skills/aem-doctor/SKILL.md`.
**Done-when:** a dated note in this section records one connect + one tool call (e.g. `getNodeContent`) against a local AEM on Claude Code ≥ v2.1.299 with the result, AND if it fails, `grep -rn "MCP_PROTOCOL_NEGOTIATION" plugins/dx-aem` shows the documented workaround.

## Copilot agent-scoped hooks for `.github/agents`

**Added:** 2026-10-15
**Problem:** Copilot CLI v1.0.97 added agent-scoped declarative hooks for custom agents. Our generated `.github/agents/` definitions carry no hooks, so on Copilot a custom agent runs without the branch guard that Claude Code gets from the plugin `hooks.json`. Related: v1.0.97 also fixed `--plugin-dir` skills/agents missing from invocation and plugin hooks lost after `--resume`.
**Scope:** `plugins/*/templates/agents/`, `cli/lib/scaffold.js` (if it filters frontmatter), `docs/todo/todo-copilot-cli.md`.
**Done-when:** `grep -rln "hooks:" plugins/*/templates/agents` hits at least the agents that commit (or a recorded decision in this section on why not), AND #229's re-test anchor is moved to v1.0.98.

**Done 2026-10-15.**
- **Schema** (Copilot CLI 1.0.98): `hooks:` in agent frontmatter is an event map — `PreToolUse:` → list of `{type: command, command, windows|linux|osx}`. Both `preToolUse` and `PreToolUse` keys work; with `PreToolUse` the stdin payload is Claude-shaped (`hook_event_name`, `tool_name: "Bash"`, `tool_input.command`), captured live. Source: [CLI hooks reference § Agent-scoped hooks](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-hooks-reference), then confirmed against the binary. The logic lives in the native `runtime.node`, not the JS bundle, so the binary strings alone did not give the schema.
- **How it was verified, without login:** `npm pack @github/copilot-linux-x64@1.0.98` + BYOK (`COPILOT_PROVIDER_BASE_URL`) pointed at a local stub OpenAI-compatible server whose only answer is a `bash` tool call `git commit --allow-empty -m stubtest`. Control agent with no hooks → commit lands. Real `DxCommit` template → `Denied by preToolUse hook: BLOCKED: Do not commit on main…`, 1 commit; same on `feature/y` → commit lands.
- **Trust gate (new finding):** in `-p` mode agent-scoped hooks fire **only when the folder is trusted** (`trustedFolders` in `~/.copilot/config.json`). `GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS=true` and `COPILOT_ALLOW_ALL=true` load *repo* hooks but **not** agent hooks — observed with a marker-file probe. Interactive users trust the folder on first launch, so the guard is live there.
- **Which templates:** every template whose frontmatter grants a shell — `runCommands`/`execute`/`terminal`, or no `tools:` key (= all tools): DxCommit, DxPRFix, DxDebug, DxPlanExecutor, AEMCommit, AEMPRFix. Coordinators (DxAgentAll, DxStepAll, DxBugAll) have no shell and delegate to these. DxDebug does not commit, but the rule is "shell ⇒ guard", which is simpler to check than "mentions commit".
- **Fail-closed:** a Copilot command `preToolUse` hook that exits non-zero denies the tool call. So the guard always exits 0, and has a `windows:` PowerShell variant — without it the POSIX script would error on Windows and deny every tool of that agent. Both variants run in `scripts/check-agent-hooks.test.sh` (pwsh 7.4.6 locally; GitHub ubuntu runners ship pwsh, so CI runs both; the pwsh half SKIPs only where pwsh is absent).
- **Check:** `scripts/check-agent-hooks.sh` requires the canonical block from `plugins/dx-core/templates/hooks/agent-branch-guard.yaml` verbatim in each shell-capable template; seen failing on 6 bad inputs (block removed, drifted branch list, no-`tools:` agent, new `execute` agent, missing canonical file; current `main` failed with 6 errors before the blocks were added).
- **Not verified:** Copilot on Windows actually choosing `windows:` and running it in PowerShell (only the script logic was run, under pwsh on Linux); VS Code Chat honouring the same block (its docs use `hookSpecificOutput`, which the output also carries); agent hooks when the agent runs as a *subagent* of a coordinator.
- #229's re-test anchor was already on v1.0.98.
- **Side finding → #249:** the Copilot 1.0.98 bundle checks `GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS === "true"`; the `=1` we tell users to export does nothing (seen live). Separate PR.

## Claude Code Mods (watch)

**Added:** 2026-10-15
**Problem:** v2.1.287 introduced mods: a plugin whose `hooks.json` has a `modules` key pointing to a JS/TS hooks module that runs inside Claude Code's process (events such as `tool.check`, `agent.spawn`, `turn.step`; later releases add more). It could replace some bash hooks with in-process logic, but Copilot CLI and the other platforms we support have no equivalent, so moving guards there would split our safety story by platform.
**Scope:** `plugins/dx-core/hooks/`, `docs/research/`.
**Done-when:** a decision (adopt for Claude-only extras, or not) is recorded in this section with the reason, OR Copilot ships an equivalent and this becomes a real item.

## Small v2.1.286–v2.1.301 notes for existing items

**Added:** 2026-10-15
**Problem:** Smaller changes that belong in open items, not new work:
- `claude plugin test` fails on a hook's `expect` (v2.1.292); `claude plugin validate` lists gating hooks (`gatingHooks` under `--json`, v2.1.290) → #180.
- `claude plugin eval --disallow-tools`; runs the API refused now score 0 and exit 1 (v2.1.299) → #206.
- `--bare` connects only CLI-named MCP servers, sends no system reminders, starts no background tasks (v2.1.286); `CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL` (v2.1.296) → #200.
- Skill `allowed-tools` / `effort` were dropped in `-p` runs until v2.1.296 — any pipeline Bash denial before ~2026-10-09 may be this, not our code. Pipelines install `@anthropic-ai/claude-agent-sdk` unpinned, so they already have the fix; record it next to #233 when pins are added.
- Dangerous `rm` inside `bash -c` now prompts (v2.1.288) → #223.
- Haiku 5.5 is the default Haiku (v2.1.293) → #222.
- Agent tool `effort` param (v2.1.292), `autoCompactWindow` subagent frontmatter (v2.1.296), max 32 preloaded skills per subagent (v2.1.295) → Model Tier Strategy.
- "`verify` skills are run before commits, except docs-only and tests-only changes" (v2.1.286) — check whether this matches `dx-step-verify` by name and runs it unasked.
**Scope:** the listed TODO detail sections; `CLAUDE.md` § Model Tier Strategy.
**Done-when:** `grep -n "gatingHooks" docs/todo/todo-upstream-2026-09.md` and `grep -n "Haiku 5.5" CLAUDE.md` both hit, and the `verify`-skill question has a one-line answer in this section.

**Update 2026-10-15:** notes distributed into #180, #199, #200, #205, #206, #208, #209, #222, #223 and #233. `verify`-skill question answered from the v2.1.286 entry: it applies only to a project or user skill named exactly `verify` — our `dx-step-verify` is a plugin skill with another name, so it is not run unasked. `Haiku 5.5` added to `CLAUDE.md` § Model Tier Strategy.
