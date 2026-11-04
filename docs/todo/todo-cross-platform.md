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
**Problem:** We have no OpenCode install path. Our skills ship inside Claude Code / Copilot CLI plugins and live in the plugin cache (`~/.claude/plugins/cache/…`), not in a project's `.claude/skills/`. OpenCode does not read Claude Code plugins or marketplaces. Its plugins are JS modules (`.opencode/plugins/`, or npm/git entries in `opencode.json`), so `/plugin install dx-core@dx-aem-flow` gives OpenCode nothing. Native discovery covers only `.claude/skills/`, `.agents/skills/` and `.opencode/skills/`, so today the only route is the Codex-style manual symlink. Even with skills reachable, OpenCode fails quietly in three places:
- 17 skill files call scripts through `$CLAUDE_PLUGIN_ROOT` / `${CLAUDE_SKILL_DIR}`. These are unset in OpenCode, so `dx-bug-all`, `dx-simple`, `dx-step`, `dx-figma-all` and `aem-init` break.
- OpenCode does not read `.mcp.json`, so AEM/Playwright/axe/Figma are missing.
- OpenCode loads `AGENTS.md` *instead of* `CLAUDE.md`. Our `/dx-init` and `dx-scaffold` always write `AGENTS.md`, so the consumer's `CLAUDE.md` is dropped.

The way to "install" in OpenCode is a JS plugin that registers our skill dirs. That is what superpowers does today: it uses one `config` hook pushing into `skills.paths` on v1 and `ctx.skill.transform()` on v2.
**Scope:**
- New repo-root `package.json` + `index.js`, and `.opencode/plugins/dx-aem-flow.js` (v1 + v2 entry, registers `plugins/*/skills`)
- New `.opencode/INSTALL.md` (sibling of `.codex/INSTALL.md`)
- `scripts/validate-skills.sh`: OpenCode name/description rules
- Skills using `CLAUDE_PLUGIN_ROOT`/`CLAUDE_SKILL_DIR`: `plugins/dx-core/skills/{dx-bug-all,dx-simple,dx-step,dx-figma-all}`, `plugins/dx-aem/skills/aem-init`; find the rest with `grep -rlE 'CLAUDE_(PLUGIN_ROOT|SKILL_DIR)' plugins/*/skills`
- `cli/lib/scaffold.js` and `cli/bin/dx-scaffold.js` (`--opencode`)
- Optional `.opencode/plugins/dx-guard/`
- Website cross-platform page
**Done-when:**
- With `"plugin": ["dx-aem-flow@git+https://github.com/easingthemes/dx-aem-flow.git"]` (v1) or `"plugins": [...]` (v2) in a test project's `opencode.json`, and no symlinks, the `skill` tool lists `dx-help` on both versions
- `test -f .opencode/INSTALL.md`
- `validate-skills.sh` fails on a fixture skill whose `name` ≠ dir or whose description is >1024 chars
- `node cli/bin/dx-scaffold.js /tmp/oc --all --opencode` writes `/tmp/oc/opencode.json` with `mcp` and `instructions: ["CLAUDE.md"]`, plus `/tmp/oc/.opencode/agents/dx-code-reviewer.md`
- In that project, `opencode run "use the skill tool to load dx-help, then say which config file it reads"` mentions `.ai/config.yaml`. Record the version (v1 or v2) used.
**Approach:** phases, each shippable on its own:
1. **Install plugin + docs + compat check.**
   - Add a zero-dependency JS plugin, dual v1/v2, modelled on superpowers `.opencode/plugins/superpowers.js`. On v1 its `config` hook appends our skill dirs to `config.skills.paths`; this is undocumented but works on 1.18.x. On v2, `setup(ctx)` registers them with `ctx.skill.transform()`.
   - Choose which plugins load through plugin options (v2 `{package, options}`), default `dx-core` (+ `dx-aem`). A root `package.json` `main` covers the git/npm install, and a root `index.js` covers v2's directory-form install.
   - Optionally inject a short tool-mapping note (Skill → `skill`, Agent/Task → `task`/`subagent`, Bash → `bash`/`shell`) as superpowers does.
   - `INSTALL.md` covers the `opencode.json` plugin entry (v1 `plugin`, v2 `plugins`) and keeps the manual `.agents/skills/` symlink as a fallback. It includes a sample `opencode.json` with an `mcp` block translated from our `.mcp.json` files and `"instructions": ["CLAUDE.md"]`.
   - Interim with no code from us: the third-party `opencode-agent-skills` plugin scans `~/.claude/plugins/cache/` and serves skills already installed via Claude Code. It is unvetted; mention it, don't depend on it.
   - Add a degradation table: `model`/`effort`/`context: fork`/hooks are ignored.
   - Add the name regex `^[a-z0-9]+(-[a-z0-9]+)*$`, the name = dir rule and the ≤1024-char description rule to `validate-skills.sh`. All 79 skills pass today; the check only keeps it that way.
2. **Plugin-root portability.** Skills resolve their own script dir with a fallback when `CLAUDE_PLUGIN_ROOT` is unset. Fix this together with TODO #86, because it also fixes Codex and Gemini. Run the `dx-bug-all` / `dx-simple` suites after the change.
3. **`dx-scaffold --opencode`.**
   - Emit `opencode.json` with `mcp`, `instructions` and `permission.skill: {"*": "allow"}`.
   - Emit `.opencode/agents/*.md` from `plugins/{dx-core,dx-aem}/agents/`, setting `mode: subagent` and mapping `tools` to `permission`. Omit `model` (no alias equivalent; a pinned id goes stale).
   - Add a `/dx-init` note too.
4. **Guard hooks in the same plugin.** `tool.execute.before` blocks `git commit` on protected branches, mirroring the `PreToolUse` branch-guard.
5. **Parked:** publish to npm (git spec is enough for now; Bun caches git deps, so document a cache clear for updates).

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
