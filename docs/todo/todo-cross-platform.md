# Cross-Platform Agent Support

Tracking expansion from 3 platforms (Claude Code, Copilot CLI, VS Code Chat) to 6+ platforms. Based on [agent standards research](../research/agent-standards-landscape-2026.md).

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

**Added:** 2026-04-04
**Problem:** OpenCode is a growing open-source AI coding tool that supports JS-based plugins. superpowers supports it via `.opencode/plugins/superpowers.js`. We don't have OpenCode support.
**Scope:** New directory: `.opencode/` with plugin entry point.
**Done-when:** `.opencode/plugins/dx-core.js` exists and bootstraps skill discovery for OpenCode.
**Approach:** Low priority. Follow superpowers pattern — JS entry point with `experimental.chat.system.transform` hook to inject context and `config` hook to register skills directory.

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
