# TODO: Copilot CLI Compatibility

Background: Copilot CLI (GA Feb 2026) reads plugins from `.claude-plugin/`. Full analysis in `docs/architecture/cross-agents.md`, `docs/authoring/technical-reference.md` §12–14, and `internal/learnings/2026-03-22-cross-platform-gap-tracker.md`.

**What already works:** `plugin.json`, `marketplace.json`, SKILL.md, `.mcp.json`, hooks (`hooks.json` serves both), `COPILOT_CUSTOM_INSTRUCTIONS_DIRS`, ToolSearch MCP discovery, `applyTo` arrays, plugin discovery via `--plugin-dir`, Open Plugins spec, Skill-to-Skill invocation (verified 2026-03-22).

**Latest version:** v1.0.83 (2026-09-04) — see § "Copilot CLI v1.0.83 hook capabilities" below for what changed since v1.0.40. Everything in the release list below was compiled against **v1.0.40 (2026-05-01)** and has not been re-verified since. Key additions since v1.0.14 — see [2026-05-01-platform-state-update.md](../research/2026-05-01-platform-state-update.md) (delta) and [2026-04-25-platform-state-update.md](../research/2026-04-25-platform-state-update.md) for the full release table:
- v1.0.15: postToolUseFailure hook; MCP OAuth device-code flow.
- v1.0.16: PermissionRequest hook; MCP servers reload after login.
- v1.0.18: **Notification hook** (agent_completion, permission_prompt, elicitation).
- v1.0.22: Plugins persist across sessions; sub-agent depth/concurrency limits; Anthropic BYOK bearer-token.
- v1.0.26: **`PLUGIN_ROOT`/`COPILOT_PLUGIN_ROOT`/`CLAUDE_PLUGIN_ROOT` env vars in plugin hooks.**
- v1.0.29: Claude Opus 4.7 support; `COPILOT_AGENT_SESSION_ID` env in shells/MCP.
- v1.0.32: `auto` model selection; document file attachments to prompts.
- v1.0.35: **HTTP hook support**; `--name`/`--resume=<name>`; pattern-specific instruction files no longer inline body each turn.
- v1.0.36: preToolUse `matcher` regex now actually filters; `~/.claude/` no longer sourced as Copilot config.
- v1.0.37: **Location-based permission persistence default** (closes the `PERSISTED_PERMISSIONS` watch); `copilot completion`; markdown in `/ask`.
- v1.0.39: `ctrl+x → b` background tasks; ACP slash commands `/compact`, `/context`, `/usage`, `/env`.
- v1.0.40: **`GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS` and `GITHUB_COPILOT_PROMPT_MODE_WORKSPACE_MCP` opt-in env-var gates** (BREAKING — see section below); MCP OAuth `client_credentials`; ADO auto-detect with GitHub MCP auto-disable; subagents respect own model; `/research` uses orchestrator/subagent model; autopilot capped at 5 continuations.

**Claude Code-only hook fields (silently ignored by Copilot CLI):** `if`, `async`, `statusMessage`, prompt/agent hook types. *(Compiled against v1.0.40 — re-verify against v1.0.83 as part of the batch re-test, TODO #182.)* Safe to use in plugin hooks — Copilot CLI ignores unknown JSON fields. **Note:** HTTP hook type now supported as of v1.0.35.

**`agentStop` / `subagentStop` events now exist** (Stop guard portable as of v1.0.x — see [#1157](https://github.com/github/copilot-cli/issues/1157), [#2253](https://github.com/github/copilot-cli/issues/2253), both closed 2026-04-07).

## MCP Tool Prefix Normalization

**Added:** 2026-03-22 (rewritten — was "MCP tool names in agent frontmatter")
**Problem:** Skill files use Claude Code-specific `mcp__ado__`, `mcp__atlassian__`, `mcp__plugin_*__` prefixes for MCP tool names (213 occurrences). Copilot CLI and VS Code Chat register bare names (`wit_get_work_item`). However, this is **not a functional blocker** — the LLM reads prefixed names as prose hints and maps them to the actual registered tool names on each platform. Confirmed: `/dx-req` ran all 5 phases on Copilot CLI (2026-03-22), calling bare-name tools successfully despite skills referencing prefixed names.
**Scope:** 213 occurrences across 38 skill files:
- `mcp__ado__` — 84 occurrences in 22 files
- `mcp__atlassian__` — 44 occurrences in 12 files
- `mcp__plugin_*__` — 85 occurrences in 16 files (AEM, Chrome DevTools, Figma, axe)
Also: `plugins/dx-core/shared/*.md` reference files, `docs/reference/agent-catalog.md`
**Done-when:** `grep -rn "mcp__ado__\|mcp__atlassian__\|mcp__plugin_" plugins/*/skills/*/SKILL.md plugins/*/shared/*.md | wc -l` returns 0.
**Approach:** Cosmetic cleanup — normalize to bare tool names for consistency across platforms. Low priority since the LLM resolves either format. Risk: Claude Code may need `ToolSearch` to resolve bare names — test on one skill first.
**Why not a blocker:** MCP tool names in SKILL.md are prose instructions to the LLM, not literal function calls. The LLM maps `mcp__ado__wit_get_work_item` → `wit_get_work_item` when the actual tool registry uses bare names (Copilot CLI, VS Code Chat), and uses the full prefix when the registry has it (Claude Code).
**Evidence:** `internal/learnings/2026-03-22-copilot-cli-compatibility.md` §2, `internal/learnings/2026-03-22-skill-simplification-refactor.md` (Copilot CLI PASS — all 5 phases)

## Agent Format Divergence

**Added:** 2026-03-03
**Problem:** Claude Code agents (`agents/*.md`) use PascalCase tools and `model:` alias. Copilot agents (`templates/agents/*.agent.md`) use lowercase tools and `handoffs:`. These are maintained as dual files. `handoffs:` is parsed but does NOT execute in Copilot CLI — agents can't actually call other agents.
**Scope:** `plugins/dx-core/agents/*.md` (12 files) AND `plugins/dx-core/templates/agents/*.agent.md.template` (15 files). Also `plugins/dx-aem/agents/` and `plugins/dx-aem/templates/agents/`. Install script: `plugins/dx-core/data/lib/install-copilot-agents.sh`.
**Done-when:** Either (a) single-source agent files work on both platforms (check: `ls plugins/dx-core/templates/agents/` returns empty or doesn't exist), OR (b) Copilot CLI `handoffs:` works (check: GitHub issue [#561](https://github.com/github/copilot-cli/issues/561) is closed).
**Approach:** Watch for #561 resolution AND VS Code/Copilot CLI supporting Claude-format tool names natively. Current: `install-copilot-agents.sh` copies templates → `.github/agents/` with post-copy transforms (editFiles→edit, chrome-devtools→chrome-devtools-mcp, allowed-tools injection).
**Upstream check (2026-07-01):** STILL BLOCKED. [#561](https://github.com/github/copilot-cli/issues/561) and [#1180](https://github.com/github/copilot-cli/issues/1180) remain Open; no runtime `handoffs:` execution shipped through Copilot CLI v1.0.67 (2026-06-30). Dual-file maintenance continues. (GH #19.)

## Shared Path Resolution

**Added:** 2026-03-22
**Problem:** Copilot CLI looks for `shared/*.md` reference files at `~/.copilot/installed-plugins/.../skills/shared/` instead of the correct `~/.copilot/installed-plugins/.../shared/`. This means `shared/provider-config.md`, `shared/external-content-safety.md`, `shared/hub-dispatch.md` all fail to load. Non-blocking (skills continue without them) but means provider detection, safety rules, and hub dispatch logic are silently skipped.
**Scope:** `plugins/dx-core/shared/` (all reference files) — currently: `provider-config.md`, `external-content-safety.md`, `hub-dispatch.md`, `pr-review.md`, `pr-answer.md`.
**Done-when:** Either (a) Copilot CLI fixes plugin path resolution for `shared/`, OR (b) critical logic from reference files is moved into main SKILL.md bodies (check: `grep -rn "Read.*shared/" plugins/*/skills/*/SKILL.md | wc -l` — if zero, all critical logic has been inlined).
**Approach:** May be upstream Copilot CLI bug. Workaround: inline critical reference file logic (like DoR dedup checks) into SKILL.md. Non-critical context (provider detection) can remain in reference files.
**Evidence:** `internal/learnings/2026-03-22-skill-simplification-refactor.md` bug #2
**Upstream check (2026-07-01):** STILL OPEN. Confirmed upstream at [#1090](https://github.com/github/copilot-cli/issues/1090) (Open; shared skills libraries / symlinks / scripts not resolving); no fix after v1.0.36 through v1.0.67. Related discovery issues [#2390](https://github.com/github/copilot-cli/issues/2390), [#1080](https://github.com/github/copilot-cli/issues/1080) also open. Keep inlining critical logic / use canonical paths (TODO #20, #90).

## Attachment Download

**Added:** 2026-03-22
**Problem:** Copilot CLI ignores the skill instruction "preserve URLs as-is" and tries to download ADO image attachments via HTTP. Gets HTML login page instead of images (saved as garbage `.bin` files in spec directory). Claude Code correctly skips downloads.
**Scope:** `plugins/dx-core/skills/dx-req/SKILL.md` — Phase 1 (fetch work item) where attachments are processed.
**Done-when:** `grep -n "Do NOT download\|NEVER download\|preserve.*attachment.*URL" plugins/dx-core/skills/dx-req/SKILL.md` returns a match with explicit "Do NOT download attachments" instruction.
**Approach:** Add stronger instruction to SKILL.md Phase 1: "Do NOT download attachments — ADO requires browser auth. Preserve `<img>` URLs as-is in the raw story." Current wording is too soft for Copilot CLI to follow.
**Evidence:** `internal/learnings/2026-03-22-skill-simplification-refactor.md` bug #3
**Upstream check (2026-07-01):** STABLE — no regression. Copilot CLI attachment handling improved since v1.0.32 (large-file sends v1.0.60, resume fidelity v1.0.62/64) through v1.0.67; the shipped mitigation still holds (TODO #91). No further action needed.

## Hooks Porting — UNBLOCKED 2026-04-07

**Added:** 2026-03-22
**Updated:** 2026-04-25
**Problem:** Several plugin hooks not ported to Copilot CLI's `.github/hooks/hooks.json`. Only branch guard was deployed (dx-init step 9i).
**Status:** Stop event now exists in Copilot CLI as `agentStop` / `subagentStop` (issues [#1157](https://github.com/github/copilot-cli/issues/1157), [#2253](https://github.com/github/copilot-cli/issues/2253) closed 2026-04-07). The Notification hook (v1.0.18) provides agent_completion signals as a complementary substitute. All previously blocked hooks are now portable.
**Scope:**
- Source: `plugins/dx-core/hooks/hooks.json` (all hooks defined here)
- Target: `plugins/dx-core/templates/hooks/` or dx-init step that copies to `.github/hooks/`
- Supported events in Copilot CLI v1.0.36: PreToolUse, PostToolUse, SessionStart, PreCompact, SubagentStart, **agentStop**, **subagentStop**, Notification, PermissionRequest, postToolUseFailure, **HTTP hooks** (v1.0.35)
**Done-when (rewritten 2026-11-10):** (a) `bash plugins/dx-core/skills/dx-doctor/scripts/__tests__/repo-hooks-audit.test.sh` exits 0 — template has no plugin-root reference, its guard blocks `git commit` on main with exit 2, and the audit flags/repairs old installs without touching foreign hooks; **and** (b) a Copilot cloud coding agent run in a test repo whose `.github/hooks/hooks.json` is the template shows the branch guard refusing a `git commit` on the default branch, recorded in this section. (a) passes; (b) not done.
**Old Done-when (retired):** `grep -c "SessionStart\|PostToolUse\|agentStop" .github/hooks/hooks.json` ≥4 — it counted event names and could not tell a hook that runs from one that exits 127. The file it asked for was the broken one.
**Approach:**
1. Port SessionStart hook (config validation)
2. Port Figma PostToolUse hooks
3. Port Edit PostToolUse hook
4. **Port Stop guard using `agentStop` event (newly available)**
5. Audit existing `preToolUse` `matcher` patterns — v1.0.36 fixed regex matching, previously-loose patterns may now over-filter.
**Evidence:** `internal/learnings/2026-03-22-cross-platform-gap-tracker.md` GAP 6; release notes for v1.0.18, v1.0.35, v1.0.36.
**Status update 2026-07-01:** Still not ported — `.github/hooks/hooks.json` does not exist, so Copilot CLI users get zero harness safety (no branch guard, next-step hints, or workflow-state tracking). Single biggest driver of the Copilot CLI score (6.5/10) in the July re-rating. Env-var precondition (#97/#98) already satisfied, so this is now the top unblocked Copilot fix. See [2026-07-01-plugin-eval-claude-copilot.md](../research/2026-07-01-plugin-eval-claude-copilot.md).

**Re-check 2026-11-10 (static, not on Copilot):** the Done-when grep counts event names; it cannot tell whether the hooks run. Three problems:
1. `dx-scaffold.js` does not write `.github/hooks/` at all. Only `/dx-init` step 9i copies `templates/hooks/branch-guard-hooks.json.template`, so the Done-when has no file to check in a scaffolded project.
2. The template's SessionStart (`session-start.sh`, `next-step.sh`) and PostToolUse (`validate-plugin-edit.sh`) commands resolve their scripts through `${PLUGIN_ROOT:-${COPILOT_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}}`. Copilot sets those variables for **plugin** hooks (v1.0.26). Nothing we have says it sets them for **repo** hooks in `.github/hooks/`. With all three unset, the command is `bash "/hooks/scripts/session-start.sh"` → exit 127 (reproduced locally). Likely broken on Copilot; one interactive check settles it.
3. Copilot already reads the plugin's own `hooks/hooks.json` (CLAUDE.md § Hook System). The branch guard and Stop guard in the `.github/hooks/` copy therefore probably fire twice. That is harmless for a guard, but it doubles the work and noise of every non-guard hook.
Before marking this done: on Copilot, record whether `PLUGIN_ROOT` is set inside a `.github/hooks` command, and whether a plugin `Stop` hook fires as `agentStop`. If plugin hooks already cover Copilot, the `.github/hooks/` copy may only need the `-p` untrusted-folder case.

**Docs check 2026-11-10** ([hooks reference](https://docs.github.com/en/copilot/reference/hooks-reference)): Copilot CLI loads hooks from policy, then user (`~/.copilot/hooks/*.json`, `~/.copilot/settings.json`), then project (`.github/hooks/*.json`, `.github/copilot/settings(.local).json`, `.claude/settings(.local).json`), then plugins (`hooks.json` or `hooks/hooks.json`). "All hook entries from all sources are run" — there is no dedup. PascalCase event names (`Stop`, `PreToolUse`) are accepted, with Claude matcher semantics, and `Stop` is `agentStop`. So the plugin `hooks/hooks.json` alone already gives Copilot the branch guard and Stop guard, and the `.github/hooks/` copy makes them run twice (point 3 above is now documented, not inferred). `PLUGIN_ROOT`, `COPILOT_PLUGIN_ROOT`, `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PROJECT_DIR` are **not documented** for any hook source; only `COPILOT_PLUGIN_DATA` is. Point 2 still needs the live check.

**Resolution 2026-11-10 (fix PR, not yet verified on the cloud agent):** the port is turned around. Copilot CLI already runs the plugin `hooks/hooks.json` (all sources, no dedup, `Stop` = `agentStop`), so nothing more needs porting for the CLI. The repo copy is kept only for the cloud coding agent and now holds only self-contained entries:
- `templates/hooks/branch-guard-hooks.json.template` — inline branch guard (`Bash|bash|shell|execute`, stdin `git commit` filter, exit 2) and the `agentStop` guard via `${CLAUDE_PROJECT_DIR:-$PWD}`. SessionStart (`session-start.sh`, `next-step.sh`) and PostToolUse (`validate-plugin-edit.sh`) are gone; they stay plugin-only.
- `skills/dx-doctor/scripts/repo-hooks-audit.sh` — dx-doctor 6.5d runs it read-only; dx-upgrade 3e-ii and dx-init 9i (merge into an existing file) run `--fix`. Flags plugin-root commands, permission-rule matchers, `exit 1` blocks, stale/missing/duplicate dx guards. `--fix` repairs only dx-installed entries; foreign hooks stay byte-identical (tested).
- Figma PostToolUse hooks from the old Approach were never ported and are not: they need a plugin root too.
Not verified: that the cloud agent runs `PreToolUse`/`agentStop` from this file and honours exit 2 — Done-when (b). Locally the two guards run twice (plugin + repo); harmless, not removed.

## Prompt-Mode Gates v1.0.40

**Added:** 2026-05-01
**Problem:** Copilot CLI v1.0.40 (released 2026-05-01) gates two previously-default behaviors behind opt-in environment variables:
- `GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS=true` — required for `.github/hooks/hooks.json` (repo-level hooks) to load.
- `GITHUB_COPILOT_PROMPT_MODE_WORKSPACE_MCP=true` — required for project-root `.mcp.json` (workspace MCP) to load.

Without these, Copilot CLI silently ignores both. This breaks our entire Copilot setup on v1.0.40+ — branch-guard hooks, Stop guards, ADO MCP, Atlassian MCP — without any error message.

**Scope:**
- `/dx-init` step 9i — Copilot setup
- `dx-doctor` (and `aem-doctor` if applicable) — env var verification
- `website/src/pages/setup/copilot-cli.mdx` — user-facing instruction (already updated)
- `CLAUDE.md` § Hook System — Platform Separation (already updated)
- ADO auto-disable side effect: v1.0.40 auto-disables the GitHub MCP server when an ADO repo is detected. Audit `dx-automation` skills for `mcp__github__` references that may now silently no-op.

**Done-when:**
- `grep -r "GITHUB_COPILOT_PROMPT_MODE" plugins/dx-core/skills/dx-init/` returns the two exports.
- `dx-doctor` checks both env vars and warns if missing on Copilot ≥ 1.0.40.
- A test session on Copilot v1.0.40 with the env vars unset confirms hooks/MCP do not load (negative test).
- A test session on Copilot v1.0.40 with the env vars set confirms `Stop` guard fires and ADO MCP servers are visible.

**Correction 2026-10-15 (TODO #249):** the value was wrong from day one. Copilot CLI compares both variables `=== "true"` — seen in the `@github/copilot@1.0.40` bundle (`process.env.GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS==="true"`) and again in the 1.0.98 `cli-main.js`, where the gate is `COPILOT_ALLOW_ALL==="true" || GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS==="true" || folderTrustIsTrusted(cwd)`. So the `=1` we exported never enabled anything. Live check on 1.0.98 (BYOK stub model, untrusted folder, repo `preToolUse` hook writing a marker file): `=true` → hook fires; `=1` → it does not. Also: the gate only exists in prompt mode (`-p`); a trusted folder loads repo hooks and workspace MCP without any env var. Fixed: dx-init writes `=true` and rewrites existing `export …=<anything>` lines (snippet run twice against fresh / old `=1` / mixed rc files — all end with two `=true` lines, no duplicates); dx-doctor checks for `true` and reports a wrong value; CLAUDE.md, `website/src/pages/setup/copilot-cli.mdx`, `website/src/pages/contributing/technical-ref.mdx`. Not touched: dated research notes under `docs/research/` (historical record).

**Approach:**
1. Add an `init-copilot-shell-exports.sh` helper invoked from `/dx-init` step 9i that detects Copilot CLI version and appends the two exports to `~/.zshrc` / `~/.bashrc` (idempotently).
2. Add a `doctor-copilot-prompt-mode.sh` check.
3. Update auto-init for similar handling in CI environments.

**Evidence:** Copilot CLI v1.0.40 release notes (2026-05-01); [2026-05-01 platform state update](../research/2026-05-01-platform-state-update.md).
**Upstream check (2026-07-01):** ADO auto-disable of the GitHub MCP server is CONFIRMED PRESENT through v1.0.67 (introduced v1.0.46, reinforced ~v1.0.62). The `mcp__github__` audit for `dx-automation` (TODO #102) is still warranted — those calls silently no-op on detected ADO repos. **Audit done 2026-11-10 (TODO-102):** `grep -rn "mcp__github__" plugins cli .github` → 0; nothing to no-op.

## PostToolUse `matcher` Ignored on Plugin Hooks

**Added:** 2026-05-16
**Upstream check (2026-07-01):** ✅ FIXED UPSTREAM in Copilot CLI **v1.0.63** (2026-06-15) — changelog: *"PostToolUse hook matchers (e.g. `Edit|Write`) are now honored instead of silently dropped."* This resolves the "fires every hook on every turn" behavior. Our `CLAUDE_TOOL_NAME` guards (shipped 2026-05-16) are now defense-in-depth and can stay. Remaining follow-up items: file the retroactive upstream issue is now moot; the CLAUDE.md hook-platform table correction (#125) still stands. See [2026-07-01-upstream-dependency-check.md](../research/2026-07-01-upstream-dependency-check.md).
**Problem:** Copilot CLI v1.0.45 fires every `PostToolUse` hook entry in `~/.copilot/installed-plugins/.../hooks/hooks.json` after every AI turn, regardless of (a) whether any tool was called and (b) whether the entry's `matcher` field matches the tool that was called. This produces:
- `[ERROR] Hook execution failed` log noise for hooks that call project-level scripts which don't exist (e.g., `.ai/lib/figma-screenshot-hook.sh` in a fresh project)
- Spurious side-effect files (e.g., `.ai/screenshots/screenshot-log.txt` with `unknown` rows appearing in projects that never used AEM)
- Counter pollution (`compaction-reminder.sh` ticks on every turn instead of just Edit/Write)
- Wasted bash subprocess spawns per AI turn

Empirical evidence: typing "hi" in a clean Copilot CLI session in `/Users/715466/PROJECTS/AI/kai-team/` (a project with no `.ai/`, no `.claude/`, no `.github/hooks/`) triggers 5 distinct plugin PostToolUse hooks within 80ms of the model response — full trace in [`docs/research/2026-05-16-copilot-cli-hook-matcher-bug.md`](../research/2026-05-16-copilot-cli-hook-matcher-bug.md).

**Scope:**
- `plugins/dx-core/hooks/hooks.json` — 5 `PostToolUse` entries (figma×2, validate-plugin-edit, Task, compaction-reminder)
- `plugins/dx-aem/hooks/hooks.json` — 2 `PostToolUse` entries (take_screenshot, take_snapshot)
- `plugins/dx-core/hooks/scripts/compaction-reminder.sh`, `plugins/dx-aem/hooks/scripts/screenshot-log.sh` — defensive guards required at script level
- `CLAUDE.md` § Hook System — Platform Separation table is wrong: "Plugin `hooks/hooks.json` is active in Claude Code CLI only" — Copilot CLI also consumes the file.

**Done-when:**
- Run `grep -lE "CLAUDE_TOOL_NAME" plugins/{dx-core,dx-aem}/hooks/scripts/*.sh` and confirm every PostToolUse script has a tool-name guard.
- Run `grep -E "CLAUDE_TOOL_NAME" plugins/dx-core/hooks/hooks.json | wc -l` returns ≥4 (each PostToolUse inline command guarded).
- Reproduce: open a fresh project with no `.ai/` in Copilot CLI, type "hi", confirm `~/.copilot/logs/process-*.log` has zero `[ERROR] Hook execution failed` lines for plugin hooks.
- Upstream issue filed against `github/copilot-cli` with reproduction steps.

**Approach:**
1. ✅ Mitigation (shipped 2026-05-16): added `case "$CLAUDE_TOOL_NAME" in ... ) ;; *) exit 0 ;; esac` guards to plugin scripts; wrapped `hooks.json` inline commands with `[ "${CLAUDE_TOOL_NAME:-}" = "<exact-tool>" ] && [ -f <script> ] && bash <script> || true`.
2. File upstream Copilot CLI bug. Title: "PostToolUse hooks fire on every AI turn regardless of matcher (plugin hooks at ~/.copilot/installed-plugins/)". Include the empirical trace.
3. Update CLAUDE.md § Hook System — Platform Separation: change row to reflect that Copilot CLI also reads `hooks/hooks.json` but ignores `matcher` on PostToolUse.
4. Test whether the same bug affects `PreToolUse`. **2026-10-16:** the branch-guard matcher `Bash(git commit*)` never misfired because it never fired at all — as a regex it matches no tool name, in Claude Code too. Now `Bash|bash|shell|execute` with an inline `git commit` stdin check (`plugins/dx-core/hooks/branch-guard-hook.test.sh`); whether Copilot honours a PreToolUse matcher is still untested.
5. After upstream fix lands, audit our guards — they're defense-in-depth and harmless to keep, but the redundancy noise in `hooks.json` commands could be removed.

**Evidence:** [`docs/research/2026-05-16-copilot-cli-hook-matcher-bug.md`](../research/2026-05-16-copilot-cli-hook-matcher-bug.md), Copilot CLI session log `~/.copilot/logs/process-1778960080353-20620.log` lines 95–104.

**Re-test 2026-11-10 on v1.0.108 (TODO-263):** matcher `Edit|Write` is honored — on a prompt asking for file creation, a shell command, and a file edit, the matching plugin hook fired only for the two successful file operations, both reported as `tool_name: "Edit"`; it did not fire for the shell call. Copilot does **not set `CLAUDE_TOOL_NAME`**; plugin `PostToolUse` stdin carries `tool_name` and `tool_input`. (A separate repo-level `preToolUse` capture used camel-case `toolName`/`toolArgs`.) The stdin fallback lets `compaction-reminder.sh` count the observed `Edit` calls; `screenshot-log.sh` did not log them. Regression coverage is in `plugins/dx-core/hooks/hook-tool-name.test.sh`. The inline `CLAUDE_TOOL_NAME` guards in `plugins/dx-core/hooks/hooks.json` (Figma, Task, validate-plugin-edit) had the same blind spot — on Claude Code too, which never sets that variable either (v2.1.322 probe). Fixed under TODO-263.

## Project MCP Discovery — CLOSED 2026-04-07

**Added:** 2026-03-22
**Resolved:** 2026-04-07 (Copilot CLI v1.0.12)
**Problem:** Copilot CLI did NOT read project-level `.mcp.json` at startup. Plugin MCP servers loaded correctly, but project-specific servers (ADO, Atlassian) were invisible.
**Status:** Closed — [github/copilot-cli#2198](https://github.com/github/copilot-cli/issues/2198) closed 2026-04-07. v1.0.12 added `CLAUDE_PROJECT_DIR` and `CLAUDE_PLUGIN_DATA` env vars; workspace MCP servers now load correctly.
**Follow-up actions:**
- [ ] Remove `--additional-mcp-config` workaround from `website/src/pages/setup/copilot-cli.mdx`.
- [ ] Verify in workflows that previously needed `--additional-mcp-config`.
**Evidence:** `internal/learnings/2026-03-22-cross-platform-gap-tracker.md` GAP 1; release notes for v1.0.12.

**Re-test 2026-11-10 on v1.0.108:** STILL OPEN. With distinct markers at `<plugin>/shared/`, `<plugin>/skills/<skill>/shared/`, and `<plugin>/skills/shared/`, a `--plugin-dir` skill read the skill-local marker; a second skill with no local marker read the `<plugin>/skills/shared/` marker. Installing the same local plugin into an isolated `COPILOT_HOME` produced the same skill-local result. Neither path resolved `<plugin>/shared/`; keep inlining critical logic. A skill body containing `${CLAUDE_PLUGIN_ROOT}/shared/marker.md` did not expand it (the shell saw an empty variable).

## Copilot CLI v1.0.83 hook capabilities

**Added:** 2026-09-13
**Problem:** Every Copilot CLI note in this file was written against v1.0.40
(2026-05-01). Copilot CLI is now at **v1.0.83 (2026-09-04)** and has added three
hook capabilities we neither use nor document:
1. **Personal hooks from `~/.copilot/hooks`**, in addition to the repo-level
   `.github/hooks`. Our hook-source table (`CLAUDE.md` § "Hook System — Platform
   Separation", and the docs-site hooks page) lists only plugin `hooks/hooks.json`,
   `.github/hooks/hooks.json` and agent-frontmatter `hooks:` — there is no row for
   a user-level Copilot hook directory, so a consumer with personal hooks has an
   undocumented fourth layer interacting with ours.
2. **An `ask` permission decision for `preToolUse` hooks** — request user
   confirmation before the tool executes, rather than only allow/deny. Our
   `preToolUse`-shaped guards (branch-guard is the live example) are binary
   today: `exit 2` blocks with stderr feedback, anything else lets the call
   through. `ask` is the missing middle for guards that should warn rather than
   hard-block.
3. **OpenTelemetry trace context in hook input** (`traceparent` / `tracestate`),
   so a hook can emit spans correlated with the agent run. This is the Copilot-side
   counterpart of the OTel work in #100 and the telemetry line in #160
   (`.ai/telemetry.jsonl`).
**Scope:**
- Docs (other workstream): `CLAUDE.md` § "Hook System — Platform Separation" table;
  `website/src/pages/learn/hooks.mdx`.
- Templates/implementation: `plugins/dx-core/hooks/hooks.json` (10 handlers today,
  8 with `statusMessage`, 2 `async`), `plugins/dx-aem/hooks/hooks.json` (2 handlers),
  and the `.github/hooks/` install performed by `/dx-init` step 9i.
**Done-when:** `grep -rn "~/.copilot/hooks" CLAUDE.md website/src/pages/learn/hooks.mdx`
returns the new hook-source row, AND `grep -rn '"ask"' plugins/*/hooks/hooks.json
plugins/dx-core/skills/dx-init/SKILL.md` returns either an adopted `ask` decision
or an explicit written decision not to adopt it.
**Approach:** Document all three first — the personal-hooks row is a correctness
fix to a table we ship, and costs nothing. `ask` is the only one worth adopting
immediately, and only for advisory guards; branch-guard must stay a hard block.
Defer OTel until #100/#160 pick a telemetry sink, otherwise it is spans with
nowhere to go.

## Experimental Features

**Added:** 2026-03-03
**Problem:** Three Copilot CLI experimental features would significantly improve coordinator workflows if they stabilize. Need to monitor and prototype when ready.
**Scope:** Coordinator skills (`dx-step-all`, `dx-agent-all`, `dx-bug-all`, `dx-req`) and init skills (`dx-init`, `aem-init`).
**Done-when:** Each feature is individually actionable — check `/experimental` in Copilot CLI for GA status.
**Upstream check (2026-07-01, v1.0.67):** `MULTI_TURN_AGENTS` confirmed real (referenced since v1.0.35). `SUBAGENT_COMPACTION` **could not be confirmed** from primary sources — treat as unverified until visible in `/experimental`. Subagent config knobs (model/effort/context tier, nested concurrency) shipped v1.0.62; parent-tool-restriction inheritance v1.0.67 — but skills-from-subagents / `/fleet` skill support still missing (GH #20).

### MULTI_TURN_AGENTS — Persistent subagents with write_agent

**Impact: High.** Currently coordinators invoke skills via Skill tool for each step, losing context. Multi-turn agents stay alive — coordinator sends follow-ups via `write_agent`.

**Done-when:** `dx-step-all` uses `write_agent` to send step instructions to a persistent subagent instead of re-spawning per step.
**Action when stable:**
1. Test with `DxStepAll` → persistent subagent
2. Update all coordinator agent templates
3. Measure context quality vs current re-spawn approach

### SUBAGENT_COMPACTION — Compaction instead of truncation

**Impact: Medium.** Benefits subagent-heavy workflows — especially `dx-agent-all` (8+ skills). Addresses [#1180](https://github.com/github/copilot-cli/issues/1180).

**Done-when:** `/experimental` shows SUBAGENT_COMPACTION as stable. No code changes needed — enable flag, test with `/dx-agent-all`.

### ASK_USER_ELICITATION — Structured form-based input

**Impact: Medium.** `/dx-init` and `/aem-init` ask 6-8 sequential questions. A form presents all fields at once.

**Done-when:** `dx-init` SKILL.md uses structured elicitation tool for step 1-3 questions, with fallback to sequential.
**Action when stable:**
1. Prototype with `/dx-init` step 1-3
2. Map sequential questions to form fields with defaults
3. Update SKILL.md with fallback

### Other (not actionable)

| Feature | Assessment |
|---------|------------|
| `PERSISTED_PERMISSIONS` | Nice UX, no code changes needed |
| `SESSION_STORE` | Our agents don't depend on cross-session state |
| `EXTENSIONS` | Too early — our hooks work fine |
| `CONFIGURE_COPILOT_AGENT` | `/dx-init` already handles this |

## Copilot reads `.claude/rules` natively — and the env var may never have worked

**Added:** 2026-09-29
**Problem:** Copilot CLI v1.0.89 (2026-09-28, [changelog](https://raw.githubusercontent.com/github/copilot-cli/main/changelog.md)) reads `.claude/rules` as custom instructions natively. Before that we relied on `COPILOT_CUSTOM_INSTRUCTIONS_DIRS=.claude/rules` (set by `/dx-init` step 9a-bis). The current [docs](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions) say that env var loads only `AGENTS.md` and `*.instructions.md` — our rules are plain `<name>.md`. So on <1.0.89 the rules may never have loaded on Copilot, though the list above marks it "works". On ≥1.0.89 they may load twice, and it is unknown if the native loader honours `applyTo:`.
**Scope:** `plugins/dx-core/skills/dx-init/SKILL.md` (env-var step), `plugins/dx-core/templates/claude-code/settings.json.template`, `plugins/dx-aem/skills/aem-init/SKILL.md` (lines 22, 270, 342), `plugins/dx-hub/skills/dx-hub-init/`, `website/src/pages/architecture/cross-agent.mdx`, `plugins/*/templates/rules/**`.
**Done-when:** `/instructions` output from a Copilot v1.0.89 session with and without the env var is recorded in this section, AND the dx-init env-var step is either removed or version-gated to match the result.

**Done 2026-10-15.** `copilot instruction list` works without a login, so this was measured, not inferred. Fixture: a repo with `.claude/rules/{cross-repo,pr-review}.md` (our templates) and a `ts-only.md` with only `paths: ["src/**/*.ts"]`.

| Copilot CLI | env var unset | `COPILOT_CUSTOM_INSTRUCTIONS_DIRS=.claude/rules` |
|---|---|---|
| v1.0.88 | "No instruction sources found." | "No instruction sources found." (a `control.instructions.md` in the same folder **is** listed) |
| v1.0.98 | all 3 rules listed; `ts-only.md` gets `"applyTo": ["src/**/*.ts"]` from `paths:` | same 3 rules, no duplicates |

So the env var never loaded our rules — it only picks `AGENTS.md` and `*.instructions.md` — and from v2.43.0 (when `.github/instructions/` copies were dropped) until Copilot v1.0.89 our rules did not reach Copilot at all. Native loading honours `paths:`. Done: removed step 9a-bis's env var (now says "nothing to set; existing value is harmless"), the env block in `templates/claude-code/settings.json.template`, `dx-hub-init` and this repo's `.claude/settings.json`; corrected `aem-init` and 4 website pages. `applyTo:` stays in the rule templates for VS Code Chat.

## Tier Copilot custom agents — `model` + `reasoning-effort`

**Added:** 2026-09-29
**Problem:** Copilot v1.0.88 (2026-09-22) makes a custom agent's `reasoning-effort` actually apply (before, only `model` did); v1.0.85 (2026-09-16) added `model` as an ordered fallback list and `model-policy: required`. None of our `.github/agents` templates set `model`, `reasoning-effort` or `model-policy`, so the Opus/Sonnet/Haiku tiering in `CLAUDE.md` never reaches Copilot.
**Scope:** `plugins/*/templates/agents/*.agent.md.template`, `cli/lib/scaffold.js` if it rewrites frontmatter.
**Done-when:** `grep -rln "reasoning-effort" plugins/*/templates/agents` returns the tiered agents, OR this section records a decision not to tier.
**Approach:** Decide together with #202/#215 (per-agent frontmatter pass). Use aliases or fallback lists, never a single pinned id.

**Done 2026-10-15.** Tiers follow each template's `<!-- Source: -->`: `DxCodeReview` → `model: ['Claude Opus 5.5', 'Claude Opus 5']` + `reasoning-effort: high`; 6 Sonnet-backed templates (`AEMAfter`, `AEMBefore`, `AEMEditorialGuide`, `AEMSnapshot`, `AEMVerify`, `DxPRReview`) → Sonnet list, no effort (vendor default, as on the Claude side); `DxComponent`, `DxHelp` → Haiku list; `AEMTicket`, `DxTicket` → Haiku list + `reasoning-effort: low` (their source skill sets `effort: low`). The 14 templates backed by untiered skills or coordinators stay unset. Display names, not ids: Copilot CLI accepts them since v1.0.24 and they are VS Code's documented format, so one value works in both. `model-policy` left at the default (`preferred`) so a user can still switch models.

**Also found:** 20 of 25 templates opened with the `<!-- Source: -->` comment *before* `---`. Copilot's instruction parser anchors frontmatter at the start of the file (`(?s)^---`); if the agent parser does the same, those agents lost `name`/`tools`/`handoffs`. Not confirmed live (a Copilot session needs a login), but moving the comment below the closing `---` is correct for every parser. Consumers get the fixed files only via `/dx-upgrade` (it re-runs `install-copilot-agents.sh --force`); `/dx-init` skips existing files. Guarded by `validate-structure.sh` check 9.

## v1.0.87–v1.0.89 notes for the batch re-test

**Added:** 2026-09-29
**Problem:** Changes that shift what the #182 re-test must check:
- v1.0.85: plugin agents/skills/MCP no longer dropped in `-p` (so `--agent <plugin>:<agent>` works headless without `--plugin-dir`); `sessionEnd` fires on `/clear`; `${PLUGIN_ROOT}` expanded in agent `mcp-servers` frontmatter (#86); `allowManagedHooksOnly` also blocks extension callbacks.
- v1.0.87: prompt mode exits 0 when a child task fails but parent recovers; `strictKnownMarketplaces: []` blocks built-in marketplaces.
- v1.0.88: hooks without `cwd` run from project root **again** (regression between 1.0.83 and 1.0.87); namespaced custom skills + ignored skill dirs (→ #12, Copilot must resolve `dx-core:<name>` too).
- v1.0.89: direct plugin installs can be enabled/disabled; valid workspace MCP servers kept when a sibling entry is invalid.
- Upstream bugs still open at 2026-09-29: copilot-cli#4708, #4886, #4545 — #19–#22 stay blocked.
**Scope:** #182 and rows #20, #22, #40, #87, #90, #91, #102, #124 (still say "current is v1.0.83").
**Done-when:** `grep -c "v1.0.83" docs/todo/TODO.md` drops to the historical mentions only, with the re-test anchor at v1.0.89.

**Update 2026-10-15:** anchor moved straight to **v1.0.98** (2026-10-14) — 9 more releases since v1.0.89. What the #182 re-test must add: agent-scoped declarative hooks for custom agents (v1.0.97, → #245); `--plugin-dir` skills/agents now reach invocation and plugin hooks survive `--resume` (v1.0.97); autopilot denies a preToolUse `ask` instead of stalling (v1.0.97); MCP config applies between turns (v1.0.93); retired models removed (v1.0.92). Nothing on `.claude/rules` or AGENTS.md (#227 open). Remaining `v1.0.83` mentions in `TODO.md` are historical (#182's own title and the September intake line).

## External harness research + v1.0.107–v1.0.108 notes

**Added:** 2026-11-10
**Problem:** An external cross-harness capability snapshot (dated 2026-09-29, ~Copilot CLI v1.0.89) and the v1.0.107 (2026-11-06) / v1.0.108 (2026-11-09) changelogs carry Copilot behaviours our notes do not record. Each one can make a guard we ship weaker than we think:
- **Hook timeouts fail open on every event, `preToolUse` included.** Only a hook *error* denies (TODO-243 records that half). A slow `branch-guard.sh` on Copilot lets the commit through.
- **VS Code Local ignores hook `matcher` values** — every hook for the event runs. Our agent-frontmatter branch guard (TODO-245) must filter by tool itself, not rely on the matcher.
- **Copilot CLI overrides a Stop/`agentStop` hook after 8 consecutive block continuations.** Our Stop guard can be bypassed by persistence (#22).
- **Copilot CLI reads hooks from `.claude/settings(.local).json`.** Safe today: `templates/claude-code/settings.json.template` has no `hooks`. If one is added there, Copilot runs it in addition to `.github/hooks/` → double firing.
- **Copilot reads `.claude/agents/`;** `.github/agents` wins at the same level. `dx-eject` writes both → possible duplicate agent listings on Copilot.
- **Cloud coding agent ignores symlinks**, user scope and plugins — the `.codex/INSTALL.md` symlink approach is invisible to it.
- **`${CLAUDE_PLUGIN_ROOT}` expansion inside skill bodies on Copilot is unverified** — same unknown as #20 and #86.
- **Snapshot gaps (not ours to fix):** its `.agent.md` field list misses `reasoning-effort` (v1.0.88) and agent-scoped `hooks` (v1.0.97).
- **v1.0.107:** an unreadable/invalid `.github/hooks` file is now reported, not skipped (helps #40); plugin rules with `alwaysApply: false` stay out of the prompt until enabled; `COPILOT_SESSION_CWD` for MCP/LSP configs.
- **v1.0.108:** a `preToolUse` `ask` on parallel calls asks per call again (#182); `.github/mcp.json` is **ignored** when `.mcp.json` exists in the same directory (not merged); interactive sessions pass local MCP `env` values literally — host vars need `${NAME}` (our plugin `.mcp.json` files set no `env`); `copilot help config` names `.claude/rules` and `.claude/settings.json` (confirms TODO-227); a selected agent with missing skills now warns; `disabledSkills` matches any case.
- Issues #19–#22: nothing in the 1.0.107/1.0.108 changelogs addresses them.
**Scope:** `plugins/dx-core/templates/hooks/`, `scripts/check-agent-hooks.sh`, `plugins/*/templates/agents/*.agent.md.template`, `plugins/dx-core/skills/dx-eject/SKILL.md`, `.codex/INSTALL.md`, website hook pages.
**Done-when:** the #182 batch re-test runs on Copilot CLI ≥ v1.0.108 and its dated note records a result for: (a) a `preToolUse` hook that sleeps past its timeout — allowed or denied; (b) the branch guard in a `.agent.md` under VS Code Local with a non-matching tool (moved to TODO-265 on 2026-11-10 — VS Code Chat, not Copilot CLI); (c) a Stop hook that blocks 9 times; (d) agent listing after `dx-eject` in a scaffolded project. Each (a)–(d) is either fixed in code or documented on the website hook page.
**Approach:** re-anchor the #182 batch re-test from v1.0.98 to v1.0.108 when it is run. For (a), if timeouts fail open, keep the guard fast (no network) and say so in the hook docs.

### Fix 2026-11-10 — Stop guard on Copilot (item c)

`stop-guard.sh` only stopped re-blocking on `stop_hook_active`, which Copilot's `agentStop` input does not send — so on Copilot it blocked until the 8-block cap. It now writes `<checksum of reason> <epoch>` to `$GIT_DIR/dx-stop-guard.last` and lets the agent stop when the same findings come back within 10 minutes (one block per finding set, both harnesses). Also fixed: in a repo with no `.ai/specs/`, a duplicate in-progress check (`find` under `pipefail`) made the script exit 1, a non-blocking error, so the guard never blocked there. Covered by `plugins/dx-core/data/hooks/stop-guard.test.sh` (fails on the old script). Items (a) and (c) are on the website hook page; (b) moved to TODO-265; (d) open as TODO-264. Remaining for this item: confirm on Copilot that `agentStop` stdin has no `stop_hook_active` and does carry `cwd` (one probe).

### Validated 2026-11-10 on Copilot CLI v1.0.108 (TODO-182 batch)

Setup: `copilot --version` → `GitHub Copilot CLI 1.0.108`; fresh `node cli/bin/dx-scaffold.js /tmp/cp-v --all`, `git init -b main`, one initial commit. Prompt-mode probes used `GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS=true`, `GITHUB_COPILOT_PROMPT_MODE_WORKSPACE_MCP=true`, `--trust-folder`, and `--allow-all-tools`. No live ADO/AEM calls. The session ran in a VS Code integrated terminal; that does not change the results: Copilot CLI loads hooks, plugins, agents and `shared/` from the project and `~/.copilot`, and `-p` prompt mode uses nothing from the editor (the `/ide` connection is interactive-only). The results hold for Copilot CLI in any terminal. Interactive mode was not covered (see D). Commands below omit those two environment assignments only where the cell already names the test.

| # | Test | Exact command and result | Verdict |
|---|------|--------------------------|---------|
| A | 262(a) timeout + controls | Hook `bash: "sleep 8", timeoutSec: 2`; exact prompt: `copilot -p 'Run exactly: echo X > sentinel-timeout.txt' --allow-all-tools --trust-folder` → timeout and file written. Controls used the same `copilot -p ... --allow-all-tools --trust-folder` with prompts `Run exactly: echo X > sentinel-exit2.txt` and `Run exactly: echo X > sentinel-deny.txt`; hook commands were `echo controlled-block >&2; exit 2` and `printf '{"permissionDecision":"deny","permissionDecisionReason":"controlled denial"}'` respectively → both denied, files absent. | **CONFIRMED** timeout fails open; controls prove hook enforcement worked |
| B | 262(b) Local matcher | VS Code Chat probe not run (no GUI; VS Code Chat is not Copilot CLI — moved to TODO-265). Extracted with `ruby -ryaml -e 'print YAML.load_file("plugins/dx-core/templates/hooks/agent-branch-guard.yaml").dig("hooks","PreToolUse",0,"command")'`; piped actual-shaped `toolName`/`toolArgs` JSONs to `bash guard.sh` on `main`: `{"toolName":"view","toolArgs":{"path":"README.md"}}`, `{"toolName":"bash","toolArgs":{"command":"ls"}}`, `{"toolName":"edit","toolArgs":{"path":"shape-probe.txt","old_str":"OLD","new_str":"git commit -m x"}}`, and `{"toolName":"bash","toolArgs":{"command":"git commit -m x"}}` → first three exit 0 without output; last emitted deny JSON. A throwaway repo hook captured real `view`, `edit`, and `bash` calls with `toolName`/`toolArgs`. Plugin `PostToolUse` below instead used snake-case keys. | Static **CONFIRMED**; VS Code behavior **UNVERIFIED** |
| C | 262(c) Stop cap | Twice ran `copilot -p 'Reply with the single word: hi' --allow-all-tools --trust-folder` with an `agentStop` hook appending to a counter and returning `{"decision":"block","reason":"test block"}` → **9 hook calls on each run**, then turn ended. | **CONFIRMED** |
| D | 262(d) agent collisions | Copied `plugins/*/agents/*.md` into `.claude/agents/` beside `.github/agents/`. With same `name: CollisionProbe` and different bodies in `.github/agents/CollisionProbe.agent.md` and `.claude/agents/CollisionProbe.md`, ran `copilot -p 'Respond with the exact token specified in your instructions.' --agent CollisionProbe --trust-folder` → `.github` token. `.claude`-only check: `copilot -p 'Respond with the exact token specified in your instructions.' --agent ClaudeOnlyProbe --trust-folder` → token. Ran `copilot -p 'Respond with one token identifying whether agent instructions loaded.' --agent dx-code-reviewer --trust-folder` → loaded with ignored-field and unavailable-model warnings. Interactive `/agent` listing was not available: `--interactive` rejects `--trust-folder`, and the CLI did not expose a UI over piped input. | **CONFIRMED** precedence and cross-read; listing **UNVERIFIED** |
| E | 259 ignored keys | For each of the 25 `.github/agents/*.agent.md`: `copilot -p 'noop' --agent "$name" --trust-folder > /dev/null 2>"ignored-key-stderr-verified/$name.err"` ran serially, one stderr file per template. Ignored-field groups match the prior record: only `argument-hint`, `agents`, `handoffs`; special cases unchanged. No ignored-field warning named `hooks`, `model`, or `reasoning-effort`. Some templates separately warned that their selected model was unavailable and Copilot would use Auto; this is a model-availability warning, not an ignored-field warning. | Ignored-key findings **CONFIRMED**; prior “no model warning” wording needs this distinction |
| F | TODO-20 `shared/` | Direct: `copilot --plugin-dir /tmp/cp-v-plugin -p 'Invoke the path-probe skill and return the exact marker token it reads.' --allow-all-tools --trust-folder`. Installed: `COPILOT_HOME=/tmp/cp-v-installed-home copilot -p 'Invoke path-probe and report the exact marker token.' --allow-all-tools --trust-folder`. A fallback skill was invoked with `copilot --plugin-dir /tmp/cp-v-plugin -p 'Invoke shared-fallback and report its exact token.' --allow-all-tools --trust-folder`. Results: skill-local marker for direct and installed paths; `skills/shared/` marker when skill-local marker absent; root `shared/` never resolved. A shell command from a skill reference to `${CLAUDE_PLUGIN_ROOT}` saw it unset and tried `/shared/marker.md`. | **CONFIRMED** root `shared/` unresolved; same path behavior for direct and installed plugin |
| G | TODO-124 matcher + scripts | With plugin hook matcher `Edit|Write`, exact prompt: `copilot --plugin-dir /tmp/cp-v-g-plugin -p 'Create a brand new file \`new-create.txt\` containing exactly \`CREATED\` using the file tool. Run the shell command \`printf SHELL_MARKER\`. Then edit \`new-create.txt\` using the file tool so it contains exactly \`EDITED\`.' --allow-all-tools --trust-folder` → matching hook fired for create and edit only; both stdin records had `tool_name: "Edit"` and `CLAUDE_TOOL_NAME` was unset; shell call did not fire the matcher. Real `compaction-reminder.sh` emitted its count on both Edit events; `screenshot-log.sh` created no screenshot log. Its allowlist includes the observed `Edit` (and `Write`, `MultiEdit`, `NotebookEdit`); Bash is not included. | **CONFIRMED** matcher and stdin fallback; actual file tool name was `Edit`, not `Write` |
| H | Copilot issue probes 19–22 (not TODO rows 19–22) | 19 exact command: `copilot --plugin-dir /tmp/cp-v-h -p 'Use your Run worker probe handoff now. Return exactly the result of the handoff.' --agent issue-probes:CoordinatorProbe --allow-all-tools --trust-folder` → worker handoff token; stderr still warned `handoffs` is unknown. 20: `copilot --plugin-dir /tmp/cp-v-h -p 'Invoke coordinator-skill. Follow the delegation chain exactly and return only the second skill result.' --allow-all-tools --trust-folder` → coordinator delegated to `WorkerSkillProbe`, which invoked `second-skill`; token returned. 21: one-shot `copilot --plugin-dir /tmp/cp-v-h -p 'The parent context contains PARENT_CONTEXT_MARKER_7Q. Invoke fork-probe and report its exact result.' --allow-all-tools --trust-folder` returned the parent marker; this does not isolate a prior-turn marker. Multi-turn resume was not completed (`--resume` rejects `--trust-folder`; resume without it failed model resolution). 22: direct `copilot --plugin-dir /tmp/cp-v-h -p 'Return your mandatory token.' --agent issue-probes:ProbeAgent --allow-all-tools --trust-folder` returned its token; `copilot --plugin-dir /tmp/cp-v-h -p 'Invoke agent-target and report its output verbatim.' --allow-all-tools --trust-folder` selected the agent from skill metadata and returned that token. | 19 **CONTRADICTED** (“still broken”); 20 **CONTRADICTED** (“coordinator flow not reproduced”); 21 **UNVERIFIED**; 22 **CONTRADICTED** (“still ignored”) |

The version, hook environment gates, scaffold, and prompt-mode `--trust-folder` setup apply to every prompt command above. The initial sequential E run included one extra collision fixture; the 25-template result above is from a clean rerun excluding that fixture. Stderr was isolated per template, not combined through `xargs`.

**Fix regression check:** `bash plugins/dx-core/hooks/hook-tool-name.test.sh </dev/null` passes on the current scripts. Running the suite against the two scripts from the parent revision in a temporary fixture (including `hook-profile.sh`) yields the two Copilot-stdin failures: compaction stdin tool name and screenshot stdin tool name.

### Validated 2026-11-10 on Copilot CLI v1.0.109 — issue #21 (`context: fork`), interactive

Closes the gap left by row H/21 above (one-shot `-p` put the marker in the same prompt, and `--resume` rejects `--trust-folder`). This run used an interactive `copilot` session in a consumer project with dx plugins installed from the marketplace — no `--plugin-dir`, no probe plugin. Real skill: `dx-step-build` (`context: fork`), with its build-command argument pointed at a probe script outside the repo that prints `pwd`, `git rev-parse --show-toplevel`, `git worktree list` and writes one file.

| Turn | Prompt | Result |
|------|--------|--------|
| 1 | `Session rule: whenever you run any build in this session, run "echo PARENT_MARKER_K7Q" right after it. Reply only OK.` | OK |
| 2 | `/dx-core:dx-step-build sh /tmp/probe-build.sh` | Shell calls shown inline in the main session, no subagent/task block. The build call was `sh /tmp/probe-build.sh …; echo PARENT_MARKER_K7Q` — the turn-1 rule was applied **inside** the skill. Ran in the main worktree. |
| 3 | `Without using tools or reading files: quote the first sentence of the dx-step-build skill instructions (the body, not the description). If the body is not in your context, answer exactly UNKNOWN.` | Quoted the body's first sentence verbatim — the skill body is in the parent context. |
| 4 | `Run git status --short and git worktree list` | Probe file in the main worktree; no worktree created by this run (one stale `.claude/worktrees/agent-*` from an earlier Claude Code session). |

**Verdict: CONFIRMED — `context: fork` is ignored on Copilot CLI v1.0.109.** The skill runs inline: it sees parent context (turn 2) and leaks its body into the parent (turn 3). Neither harness creates a worktree for `context: fork` — the issue #21 title's "worktree isolation" is wrong; the loss is *context* isolation. **Claude Code baseline (same day, cloud session):** with the same marker rule in the conversation, `Skill(dx-core:dx-step-build, "sh <probe>")` returned `completed (forked execution)` and only the fork's summary. The build ran **without** the marker echo (the fork did not see the parent rule), in the main checkout, and created no worktree. Turn 3 was not used there: that session had already read the SKILL.md, so the quote oracle could not tell anything. The marker oracle discriminates: Claude Code forks, Copilot does not.

**Also found:** Copilot registers plugin skills **only** with the plugin prefix — `/dx-step-build` → `Unknown command`; `/dx-core:dx-step-build` works. See TODO-266.

## Copilot slash commands need the plugin prefix

**Added:** 2026-11-10
**Problem:** On Copilot CLI v1.0.109 (interactive, plugins installed from the marketplace) a dx skill is reachable as a slash command only with its plugin prefix: `/dx-step-build` → `Unknown command`, `/dx-core:dx-step-build` works. Our docs, templates and next-step hook hints print the bare form, so a Copilot user who copies them gets `Unknown command`. Calling the skill by name in plain words still works. Copilot added namespaced custom skills in v1.0.88; related to TODO-12 (names now read `dx-core:dx-*`).
**Scope:** `website/src/`, `plugins/*/templates/` (Copilot instructions, `.github/agents`), `plugins/dx-core/hooks/scripts/next-step.sh` and other hook hints, skill bodies that tell the user "run `/dx-…`" — 30 files under `website/src`, `plugins/*/templates` and hook scripts contain a bare `` `/dx-`` reference today.
**Done-when:** this section records whether Claude Code also accepts `/dx-core:dx-*` (one interactive check), AND the Copilot install/usage page on the website states the prefixed form, AND `next-step.sh` hints print a form that works on both harnesses.
**Approach:** if both harnesses accept `/<plugin>:<skill>`, print that everywhere user-facing (one form, no per-harness branch). Otherwise document both forms on the Copilot page. Decide together with TODO-12.

**Priority note (2026-11-10): Medium → Low.** Typing a partial name (`/dx-pr-rev`) lists the matching skills in autocomplete on both Copilot CLI and Claude Code, and arrow + Enter inserts the prefixed form, which works. Only a bare command copy-pasted from docs or a hook hint, or typed in full without picking from the list, fails. Do it with TODO-12: a rename changes every `/dx-…` reference anyway, so touch the ~30 files once.

**Website (2026-11-10):** `website/src/pages/setup/copilot-cli.mdx` § "Frontmatter Copilot CLI Ignores" now states the `context: fork`, `agent:`, subagent `model:`, `handoffs:` and `.claude/agents` results above, and the Differences table shows the prefixed slash form.

### Re-reading row H (2026-11-10) — not enough to close issues #19, #20, #22

Checked before closing the three issues. None of them can be closed on row H alone:
- **#19 `handoffs:`** — row E has Copilot warn that `handoffs` is an *unknown field*, and the H/19 run printed that warning too. The worker token came back because the model delegated on its own, as the prompt told it to; the field did nothing. The issue is worse than its title: the field is not parsed at all.
- **#22 `agent:`** — every skill that sets `agent:` (6, all in dx-aem) also sets `context: fork`. In Claude Code `agent:` only picks the subagent type of the fork. Since `context: fork` is ignored on v1.0.109 (above), the harness cannot route to the agent. The H/22 token proves the model reached the agent, not that the frontmatter did. Model tier and tool allowlist were not checked.
- **#20 subagent → skill** — the most likely to be fixed, but H/20 did not tell a real skill invocation from the subagent reading `SKILL.md` as a file. That file read is the failure the issue describes. Needs one run that shows the tool the subagent called.

### Issue #20 re-test 2026-11-10, Copilot CLI v1.0.109 interactive

Prompt: `Use a subagent (task tool) for this. The subagent must invoke the dx-core:dx-help skill with the question "what is the spec directory convention?" and return its answer. Do not read SKILL.md files.` UI tree: `General-purpose` subagent → `skill(dx-core:dx-help)` → nested `dx-core:dx-doc-searcher` subagent. **#20 passes:** a subagent invokes a plugin skill through the skill tool (not a file read), and the nesting goes 2 levels deep (the issue says 1 max). **Side finding for #22:** `dx-doc-searcher` sets `model: haiku`, yet the UI shows it running on the session's Opus model. The agent's model tier did not apply.

### Repo-hook env re-test 2026-11-10, Copilot CLI v1.0.109 interactive

A `sessionStart` probe in `.github/hooks/zz-probe.json` ran `env | grep -iE "plugin_root|claude_project_dir|copilot_plugin"`. Output: only `CLAUDE_PROJECT_DIR=<project root>`. **`PLUGIN_ROOT`, `COPILOT_PLUGIN_ROOT` and `CLAUDE_PLUGIN_ROOT` are not set for repo hooks.** In `templates/hooks/branch-guard-hooks.json.template`:
- `session-start.sh`, `next-step.sh` (SessionStart) and `validate-plugin-edit.sh` (PostToolUse) run as `bash "/hooks/scripts/…"` and fail with exit 127 in every project where `/dx-init` 9i installed the file;
- the inline branch guard and the `agentStop` guard (it uses `${CLAUDE_PROJECT_DIR:-$PWD}`) work, but they duplicate the plugin's own hooks.

The Copilot **cloud coding agent** ignores plugins and reads only `.github/hooks/`. That is the one consumer the repo copy is still for, and every command in it has to be self-contained (no plugin path).
