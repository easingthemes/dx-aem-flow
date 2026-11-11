# Codex parity — what we have, what Codex offers, how to get Claude Code-level support

**Date:** 2026-11-11
**Codex CLI checked:** 0.167.1 (2026-11-10)
**Related:** TODO #88 (Codex first-class plugin), #181 (symlink layout), #212 (spec conformance), the Copilot CLI parity work in PRs #249–#264.

> Docs moved: every `developers.openai.com/codex/*` URL now 308-redirects to `learn.chatgpt.com/docs/*`. Facts marked **(unverified)** come from third-party posts or could not be confirmed on an official page.

## 1. What we have today

| Area | State |
|------|-------|
| Install | `.codex/INSTALL.md` — clone repo, `ln -sf` every skill dir into `.agents/skills/` |
| Instructions | Scaffold (`cli/lib/scaffold.js`) and `/dx-init` generate `AGENTS.md` — Codex reads it |
| Skills | 76 SKILL.md, portable; Codex documents only `name` + `description` |
| Agents | 13 plugin agents (Markdown + YAML) — **no Codex form** |
| Hooks | `plugins/dx-core/hooks/hooks.json` — **never tested on Codex** |
| MCP | Plugin `.mcp.json` files — **no Codex config emitted** |
| Manifest | `.claude-plugin/`, `.cursor-plugin/`, `gemini-extension.json` — **no `.codex-plugin/`** |
| Marketplace | `.claude-plugin/marketplace.json` lists `codex` in `platforms` — only metadata |
| Docs | `CLAUDE.md` MCP-naming table has a Codex row; `skill-frontmatter-compatibility.md` has a Codex column |

So Codex today = skills via symlink + AGENTS.md. Everything else (agents, hooks, MCP, plugin install) is missing.

## 2. Codex state (Nov 2026), relevant parts

### Instruction files
- `AGENTS.override.md` → `AGENTS.md` → `project_doc_fallback_filenames`, **one file per directory**, root-to-cwd, joined in order.
- Combined cap `project_doc_max_bytes` = **32 KiB** default. Built once per session.
- No native `CLAUDE.md`. `project_doc_fallback_filenames = ["CLAUDE.md"]` makes Codex read it **only in dirs without AGENTS.md**.
- Source: <https://learn.chatgpt.com/docs/agent-configuration/agents-md>

### Skills
- `.agents/skills` (cwd and parents up to repo root), `~/.agents/skills`, `/etc/codex/skills`, bundled. Symlinked folders **are followed**.
- Frontmatter: `name`, `description` only. Extra metadata goes in `agents/openai.yaml` (`interface`, `policy.allow_implicit_invocation`, `dependencies.tools`).
- Invoke with `$skill-name` or `/skills`; implicit match on description. Plugin skills are namespaced under the plugin **(unverified)**.
- Catalog budget: 2% of context (8,000 chars fallback), `skills.max_context_tokens`.
- Source: <https://learn.chatgpt.com/docs/build-skills>

### Plugins
- New portable root `plugin.json` with OpenAI bits under `extensions["com.openai"]`; **`.codex-plugin/plugin.json` is the compatibility manifest**.
- Bundles: `skills/`, MCP (`mcp.json`, `type: streamable-http` etc.), apps (`.app.json`), `hooks/hooks.json`, assets. **No agents.**
- Hooks in plugins: docs say only for manually installed (desktop) plugins, and hook plugins can't go in the public directory.
- Marketplaces: `.agents/plugins/marketplace.json`, `~/.agents/plugins/marketplace.json`, and **legacy Claude-compatible `.claude-plugin/marketplace.json`**.
- CLI: `codex plugin marketplace add owner/repo [--ref] [--sparse PATH]`; enable via `[plugins."name@marketplace"] enabled = true`.
- Sources: <https://developers.openai.com/plugins/build/plugins>, <https://developers.openai.com/codex/plugins/build/>

### Subagents
- One **TOML** per agent in `~/.codex/agents/` or `.codex/agents/`: `name`, `description`, `developer_instructions` (required); `model`, `model_reasoning_effort`, … optional.
- Inherited, not overridable: `sandbox_mode`, `approval_policy`, `mcp_servers`, skills. No per-agent tool allowlist like `tools:`.
- Invoked by name in natural language. Built-ins: `default`, `worker`, `explorer`.
- Source: <https://learn.chatgpt.com/docs/agent-configuration/subagents>

### Hooks
- On by default. Sources: `~/.codex/hooks.json`, `~/.codex/config.toml [hooks]`, `<repo>/.codex/hooks.json`, `<repo>/.codex/config.toml` — additive. Project hooks only in **trusted** projects, plus a `/hooks` trust review.
- Events: `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PreCompact`, `PostCompact`, `UserPromptSubmit`, `Stop`, `SubagentStart`, `SubagentStop`, `SessionStart`, `SessionEnd`, `PreModelRequest`, `PostModelRequest`, `Interrupt`.
- Matcher = regex on tool name. Exit `2` blocks (stderr = reason). JSON `hookSpecificOutput.permissionDecision`, `updatedInput`, `additionalContext`.
- Handler types run: `command`, `mcp_tool` (`prompt`/`agent` parsed but skipped).
- **Plugin hooks get `PLUGIN_ROOT`, `PLUGIN_DATA` and `CLAUDE_PLUGIN_ROOT`, `CLAUDE_PLUGIN_DATA` for compat.**
- Source: <https://learn.chatgpt.com/docs/hooks>

### MCP
- `[mcp_servers.<name>]` in `~/.codex/config.toml` or project `.codex/config.toml` (trusted only). stdio: `command/args/env/env_vars/cwd`; HTTP: `url`, `bearer_token_env_var`, `http_headers`, `auth`.
- `enabled_tools`, `disabled_tools`, per-tool `approval_mode`. `codex mcp add|list|login`.
- Source: <https://learn.chatgpt.com/docs/extend/mcp?surface=cli>

### Other
- `~/.codex/prompts` custom prompts: **deprecated**, use skills.
- `model_reasoning_effort`: `low|medium|high|xhigh|…` (model-dependent). Profiles are now separate files `$CODEX_HOME/<name>.config.toml` **(v0.134 per third party)**.
- `codex exec` for CI: `--json`, `--output-schema`, `-o`, `--sandbox`, `--ephemeral`; `--full-auto` removed. Auth via `CODEX_API_KEY`. GitHub Action `openai/codex-action`.
- Trust: `projects.<path>.trust_level = "trusted"` — untrusted projects skip **all** `.codex/` layers (config, hooks, MCP). This is Codex's equivalent of Copilot's `GITHUB_COPILOT_PROMPT_MODE_*` gates.

## 3. Official migration path from Claude Code

Codex ships an importer: **`/import`** in the CLI (or Desktop → Settings → Import). Source: <https://learn.chatgpt.com/docs/import>

| Claude Code | → Codex |
|---|---|
| CLAUDE.md | AGENTS.md |
| settings.json | config.toml |
| skills / slash commands | skills |
| plugins + marketplaces | plugins |
| MCP config | MCP config |
| hooks | hooks |
| subagents | TOML subagents |
| memories, last 30 days chats | memories, chats |

Non-destructive. Manual review afterwards: tool restrictions in skills/agents, MCP auth/headers/env, hooks, plugins/marketplaces, prompts with shell interpolation.

Also: OpenAI `migrate-to-codex` skill **(seen on mirrors only)**; guides: <https://blakecrosley.com/blog/claude-code-to-codex-migration>, <https://dev.to/owen_fox/migrate-claude-code-to-codex-2026-12-configs-1-dead-end-2pgl> (says `ConfigChange` hooks and output styles have no Codex equivalent).

**Caveat for us:** the importer converts a *consumer's* Claude setup. It would turn installed dx plugins into Codex plugins as a one-off snapshot — no upgrades, and the per-file gaps below still apply. Good for a pilot, not as our support story.

## 4. Tips for repos that use both Claude Code and Codex

1. **One instruction file.** Either AGENTS.md canonical + `CLAUDE.md` containing `@AGENTS.md`, or keep CLAUDE.md and set `project_doc_fallback_filenames = ["CLAUDE.md"]`. Watch the 32 KiB cap.
2. **One skills dir.** `.agents/skills/` as source, `.claude/skills` → symlink. Codex follows symlinks.
3. **Trust the project** (`trust_level = "trusted"`) or project config/hooks/MCP are silently skipped — the most common "it does nothing" cause.
4. **Use `$skill`**, not `/skill`, to force-load a skill.
5. **Hooks with exit 2** and the same event names port mostly as-is; `${CLAUDE_PLUGIN_ROOT}` works in plugin hooks.
6. Codex cannot run Claude models without a gateway `model_provider` — `model: opus` lines are meaningless there.

## 5. Copilot CLI parity work → Codex equivalent

The last ~15 PRs adapted dx for Copilot CLI. Each fix maps to a Codex question:

| Copilot fix (PR) | Problem it solved | Codex situation | Action |
|---|---|---|---|
| Isolation check in 18 `context: fork` skills (#261) | Copilot ignores `context: fork`, runs inline | Codex ignores it too. The check is generic ("start one subagent with your task/subagent tool") — Codex can spawn subagents by request, and they inherit skills | **Test** it on Codex; fix the "Copilot CLI ignores" wording to name both |
| Braced `${CLAUDE_PLUGIN_ROOT}` in skill bash + shell export (#258, #259) | Copilot substitutes nothing in skill text | Codex sets `CLAUDE_PLUGIN_ROOT` **only for hooks**; skill text likely not substituted **(unverified)** | `/dx-init` 9i: export `CLAUDE_PLUGIN_ROOT` to the Codex plugin install path too; `dx-doctor` 6.5c checks it |
| `../../shared/<file>` relative to skill dir (#257) | Copilot resolved `shared/` under skill dir | Codex gives the model the skill path; works if the plugin install keeps `skills/` next to `shared/` | Verify in installed plugin cache layout |
| `include-custom-instructions: true` on agents (#256) | Copilot subagents didn't get AGENTS.md | Codex agents are TOML, not Markdown; plugins can't ship agents | Generate `.codex/agents/*.toml` from `plugins/*/agents/*.md` (like `.github/agents` templates) |
| Repo hook template, only self-contained guards (#249, #259) | Copilot repo hooks have no plugin root | `.codex/hooks.json` in repo (trusted) or plugin `hooks/hooks.json` (with `CLAUDE_PLUGIN_ROOT`) | Test plugin hooks first; if CLI does not load them, ship `.codex/hooks.json` via `/dx-init` |
| Hook status lines via `{"type":"progress"}` (#261) | Copilot has no `statusMessage` | Unknown if Codex shows anything | Low priority |
| Weekly Copilot bundle check (#264) | Catch silent behaviour changes | Codex is open source (Rust) — grep `openai/codex` source per release | `scripts/codex-source-check.sh` + weekly workflow |
| Re-test checklist `docs/testing/copilot-cli-retest.md` (#262) | Manual verification list | none | Add `docs/testing/codex-cli-retest.md` |

### Hook-specific risks on Codex

- PreToolUse matcher is `Bash|bash|shell|execute` — Codex shell tool name must match one of these **(check: likely `shell` / `exec_command`)**.
- The `if: "Bash(git commit*)"` field is Claude-only; the guard already re-checks with `grep -q "git commit"` on stdin, so it still works if `if` is ignored.
- `statusMessage`, `onFailure` probably ignored — harmless.
- Stop guard and PostToolUse use **`$CLAUDE_PROJECT_DIR`**. Codex docs mention no such var → would resolve to `/.claude/hooks/...` and silently skip. Fix: `${CLAUDE_PROJECT_DIR:-$PWD}` (same trick the Copilot repo template uses).
- PostToolUse matchers use Claude names `mcp__plugin_dx-core_figma__*` — will not match Codex MCP tool names.

## 6. Plan to make dx work on Codex like on Claude Code

Ordered by value / cost. Each step is testable on its own.

1. **Quick win — try the marketplace as-is.** `codex plugin marketplace add easingthemes/dx-aem-flow` — Codex reads `.claude-plugin/marketplace.json` as legacy-compatible. Record what loads (skills? hooks? MCP?). This may make `.codex/INSTALL.md` symlinks obsolete in one step.
2. **Add `.codex-plugin/plugin.json`** to all 4 plugins (name, version, description, `skills`, `mcpServers`, `hooks`). Add them to `scripts/bump-versions.sh`, `.releaserc` and `validate-structure.sh`. Closes TODO #88.
3. **MCP:** emit Codex-format MCP (`mcp.json` in the plugin, or `[mcp_servers.*]` into `.codex/config.toml` from `/dx-init`). ADO and Atlassian are project-level today — `/dx-init` writes them for Codex too.
4. **Hooks:** `${CLAUDE_PROJECT_DIR:-$PWD}` in `hooks.json`; add Codex shell tool names to the matcher regex; test the branch guard and stop guard live.
5. **Agents:** generator `plugins/*/agents/*.md` → `.codex/agents/<name>.toml` (`developer_instructions` = body; `model_reasoning_effort` from `effort:`; leave `model` unset). Run from `/dx-init`, `/dx-upgrade`, scaffold. Note: no `tools:` restriction on Codex.
6. **Skill text:** reword the Isolation check and other "Copilot CLI" mentions to "harnesses that ignore `context: fork`"; check skills that call `AskUserQuestion`, `Task`, `Skill` by name still degrade sensibly. Skill-to-skill calls (`dx-core:dx-step-build`) — check Codex namespacing.
7. **dx-init / dx-doctor / dx-upgrade:** detect Codex (`~/.codex`), write `trust_level`, `project_doc_fallback_filenames = ["CLAUDE.md"]` if consumer has no AGENTS.md, `CLAUDE_PLUGIN_ROOT` export; doctor checks each.
8. **Testing:** `docs/testing/codex-cli-retest.md`, a source-check script against `openai/codex`, and a Codex column in the compat references.
9. **Later:** `dx-automation` pipelines on `codex exec` (`--json`, `--output-schema`) as an alternative runner — separate TODO, needs `CODEX_API_KEY`.

## 7. Open questions (need a live Codex run)

- Does the CLI (not desktop) load plugin `hooks/hooks.json`?
- Is `${CLAUDE_PLUGIN_ROOT}` substituted in SKILL.md text?
- Is `~/.codex/skills` still read?
- Shell tool name seen by PreToolUse matcher.
- Plugin skill namespacing (`$dx-core:dx-req` vs `$dx-req`).
- MCP tool-name format inside Codex (affects PostToolUse matchers and the CLAUDE.md naming table).
- Does a subagent spawned from an inline skill see the parent conversation (Isolation check logic)?
