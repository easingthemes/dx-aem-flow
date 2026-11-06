# Claude Code vs Copilot CLI — state of agentic dev, 2026-11-06

Window: 2026-10-15 → 2026-11-06. Delta to [2026-10-15-upstream-sweep.md](2026-10-15-upstream-sweep.md),
plus a side-by-side comparison and a read of online opinion.

Sources marked **(official)** are the vendor changelog/blog. Everything else is secondary
(blogs, aggregators) and carried only as opinion or with a caveat.

## Versions

| Tool | Last intaken | Now | Source |
|---|---|---|---|
| Claude Code | v2.1.301 | **v2.1.318** (2026-11-03/04) | `anthropics/claude-code` CHANGELOG.md (official, no dates in file; date from aggregators) |
| Copilot CLI | v1.0.98 | **v1.0.106** (2026-11-05) | `github/copilot-cli` changelog.md (official) |

Coverage note: Claude Code 2.1.302–2.1.318 read verbatim. Copilot 1.0.106 read verbatim;
1.0.100–1.0.105 only via a summarised read — items from those versions are marked *(unverified)*.

## Verdict

Both tools are converging on the same primitive set — skills, custom agents/subagents, hooks,
plugins + marketplaces, MCP, headless `-p` — and both are now mostly in a **hardening phase**
(permissions, trust, exit codes, fail-closed hooks). Differences are less "feature X missing" and
more about *where* each is strong:

- **Claude Code** — deeper agent runtime: fork subagents, agent teams, background agents,
  workflows, mods (in-process JS hooks), richer hook events, effort tiers per subagent.
- **Copilot CLI** — multi-model (GPT, Gemini, Claude), GitHub-native (GitHub MCP built-in),
  cheaper entry, reads `.claude/skills` and `.agents/skills` so Claude-shaped content ports over.

For us: our dual-platform approach still holds. Nothing in this window breaks an existing
assumption in `CLAUDE.md`.

## Claude Code v2.1.302–v2.1.318 (official)

**Affects us**

| Change | Version | Note |
|---|---|---|
| Fork subagents on by default in `-p`, SDK, desktop, VS Code (`CLAUDE_CODE_FORK_SUBAGENT=0` off) | 2.1.302 | pipelines get forks now |
| Default permission mode `default` for `-p`/SDK on 3rd-party providers unless `--permission-mode auto` | 2.1.302 | check Bedrock/Vertex pipeline runs |
| `CLAUDE_CODE_SUBAGENT_EFFORT` — default effort for subagents | 2.1.316 | complements our `effort:` tiers |
| Subagents/teammates on other model use that model's effort | 2.1.317 | tier strategy behaves as documented |
| `onFailure: "block"` for Agent SDK hook callbacks | 2.1.317 | extends TODO-243 story to SDK |
| `claude -p` exits 1 on startup failure (was 0) and on lost transcript writes | 2.1.314 / 2.1.317 | pipelines now fail loudly — good |
| `-p` JSON has `credential_expires_at`, stderr warning 10 days before | 2.1.318 | pipeline auth monitoring |
| `permissions.blockWritesOutsideWorkingDirectories` | 2.1.314 | candidate for automation settings |
| `deniedMcpServers` URL entries block Anthropic-provided connectors too | 2.1.318 | |
| HTTP MCP calls no longer sent twice; retry only read-only/idempotent tools | 2.1.307 | AEM MCP writes safer |
| Subagents can use MCP servers that connect after they start | 2.1.311 | fixes late AEM/ADO MCP |
| `SubagentStop` fires once per subagent (was ~2/min) | 2.1.311 | our Stop guard ran too often before |
| `paths:` skills found after `cd` deeper into repo | 2.1.312 | |
| Hooks matching Bash also apply to Monitor shell commands (`Monitor(...)` if) | 2.1.314 | branch-guard coverage |
| PowerShell hooks block on exit 2 | 2.1.309 / 2.1.316 | Windows users of our hooks |

**Other**: `ultrathink` = `xhigh` on 5.5 models (2.1.311); Opus 4.8 fast mode removed 2026-11-30 (2.1.316);
`/auto-mode-setup` skill (2.1.304); marketplaces no longer re-clone on each refresh (2.1.302);
hook concurrency capped at 24 prompt/agent hooks per session (2.1.312).

## Copilot CLI v1.0.99–v1.0.106

**1.0.106 (official, verbatim)**

- Skills: `--add-dir` folders load skills from `.agents/skills` **and `.claude/skills`**; `~/` in
  `skillDirectories` resolves; warning for top-level `SKILL.md`.
- Agents: nested subagents can use session-allowed MCP tools; warn on stderr when `-p --agent`
  frontmatter has keys Copilot ignores (useful to lint our `.agent.md` templates); `/agent` no longer
  overrides explicit `--reasoning-effort`.
- Hooks: unreadable/invalid `.github/hooks` file reported at startup; BOM files load;
  `COPILOT_HOOK_DEPTH` env; `modifiedArgs: null` no longer fails.
- Plugins: rules with `alwaysApply: false` stay out of prompt until enabled; comma-string `globs` match;
  install reports ignored manifest fields; trusted non-git folders apply `enabledPlugins`.
- Trust: **prompt mode now warns when an untrusted folder skips repo hooks or workspace MCP** —
  addresses the silent-ignore trap behind our `GITHUB_COPILOT_PROMPT_MODE_*` docs (TODO-249).
- `-p`: interrupted runs exit non-zero; memory off in `-p` unless `--enable-memory`; autoUpdate off in CI.
- Models: GPT-6.1 Terra; managed "Fusion" tier.

**1.0.100–1.0.105 *(unverified, summary read)***: `--trust-folder` flag and plugin install from
GitHub links (1.0.100); workflow-subagent structured output, assisted-approval settings (1.0.101);
`git-subdir` marketplace sources (1.0.102); legacy `--remote` flags removed (1.0.103); "Fusion" model
default, Assisted Permissions GA (1.0.104/105).

## Side-by-side (Nov 2026)

| Area | Claude Code | Copilot CLI |
|---|---|---|
| Instructions | `CLAUDE.md` (+ `AGENTS.md` via `agents-md@builtin`, v2.1.277) | `AGENTS.md`, `.github/copilot-instructions.md`, `.github/instructions/` |
| Skills | `.claude/skills`, plugin `skills/`, `paths:`, `model:`/`effort:`, `context: fork` | `.github/skills`, `.agents/skills`, `.claude/skills`, plugin skills |
| Subagents | `.claude/agents/*.md`, fork subagents, background agents, agent teams, per-subagent effort | `.github/agents/*.agent.md`, nested subagents, `model:` fallback list, `reasoning-effort:` |
| Workflows / orchestration | Workflow tool (scripted multi-agent), agent teams, `/loop`, cloud scheduled tasks | autopilot, workflow subagents *(unverified)*, `/delegate` to Copilot coding agent |
| Hooks | ~35 events, `command/http/mcp_tool/prompt/agent`, `onFailure`, mods (in-process JS) | `.github/hooks/hooks.json` + plugin `hooks.json`, agent-frontmatter hooks (trusted folder) |
| Plugins | marketplaces, mods, `plugin validate/eval/test` | marketplaces (incl. `git-subdir`), installs from GH links |
| MCP | full spec 2026-07-28, connectors, managed allow/deny | GitHub MCP built in, sandboxed local MCP, Entra auth |
| Models | Anthropic only (API, Bedrock, Vertex, Foundry) | multi-vendor picker, BYOK, Fusion tier |
| Headless | `claude -p`, Agent SDK, self-hosted runners | `copilot -p`, ACP, Copilot coding agent |
| Eval tooling | `claude plugin eval` built in | none comparable |

## Ecosystem standards

- **Agent Skills** open spec (2025-12-18) — portable `SKILL.md`; adopted by both tools.
- **Agent Plugins 1.0** (2026-08-06, agent-plugins.org) — portable core is only **skills + MCP**;
  hooks, subagents, rules stay vendor-specific. Backers per secondary sources: OpenAI, Microsoft,
  GitHub, AWS, Cursor, Vercel, later Google. Anthropic's plugin format is *not* a launch client.
  *(secondary sources, partner list varies)*
- Implication for us: our cross-platform layer (skills portable, agents/hooks per-platform) matches
  where the standard drew the line. Watch whether Claude Code adopts Agent Plugins 1.0.

## Rating & opinion

- **Stack Overflow 2026 survey** (official, 2026-10-06): 65.9% use coding agents; among agent users
  **Claude Code 66%, GitHub Copilot 59%**. Claude Code rose from 41% → 55% between April pulse and
  main survey (different samples). Only 6.6% trust AI for important decisions.
- **Benchmarks**: no Copilot CLI entry on Terminal-Bench 2.0 found. Claude Code + Opus 4.8 ≈ 78.9%
  per one secondary source; harness choice moves scores by 15+ points (Opus 4.6: 58% in Claude Code
  harness vs 74.7% in another). Treat harness numbers as noisy.
- **General opinion** (blogs, mostly vendor-adjacent): Claude Code preferred for deep multi-file /
  autonomous work and subagents; Copilot for IDE flow, price, model choice and GitHub integration.
  Common pattern: teams use both. Little fresh Reddit/HN signal surfaced for Oct–Nov 2026.

## Candidate follow-ups (not yet in TODO.md)

1. Use Copilot 1.0.106 `-p --agent` stderr warning to lint our `.agent.md` templates for ignored keys.
2. Consider `permissions.blockWritesOutsideWorkingDirectories` + `CLAUDE_CODE_SUBAGENT_EFFORT` in
   dx-automation pipeline settings.
3. Re-check 3rd-party-provider pipelines after the 2.1.302 `-p` permission-mode default change.
4. Watch Agent Plugins 1.0 adoption by Claude Code.

## Sources

- https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md
- https://code.claude.com/docs/en/changelog
- https://raw.githubusercontent.com/github/copilot-cli/main/changelog.md
- https://github.com/github/copilot-cli/releases
- https://github.blog/changelog/2026-11-03-byok-and-enterprise-custom-models-in-the-copilot-usage-api/
- https://stackoverflow.blog/2026/10/06/the-results-of-the-2026-developer-survey-are-here/
- https://agenticskills.io/learn/what-are-agent-plugins
- https://andrew.ooo/answers/agent-plugins-vs-mcp-vs-agent-skills-explained-2026/
- https://nerdleveltech.com/agent-skills-portable-unmeasured
- https://paradev.com/compare/claude-code-vs-copilot-cli
- https://www.morphllm.com/comparisons/github-copilot-vs-claude-code
- https://www.metacto.com/blogs/comparing-claude-code-and-github-copilot-for-engineering-teams
- https://codex.danielvaughan.com/2026/04/09/harness-performance-terminal-bench/
- https://www.morphllm.com/ai-coding-agent
