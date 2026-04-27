# Subagent Improvements TODO

Improvements inspired by Claude Code's background agent patterns (async dispatch, task notifications, parallel execution). Goal: apply similar patterns where they benefit plugin coordinators and forked skills.

## Parallel dispatch for independent AEM phases

**Added:** 2026-03-27
**Problem:** `dx-agent-all` runs AEM phases sequentially even when they're independent. Phase 5+ (AEM Verify) and Phase 5++ (AEM FE Verify) have no data dependency — one checks dialog fields via AEM MCP, the other screenshots frontend via Chrome DevTools. Running them in parallel could cut AEM verification wall-clock time nearly in half.
**Scope:** `plugins/dx-core/skills/dx-agent-all/SKILL.md` — the DOT graph edges between Phase 5+, 5++, and 5a (Commit).
**Done-when:** `dx-agent-all` dispatches Phase 5+ and Phase 5++ as two `Skill()` calls in a single turn (Claude Code runs them concurrently). Both create their own Task. Coordinator waits for both to complete before proceeding to Commit. DOT graph updated to show parallel edges.

**Approach:**
- Change the sequential edge `Phase 5+ → Phase 5++` into two independent edges from `Phase 5 (AEM Baseline)` to both `Phase 5+` and `Phase 5++`
- Add a join node before `Phase 5a: Commit` that requires both to complete
- Each phase writes to separate output files (`aem-verify.md` vs `aem-fe-verify.md`) — no conflict
- Create a Task per parallel phase so user sees both as `in_progress`
- Fallback: if one fails, the other's result is still valid — report both independently
- Similarly evaluate if Phase 6.5 (Editorial Guide) and Phase 7 (Documentation) can run in parallel

## Error classification in Result envelope

**Added:** 2026-03-27
**Problem:** When a `context: fork` subagent fails, the Result envelope says `failure` with a text error, but the coordinator can't distinguish error types. An AEM MCP timeout (transient — retry might work) looks the same as a missing config field (permanent — tell user to fix). Claude Code's background agents get automatic retry for transient failures; our coordinators should do the same.
**Scope:** `plugins/dx-core/shared/subagent-contract.md`, all `context: fork` AEM skills (6 total), `plugins/dx-core/skills/dx-agent-all/SKILL.md`.
**Done-when:** Result envelope includes `- **Error-Class:** transient | permanent | config`. `dx-agent-all` retries `transient` failures once before reporting failure. Each AEM skill classifies MCP connection errors as `transient`, missing config as `config`, logic errors as `permanent`.

**Approach:**
- Extend the Result envelope in `subagent-contract.md` with `Error-Class` field
- Classification rules:
  - `transient`: MCP timeout, connection refused, HTTP 5xx, "tool not found" (server starting) — retry once
  - `permanent`: logic error, missing prerequisite file, assertion failure — no retry
  - `config`: missing config.yaml field, MCP server not in .mcp.json, env var not set — tell user what to configure
- Update `dx-agent-all` AEM phase nodes: on `transient`, wait 10s and retry Skill() once
- Update each AEM agent's instructions to emit the correct class

## Subagent context budget — worked examples

**Added:** 2026-03-27
**Problem:** `subagent-contract.md` says "summarize inputs >5KB before passing to fork" but provides no worked examples. Skills don't consistently follow this. `explain.md` can be 10-20KB; passing it raw to a `context: fork` skill wastes context window and reduces the subagent's working memory for actual tool calls.
**Scope:** `plugins/dx-core/shared/subagent-contract.md`, all 10 `context: fork` skills.
**Done-when:** `subagent-contract.md` has 2-3 worked examples showing: (a) what a >5KB input looks like, (b) what the summary should contain, (c) how to pass `summary + file path`. At least 3 high-traffic fork skills (`dx-step-verify`, `dx-step-build`, `aem-verify`) have explicit "Context Budget" sections.

**Approach:**
- Add worked examples to the contract:
  - `explain.md` (15KB): extract ticket ID, component name, acceptance criteria list, affected files → ~500 bytes + file path
  - `research.md` (12KB): extract key findings list, API references, constraints → ~400 bytes + file path
  - `implement.md` (8KB): extract step count, current step details only → ~300 bytes + file path
- Each fork skill gets a `## Context Budget` section listing: which files it reads, when to summarize, what to extract

## MCP tool discovery resilience — shared reference

**Added:** 2026-03-27
**Problem:** MCP-dependent agents (aem-inspector, aem-editorial-guide-capture, etc.) list tools in `tools:` frontmatter using full prefixed names. If the MCP server is slow to start in a `context: fork`, the agent gets "tool not found" on first call. Some agents have a prose fallback ("use ToolSearch if not found") but it's inconsistent. Claude Code's own agent system handles tool resolution automatically; our agents need a standardized manual fallback since they run as LLM prompts.
**Scope:** All MCP-dependent agents: `aem-inspector`, `aem-editorial-guide-capture`, `aem-fe-verifier`, `dx-figma-markup`, `dx-figma-styles` (5 agents).
**Done-when:** Shared reference `plugins/dx-core/shared/mcp-tool-resolution.md` exists. Every MCP-dependent agent includes a reference to it. The pattern is: (1) try direct call, (2) on "not found", run `ToolSearch("+<server>")`, (3) retry with discovered name, (4) if still fails, return Result with `error-class: config`.

**Approach:**
- Create `shared/mcp-tool-resolution.md` with the 3-step pattern + examples for AEM, Chrome DevTools, and Figma servers
- Add one line to each MCP agent: `Read shared/mcp-tool-resolution.md for MCP tool fallback if any tool call fails with "not found".`
- Pairs well with the error classification item — step 4 naturally produces `error-class: config`

## Coordinator output discipline — Tasks over text

**Added:** 2026-03-27
**Problem:** Coordinators sometimes echo the full Result envelope or write verbose phase summaries to the conversation. On Claude Code mobile app, Tasks render as a compact progress list — much cleaner than text walls. Claude Code's own background agents report via task-notifications, not conversation text. Coordinators should follow the same principle: use Task status as the primary progress channel.
**Scope:** All 5 coordinator skills: `dx-agent-all`, `dx-step-all`, `dx-bug-all`, `dx-figma-all`, `dx-pr-review-all`.
**Done-when:** Each coordinator has explicit instructions: "After a skill returns, update the Task (completed/failed + key metric). Only output conversation text for: (a) errors needing user input, (b) interactive mode checkpoints, (c) final pipeline summary." No coordinator echoes the Result envelope.

**Approach:**
- Add "Coordinator Output Rules" section to `subagent-contract.md`
- Rule: Task updates are the progress channel. Text output is for decisions only.
- Task subject pattern: `Phase N: <name>` → on completion update to `Phase N: <name> — PASS (key metric)` or `— FAIL (error)`
- `dx-agent-all` already uses TaskCreate (line 115) — ensure all coordinators follow the same pattern consistently
- Interactive mode checkpoints still use text (they're decision points)

## Coordinator observability — context-timeline hook

**Added:** 2026-04-27
**Problem:** When `dx-agent-all` (or any fan-out coordinator) dispatches 5+ `context: fork` subagents, there's no real-time view of which fork is running, how much of its context window each holds, or which one is the slowest. From the TUI you see Tasks updating, but you can't tell whether a fork is stuck on an MCP call vs. genuinely working. Debugging coordinator pipelines today means reading OTel logs after the fact.
**Scope:** `website/src/pages/setup/` (recommended hooks page), `plugins/dx-core/hooks/hooks.json` (optional pre-registration), `docs/reference/agent-catalog.md` and skill catalog notes for the 5 coordinator skills.
**Done-when:** The `monitoring/context-timeline` hook from `aitmpl.com` is documented as a recommended optional hook for users running coordinator skills. Install command (`npx claude-code-templates@latest --hook monitoring/context-timeline`) appears in the docs site. Decision recorded on whether to ship it pre-registered in `dx-core/hooks/hooks.json` or leave it user-installed.
**Approach:**
- Verify the hook composes cleanly with our existing branch-guard and Stop hooks (no `PreToolUse` / `Stop` matcher conflicts).
- If compatible, add a "Recommended hooks" section under the website setup pages — clearly marked as optional and external (`aitmpl.com` / `claude-code-templates`).
- Most useful for fan-out coordinators (`dx-agent-all`, `dx-step-all`, `dx-bug-all`, `dx-figma-all`, `dx-pr-review-all`); not needed for single-skill runs.
- Source: https://x.com/dani_avila7/status/2048486242321662189

## On-demand `/fork` slash command (complement to env var)

**Added:** 2026-04-27
**Problem:** TODO #84 covers the `CLAUDE_CODE_FORK_SUBAGENT=1` env var (session-wide fork mode), but Claude Code v2.1.117+ also exposes a `/fork` slash command for per-invocation forking. The env var is all-or-nothing; the slash command lets a coordinator fork only the subagents that actually need parent context (e.g., a verifier reading the plan) while keeping read-heavy ones (`dx-file-resolver`, `dx-doc-searcher`) on a clean blank context.
**Scope:** `docs/research/2026-04-25-platform-state-update.md` (current entry mentions only the env var), `plugins/dx-core/shared/subagent-contract.md` (forking guidance section).
**Done-when:** Platform-state doc lists both `CLAUDE_CODE_FORK_SUBAGENT=1` (session-wide) and `/fork` (per-invocation) with a one-line "when to use which". `subagent-contract.md` references `/fork` as the preferred surgical option for coordinators that mix context-heavy verifiers with stateless searchers.
**Approach:**
- Short addition to platform-state doc capturing the trade-off (env var = blanket session inheritance; `/fork` = surgical per-call inheritance, prompt cache shared with parent).
- When piloting #84, prefer `/fork` for `dx-step-verify` (which needs plan + research context) over the env-var approach.
- Source: https://x.com/dani_avila7/status/2048486242321662189
