# Skill & Agent Frontmatter Research — 2026-05-05

> **STATUS: UNCONFIRMED — requires verification in a new session.**
>
> This document captures findings from a planning session that was abandoned because too many assumptions turned out to be wrong, including assumptions in our own existing tip pages. **Do not act on the recommendations here without re-verifying every claim.** Treat this as a starting point for fresh research, not as a settled spec.

## What this document is

A snapshot of what we believed and what we doubted at the end of a brainstorming session about cleaning up `allowed-tools`, `model`, `effort`, and related YAML frontmatter fields across all SKILL.md and agent files in the four plugins.

The session was abandoned at the design stage when third-pass research uncovered that:

1. Our own tip pages on the docs website have **incorrect** information about Copilot CLI MCP tool naming (slashes vs parentheses).
2. Many existing skill `allowed-tools` values are likely **dead config in both platforms**, not just one.
3. The "fix direction" proposed in two earlier design iterations would have **broken Copilot CLI** if applied as planned.

A fresh research pass should verify every claim below by **direct test in actual Claude Code, Copilot CLI, and VS Code Chat sessions** before any code changes.

## What was wrong in earlier assumptions

### Wrong assumption #1 — "Lowercase tool names are dead config"

The audit initially treated `["read", "edit", "search", "write", "agent"]` in 59 skills as silently-ignored permission grants that needed to be replaced with PascalCase.

**Why it was wrong:** Our own website tip #14 (`allowed-tools-kill-the-permission-spam.md`) documents lowercase tool names as **Copilot CLI's permission format**. Replacing them with PascalCase would have removed the Copilot CLI pre-approval that those skills were actually relying on.

**What we actually know:** Lowercase tool names are intended for Copilot CLI. Whether they also work in Claude Code is **untested**.

### Wrong assumption #2 — "`ado/*` is invalid syntax, fix to `mcp__ado__*`"

The audit treated `"ado/*"` and `"atlassian/*"` as broken Claude Code syntax to be replaced with `mcp__ado__*` and `mcp__atlassian__*`.

**Why it was wrong:** Tip #29 (`mcp-tool-naming-three-formats-one-gotcha.md`) documents `ado/wit_get_work_item` as **Copilot CLI's MCP tool format**. So `ado/*` was intended as the Copilot wildcard.

**Why both were wrong anyway:** Late research suggested Copilot CLI's documented MCP syntax is actually **parentheses, not slashes** — `ado(wit_get_work_item)` or bare `ado` for all tools. If true, **even tip #29 is wrong**, and `ado/*` is dead config in *both* platforms.

**Confidence level:** LOW. The parentheses-vs-slashes finding came from one research pass against `docs.github.com/en/copilot/concepts/agents/about-copilot-cli` and was not reproduced or hand-tested.

### Wrong assumption #3 — "`paths:` and `arguments:` are safe to sweep across all skills"

A "Phase 4" in the original design proposed adopting `paths:` (auto-activation glob), `arguments:` (named positional), and `when_to_use:` (split from description) opportunistically across many skills.

**Why it was wrong:** Concrete examples were domain-incorrect. Example: `paths: "ui.frontend/**"` was proposed for `aem-fe-verify` based on the skill name, but `aem-fe-verify` actually verifies the **frontend of the deployed AEM website** (browser-side), not the `ui.frontend` codebase. A path-glob restriction would have broken auto-activation for the skill's actual use case.

**Lesson:** Adopting `paths:` requires per-skill domain knowledge. It is not a sweepable change.

### Wrong assumption #4 — "Agents are clean"

Initial audit said all 13 agents have correct frontmatter. This may be true for `tools:` casing, but agent files were not re-audited under the same standard as skills, and the same Copilot-vs-Claude split likely applies to them.

**Confidence:** UNVERIFIED.

## What is (probably) true — verify before acting

| Claim | Source | Verification status |
|---|---|---|
| Claude Code skill `allowed-tools` requires PascalCase tool names (`Read`, `Edit`, `Write`, `Grep`, `Glob`, `Bash`, `Agent`) | code.claude.com/docs/en/skills "Pre-approve tools for a skill" — uses `Bash(git add *) Bash(git commit *)` in example | Doc text confirmed; behavior with lowercase NOT tested |
| Claude Code MCP tools are referenced as `mcp__<server>__<tool>` (project-level) or `mcp__plugin_<plugin>_<server>__<tool>` (plugin-level) | CLAUDE.md table; matches our own working dx-hub skills | Confirmed by working examples in `plugins/dx-hub/skills/dx-hub-dispatch/SKILL.md` |
| Copilot CLI's built-in tool names are lowercase: `shell`/`bash`, `write`, `view`, `edit`, `grep`, `glob`, `task` | github/copilot-cli changelog (per research subagent) | NOT independently confirmed; no consolidated public list found |
| Copilot CLI MCP tool format is `SERVER(tool)` parentheses, not `SERVER/tool` slashes | docs.github.com/en/copilot/concepts/agents/about-copilot-cli (per research subagent) | NOT independently confirmed; **CONTRADICTS our own tip #29** |
| `search` is not a valid tool name in either Claude Code or Copilot CLI | Claude Code docs do not list it; Copilot CLI changelog shows `grep`/`glob` were added when ripgrep was bundled | Probably correct, but unverified by direct test |
| `agent` (lowercase) is not a valid Copilot CLI tool name; subagent invocation uses `task` | Copilot CLI changelog references "task" tool | Unverified |
| Skills are read by Copilot CLI from the same `SKILL.md` file as Claude Code (no separate manifest) | CLAUDE.md plugin structure; Copilot CLI v1.0.40+ documented to read plugin skills | Unverified by direct test |
| Unknown frontmatter fields are silently ignored across all platforms (Copilot CLI v1.0.10+) | Tip #14; agent skills open standard implicit | Mostly confirmed; VS Code Chat issue #14131 shows non-blocking warning for `allowed-tools` |
| Cross-platform `allowed-tools` works by listing both Claude Code and Copilot CLI formats in the same array | Tip #29 last paragraph: "Unrecognized names are silently ignored, so having both doesn't cause errors" | Plausible but not tested with the corrected Copilot syntax |

## Audit data (likely still accurate — values are observable from files)

These counts are mechanical observations from the codebase, not interpretations:

- **76 SKILL.md files** total across `plugins/{dx-core,dx-aem,dx-automation,dx-hub}/skills/`
- **13 agent files** total across `plugins/{dx-core,dx-aem}/agents/`
- **63 skills use `allowed-tools`**:
  - 59 use the lowercase pattern (`["read", "edit", "search", "write", "agent", ...]`)
  - 4 use PascalCase (all in `dx-hub`)
- **62 skills have no explicit `model:`** — inherit session model
- **2 skills have `model: sonnet` but no `effort:`** — `dx-council`, `dx-dor`
- **All 13 agents have explicit `model:`** and use PascalCase `tools:`

Unique `allowed-tools` patterns observed (15 distinct strings) — see `git grep "^allowed-tools" plugins/*/skills/*/SKILL.md | sort -u`.

## Skill frontmatter fields confirmed by Claude Code docs

From https://code.claude.com/docs/en/skills (frontmatter reference):

| Field | Required | Notes |
|---|---|---|
| `name` | No | Defaults to directory name; lowercase letters, numbers, hyphens, max 64 chars |
| `description` | Recommended | Capped at 1,536 chars combined with `when_to_use` |
| `when_to_use` | No | Appended to description |
| `argument-hint` | No | Autocomplete hint |
| `arguments` | No | Named positional args; maps to `$name` placeholders |
| `disable-model-invocation` | No | `true` = only user can invoke |
| `user-invocable` | No | `false` = hide from `/` menu |
| `allowed-tools` | No | Pre-approve tools — ACCEPTS SPACE-SEPARATED STRING OR YAML LIST |
| `model` | No | Same values as `/model`, or `inherit` |
| `effort` | No | `low`, `medium`, `high`, `xhigh`, `max` (depends on model) |
| `context` | No | `fork` to run in subagent |
| `agent` | No | Subagent type when `context: fork` |
| `hooks` | No | Skill-scoped lifecycle hooks |
| `paths` | No | Glob patterns to limit auto-activation |
| `shell` | No | `bash` (default) or `powershell` |

**These are Claude Code frontmatter fields.** Whether each is honored, ignored, or warned-on by Copilot CLI / VS Code Chat / Codex / Cursor / Gemini CLI is **mostly unverified** — see the cross-platform table below.

## Cross-platform support (unverified, partial)

Sourced from a research subagent against vendor docs. Treat as starting points, not facts.

| Field | Claude Code | Copilot CLI 1.0.40+ | VS Code Chat 1.118 | Codex CLI | Cursor | Gemini CLI |
|---|---|---|---|---|---|---|
| `name`, `description` | honors | honors | honors | honors | honors | honors |
| `argument-hint` | honors | honors | honors | unknown | unknown | unknown |
| `arguments` | honors | unknown | unknown | unknown | unknown | unknown |
| `when_to_use` | honors | unknown | unknown | unknown | unknown | unknown |
| `disable-model-invocation` | honors | unknown | honors | unknown | honors | unknown |
| `user-invocable` | honors | unknown | honors | unknown | unknown | unknown |
| `allowed-tools` | honors PascalCase + `mcp__server__tool` | honors lowercase + `server(tool)` per latest finding | warns ("not supported", non-blocking — issue #14131) | docs say "do not include other fields" | unknown | unknown |
| `model`, `effort` | honors | unknown | unknown | sidecar `agents/openai.yaml` | unknown | unknown |
| `paths` | honors | unknown | unknown | unknown | honors (also legacy `globs`) | unknown |
| `context: fork`, `agent:` | honors | unknown | honors (1.118+) | unknown | unknown | unknown |
| `hooks` | honors | uses `.github/hooks/` instead | honors | unknown | unknown | unknown |

## Open questions for the next research session

1. **What does Claude Code actually do with lowercase tool names in `allowed-tools`?** Does `["read", "edit"]` get silently dropped, or does Claude Code accept it as a permission rule string (like `Read` would)? Test by enabling a skill with only lowercase, then watching whether tool calls still trigger permission prompts.

2. **What does Copilot CLI actually do with PascalCase tool names?** Does `["Read", "Edit"]` get silently dropped (so the skill spams permission prompts in Copilot)? Test by running a skill with PascalCase-only `allowed-tools` in `copilot` CLI.

3. **Is the parentheses syntax `ado(wit_get_work_item)` actually correct for Copilot CLI?** Or is the slash syntax in our tip #29 also valid? Test both with a real MCP server.

4. **Does Copilot CLI require the bare server name (`ado`) for all-tool wildcards, or does it accept `ado(*)` or `ado/*`?** Untested.

5. **In Copilot CLI, is the registered MCP server name affected by being inside a plugin?** I.e., does a plugin's `.mcp.json` with `{"servers":{"ado":{...}}}` register as `ado` or as `dx-core.ado` or `plugin/ado`?

6. **For VS Code Chat 1.111+ skill-isolated subagents (1.118+):** how does the `tools:` field in agent frontmatter map to Copilot CLI's `allowed-tools`? Is it the same string format?

7. **Does our agent file `tools:` field follow the same format rules as skill `allowed-tools`?** Agent files use a comma-separated string (`tools: Read, Glob, Grep, Bash`) while skills use YAML lists or space-separated strings. Are these interchangeable?

8. **Codex CLI:** if we want to support Codex, do we need a sidecar `agents/openai.yaml` per skill, or is there another mechanism?

9. **Tier strategy enforcement:** if we add explicit `model:` to all 62 skills currently inheriting, what's the cost/perf impact? Some skills currently doing simple lookups inherit Sonnet (the typical session default) but should be Haiku per CLAUDE.md tier strategy. Need a per-skill audit, not a sweep.

## Approach options that were discussed and abandoned

For the record (and so the next session doesn't repeat the same dead ends):

**Option A — Single PR, mechanical fix only.**
Rejected when it became clear the "mechanical" fix would break Copilot CLI for 60 skills.

**Option B — Phase by concern (PascalCase fix → model tier → opportunistic fields → CI lint).**
The user accepted this phasing late in the session. Phase 1 was redefined as "drop `search` everywhere" (the only universally-confirmed dead value). Even Phase 1 was not started because the cross-platform syntax for the *replacement* is uncertain.

**Option C — Phase by plugin.**
Considered, rejected as redundant work for the same change.

**Option D — Comprehensive+** (PascalCase + explicit model + new field adoption + CI lint).
Initially accepted, then incrementally narrowed as each "safe sweep" turned out to need per-skill judgement.

## Recommendation for the next session

1. **Test before researching more docs.** The doc claims contradict each other and contradict our own tip pages. Empirical tests in actual Claude Code and Copilot CLI sessions will resolve faster than another doc round-trip.

2. **Start with one representative skill in each plugin.** Pick one (e.g., `dx-help`, `dx-pr-review`, `aem-init`, `auto-status`) and test what `allowed-tools` syntax actually pre-approves tools without a prompt. Document the test method and the observed behavior.

3. **Fix the tip pages first.** Whatever the verified syntax is, update `mcp-tool-naming-three-formats-one-gotcha.md` and `allowed-tools-kill-the-permission-spam.md` so they stop misleading future skill authors. This is a small, contained PR.

4. **Defer the bulk cleanup until after #2 and #3.** A 60-file change based on guesses about cross-platform behavior is exactly the kind of work that creates a worse mess than it cleans up.

5. **Re-audit agents under the same lens.** The audit said agents are clean, but it only checked PascalCase casing and presence of `model`. It did not check whether agent `tools:` uses the right MCP syntax for either platform.

## Files referenced

- Tip pages with potentially-incorrect info:
  - `website/src/content/tips/mcp-tool-naming-three-formats-one-gotcha.md`
  - `website/src/content/tips/allowed-tools-kill-the-permission-spam.md`
  - `website/src/content/tips/skill-frontmatter-the-yaml-that-controls-everythin.md`
  - `website/src/content/tips/writing-your-first-custom-skill.md`
  - `website/src/content/tips/what-is-an-agent-two-formats-one-concept.md`
- Existing platform research (also possibly affected by these findings):
  - `docs/research/2026-04-25-platform-state-update.md`
  - `docs/research/2026-05-01-platform-state-update.md`
- Working PascalCase reference (4 skills):
  - `plugins/dx-hub/skills/dx-hub-{config,dispatch,init,status}/SKILL.md`
- Working lowercase reference (59 skills):
  - All other `plugins/*/skills/*/SKILL.md` files
- Authoritative external docs to re-check:
  - https://code.claude.com/docs/en/skills (frontmatter reference)
  - https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills
  - https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli
  - https://agentskills.io/specification (open standard core)
  - https://github.com/microsoft/vscode-copilot-release/issues/14131 (VS Code `allowed-tools` warning)
