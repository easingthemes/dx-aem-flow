# OpenCode support — prior art, our wiring, target layout (2026-11-04)

Input for [TODO #186](../todo/todo-cross-platform.md#opencode-plugin-support). Scope:
**dx-core and dx-aem only** (dx-hub, dx-automation out of scope for now).

Method: read the official docs (opencode.ai/docs, /v2/docs), cloned and read the source of four
projects that ship Claude Code plugins to OpenCode, read OpenCode's own source
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

## 2. Prior art — how others ship Claude Code plugins to OpenCode

| Project | Approach | Skills | Agents | MCP | Hooks |
|---|---|---|---|---|---|
| **[EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin)** (very active; last commit 2026-11-04) | **Two paths.** (a) Runtime extension `.opencode/plugins/compound-engineering.js`, installed with a git spec in `opencode.json`. (b) Bun converter `bunx @every-env/compound-plugin install … --to opencode` (`src/converters/claude-to-opencode.ts`, `src/targets/opencode.ts`). | (a) v1 `config` hook → `skills.paths`; v2 `ctx.skill.transform`. Each skill also gets a slash command stub: "Load and execute the `X` skill. $ARGUMENTS". (b) Copies to `~/.config/opencode/skills/`. | (b) only → `~/.config/opencode/agents/*.md`, `mode: subagent`, **no `model` on subagents** (explicit ids caused `ProviderModelNotFoundError`), `tools` → `permission`. | (b) `command`+`args` → `{type: local, command: [...]}`, `url` → `{type: remote}` merged into `opencode.json`. | (b) generates a TS plugin: `PreToolUse`→`tool.execute.before`, `PostToolUse`→`tool.execute.after`, … |
| **[wshobson/agents](https://github.com/wshobson/agents)** (multi-harness marketplace) | Python generator `tools/adapters/opencode.py`, `make install-opencode`. Writes `.opencode/` (gitignored) and symlinks it into `~/.config/opencode/`. | `.opencode/skills/<plugin>-<skill>/` (prefixed, validated against the name regex; collisions fail). Mirrors all files in the skill dir. | `.opencode/agents/<plugin>__<agent>.md`, `mode: subagent`, `tools` → `permission` block with `skill` + `task` always allowed, model alias → full `provider/model-id`. | not documented | "via TS plugins" in the matrix; not generated |
| **[obra/superpowers](https://github.com/obra/superpowers)** | Runtime extension only (git spec). | Same as CE (a). Injects a v1/v2 tool-mapping prompt (`task`↔`subagent`, `bash`↔`shell`, `todowrite`, `skill`). | none | none | none |
| **[harnesstap/opencode-agent-plugin-support](https://github.com/harnesstap/opencode-agent-plugin-support)** (young; 1★, v0.2.0, 2026-10-12) | Runtime extension that **loads Claude Code plugin trees in place** (`~/.agents/plugins`, symlink to `~/.claude/plugins`). v2 primary. | `ctx.skill.transform`; substitutes `${CLAUDE_SKILL_DIR}` and `${CLAUDE_PLUGIN_ROOT}` in skill text *(source: `src/skills.ts:152`)* — braced form only. | `ctx.agent.transform`, namespaced `plugin:agent` | `ctx.mcp.transform` from `.mcp.json`, expands plugin-root vars | Runs `hooks.json` command hooks, gives them `CLAUDE_*` env |
| **oh-my-opencode** | Large opinionated extension with a "Claude Code compatibility layer". | `.claude/skills` | `~/.claude/agents` (marked "reserved") | `.mcp.json` | `.claude/settings.json` hooks; reads `installed_plugins.json` |
| **alirezarezvani/claude-skills** | `install.sh --tool opencode` copies skills into `.opencode/skills/`. | copy | — | — | — |

**Consensus:**
- For full fidelity (agents + MCP + hooks), the mature projects **generate native OpenCode
  files** from the Claude plugin source: CE's converter and wshobson's adapter. CE's spec
  (`docs/specs/opencode.md`, verified 2026-04-19) says it plainly: *"Keep the custom
  writer until OpenCode documents a native distribution path for packaged skills and
  agents."*
- For **skills only**, a small runtime extension that registers skill dirs is the common
  shortcut (superpowers, CE path a).
- **Recurring translations:**
  - agents get `mode: subagent`
  - `tools` → `permission`
  - subagents get no model, or a full `provider/model-id`
  - MCP becomes `local`/`remote`
  - skills get slash command stubs
  - plugin-namespaced agent refs are flattened (`plugin:agent` → `agent`; CE `transformSkillContentForOpenCode`)
  - `.claude/` paths are rewritten
- **Script paths:** CE's skills don't use a plugin-root variable. Each skill tells the model to
  set `SKILL_DIR` to "the absolute directory you loaded this SKILL.md from" and runs
  `bash "$SKILL_DIR/scripts/x"`. That works because OpenCode's `skill` tool returns the skill
  `directory` with the content *(source: `packages/core/src/tool/plugin/skill.ts`)*.

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
  - no per-agent `mcpServers`; per-agent MCP access goes through `permission` globs on `<server>_*`
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
└── plugins/                      # optional runtime extension: branch-guard only
    └── dx-guard.js

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

1. **Plugin-root variables (61 refs).** Unset. Fix patterns seen in prior art:
   - CE: skill bodies set `SKILL_DIR` to the loaded skill's directory; OpenCode's `skill`
     tool returns that directory.
   - harnesstap: textual substitution at load time (braced form only).
   - Generator: rewrite at copy time to the absolute install path.
   Our TODO #86 is the same problem for Copilot/Codex.
2. **Bare `shared/…` (87 refs).** No anchor without a plugin root. Same fix as 1 (prefix with
   the resolved root), or the generator rewrites to an absolute path.
3. **`context: fork` / `agent:` (16 + 6).** Lost. For the 6 AEM skills that delegate entirely
   to an agent, the CE/wshobson answer is a command stub with `agent: aem-inspector` +
   `subtask: true`, which runs the skill in that subagent. Model-invoked skills still run inline.
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
   - **No prior art handles `context: fork`.** CE ignores it; wshobson sets `subtask: true` only
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
| C. Generic in-place loader of Claude plugin trees | harnesstap, oh-my-opencode | Third-party; would need our refs in braced form; young/opinionated. Worth a smoke test, not a dependency. |
| D. Copy skills only | claude-skills | Breaks §4.6 relative scripts and agents. Not enough. |

## 8. Open questions

- Does OpenCode follow symlinked skill dirs on v1 and v2? (wshobson symlinks `.opencode/` as a whole — likely yes.)
- Does `{env:VAR}` substitution work inside a local server's `command` array?
- How does a v2 HTTP-catalog skill expose its cache dir for scripts?
- Does the model reliably map `mcp__plugin_dx-aem_AEM__getNodeContent` → `AEM_getNodeContent` without a rewrite? Smoke test before deciding.
