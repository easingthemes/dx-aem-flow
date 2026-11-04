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

**Added:** 2026-04-04 · **Re-planned:** 2026-11-04 ([research](../research/2026-11-04-opencode-support.md))
**Problem:** dx ships as Claude Code / Copilot CLI plugins. In those tools a plugin is a *distribution unit*: it bundles skills, agents, hooks and MCP into one install, and its files live in the plugin cache, not in the project. OpenCode has no such unit. An OpenCode "plugin" is a JS/TS *runtime extension*: hooks on tool calls, shell env, sessions, custom tools. It is the counterpart of a Claude Code mod or hook, not of a Claude Code plugin. The same word names different things.

Each part of dx therefore reaches OpenCode separately, as files and config:
- **Skills:** read from `.opencode/skills/`, `.claude/skills/`, `.agents/skills/` (project or home). On v2 there is also a `skills: [...]` config array that takes paths or an **HTTP catalog** (`<base>/index.json` listing `name`, `version`, `files`). None of these sees the Claude Code plugin cache.
- **Agents:** `.opencode/agents/*.md` or `~/.config/opencode/agents/`, with their own frontmatter.
- **MCP and instructions:** `opencode.json` (`mcp`, `instructions`). `.mcp.json` is not read.
- **Hooks:** only a JS runtime extension can do these.

Today none of this is set up. On top of that, three things fail quietly:
- 17 skill files call scripts through `$CLAUDE_PLUGIN_ROOT` / `${CLAUDE_SKILL_DIR}`. These are unset in OpenCode, so `dx-bug-all`, `dx-simple`, `dx-step`, `dx-figma-all` and `aem-init` break.
- No MCP servers (AEM, Playwright, axe, Figma).
- OpenCode loads `AGENTS.md` *instead of* `CLAUDE.md`. Our `/dx-init` and `dx-scaffold` always write `AGENTS.md`, so the consumer's `CLAUDE.md` is dropped.

**Scope:**
- `cli/lib/scaffold.js` and `cli/bin/dx-scaffold.js` (`--opencode`): the installer for OpenCode
- New `.opencode/INSTALL.md` (sibling of `.codex/INSTALL.md`)
- `scripts/validate-skills.sh`: OpenCode name/description rules
- Skills using `CLAUDE_PLUGIN_ROOT`/`CLAUDE_SKILL_DIR`: `plugins/dx-core/skills/{dx-bug-all,dx-simple,dx-step,dx-figma-all}`, `plugins/dx-aem/skills/aem-init`; find the rest with `grep -rlE 'CLAUDE_(PLUGIN_ROOT|SKILL_DIR)' plugins/*/skills`
- Optional: a skill catalog generator (`scripts/build-opencode-catalog.sh`) and a runtime extension `.opencode/plugins/dx-guard.js`
- Website cross-platform page
**Done-when:**
- `test -f .opencode/INSTALL.md`
- `validate-skills.sh` fails on a fixture skill whose `name` ≠ dir or whose description is >1024 chars
- `node cli/bin/dx-scaffold.js /tmp/oc --all --opencode` writes:
  - `/tmp/oc/opencode.json` with `mcp` and `instructions: ["CLAUDE.md"]`
  - `/tmp/oc/.opencode/agents/dx-code-reviewer.md`
  - the skills under a dir OpenCode scans (e.g. `/tmp/oc/.opencode/skills/dx-help/SKILL.md`)
- In that project, `opencode run "use the skill tool to load dx-help, then say which config file it reads"` mentions `.ai/config.yaml`. Record the version (v1 or v2) used.
**Approach:** phases, each shippable on its own:
1. **Manual install doc + compat check.**
   - `INSTALL.md`: clone the repo, then link or copy `plugins/<p>/skills/*` and translated agents into `~/.config/opencode/` (global) or `.opencode/` (project). On v2, `skills: ["~/.dx-aem-flow/plugins/dx-core/skills"]` replaces the skills symlinks.
   - Sample `opencode.json` with an `mcp` block translated from our `.mcp.json` files and `"instructions": ["CLAUDE.md"]`.
   - Degradation table: `model`/`effort`/`context: fork`/hooks are ignored.
   - Add the name regex `^[a-z0-9]+(-[a-z0-9]+)*$`, the name = dir rule and the ≤1024-char description rule to `validate-skills.sh`. All 79 skills pass today; the check only keeps it that way.
2. **Plugin-root portability.** Skills resolve their own script dir with a fallback when `CLAUDE_PLUGIN_ROOT` is unset. A runtime extension can't fix this with `shell.env`, because it is one variable and dx-core and dx-aem need different roots. Fix this together with TODO #86, because it also fixes Codex and Gemini. Run the `dx-bug-all` / `dx-simple` suites after the change.
3. **`dx-scaffold --opencode` as the installer.** The scaffold already reads `plugins/` at runtime, so it fits.
   - Copy the selected plugins' skills into `.opencode/skills/`, with their `scripts/`/`templates/` and exec bits.
   - Emit `.opencode/agents/*.md` from `plugins/{dx-core,dx-aem}/agents/`, setting `mode: subagent` and mapping `tools` to `permission`. Omit `model` (no alias equivalent; a pinned id goes stale).
   - Write `opencode.json` with `mcp`, `instructions` and `permission.skill: {"*": "allow"}`.
   - Re-running it is the upgrade path. Add a `/dx-init` note too.
4. **Optional runtime extension for hooks only.** `.opencode/plugins/dx-guard.js` with `tool.execute.before` blocks `git commit` on protected branches, mirroring the `PreToolUse` branch-guard. This is the only part that is a real OpenCode plugin. Target one OpenCode version.
5. **Parked: v2 HTTP skill catalog.** Generate `index.json` from `plugins/*/skills` and serve it from the docs site, so users add one URL to `skills`. Blocked on two unknowns: whether downloaded scripts keep exec bits, and where the cache lives (scripts need a stable path). Revisit after phase 2.

**Not doing:** registering skill dirs from a runtime extension the way superpowers does: a `config` hook into the undocumented v1 `skills.paths`, and `ctx.skill.transform()` on v2. It works, but it uses the extension API as a package manager. It relies on an undocumented key and has to track two plugin APIs.

Open questions are in the research note (MCP tool-name format, `{env:}` in `command`, symlink support, an `AskUserQuestion` equivalent).

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
