# OpenCode support — research and brainstorm (2026-11-04)

Input for [TODO #186](../todo/todo-cross-platform.md#opencode-plugin-support). The original
plan (2026-04-04) copied the superpowers pattern of that time: a JS plugin
`.opencode/plugins/dx-core.js` with an `experimental.chat.system.transform` hook to inject
context and a `config` hook to register skills. OpenCode has moved since, and so has
superpowers. This note records what OpenCode does today and what that means for us.

Sources: opencode.ai/docs (`skills`, `plugins`, `mcp-servers`, `rules`, `agents`,
`commands`, `config`), opencode.ai/v2/docs (`skills`, `plugins`, `build/plugins`),
superpowers `.opencode/INSTALL.md` (main, 2026-11-04).

## 1. What OpenCode does natively

### Two live versions

OpenCode 2 is out (2.0.x, Homebrew `opencode-v2`). OpenCode 1 is still installed by some
package managers. The two differ where it matters for a plugin:

| | OpenCode 1 | OpenCode 2 |
|---|---|---|
| Plugin config key | `plugin` (npm names) | `plugins` (npm, local dir, `file://`, `{package, options}`) |
| Plugin shape | `async ({project, client, $, directory, worktree}) => hooks` | `Plugin.define({ id, setup(ctx) })` from `@opencode/plugin` |
| Local plugin | single `.js`/`.ts` file in `.opencode/plugins/` | file **or** dir with `index`/`server` entry |
| Extra skill dirs | none (no `skills` config key) | `skills: [ ... ]` array in `opencode.json` (paths or catalog URLs) |
| Skill frontmatter honored | `name`, `description` (+ `license`, `compatibility`, `metadata`) | same + `disable-model-invocation`, `metadata.opencode/autoinvoke` |
| Skill id | from `name`, must match dir | from **file path**; `name` is a label |

A JS plugin has to be written twice, or target one version only. That is the main reason
not to start with a plugin.

### Skills — free, no plugin needed

Both versions scan, project-level (walking up to the worktree root) and global:

- `.opencode/skills/`, `~/.config/opencode/skills/`
- `.claude/skills/`, `~/.claude/skills/` (Claude Code compat; off with `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1`)
- `.agents/skills/`, `~/.agents/skills/`

The model loads a skill through the native `skill` tool (v1 `{name}`, v2 `{id}`).
`permission.skill` in `opencode.json` takes `allow | ask | deny` per name glob.

**`.codex/INSTALL.md` already symlinks our skills into `.agents/skills/`.** A Codex-style
install gives OpenCode every skill with no extra step.

Name rules (v1): `^[a-z0-9]+(-[a-z0-9]+)*$`, 1–64 chars, equal to the directory name;
description 1–1024 chars. **Checked 2026-11-04: all 79 skills pass** (no name/dir
mismatch, no description over 1024). Nothing enforces that today.

### Instructions — a trap

Project: `AGENTS.md`, falling back to `CLAUDE.md` only if there is no `AGENTS.md`.
Global: `~/.config/opencode/AGENTS.md`, falling back to `~/.claude/CLAUDE.md`.
First match wins in each category; the extra `instructions: [...]` key adds files.

`/dx-init` (step 5d-bis) and `dx-scaffold` (`cli/lib/scaffold.js:551`) **always** write a
root `AGENTS.md` listing our agents. In a consumer that has a `CLAUDE.md`, that makes
OpenCode drop the consumer's `CLAUDE.md` — the file that actually describes their
codebase — and load only our agent table. Same issue exists for Codex. Fix:
`"instructions": ["CLAUDE.md"]` in `opencode.json`.

### MCP

Configured under `mcp` in `opencode.json`: `{type: "local", command: [...], environment}`
or `{type: "remote", url, headers, oauth}`; `{env:VAR}` substitution. **No `.mcp.json`
compat.** Tools are exposed as `<server>_<tool>` (glob examples in the docs; exact format
not spelled out). Our skills name `mcp__plugin_dx-aem_AEM__*` etc.; per CLAUDE.md the model
maps these as prose hints, same as Copilot/Gemini — needs a smoke test, not code.

Mapping of our servers:

| Ours (`.mcp.json`) | OpenCode `mcp` entry |
|---|---|
| dx-aem `AEM` stdio `npx -y aem-mcp-server -t stdio -I ${AEM_INSTANCES}` | `local`, `command: ["npx","-y","aem-mcp-server","-t","stdio","-I","{env:AEM_INSTANCES}"]` — check `{env:}` works inside `command` |
| dx-aem `playwright` stdio | `local`, same args |
| dx-core `axe-mcp-server` docker | `local`, `environment: {AXE_API_KEY: "{env:AXE_API_KEY}"}` |
| dx-core `figma` http `127.0.0.1:3845/mcp` | `remote`, `oauth: false` |
| ADO / Atlassian (project-level) | consumer adds, like for Copilot |

### Agents

Markdown in `.opencode/agents/` or `~/.config/opencode/agents/` — **`.claude/agents` is not
read**. Frontmatter: `description` (required), `mode: primary|subagent|all`, `model`
(`provider/model-id`, e.g. `anthropic/claude-sonnet-5-5`), `permission` (`tools` is
deprecated), `hidden`, `steps`. Called through the `task` tool or `@name`.

Our 13 agents (`plugins/{dx-core,dx-aem}/agents/`) would need a translated copy. Their
`model: sonnet` aliases have no OpenCode equivalent — either a pinned id (goes stale; we
avoid that for Claude Code) or omit and inherit.

### Commands

`.opencode/commands/*.md`, `$ARGUMENTS`, `$1..`; frontmatter `description`, `agent`,
`model`, `subtask`. `.claude/commands` not documented as read. Skills are not slash
commands in v1; the user asks for them in prose or the model picks one by description.

### Plugins (only for what config cannot do)

v1 hooks: `tool.execute.before` / `after` (throw to block), `shell.env` (inject env vars
into every shell call), `event` (`session.created`, `session.idle`, …),
`experimental.session.compacting`. The `experimental.chat.system.transform` and `config`
hooks the old plan relied on are **not in the current docs**. v2 hook names are on a
separate page not covered here.

## 2. What breaks in our skills

| Issue | Where | Effect on OpenCode |
|---|---|---|
| `$CLAUDE_PLUGIN_ROOT` / `${CLAUDE_SKILL_DIR}` | 17 files; heavy in `dx-bug-all`, `dx-simple`, also `dx-step`, `dx-figma-all`, `aem-init` | Unset → script calls fail. `dx-bug-all/scripts/preflight.sh` stops with "CLAUDE_PLUGIN_ROOT not set". Codex has the same hole. |
| `model:` / `effort:` | Opus/Haiku tiers | Ignored; session model used |
| `context: fork` + `agent:` | 16 skills | Ignored; skill runs inline in the main context |
| Named subagents | 15 skills reference Agent/Task tool + our agents | Agents missing unless installed to `.opencode/agents/` |
| `AskUserQuestion` | 8 skills | Not checked whether OpenCode has an equivalent; model falls back to asking in text |
| Plugin hooks (`hooks.json`) | branch-guard, Stop guard, session-start, screenshot log | None run |

## 3. Brainstorm — options

1. **Docs only.** `.opencode/INSTALL.md`: clone, reuse the `.agents/skills/` symlinks (v1) or
   a `skills: [...]` array pointing at the clone (v2, no symlinks), an `opencode.json`
   example with `mcp` + `instructions: ["CLAUDE.md"]`, and a degradation table.
   Cheap, covers ~80% of skills.
2. **Fix plugin-root portably.** Skills that call their own scripts resolve the dir
   themselves instead of trusting `$CLAUDE_PLUGIN_ROOT`, e.g. fallback to the dir of the
   loaded SKILL.md. This is TODO #86 / #29 and helps Codex and Gemini too. Alternative for
   OpenCode only: a plugin with `shell.env` setting `CLAUDE_PLUGIN_ROOT`.
3. **`dx-scaffold --opencode`.** Emit `opencode.json` (`mcp`, `instructions`,
   `permission.skill`) and `.opencode/agents/*.md` translated from our agents. Same
   template-reading pattern the scaffold already uses.
4. **Guard plugin.** Tiny `.opencode/plugins/dx-guard` — `tool.execute.before` blocks
   `git commit` on protected branches (mirror of the `PreToolUse` hook). Pick one OpenCode
   version, v2 likely.
5. **Full npm/git plugin** (superpowers today: `"plugins": ["superpowers@git+…"]`, plugin
   registers skills + injects a tool-name mapping). Best UX, but two plugin APIs, a release
   artifact, and Bun cache issues. Not worth it before 1–4 show demand.
6. **Do nothing**, point to Codex install. Works partly by accident; the `AGENTS.md`
   trap and `CLAUDE_PLUGIN_ROOT` failures would hit silently.

**Recommendation:** 1 → 2 → 3, with 4 optional and 5 parked. See the TODO for phases and
done-when checks.

## 4. Open questions

- Exact MCP tool name format in OpenCode (`server_tool`?) and whether the model maps
  `mcp__plugin_dx-aem_AEM__getNodeContent` to it reliably.
- Does `{env:VAR}` substitution work inside a local server's `command` array?
- Does OpenCode follow symlinked skill dirs on both versions? (Claude Code now refuses
  symlinked plugin component paths — TODO #181 — so don't assume.)
- An `AskUserQuestion` equivalent (a `question` tool?) in v1/v2.
- v2 hook names (`/v2/docs/build/plugins/server`).
