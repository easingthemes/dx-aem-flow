# Cross-Platform Agent Support

Tracking expansion from 3 platforms (Claude Code, Copilot CLI, VS Code Chat) to 6+ platforms. Based on [agent standards research](../research/agent-standards-landscape-2026.md) and [2026-04-25 platform state update](../research/2026-04-25-platform-state-update.md).

## Codex CLI first-class plugin support

**Added:** 2026-04-25
**Problem:** Codex v0.122–0.125 (April 2026) added a first-class plugin system, native subagents, hooks (stabilized 0.124), and slash commands. Our current Codex support is a `.codex/INSTALL.md` symlink hack — significantly under-leveraging what Codex now offers.
**Scope:** Per plugin (`dx-core`, `dx-hub`, `dx-aem`, `dx-automation`):
- `.codex-plugin/plugin.json` manifest (parallel to `.claude-plugin/plugin.json` and `.cursor-plugin/plugin.json`)
- Mirror MCP config to `~/.codex/config.toml` `[mcp_servers.*]`
- Mirror hooks to Codex `requirements.toml` (event names differ from Claude)
- Update `cli/lib/scaffold.js` to emit `.agents/skills/`
- Update `CLAUDE.md` "Plugin Manifest — Dual-Platform" → multi-platform
**Done-when:** `ls plugins/dx-core/.codex-plugin/plugin.json` exists; Codex CLI loads dx-core skills natively without symlinks.
**Approach:** Skill content (SKILL.md) is largely portable — Codex follows agentskills.io spec but only honors `name` and `description` of frontmatter (others silently degrade). Document degradation in `docs/reference/skill-catalog.md`.
**Evidence:** [Codex changelog](https://developers.openai.com/codex/changelog), [Codex skills docs](https://developers.openai.com/codex/skills)

## Gemini CLI extension proper buildout

**Added:** 2026-04-25
**Problem:** Currently only a 52-byte `GEMINI.md` stub and a tiny `gemini-extension.json`. Gemini CLI v0.36+ supports full extensions with skills, agents, hooks (11 events!), MCP, settings — we're not using any of it.
**Scope:** Per plugin:
- Generate `gemini-extension.json` with `mcpServers`, `contextFileName`, `excludeTools`, `settings[]`
- Use `.agents/skills/` alias to share skills with Codex (cross-tool)
- Map hooks: `PreToolUse` → `BeforeTool`, `PostToolUse` → `AfterTool`, `Stop` → `AfterAgent`, `PreCompact` → `PreCompress`, `UserPromptSubmit` → `BeforeAgent`
- Map model tiers: opus → `gemini-3-pro-preview`, sonnet/haiku → `gemini-3-flash-preview`
- Update `cli/lib/scaffold.js` to emit `.gemini/` tree
- Add Gemini row to CLAUDE.md "Plugin MCP Tool Naming" table — Gemini uses `mcp_<server>_<tool>` (single underscore, lowercase)
**Done-when:** `wc -c GEMINI.md` > 1KB; `gemini-extension.json` declares mcpServers; `.gemini/skills/` discovered by Gemini CLI.
**Approach:** Tool naming differs (snake_case `read_file` vs PascalCase `Read`) — Gemini hooks already provide `CLAUDE_PROJECT_DIR` as alias for `GEMINI_PROJECT_DIR`, so hook scripts that read either work on both.
**Evidence:** [Gemini extensions reference](https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions/reference.md), [Gemini skills](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/skills.md)


## Cursor hooks-cursor.json for dx-core and dx-aem

**Added:** 2026-04-04
**Problem:** Cursor requires a separate `hooks-cursor.json` with its own schema (camelCase events, `version: 1`, simpler format). The `.cursor-plugin/plugin.json` manifests reference `./hooks/hooks-cursor.json` but the files don't exist yet. Cursor plugin install will work (skills/agents discovered) but hooks won't fire.
**Scope:** `plugins/dx-core/hooks/hooks-cursor.json`, `plugins/dx-aem/hooks/hooks-cursor.json`
**Done-when:** `ls plugins/dx-core/hooks/hooks-cursor.json plugins/dx-aem/hooks/hooks-cursor.json` returns both files, and each contains `sessionStart` (camelCase) hooks matching the Claude Code equivalents.
**Approach:** Follow superpowers pattern. Cursor hooks use `version: 1`, camelCase event names (`sessionStart` not `SessionStart`), simpler command format. Detect platform via `$CURSOR_PLUGIN_ROOT` env var. The session-start hook script needs a platform detection block (see superpowers `hooks/session-start` for reference).

## Tool name reference docs for non-Claude platforms

**Added:** 2026-04-04
**Problem:** Skills reference MCP tools with Claude Code's prefixed naming (`mcp__plugin_dx-core_figma__get_screenshot`). Other platforms use different tool resolution. Codex, Cursor, and Gemini CLI users need a translation reference.
**Scope:** New file: `docs/reference/tool-name-mapping.md` or per-plugin `shared/tool-names-<platform>.md`
**Done-when:** A reference doc exists mapping all MCP tool names used in skills to their platform equivalents (at minimum Codex and Cursor).
**Approach:** Follow superpowers pattern — they use `skills/using-superpowers/references/gemini-tools.md` to map Claude tool names to Gemini equivalents. Create a similar reference. Low priority since LLMs on all platforms can resolve prefixed names via context, but useful for documentation.

## Cursor plugin marketplace registration

**Added:** 2026-04-04
**Problem:** Cursor has a growing plugin ecosystem but dx-aem-flow isn't registered. The `.cursor-plugin/plugin.json` manifests are in place but not discoverable via Cursor's plugin marketplace.
**Scope:** Cursor marketplace registration process (external).
**Done-when:** `dx-core` appears in Cursor's plugin browser.
**Approach:** Investigate Cursor's plugin submission process. May require a `.cursor-plugin/` at repo root level (marketplace equivalent). Low priority — manual clone + symlink works today.

## OpenCode plugin support

**Added:** 2026-04-04 · **Re-planned:** 2026-11-04 ([research](../research/2026-11-04-opencode-support.md): existing solutions, wiring map, target layout)
**Problem:** dx-core and dx-aem have no OpenCode install path.
- In Claude Code / Copilot CLI a plugin is a *distribution unit* that bundles skills, agents, hooks and MCP. OpenCode has no such unit. Its "plugins" are JS runtime extensions. So skills, agents, MCP and instructions must reach OpenCode as separate native files and `opencode.json` entries.
- Projects that already ship Claude Code plugins to OpenCode (compound-engineering's converter, wshobson/agents) do this with a **generator** that writes native files.
- Even with the files in place, our skills depend on Claude-only wiring (research §4–6):
  - 61 `CLAUDE_PLUGIN_ROOT` / `CLAUDE_SKILL_DIR` refs and 87 bare `shared/…` refs have no anchor.
  - 4 skill scripts need the `skills/` ↔ `shared/` relative layout.
  - 16 `context: fork` and 6 `agent:` delegations are ignored.
  - `subagent_type: dx-core:dx-figma-*` is plugin-namespaced.
  - 22 files tell the model to use `ToolSearch`.
  - MCP tools are named `<server>_<tool>` instead of `mcp__plugin_…__`.
  - OpenCode drops `CLAUDE.md` when our generated `AGENTS.md` exists.


**Scope:** dx-core + dx-aem only (dx-hub, dx-automation later).
- `cli/lib/scaffold.js`, `cli/bin/dx-scaffold.js` (`--opencode`)
- `.opencode/INSTALL.md`
- `scripts/validate-skills.sh`
- Skills with plugin-root / `shared/` refs: `grep -rlE 'CLAUDE_(PLUGIN_ROOT|SKILL_DIR)|[ \`(]shared/' plugins/dx-{core,aem}/skills`
- `plugins/dx-core/skills/dx-figma-prototype` (namespaced `subagent_type`)
- Website cross-platform page


**Done-when:**
- **Phase 1:**
  - `test -f .opencode/INSTALL.md && test -f .opencode/plugins/dx-env.js` (repo copy, installed to `~/.config/opencode/plugins/`)
  - `grep -rn 'CLAUDE_SKILL_DIR' plugins/dx-core/skills plugins/dx-aem/skills` is empty
  - `grep -rn 'CLAUDE_PLUGIN_ROOT' plugins/dx-aem/skills` is empty
  - `validate-skills.sh` fails on a fixture whose `name` ≠ dir or whose description is >1024 chars
  - With the manual install:
    - `opencode run "load the dx-help skill and say which config file it reads"` mentions `.ai/config.yaml`
    - `aem-inspector` can call an `AEM_*` tool
    - `dx-bug-all/scripts/preflight.sh` passes
    - Record the OpenCode version.
- **Phase 2:** the research §10.6 test plan passes; `dx-agent-all` finishes on a fixture story with forked phases running as subagents.
- **Phase 3:** `node cli/bin/dx-scaffold.js /tmp/oc --all --opencode` writes:
  - `opencode.json` with `mcp.AEM`, `mcp.playwright` and `instructions: ["CLAUDE.md"]`
  - 13 agents + the wrapper agents in `.opencode/agents/`, all `mode: subagent` without `model:`
  - all 61 dx-core/dx-aem skills reachable
  - `plugins/dx-env.js`

**Approach:** the existing solutions with real code behind them (compound-engineering's converter and wshobson/agents generate native OpenCode files; oh-my-openagent loads Claude plugins in place; see research §2.1 for the value filter). We first make the main flow work by hand, then cover the details, then automate. Every limitation is documented in the [research note](../research/2026-11-04-opencode-support.md) even when it is deferred.

**Phase 1 — main flow works (manual install).** Goal: single skills (`dx-req`, `dx-plan`, `dx-step`, `aem-verify`, …) run on OpenCode with MCP and agents.
- `.opencode/INSTALL.md` from research §5:
  - an intact plugin tree in `~/.config/opencode/dx/{dx-core,dx-aem}`
  - per-skill symlinks (v1) or a `skills` array (v2)
  - 13 hand-translated agents (`mode: subagent`, no `model`, `permission`)
  - global `opencode.json` with `mcp`, and a project `opencode.json` with `ado` / `atlassian` + `instructions: ["CLAUDE.md"]`
  - a degradation table
- **Plugin root (research §9):**
  - Add `~/.config/opencode/plugins/dx-env.js`. It sets `CLAUDE_PLUGIN_ROOT` to the dx-core tree on every shell call: v1 `shell.env`, v2 `shell.hook("create.before")`. The path is derived from the file's own location, so nothing is hardcoded.
  - Document the launcher alias as the no-code fallback.
  - Don't export the variable globally; it would leak into Claude Code.
- **Text fixes, Claude-Code-safe:**
  - Rewrite the 7 `${CLAUDE_SKILL_DIR}` refs (dx-init, dx-sync, dx-doctor, dx-eject) to `$CLAUDE_PLUGIN_ROOT/skills/<skill>/…`, the form 37 refs already use.
  - Make the one dx-aem ref in aem-init find the AEM plugin by glob, like dx-init does.
  - Optional: brace the 47 unbraced `$CLAUDE_PLUGIN_ROOT` refs, so in-place loaders (oh-my-openagent, harnesstap) substitute them too (research §9.3).
  - Run the dx-init / dx-sync / dx-doctor / dx-eject suites after.
- **Checks:**
  - `validate-skills.sh` gets the OpenCode name/description rules.
  - `/dx-doctor` gets a check that `$CLAUDE_PLUGIN_ROOT/skills/dx-init/SKILL.md` exists when running under OpenCode.
- **Smoke test** the open questions (research §8), mainly whether the model maps `mcp__plugin_dx-aem_AEM__x` → `AEM_x`.
- **Known Phase 1 limits** (documented, not fixed): forked skills run inline, so coordinators like `dx-agent-all` degrade (research §10.3). Also: no model tiers, no hooks, `ToolSearch` instructions are dead, and bare `shared/` refs rely on one `AGENTS.md` hint (research §9.5).

**Phase 2 — details (important).**
- **Context isolation for the 16 `context: fork` skills and 6 `agent:` skills** (research §10). Generate:
  - a wrapper agent per forked skill (`mode: subagent`, `hidden`, body loads the skill)
  - command stubs with `subtask: true`
  - a platform note in the 6 coordinators: dx-agent-all, dx-bug-all, dx-step-all, dx-figma-all, dx-bug-fix, dx-pr

  Run the §10.6 test plan: isolation, `subagent_depth` for 3–4 levels, `agent:` permission scoping, a full `dx-agent-all` run, parallel subagents. No existing solution handles this; this is new ground.
- Decide on rewriting MCP names and bare `shared/` refs, based on the Phase 1 smoke test.
- `ToolSearch` instructions: make them conditional or drop them on OpenCode.
- Hooks: port branch-guard to `dx-guard.js`.
- Model tiers: document the trade-off of pinned `provider/model-id`.
- Shared with TODO #86 (same plugin-root hole on Copilot/Codex).

**Phase 3 — automate.** `dx-scaffold --opencode` writes the Phase 1 + 2 layout (copies the tree, translates agents, writes `opencode.json`, wrappers, stubs, `dx-env.js`). Re-running it is the upgrade path.

**Not doing (for now):** a skill-registering runtime extension like superpowers or compound-engineering's plugin path; it covers skills only. Also not depending on third-party loaders (harnesstap, oh-my-opencode); smoke-test them only.

## SessionStart hook platform detection (shared script)

**Added:** 2026-04-04
**Problem:** Currently our hooks are platform-specific by installation location (plugin hooks.json for Claude Code, .github/hooks/ for Copilot CLI). superpowers uses a single shared script with runtime platform detection via env vars (`CLAUDE_PLUGIN_ROOT`, `CURSOR_PLUGIN_ROOT`, `COPILOT_CLI`). This is more maintainable for 4+ platforms.
**Scope:** `plugins/dx-core/hooks/scripts/session-start.sh`, `plugins/dx-aem/hooks/scripts/session-start.sh`
**Done-when:** Hook scripts detect the current platform via env vars and return the correct JSON response format for each platform.
**Approach:** Add platform detection block to existing session-start scripts. Three response formats: Claude Code (nested `hookSpecificOutput.additionalContext`), Cursor (`additional_context` snake_case), Copilot CLI (`additionalContext` top-level). Reference: superpowers `hooks/session-start`.

## AGENTS.md maintenance — keep in sync with CLAUDE.md

**Added:** 2026-04-04
**Problem:** `AGENTS.md` is a cross-platform subset of `CLAUDE.md`. When CLAUDE.md changes (new skills, architecture updates), AGENTS.md may fall out of sync.
**Scope:** Root `AGENTS.md` and `CLAUDE.md`.
**Done-when:** N/A — ongoing maintenance task. Check periodically that key sections (plugin table, conventions, skill format) match.
**Approach:** When updating CLAUDE.md architecture sections, check if AGENTS.md needs corresponding updates. AGENTS.md should remain a concise subset, not a full copy.
