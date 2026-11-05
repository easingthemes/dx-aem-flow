# OpenCode support — existing solutions, our wiring, target layout (2026-11-04)

Input for [TODO #186](../todo/todo-cross-platform.md#opencode-plugin-support). Scope:
**dx-core and dx-aem only** (dx-hub, dx-automation out of scope for now).

Method: read the official docs (opencode.ai/docs, /v2/docs), cloned and measured nine
projects that claim to ship Claude Code plugins to OpenCode (filtered in §2.1), read OpenCode's own source
(`anomalyco/opencode` main, 2026-11-04) where the docs were silent, and grepped our
plugins. Statements marked *(source)* were read in code, not docs.

## 1. Terminology — "plugin" means two things

| | Claude Code / Copilot CLI plugin | OpenCode plugin |
|---|---|---|
| What it is | Distribution unit: bundles skills, agents, hooks, MCP | Runtime extension: JS/TS module with hooks, custom tools |
| Install | `/plugin install x@marketplace` → plugin cache | `opencode.json` `plugin`/`plugins` entry, or file in `.opencode/plugins/` |
| Claude equivalent | — | a mod / `hooks.json` |

OpenCode has **no distribution unit** for skills + agents + commands + MCP. Each goes in
separately as files and config. Every project below works around that.

## 2. Existing solutions — how others ship Claude Code plugins to OpenCode

### 2.1 Value filter

Stars are not a quality signal in this space. Several repos with 100k+ stars have no relevant
code, and big multi-tool repos often have a thin OpenCode part. Each candidate was cloned
(2026-11-05) and measured on its **OpenCode-specific** code only:

- commits that touch OpenCode files, and how many distinct authors made them
- OpenCode-specific test files
- the date of the last change to that code
- whether it covers more than skills (agents, MCP, hooks)

| Project | ★ | OpenCode commits / authors | OpenCode tests | Last OpenCode change | Covers | Verdict |
|---|---|---|---|---|---|---|
| [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) | 25.9k | 40 / 15 | 4 (converter, writer, plugin, commands) | 2026-10-28 | skills, agents, commands, MCP, hooks | **Reference #1.** Real converter with tests. A written OpenCode spec (`docs/specs/opencode.md`). Lessons from real bugs (`ProviderModelNotFoundError` on subagent models, parallel-hook crash guard). |
| [code-yeongyu/oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) (was oh-my-opencode) | 70.7k | 843 / 54 (whole repo is OpenCode) | 42 in the Claude-Code compat layer | 2026-10-30 | Claude Code **marketplace plugins in place** (`installed_plugins.json`), skills, agents, commands, MCP, hooks | **Reference #2, for code only.** `packages/claude-code-compat-core/…/claude-code-plugin-loader` is a real, tested loader. But it is a large opinionated harness; using it means adopting all of it. |
| [obra/superpowers](https://github.com/obra/superpowers) | 312k | 29 / 6 | 13 | 2026-11-03 | skills (+ tool-name mapping prompt) | **Reference for the plugin API.** Clean dual v1/v2 entry point, zero dependencies. Skills only. |
| [wshobson/agents](https://github.com/wshobson/agents) | 42.2k | 8 / 2 | 1 | 2026-09-13 | skills, agents, commands | **Small but readable.** `tools/adapters/opencode.py` (265 lines) shows the agent translation rules. Thin otherwise. |
| [harnesstap/opencode-agent-plugin-support](https://github.com/harnesstap/opencode-agent-plugin-support) | 1 | 18 / 3 | 99 | 2026-10-12 | skills, agents, commands, MCP, hooks, instructions (in place) | **Well engineered, unproven.** Many tests, but four weeks old and no users yet. Watch it, don't depend on it. |
| [joshuadavidthomas/opencode-agent-skills](https://github.com/joshuadavidthomas/opencode-agent-skills) | 287 | 60 / 4 | 13 | 2026-07-24 (later: only dependency bumps) | skills from `~/.claude/plugins` cache | Skills only, maintenance mode. Not enough for us. |
| [TokenRollAI/acplugin](https://github.com/TokenRollAI/acplugin) | 58 | 5 / 2 | 0 | 2026-08-24 | "convert Claude plugins to Codex/OpenCode/Cursor" | **Dropped:** no tests, two authors, mostly generated scaffolding. |
| [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills) | 29.3k | — | 0 | — | copies skills via `scripts/convert.sh` | **Dropped:** a skill collection judged by count ("410 skills"); the OpenCode support is a copy step. |
| oh-my-opencode-slim, MSApps "converted" plugins, other `*-opencode` ports | 0–10k | — | — | — | — | **Dropped:** forks, ports of one plugin, or tools unrelated to plugin delivery. |
| Search hits with 100k+ ★ (e.g. ECC, ponytail, agency-agents) | — | — | — | — | — | **Dropped:** no OpenCode delivery code for plugins. |

Only the first four (plus harnesstap as a watch item) are used in the rest of this note.

### 2.2 What the kept solutions do

| Solution | Approach | Skills | Agents | MCP | Hooks |
|---|---|---|---|---|---|
| **compound-engineering** (CE below) | (a) Runtime extension `.opencode/plugins/compound-engineering.js`, installed with a git spec in `opencode.json`. (b) Bun converter `bunx @every-env/compound-plugin install … --to opencode` (`src/converters/claude-to-opencode.ts`, `src/targets/opencode.ts`). | (a) v1 `config` hook → `skills.paths`; v2 `ctx.skill.transform`. Each skill also gets a slash command stub: "Load and execute the `X` skill. $ARGUMENTS". (b) Copies to `~/.config/opencode/skills/`. | (b) only → `~/.config/opencode/agents/*.md`, `mode: subagent`, **no `model` on subagents** (explicit ids caused `ProviderModelNotFoundError`), `tools` → `permission`. | (b) `command`+`args` → `{type: local, command: [...]}`, `url` → `{type: remote}` merged into `opencode.json`. | (b) generates a TS plugin: `PreToolUse`→`tool.execute.before`, `PostToolUse`→`tool.execute.after`, … |
| **oh-my-openagent** | Runtime harness that reads Claude Code's `installed_plugins.json` and loads each plugin from its install path. | Loaded in place. The body is wrapped with "Base directory for this skill: <dir>", and **`${CLAUDE_PLUGIN_ROOT}` is replaced with the install path** *(source: `skill-loader.ts:47-49`, `plugin-path-resolver.ts` — braced form only)*. | Loaded (`agent-loader.ts`) | Loaded (`mcp-server-loader.ts`), plugin root expanded | Claude hooks run, with `CLAUDE_PLUGIN_ROOT` set on the hook process |
| **superpowers** | Runtime extension only (git spec). | Same as compound-engineering (a). Injects a v1/v2 tool-mapping prompt (`task`↔`subagent`, `bash`↔`shell`, `todowrite`, `skill`). | none | none | none |
| **wshobson/agents** | Python generator `tools/adapters/opencode.py`, `make install-opencode`. Writes `.opencode/` (gitignored) and symlinks it into `~/.config/opencode/`. | `.opencode/skills/<plugin>-<skill>/` (prefixed, validated against the name regex; collisions fail). Mirrors all files in the skill dir. | `.opencode/agents/<plugin>__<agent>.md`, `mode: subagent`, `tools` → `permission` block with `skill` + `task` always allowed, model alias → full `provider/model-id`. | not generated | not generated |
| *harnesstap (watch)* | Runtime extension, loads Claude plugin trees in place, v2 primary. | `ctx.skill.transform`; substitutes `${CLAUDE_SKILL_DIR}` and `${CLAUDE_PLUGIN_ROOT}` (braced only, `src/skills.ts:152`). | `ctx.agent.transform` | `ctx.mcp.transform` | `hooks.json` command hooks |

**What the kept solutions agree on:**
- For full fidelity (agents + MCP + hooks), either **generate native OpenCode files**
  (compound-engineering's converter, wshobson) or **load the Claude plugin in place** with a
  substantial runtime layer (oh-my-openagent). compound-engineering's spec (verified
  2026-04-19) says: *"Keep the custom writer until OpenCode documents a native distribution
  path for packaged skills and agents."*
- For **skills only**, a small runtime extension that registers skill dirs is the common
  shortcut (superpowers, compound-engineering path a).
- **Recurring translations:**
  - agents get `mode: subagent`
  - `tools` → `permission`
  - subagents get no model, or a full `provider/model-id`
  - MCP becomes `local`/`remote`
  - skills get slash command stubs
  - plugin-namespaced agent refs are flattened (`plugin:agent` → `agent`; compound-engineering `transformSkillContentForOpenCode`)
  - `.claude/` paths are rewritten
- **Script paths.** compound-engineering's skills tell the model to set `SKILL_DIR` to "the
  absolute directory you loaded this SKILL.md from"; OpenCode's `skill` tool returns that
  directory *(source: `packages/core/src/tool/plugin/skill.ts`)*. oh-my-openagent and harnesstap
  instead replace the literal **`${CLAUDE_PLUGIN_ROOT}`** in skill text, braced form only.
  Our 47 unbraced `$CLAUDE_PLUGIN_ROOT` refs would not be replaced (see §9.3).

## 3. OpenCode facts the design depends on

- **Skills discovery:** `.opencode/skills/`, `.claude/skills/`, `.agents/skills/` (project,
  walking up to the worktree root) and the same under `~/.config/opencode`, `~/.claude`,
  `~/.agents`.
  - v2 adds a `skills: [...]` config array taking paths or an HTTP catalog.
  - v1 has an undocumented `skills.paths`; CE and superpowers both use it, but CE's spec
    warns not to depend on it untested.
- **Skill name rules (v1):** `^[a-z0-9]+(-[a-z0-9]+)*$`, ≤64 chars, equal to the dir name;
  description ≤1024 chars. v2 takes the id from the path.
- **MCP tool names:** `<server>_<tool>`; any char outside `[a-zA-Z0-9_-]` becomes `_`
  *(source: `packages/core/src/tool/runtime.ts:288-293`, `tool/mcp.ts:23-25`)*.
  Server `AEM` + tool `getNodeContent` → **`AEM_getNodeContent`**.
- **Built-in tools (v2):** `read`, `write`, `edit`, `patch`, `glob`, `grep`, `shell`,
  `subagent`, `skill`, `question`, `todo`, `webfetch`, `websearch`
  *(source: `packages/core/src/tool/plugin/`)*. v1 uses `bash`, `task`, `todowrite`,
  `apply_patch` instead (per superpowers' and CE's maps).
- **Agents:**
  - read from `.opencode/agents/` and `~/.config/opencode/agents/`; **not** from `.claude/agents/`
  - frontmatter: `description` (required), `mode`, `model` (`provider/id`), `permission`, `hidden`, `steps`
  - no per-agent `mcpServers`; per-agent MCP access goes through `permission` (or deprecated `tools`) globs on `<server>_*` — glob form in `permission` to verify (§8)
- **Instructions:** `AGENTS.md`, falling back to `CLAUDE.md` only when no `AGENTS.md` exists;
  `instructions: [...]` adds more files.
- **MCP config:** the `mcp` key in `opencode.json`; `.mcp.json` is **not** read.

## 4. How dx-core and dx-aem are wired (what must survive the move)

Counts from `plugins/dx-core` + `plugins/dx-aem`, 2026-11-04.

### 4.1 Inventory

| | dx-core | dx-aem |
|---|---|---|
| Skills | 49 | 12 |
| Agents | 7 | 6 |
| Skills with `scripts/` or `templates/` | 10 (dx-agent-all, dx-bug-all, dx-doctor, dx-eject, dx-figma-prototype, dx-init, dx-pr-review, dx-pr-reviews-report, dx-simple, dx-sync) | 0 |
| Plugin-level dirs skills read | `shared/` (25 files), `data/`, `templates/`, `rules/` | `shared/` (2), `data/`, `templates/` |

### 4.2 Skill frontmatter

| Field | Skills | On OpenCode |
|---|---|---|
| `name`, `description` | 61 | honored; all pass the v1 name/length rules |
| `argument-hint` | 61 | ignored (CE carries it onto the command stub) |
| `allowed-tools` | 60 — **Copilot names** (`read`, `edit`, `search`, `write`, `agent`, `ado/*`, `AEM/*`, …) | ignored |
| `context: fork` | 16 | ignored → runs inline |
| `agent:` | 6 (aem-doc-gen, aem-editorial-guide → aem-editorial-guide-capture; aem-fe-verify → aem-fe-verifier; aem-qa-handoff, aem-snapshot, aem-verify → aem-inspector) | ignored → the fork-into-agent is lost |
| `model` / `effort` | 14 / 8 | ignored |
| `disable-model-invocation` | 10 | honored on v2, ignored on v1 |
| `hooks:` | 2 (dx-agent-all, dx-simple) | ignored |

### 4.3 Skill → skill calls

Coordinators call other skills by `/name` or the Skill tool. OpenCode's `skill` tool
covers this, and bare kebab ids match ours.

- `dx-agent-all` → 19 skills (dx-req, dx-plan*, dx-step*, dx-pr*, dx-figma-all, aem-snapshot/verify/fe-verify/doc-gen, …)
- `dx-bug-all` → dx-bug-triage, dx-bug-verify, dx-bug-fix, dx-pr-commit
- `dx-step-all` → dx-step, dx-step-build, dx-step-fix
- `dx-figma-all` → dx-figma-extract, dx-figma-prototype, dx-figma-verify
- `dx-req` → dx-dor, dx-req-import, dx-ticket-analyze
- `aem-init` ↔ `dx-init`, `aem-doc-gen` → aem-editorial-guide

**dx-aem skills call dx-core skills and the reverse** (dx-agent-all → aem-*; aem-qa →
dx-pr-commit). Both plugins must be installed together.

### 4.4 Skill → agent calls

| Agent (model) | Called by | Tools / MCP |
|---|---|---|
| dx-code-reviewer (opus) | dx-pr-review, dx-step-verify, dx-eject | all |
| dx-pr-reviewer (sonnet) | dx-pr-review, dx-pr-review-all, dx-simple | Read, Glob, Grep, Bash |
| dx-doc-searcher (haiku) | dx-help, dx-ticket-analyze | Glob, Grep, Read |
| dx-figma-{components,markup,styles} (haiku) | dx-figma-prototype — as `subagent_type: dx-core:dx-figma-*` (**plugin-namespaced**) | Read, Glob, Grep |
| dx-file-resolver (haiku) | no skill names it (Copilot agent templates only) | + `mcp__ado__search_code` |
| aem-inspector (sonnet) | aem-snapshot, aem-verify, aem-qa-handoff, aem-doc-gen, aem-fe-verify, dx-simple | `mcpServers: [AEM]` + 15 `mcp__plugin_dx-aem_AEM__*` |
| aem-fe-verifier (sonnet) | aem-fe-verify | AEM + playwright tools |
| aem-editorial-guide-capture (sonnet) | aem-editorial-guide, aem-doc-gen | playwright tools |
| aem-file-resolver / aem-page-finder (haiku) | aem-component, dx-ticket-analyze, dx-simple | `mcp__ado__search_code` / AEM search tools |
| aem-bug-executor (sonnet) | no skill names it (description says dx-bug-verify uses it) | AEM + playwright |

`subagent_type` values in skill bodies: `general-purpose` ×6 (→ OpenCode `general`),
`dx-pr-reviewer` ×4, `dx-core:dx-figma-*` ×3 (namespace must be flattened, as CE does),
`aem-*` ×3.

### 4.5 MCP tool references

| Our prefix | Refs | Distinct tools | Server in | OpenCode name (server key as below) |
|---|---|---|---|---|
| `mcp__ado__` | 146 | 16 | consumer project config | `ado_<tool>` |
| `mcp__plugin_dx-aem_AEM__` | 117 | 16 | dx-aem `.mcp.json` | `AEM_<tool>` |
| `mcp__plugin_dx-aem_playwright__` | 99 | 20 | dx-aem `.mcp.json` | `playwright_<tool>` |
| `mcp__atlassian__` | 82 | 22 | consumer project config | `atlassian_<tool>` |
| `mcp__plugin_dx-core_figma__` | 5 | 4 | dx-core `.mcp.json` | `figma_<tool>` |
| `mcp__plugin_dx-core_axe-mcp-server__` | 0 (skills name the server generically) | — | dx-core `.mcp.json` | `axe-mcp-server_<tool>` |
| `mcp__claude_ai_Figma__`, `mcp__plugin_dx-aem_chrome-devtools-mcp__` | 2, 1 | — | stale/alt refs | — |

`ToolSearch` appears in 22 skill/agent files. OpenCode has no deferred-tool loader, so these
instructions point at a tool that doesn't exist; the model has to skip them.

### 4.6 Paths and Claude-only tools

| Pattern | Refs | Resolves on OpenCode? |
|---|---|---|
| Bare `shared/<file>` ("Read `shared/provider-config.md`") | 87 | Only if the model finds the plugin root. No anchor. |
| `plugins/dx-core/shared/…` | 17 | Only in this repo (dev layout). |
| `$CLAUDE_PLUGIN_ROOT/…` (47 unbraced, 7 braced) + `${CLAUDE_SKILL_DIR}` (7) | 61 | **No** — unset. harnesstap substitutes only the braced form. |
| Skill scripts using `$(dirname "${BASH_SOURCE[0]}")/../../../shared` | 4 files | Only if `skills/<s>/scripts` and `shared/` keep their relative layout. **Copying skills alone breaks it.** |
| `.ai/lib/*.sh` / `.js` (dx-common 53, ensure-feature-branch 10, …) | ~100 | **Yes** — project files installed by `/dx-init` or `dx-scaffold`. |
| `AskUserQuestion` | 7 files | → `question` (exists v1+v2) |
| `TaskCreate` | 6 | → `todowrite` (v1) / `todo` (v2) |
| Skill tool | 12 | → `skill` |
| Agent/Task tool, `subagent_type` | 15 | → `task` (v1) / `subagent` (v2) |

## 5. Target layout on OpenCode (manual install, no tooling)

What a consumer machine needs, mirroring the CE/wshobson output shape. The
plugin-relative tree is kept **intact** because of §4.6.

```
~/.config/opencode/
├── opencode.json                 # mcp, permission, (v2) skills paths
├── dx/                           # untouched copy/clone of the two plugins
│   ├── dx-core/{skills,shared,data,templates,rules}/
│   └── dx-aem/{skills,shared,data,templates}/
├── skills/                       # v1 only: one symlink per skill
│   ├── dx-req -> ../dx/dx-core/skills/dx-req
│   └── aem-verify -> ../dx/dx-aem/skills/aem-verify   # 61 links
├── agents/                       # 13 translated files (§5.2)
│   ├── dx-code-reviewer.md
│   └── aem-inspector.md …
├── commands/                     # optional: stubs for user-invoked skills (CE pattern)
│   └── dx-agent-all.md           # "Load and execute the `dx-agent-all` skill.\n\n$ARGUMENTS"
└── plugins/                      # runtime extensions (OpenCode-only JS)
    ├── dx-env.js                 # Phase 1: sets CLAUDE_PLUGIN_ROOT for shell calls (§9)
    └── dx-guard.js               # optional: branch-guard

<project>/
├── opencode.json                 # project MCP (ado, atlassian), instructions
├── AGENTS.md / CLAUDE.md
└── .ai/{config.yaml,lib/,rules/,…}   # from /dx-init or dx-scaffold — unchanged
```

On v2, the `skills/` symlinks are replaced by
`"skills": ["~/.config/opencode/dx/dx-core/skills", "~/.config/opencode/dx/dx-aem/skills"]`.

### 5.1 `opencode.json` (global)

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "AEM":        { "type": "local", "command": ["npx","-y","aem-mcp-server","-t","stdio","-I","{env:AEM_INSTANCES}"] },
    "playwright": { "type": "local", "command": ["npx","@playwright/mcp@0.0.83","--headless","--isolated",
                    "--viewport-size=1440,900","--caps=storage","--no-webmcp","--output-dir=.ai/playwright/screenshots"] },
    "axe-mcp-server": { "type": "local", "command": ["docker","run","--add-host=host.docker.internal:host-gateway",
                    "-i","--rm","-e","AXE_API_KEY","dequesystems/axe-mcp-server:latest"],
                    "environment": { "AXE_API_KEY": "{env:AXE_API_KEY}" } },
    "figma":      { "type": "remote", "url": "http://127.0.0.1:3845/mcp", "oauth": false }
  },
  "permission": { "skill": { "dx-*": "allow", "aem-*": "allow" } }
}
```

Project `opencode.json`: `ado` and `atlassian` servers (named exactly so the tool prefixes
in §4.5 line up), plus `"instructions": ["CLAUDE.md"]` whenever `/dx-init` wrote an
`AGENTS.md` (otherwise the consumer's `CLAUDE.md` is dropped — §3).

### 5.2 Agent translation (example)

Source `plugins/dx-aem/agents/aem-inspector.md`:
```yaml
tools: Read, Write, Glob, Grep, ToolSearch, mcp__plugin_dx-aem_AEM__getNodeContent, …
mcpServers: [AEM]
model: sonnet
memory: project
maxTurns: 50
```
OpenCode `~/.config/opencode/agents/aem-inspector.md` (CE/wshobson rules):
```yaml
description: <same>
mode: subagent
# no model: subagents inherit the session model (CE: explicit ids broke providers)
steps: 50                       # from maxTurns
permission:
  edit: allow
  bash: deny                    # not in source tools
  "AEM_*": allow
  "playwright_*": deny
  "ado_*": deny
```
Body unchanged, except `mcp__plugin_dx-aem_AEM__x` → `AEM_x` if we rewrite (optional;
CLAUDE.md's position is that the model maps prefixed names itself). `memory: project`
has no OpenCode equivalent.

## 6. What still breaks, even with the layout above

1. **Plugin-root variables (61 refs).** Unset. **Phase 1 fix: §9.** Fix patterns seen in existing solutions:
   - CE: skill bodies set `SKILL_DIR` to the loaded skill's directory; OpenCode's `skill`
     tool returns that directory.
   - harnesstap: textual substitution at load time (braced form only).
   - Generator: rewrite at copy time to the absolute install path.
   Our TODO #86 is the same problem for Copilot/Codex.
2. **Bare `shared/…` (87 refs).** Read instructions to the model, not shell paths. Phase 1: an
   install-note hint; Phase 2: maybe rewrite to `$CLAUDE_PLUGIN_ROOT/shared/…` (§9.5).
3. **`context: fork` / `agent:` (16 + 6).** Lost. **Phase 2, full analysis: §10.** Command stubs
   with `agent:` + `subtask: true` (wshobson uses `subtask` on agent-orchestrating commands) can
   run a *user-typed* skill in a subagent. Model-invoked skills still run inline.
   - **Subagents themselves work.** v1 has the `task` tool; v2 has `subagent` (`agent`, `prompt`,
     `background`, `sessionID` for follow-ups) *(source: `tool/plugin/subagent.ts`)*. Several
     calls in one turn run in parallel (per wshobson's matrix, not verified), `background: true` runs async, and `subagent_depth`
     (config) allows nesting. So skills that spawn agents explicitly (dx-figma-prototype ×3,
     dx-pr-review-all, dx-step-verify → dx-code-reviewer, the aem-* skills → aem-inspector)
     keep working, given translated agents.
   - **What is lost is the skill-level fork.** OpenCode's `skill` tool only returns content
     into the caller's context. Coordinators chain forked skills (`dx-agent-all` → dx-req →
     dx-plan → dx-step-all → dx-step …), and on OpenCode these all pile into one context,
     relying on compaction.
   - **No existing solution handles `context: fork`.** CE ignores it; wshobson sets `subtask: true` only
     on *commands* whose body mentions agents; harnesstap doesn't map it.
   - **Possible fix: a generated wrapper.** For each fork skill, emit an OpenCode agent
     (`mode: subagent`, `agents/dx-step.md`, body "Load the `dx-step` skill with the `skill` tool
     and execute it for: <task>"). The coordinator calls `subagent(agent: "dx-step", …)`
     instead of loading the skill, and a command stub with `subtask: true` covers the
     user-typed `/dx-step`. Untested; needs a smoke test.
4. **`ToolSearch` (22 files).** Dead instruction on OpenCode.
5. **Model tiers.** Lost (subagents inherit). An explicit `provider/model-id` per agent is
   possible but pins a provider.
6. **Hooks.** Branch-guard / Stop guard / session-start don't run unless ported to a runtime
   extension (CE generates one).

## 7. Options seen in the wild, mapped to us

| Option | Who does it | Fit for dx-core + dx-aem |
|---|---|---|
| A. Generator writes native files (skills, agents, commands, `opencode.json`) | CE converter, wshobson | Covers everything in §5. Natural home: `dx-scaffold` (already reads `plugins/` at runtime). Can rewrite §6.1/6.2 paths at write time. |
| B. Runtime extension registers skill dirs in place | superpowers, CE plugin | Skills + command stubs only; no agents/MCP. Needs v1+v2 dual entry. |
| C. Generic in-place loader of Claude plugin trees | oh-my-openagent (mature, tested, but a whole harness), harnesstap (young) | Needs our refs in braced form (§9.3). A user who already runs oh-my-openagent may get dx almost for free; worth a smoke test, not a dependency. |
| D. Copy skills only | (dropped projects) | Breaks §4.6 relative scripts and agents. Not enough. |

## 8. Open questions

- Does OpenCode follow symlinked skill dirs on v1 and v2? (wshobson symlinks `.opencode/` as a whole — likely yes.)
- Does `{env:VAR}` substitution work inside a local server's `command` array?
- How does a v2 HTTP-catalog skill expose its cache dir for scripts?
- Do agent `permission` blocks accept tool-name globs like `"AEM_*": allow`? (The MCP docs show globs under `tools`.)
- Does the model reliably map `mcp__plugin_dx-aem_AEM__getNodeContent` → `AEM_getNodeContent` without a rewrite? Smoke test before deciding.

## 9. Plugin root on OpenCode — `CLAUDE_PLUGIN_ROOT` / `CLAUDE_SKILL_DIR` (Phase 1)

Claude Code stays primary, so skill text keeps the Claude variables. OpenCode only has to
**provide** them. The question is what value and who sets it.

### 9.1 What the references actually need

| Variable | Refs | Files | Points into | Global value possible? |
|---|---|---|---|---|
| `$CLAUDE_PLUGIN_ROOT/skills/<s>/…` | 39 | dx-bug-all, dx-simple (+ their `scripts/`), dx-step, dx-step-all, dx-figma-all, dx-req, dx-req-dod, dx-agent-all, dx-init | **dx-core** | yes |
| `$CLAUDE_PLUGIN_ROOT` existence checks (no path suffix) | 7 | `dx-bug-all/scripts/preflight.sh`, `dx-simple/scripts/{preflight,resume-check}.sh` | **dx-core** | yes |
| `$CLAUDE_PLUGIN_ROOT/shared/…` | 7 | same set | **dx-core** | yes |
| `${CLAUDE_PLUGIN_ROOT}/data/lib/aem-playwright-auth.sh` | 1 | aem-init (line 388) | **dx-aem** | no — conflicts with the dx-core value |
| `${CLAUDE_SKILL_DIR}/scripts/…` | 7 | dx-init (×4), dx-sync, dx-doctor, dx-eject | the skill's own dir | **no** — different value per skill |

So 53 of the 54 `CLAUDE_PLUGIN_ROOT` refs agree on one value, the **dx-core plugin root**. The aem-init ref and the 7
`CLAUDE_SKILL_DIR` refs (61 total with these) need a text change.

### 9.2 The value

With the layout from §5, `CLAUDE_PLUGIN_ROOT` must be the dx-core directory that contains
`skills/` and `shared/`:

```
CLAUDE_PLUGIN_ROOT=$HOME/.config/opencode/dx/dx-core
```

It must be the intact plugin tree, not `~/.config/opencode/skills`. The 39 `…/skills/<s>/…`
refs and the `scripts/../../../shared` lookups (§4.6) both assume
`<root>/skills/<s>/scripts` and `<root>/shared` side by side.

### 9.3 Text changes (small, Claude-Code-safe)

- **`CLAUDE_SKILL_DIR` (7 refs)** → rewrite to `$CLAUDE_PLUGIN_ROOT/skills/<skill>/scripts/…`.
  37 refs already use this form and work in Claude Code today (dx-bug-all, dx-simple), so
  Claude Code behaviour does not change. After this, OpenCode needs only one variable.
- **aem-init (1 ref)** → the instruction copies a file from the dx-aem plugin. Change it to
  locate the file the same way dx-init already locates the AEM plugin (`$AEM_PLUGIN_DIR`, found
  by glob for `**/skills/aem-init/SKILL.md`), or add a second variable `DX_AEM_PLUGIN_ROOT`.
  Prefer the glob: no new variable.

- **Unbraced → braced (47 refs, optional):** `$CLAUDE_PLUGIN_ROOT/…` → `${CLAUDE_PLUGIN_ROOT}/…`.
  It means the same in a shell. But oh-my-openagent and harnesstap replace only the braced
  literal in skill text, so this would make dx work under those loaders with no
  `dx-env.js`. Low cost; do it with the `CLAUDE_SKILL_DIR` rewrite.

### 9.4 Who sets it — options

| Option | Scope | Notes |
|---|---|---|
| a. `export CLAUDE_PLUGIN_ROOT=…` in `~/.zshrc` | **every** process, Claude Code included | Rejected: leaks into Claude Code sessions. Whether Claude Code overrides an inherited value for plugin skills is unverified, and a stale OpenCode copy could shadow the installed plugin. |
| b. Launcher alias `alias opencode='CLAUDE_PLUGIN_ROOT=$HOME/.config/opencode/dx/dx-core opencode'` | OpenCode only | No code, works on v1 and v2. Easy to forget on another shell or in the desktop app. |
| c. **Global runtime extension** `~/.config/opencode/plugins/dx-env.js` | OpenCode shell calls only | Sets the var on every shell call. v1 hook `"shell.env": (input, output) => { output.env.CLAUDE_PLUGIN_ROOT = … }` (docs). v2 hook `ctx.shell.hook("create.before", …)` with `env` on the input *(source: `packages/plugin/src/promise/shell.ts`)*. It derives the path from its own location (`path.resolve(__dirname, "../dx/dx-core")`), so **nothing is hardcoded and no config is needed**. |
| d. `/dx-init` sets it | — | `/dx-init` is per **project** and writes committed files. The value is per **machine** (where dx was installed), and a skill cannot change the environment of the OpenCode process. dx-init can only *check* it. |

**Recommendation:** (c) as the default, (b) documented as the no-code fallback.

`/dx-init` and `/dx-doctor` get an OpenCode check: if it runs under OpenCode (detection method to be verified; no env marker confirmed yet) and
`$CLAUDE_PLUGIN_ROOT/skills/dx-init/SKILL.md` does not exist, print the fix (install the
extension or the alias). `dx-bug-all/scripts/preflight.sh` already fails loudly when the variable
is missing (`CLAUDE_PLUGIN_ROOT not set in environment`). Reuse its message.

### 9.5 Not covered by the variable

- **87 bare `shared/<file>` refs** ("Read `shared/provider-config.md`"): these are read
  instructions to the model, not shell paths. In Claude Code the model resolves them against the
  plugin it loaded the skill from. On OpenCode the `skill` tool returns the skill `directory`, so
  `<directory>/../../shared/<file>` resolves. Phase 1: one line in the OpenCode install note /
  `AGENTS.md` telling the model this. Phase 2: decide whether to rewrite them to
  `$CLAUDE_PLUGIN_ROOT/shared/…`.
- **17 `plugins/dx-core/shared/…` refs**: repo-layout paths, wrong on every consumer platform.
  Separate cleanup.

## 10. Context isolation — `context: fork` and `agent:` (Phase 2)

This matters: it decides whether long pipelines (`dx-agent-all`, `dx-bug-all`) survive on
OpenCode at all. Phase 1 accepts the degraded behaviour below. Phase 2 fixes it.

### 10.1 What `context: fork` does in Claude Code

A skill with `context: fork` runs in a **fresh subagent context**. It does not see the caller's
conversation. It works through its steps, and only its final message returns to the caller.
With `agent: <name>` it runs as that named agent (its tools, model, MCP servers). This is what
keeps a coordinator's context small: `dx-agent-all` sees ~10 short results, not the full
transcripts of dx-req, dx-plan, every dx-step, build, verify and PR.

### 10.2 The 16 forked skills and who chains them

| Forked skill | `agent:` | Called by |
|---|---|---|
| dx-req | — | dx-agent-all, dx-bug-triage, dx-plan-validate, dx-step, aem-qa, aem-doc-gen, … |
| dx-plan, dx-plan-validate, dx-plan-resolve | — | dx-agent-all; dx-plan ↔ dx-plan-validate ↔ dx-plan-resolve |
| dx-step | — | dx-step-all, dx-agent-all, dx-bug-fix, dx-pr |
| dx-step-all | — | dx-agent-all, dx-figma-all, dx-pr-review |
| dx-step-build, dx-step-fix | — | dx-step-all, dx-agent-all, dx-bug-fix |
| dx-step-verify | — (spawns dx-code-reviewer itself) | dx-agent-all, dx-pr, aem-fe-verify |
| dx-pr-commit | — | dx-agent-all, dx-bug-all, dx-bug-fix, aem-qa, aem-fe-verify |
| aem-snapshot, aem-verify, aem-qa-handoff | aem-inspector | dx-agent-all, aem-qa, dx-doc-gen |
| aem-fe-verify | aem-fe-verifier | dx-agent-all, dx-doc-gen |
| aem-editorial-guide, aem-doc-gen | aem-editorial-guide-capture | dx-agent-all, aem-doc-gen |

Nesting depth in the worst path: `dx-agent-all` → `dx-step-all` → `dx-step` /
`dx-step-fix` → (dx-step-verify → dx-code-reviewer). That is 3–4 levels of isolated context in
Claude Code.

### 10.3 What happens on OpenCode (Phase 1 behaviour)

- The `skill` tool returns the skill's text **into the caller's context**. There is no isolation.
  `context` and `agent` are unknown frontmatter keys and are dropped.
- Every forked skill in a chain runs inline in the same conversation: dx-req's research, dx-plan's
  reasoning, every dx-step's edits and test output accumulate. A full `dx-agent-all` run will hit
  the context limit and rely on compaction, which can drop the plan state mid-run.
  Mitigation that exists already: our skills checkpoint to files (`.ai/specs/<id>/…`,
  `implement.md` status, `resume-state.json`), so the state survives compaction even if the
  conversation does not.
- The 6 `agent:` skills lose their agent's restrictions: they run with the caller's tools, and
  the AEM MCP permission scoping from §5.2 does not apply.
- **Subagents that skills spawn explicitly still work** (§6 item 3: `task` on v1, `subagent` on v2,
  `background`, `sessionID`, `subagent_depth`). The fan-out in dx-figma-prototype,
  dx-pr-review-all, dx-step-verify → dx-code-reviewer and aem-* → aem-inspector is unaffected.
  Parallel calls in one turn are claimed by wshobson's matrix; unverified.
- Each skill also triggers on its own. A user who runs one skill at a time (`dx-req`, then
  `dx-plan`, then `dx-step`) sees no difference. The loss only shows in the coordinators.

### 10.4 Existing solutions

None handles it. compound-engineering's converter ignores `context: fork`. wshobson sets `subtask: true`
only on *commands* whose body mentions agents (`_SUBAGENT_KEYWORD_RE`). harnesstap has no
mapping. superpowers' skills don't fork.

### 10.5 Options for Phase 2

| Option | How | Pros | Cons |
|---|---|---|---|
| A. **Wrapper agent per forked skill** | Generate `agents/<skill>.md`: `mode: subagent`, `hidden: true`, body "Load the `<skill>` skill with the `skill` tool and execute it. Arguments: from the prompt." For `agent:` skills, copy the target agent's `permission` block into the wrapper. | Restores isolation one-to-one. No change to Claude Code text. | The coordinator must call `subagent(agent: "dx-step")` instead of loading the skill. The model has to be told (see C). Up to 16 extra agents in the `@` list (mitigated by `hidden`). |
| B. **Command stubs with `subtask: true`** | `commands/<skill>.md` with `agent: <wrapper or target>`, `subtask: true`. | User-typed `/dx-step` runs isolated. CE/wshobson already generate stubs. | Only covers user-typed commands, not a coordinator calling the skill. |
| C. **Platform note in coordinators** | One block in dx-agent-all, dx-bug-all, dx-step-all, dx-figma-all, dx-bug-fix, dx-pr: "If the platform has no skill fork (OpenCode), run each forked phase via the subagent tool with agent `<skill>`." | Small, explicit, harmless in Claude Code. | Edits 6 coordinator bodies. Same pattern as the superpowers soft-dependency text. |
| D. **Runtime extension** | Intercept the `skill` tool for forked ids and redirect to a subagent call. | Invisible to skill text. | Deep in both plugin APIs (v1/v2). Not attempted by anyone. Fragile. |
| E. **Accept inline** | Document the limitation and lean on file checkpoints. | Zero work. | Long pipelines will degrade. |

**Leaning:** A + B + C together. A gives the isolated runner, B covers typed commands, C tells
coordinators to use it. All three are generatable, and C is a few lines.

### 10.6 Phase 2 test plan

1. Smoke: `subagent(agent: "dx-step")` wrapper loads the skill inside the child session and
   returns only its final message to the parent. Check the parent's token count before and after.
2. Nesting: `dx-step-all` (wrapper) → `dx-step` (wrapper) → `dx-code-reviewer` needs
   `subagent_depth` ≥ 3. Find the default and set it in `opencode.json`.
3. `agent:` skills: `aem-verify` wrapper with `aem-inspector`'s permission block can call `AEM_*`
   and nothing outside its allowlist.
4. End-to-end: `dx-agent-all` on a fixture story finishes without compaction losing
   `implement.md` state. Compare against Phase 1 inline behaviour.
5. Parallel: two `subagent` calls in one turn really run concurrently (closes the wshobson claim).

