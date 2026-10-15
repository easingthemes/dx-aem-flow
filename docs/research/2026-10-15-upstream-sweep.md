# Upstream + best-practice sweep — 2026-10-15

Window: 2026-09-29 → 2026-10-15. Two parallel lanes: (1) official vendor sources —
Claude Code and Copilot CLI changelogs, ADO MCP and Playwright MCP releases, Adobe docs;
(2) general best practice. Deduped against `docs/todo/TODO.md` (#1–#242).
Delta to [2026-09-29-upstream-sweep.md](2026-09-29-upstream-sweep.md).

Every claim below is from an official changelog or release page unless marked otherwise.
Aggregator sites were used only to cross-check, and nothing from them is carried without
an official source.

## Versions

| Dependency | Last intaken | Now | Date |
|---|---|---|---|
| Claude Code | v2.1.285 | **v2.1.301** | 2026-10-14 |
| Copilot CLI | v1.0.89 | **v1.0.98** | 2026-10-14 |
| `@azure-devops/mcp` | v2.10.0 | v2.10.0 (no new release) | 2026-09-09 |
| `@playwright/mcp` | 0.0.75 (our pin) | 0.0.83 (no new release) | 2026-09-28 |

Models: Claude Haiku 5.5 is the default Haiku in Claude Code since v2.1.293, and in Copilot's
picker since v1.0.94. Copilot removed retired models from the picker in v1.0.92 — #230's
deadline is 2026-10-19.

## Verdict

Nothing structural moved. The release batch is mostly hardening, and two changes touch
our safety story directly: hooks can now fail closed (`onFailure: "block"`), and the MCP
protocol default changed under our own AEM MCP server. The backlog is the bigger problem
than upstream: #221 (a false statement in `CLAUDE.md`) and #230 (deadline in 4 days)
are both still open from the last sweep.

## Claude Code v2.1.286–v2.1.301

**Affects us directly**

| Change | Version | Where it lands |
|---|---|---|
| `onFailure: "block"` for command/HTTP hooks — a hook that can't start, times out or exits oddly now blocks | 2.1.295 | **#243** (new) |
| PreToolUse / PermissionRequest hooks now block (not skip) when matching fails | 2.1.288 | #243 |
| Skill `allowed-tools` and `effort` were dropped before the response ended, denying Bash in `-p` runs | fixed 2.1.296 | #247 note; pipelines install the Agent SDK unpinned, so they already get the fix |
| Dangerous `rm` inside `bash -c` now prompts | 2.1.288 | #223 (makes it more likely) |
| MCP protocol `2026-07-28` is the default for stdio servers and connectors; MCP no longer follows redirects; `MCP_PROTOCOL_NEGOTIATION=legacy` opts out | 2.1.292 / 2.1.295 / 2.1.299 | **#244** (new) |
| MCP allow rules reach only the server they name (`mcp__a` no longer covers `a__b`); agent `tools:` lists take only the named server's tools | 2.1.299 | checked: our `mcp__ado__*` and fully-named tools are unaffected |
| Path-scoped `.claude/rules` and nested `CLAUDE.md` load on Write/Edit and on `cat`/`grep`/`sed` views too | 2.1.288 / 2.1.293 | benefit, no action |
| Haiku 5.5 default Haiku | 2.1.293 | #222 (extend to the Haiku tier) |

**New, not yet used**

- **Mods** (2.1.287): a plugin with a JS/TS hooks module that runs inside Claude Code's process. Claude Code only — Copilot has no equivalent → **#246** (watch).
- CI tooling: `claude plugin test` fails on hook `expect` (2.1.292); `plugin validate` lists gating hooks (`gatingHooks` in `--json`, 2.1.290); `plugin eval --disallow-tools`, and API-refused eval runs score 0 + exit 1 (2.1.299) → #180 / #206.
- `--bare` (2.1.286): only CLI-named MCP servers, no system reminders, no background tasks → #200.
- Subagents: `effort` param on the Agent tool (2.1.292), `autoCompactWindow` frontmatter (2.1.296), `CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL` (2.1.296), max 32 preloaded skills (2.1.295), names ≤256 chars (2.1.292).
- MCP tool description cap 2,048 → 4,096 chars (2.1.296).
- "`verify` skills are run before commits, except docs-only and tests-only changes" (2.1.286) — unclear whether this matches our `dx-step-verify` by name → #247.

## Copilot CLI v1.0.90–v1.0.98

- **Agent-scoped declarative hooks for custom agents** (1.0.97) → **#245** (new).
- Skills and agents from `--plugin-dir` now reach autocomplete and invocation; resumed sessions no longer rebuild plugin hooks from the wrong plugin list (1.0.97) → #229 re-test.
- Autopilot now denies a preToolUse `ask` instead of waiting on a dialog nobody watches (1.0.97).
- MCP config changes apply between turns without a restart (1.0.93).
- Nothing on `.claude/rules` or AGENTS.md — #227 stays open.

## Ecosystem

- **ADO MCP:** no release since v2.10.0. `pipeline-agent.js` still runs it unpinned → #233.
- **Playwright MCP:** 0.0.83 still latest; we pin 0.0.75 → #234. New: `browser_find` takes `filename` to save matches to a file instead of the response.
- **Adobe Content MCP Servers** (AEM CS 2026.1.0, read-only + read-write) → already #235.
- **Codex CLI:** extension hooks for model requests (0.158.0), OTel events for skill invocation, bundled plugin-creator skill removed (0.159.0). Low relevance.

## Best practice (lane 2)

No new substance. The consensus is unchanged and already reflected here: keep AGENTS.md
short and project-specific; skills do not trigger reliably, so static context beats them
for must-have rules; build eval tasks from observed failures, against a clean baseline
(LangChain). One paper worth reading for #113 / #238: *From Anatomy to Smells: An Empirical
Study of SKILL.md in Agent Skills* (arXiv 2607.01456).

**Rejected as recycled or empty:**

- "Azure DevOps MCP October release" results are the **October 2025** GA.
- "Anthropic introduces Agent Skills" coverage is the **October 2025** launch.
- The ETH study on LLM-written AGENTS.md files hurting task success is re-circulated as new; it was discussed on HN earlier in 2026, and its figures were not checked against the paper.
- "N plugins every developer should install" listicles and "Claude news October 2026" newsletters carry no release information.
- Aggregators disagree with the official changelog (one lists 2.1.300 as latest; official is 2.1.301). Two aggregator claims could not be confirmed: "plugin evals gained reproducible reports on 10-11" and "forked skills return results to workflow subagents in 2.1.299".

## New TODOs

| # | Item | Prio |
|---|---|---|
| 243 | Fail-closed hooks — `onFailure: "block"` on branch-guard | High |
| 244 | Test our AEM MCP server against MCP protocol `2026-07-28` | Medium |
| 245 | Copilot agent-scoped hooks for `.github/agents` | Medium |
| 246 | Claude Code Mods (watch) | Low |
| 247 | Small v2.1.286–v2.1.301 notes for existing items | Low |

## Overdue from earlier sweeps

#230 (deadline 2026-10-19), #221 (`CLAUDE.md:117` still false), #233 / #234 (pins),
#222 (now also Haiku 5.5), #173 / #174 (still one eval suite).

## Sources

- https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md
- https://code.claude.com/docs/en/changelog
- https://code.claude.com/docs/en/plugins/mods/create
- https://github.com/github/copilot-cli/blob/main/changelog.md
- https://github.com/microsoft/azure-devops-mcp/releases
- https://github.com/microsoft/playwright-mcp/releases
- https://experienceleague.adobe.com/en/docs/experience-manager-cloud-service/content/release-notes/release-notes/2026/2026-1-0
- https://developers.openai.com/codex/learn/best-practices
- https://www.langchain.com/blog/evaluating-skills
- https://arxiv.org/pdf/2607.01456
- https://news.ycombinator.com/item?id=47034087
- Aggregators, cross-check only: https://www.gradually.ai/en/changelogs/claude-code/, https://www.havoptic.com/tools/claude-code
