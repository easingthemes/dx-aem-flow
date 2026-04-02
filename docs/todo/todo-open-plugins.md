# Open Plugins Standard Alignment

Tracking alignment with the [Open Plugins spec](https://open-plugins.com/) (v1.0.0, by Vercel Labs).

## Vendor-Neutral Manifest

**Added:** 2026-03-26
**Problem:** Open Plugins defines a vendor-neutral `.plugin/plugin.json` alongside vendor-specific dirs (`.claude-plugin/`, `.cursor-plugin/`). Our plugins only have `.claude-plugin/plugin.json`, limiting cross-tool discoverability (Cursor, Codex).
**Scope:** All 4 plugins — `plugins/dx-core/`, `plugins/dx-aem/`, `plugins/dx-hub/`, `plugins/dx-automation/`. Each needs a `.plugin/plugin.json` added.
**Done-when:** Each plugin dir has both `.plugin/plugin.json` (vendor-neutral) and `.claude-plugin/plugin.json` (Claude-specific), and both contain consistent metadata.
**Approach:** Wait until the Open Plugins GitHub repo (`vercel-labs/open-plugin`) goes public and Claude Code officially supports `.plugin/`. Adding it prematurely could cause conflicts. Monitor the spec.

## Rules File Extension (.md → .mdc)

**Added:** 2026-03-26
**Problem:** Open Plugins spec uses `.mdc` extension for rules files (Cursor convention). Our plugins use `.md`. Cursor and other tools may not discover `.md` rules.
**Scope:** `plugins/*/rules/*.md` across all 4 plugins.
**Done-when:** Rules files use `.mdc` extension, or investigation confirms `.md` is equally supported across tools.
**Approach:** `.mdc` is Cursor's convention (MDX-like with frontmatter). Investigate whether Claude Code accepts `.mdc` before renaming. May need dual files or a single extension that all tools accept.

## Commands Directory Separation

**Added:** 2026-03-26
**Problem:** Open Plugins defines a separate `commands/` directory for slash commands, distinct from `skills/`. Our plugins use skills for both. This may affect discoverability in non-Claude tools.
**Scope:** All plugin `skills/` directories. Some skills are user-invoked commands (e.g., `dx-init`, `dx-help`), others are agent-only.
**Done-when:** Decision made on whether to adopt `commands/` separation or keep current unified `skills/` approach. Document rationale.
**Approach:** Low priority. Claude Code treats skills as commands already. Only worth splitting if another tool requires the `commands/` convention. Monitor adoption.

## PLUGIN_ROOT Variable Naming

**Added:** 2026-03-26
**Problem:** Open Plugins uses `${PLUGIN_ROOT}` for path expansion. Our plugins use `${CLAUDE_PLUGIN_ROOT}` (Claude Code convention). Cross-tool plugins would need the generic name.
**Scope:** Any skill, hook, or config file referencing `${CLAUDE_PLUGIN_ROOT}`.
**Done-when:** Grep for `CLAUDE_PLUGIN_ROOT` returns zero results AND `PLUGIN_ROOT` is used everywhere, OR investigation confirms both are supported.
**Approach:** Wait for Claude Code to support `${PLUGIN_ROOT}` as an alias. Changing now would break Claude Code.

## Output Styles Support

**Added:** 2026-03-26
**Problem:** Open Plugins defines an `outputStyles/` directory for custom output formatting. Our plugins don't use this. Could be useful for consistent formatting across tools.
**Scope:** New directory in each plugin, referenced in plugin.json.
**Done-when:** Decision made on whether output styles add value for our use case. If yes, at least one style implemented.
**Approach:** Low priority. Research what output styles look like in practice once the spec repo goes public.

## Plugin Logo / Icon

**Added:** 2026-03-26
**Problem:** Plugins show a generic puzzle-piece icon in VS Code Chat Customizations. No `logo` field in `plugin.json` is recognized yet.
**Scope:** All 4 plugins — `plugins/dx-core/`, `plugins/dx-aem/`, `plugins/dx-hub/`, `plugins/dx-automation/`. Each has `assets/logo.png` (256x256, rendered from `website/public/kai-logo.svg`) and `"logo": "./assets/logo.png"` in `plugin.json`.
**Done-when:** VS Code renders the KAI logo in the Chat Customizations panel instead of the generic puzzle-piece icon.
**Approach:** Tracked in [microsoft/vscode#304758](https://github.com/microsoft/vscode/issues/304758) — assigned to Connor Peet, milestone "On Deck". Field name will be `logo` (per Open Plugins spec). Our plugins are already prepared — the field is silently ignored until VS Code ships support. When it lands, verify the logo renders correctly and adjust dimensions if needed.

## Monitor Spec Finalization

**Added:** 2026-03-26
**Problem:** The Open Plugins GitHub repo (`vercel-labs/open-plugin`) returns 404. The spec is only on the website. Until the repo is public, the spec may change significantly.
**Scope:** All alignment items above depend on spec stability.
**Done-when:** `github.com/vercel-labs/open-plugin` is public and has a tagged release.
**Approach:** Periodic check (monthly). Once public, review the full spec and re-evaluate all items above. The Agent Skills layer (SKILL.md) is already stable and adopted — the packaging layer is the uncertain part.
