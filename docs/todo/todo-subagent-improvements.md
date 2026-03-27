# Subagent Improvements TODO

## Coordinator waiting UX — use Tasks instead of polling

**Added:** 2026-03-27
**Problem:** When the main session launches background agents (via `Agent` tool with `run_in_background: true`), it should use Tasks to communicate status rather than outputting idle text like "Waiting for research to complete..." or "[Waiting for research...]". The correct pattern is: launch the agent, create a Task showing what's in progress, then proceed with independent work or wait silently for the task-notification. On Claude Code mobile app, Tasks render as a clean progress list — much better UX than text messages about waiting. The subagent's own tool activity (Read, Bash, etc.) is correctly hidden behind the collapsed activity summary, so that's not the problem — the main thread's idle waiting messages are.
**Scope:** `plugins/dx-core/shared/subagent-contract.md`, coordinator skills that could dispatch parallel agents, and any rules guiding Agent tool usage.
**Done-when:** `subagent-contract.md` has a "Background Agent Etiquette" section stating: (1) create a Task via `TaskCreate` before launching to show the user what's running, (2) do independent work or wait silently for task-notification — no "waiting for..." text output, (3) mark Task complete when notification arrives and summarize results.

**Approach:**
- Add "Background Agent Etiquette" section to `subagent-contract.md`
- Key rules: use `TaskCreate` with `in_progress` for each launched agent, no idle "waiting" text — Task status IS the waiting indicator, update task on notification
- This works well on mobile (Claude Code app) where Tasks show as a clean progress list
- Consider also adding this to `plugins/dx-core/rules/` as a default rule

## Parallel subagent dispatch for independent phases

**Added:** 2026-03-27
**Problem:** `dx-agent-all` runs all phases sequentially even when some are independent. Phase 5+ (AEM Baseline via `/aem-snapshot`) and Phase 4's completion are independent. Phase 6+ (AEM Verification) and Phase 6++ (AEM FE Verification) are independent of each other. Running them sequentially adds unnecessary wall-clock time.
**Scope:** `plugins/dx-core/skills/dx-agent-all/SKILL.md` phases 5/5+, 6+/6++.
**Done-when:** `dx-agent-all` dispatches independent phase pairs concurrently using multiple `Skill()` calls in a single turn. Each phase still creates its own Task for progress visibility. Progress counter uses shared "slot" for parallel phases (e.g., "Phases 6+/6++ (9-10/12)").

**Approach:**
- After Phase 4 (Build) passes, dispatch Phase 5+ (AEM Baseline) alongside Phase 5 if both apply
- After Phase 6 (Code Review) passes, dispatch Phase 6+ (AEM Verify) and Phase 6++ (AEM FE Verify) in parallel
- Each parallel skill returns a Result envelope — coordinator collects both before proceeding
- Create a Task per parallel phase so user sees both as `in_progress`
- Risk: file overlap between parallel phases. Mitigate by confirming no shared output files (AEM Baseline writes `aem-baseline.md`, AEM Verify writes `aem-verify.md` — no overlap)

## Subagent context budget enforcement

**Added:** 2026-03-27
**Problem:** `subagent-contract.md` has "Pre-Dispatch Context Hygiene" (>5KB = summarize first), but skills don't consistently follow it. Large spec files (`explain.md` can be 10-20KB) sometimes get passed raw, bloating the forked context and reducing effective working memory. This is especially problematic for `context: fork` skills.
**Scope:** `plugins/dx-core/shared/subagent-contract.md`, all 10 `context: fork` skills across dx-core and dx-aem.
**Done-when:** Each `context: fork` skill has explicit "Context Budget" instructions specifying what to summarize vs pass raw. `subagent-contract.md` has a worked example showing the summarization pattern.

**Approach:**
- Audit each `context: fork` skill for what data it reads/passes
- Add per-skill instructions: (a) what to read, (b) max size before summarizing, (c) what fields to extract
- Worked example in contract: "explain.md is 15KB — extract: ticket ID, acceptance criteria list, component name, affected files; pass as 500-byte summary + file path"

## Subagent error classification in Result envelope

**Added:** 2026-03-27
**Problem:** When a `context: fork` subagent fails (AEM MCP unreachable, Chrome DevTools not running), the Result envelope says `failure` but doesn't classify the error. The coordinator can't distinguish transient (MCP timeout — retry) from permanent (logic error — don't retry) from config (server not configured — tell user). Currently `dx-step-all` has self-healing for code failures, but AEM skills just report failure with no retry.
**Scope:** All `context: fork` AEM skills (6), `plugins/dx-core/shared/subagent-contract.md`, `plugins/dx-core/skills/dx-agent-all/SKILL.md`.
**Done-when:** Result envelope includes `- **Error-Class:** transient | permanent | config`. Coordinators retry `transient` once. AEM skills classify MCP connection failures as `transient`, missing config as `config`, logic errors as `permanent`.

**Approach:**
- Extend Result envelope with `Error-Class` field
- `transient`: MCP timeout, connection refused, 5xx — coordinator retries once
- `permanent`: logic error, missing prerequisite, assertion — no retry
- `config`: missing config field, MCP not configured — tell user what to fix
- Update `dx-agent-all` to handle retries for transient AEM failures
- Update each AEM agent's instructions to classify errors

## MCP tool discovery resilience pattern

**Added:** 2026-03-27
**Problem:** Agent definitions list MCP tools using full prefixed names in `tools:` frontmatter. In `context: fork`, tool availability depends on MCP server startup timing. If the server is slow to start, the agent hits "tool not found". The fallback (`ToolSearch("+AEM")`) exists as prose in some agents but isn't standardized.
**Scope:** All MCP-dependent agents: `aem-inspector`, `aem-editorial-guide-capture`, `aem-fe-verifier`, `dx-figma-markup`, `dx-figma-styles`.
**Done-when:** A shared reference `plugins/dx-core/shared/mcp-tool-resolution.md` exists with the 3-step pattern: (1) try direct call, (2) `ToolSearch("+<server>")` on failure, (3) classify as `config` error if still not found. Every MCP-dependent agent references this file.

**Approach:**
- Create `shared/mcp-tool-resolution.md` with the standardized pattern
- Each agent includes a reference to it
- Pattern: try tool → "not found" → ToolSearch → retry → fail with `error-class: config`

## Coordinator output discipline — summarize don't echo

**Added:** 2026-03-27
**Problem:** When a subagent returns its Result envelope, coordinators sometimes echo it verbatim. On mobile (Claude Code app), this creates long messages the user has to scroll through. The Result envelope is for coordinator logic, not the user. Users need a 1-line status per phase — which Task updates already provide.
**Scope:** All 5 coordinator skills: `dx-agent-all`, `dx-step-all`, `dx-bug-all`, `dx-figma-all`, `dx-pr-review-all`.
**Done-when:** Each coordinator has explicit instructions: "After a skill returns, update the Task status. Do NOT echo the Result envelope. Only output text if there's a decision point or error requiring user input."

**Approach:**
- Add "Coordinator Output Rules" to `subagent-contract.md`
- Pattern: update Task to `completed` with key metric, e.g. "Build — PASS (42s)" or "Code Review — 2 issues fixed"
- Only output text for: errors requiring user action, decision points, final pipeline summary
- This keeps mobile UX clean — user sees Task progress list, not walls of text

## Task-based progress for long-running subagent phases

**Added:** 2026-03-27
**Problem:** For long-running `Skill()` calls (build 5+ min, code review 3+ min), the coordinator blocks and the user sees just a spinning cursor. The coordinator creates a Task before dispatching, which helps, but the Task shows no intermediate progress (just "in_progress" until done).
**Scope:** `plugins/dx-core/skills/dx-agent-all/SKILL.md`, `plugins/dx-core/skills/dx-step-all/SKILL.md`.
**Done-when:** Coordinators create descriptive Tasks before each phase dispatch (e.g., "Building project — mvn clean install") so mobile users see what's happening. Subagent skills update their own Tasks for internal progress (e.g., "Fix attempt 2/3 for lint errors"). The combination gives users a two-level progress view.

**Approach:**
- **Coordinator level:** `TaskCreate` with descriptive subject before each `Skill()` call. Mark `completed` when skill returns.
- **Skill level:** `context: fork` skills already run in isolation. They can use `TaskCreate`/`TaskUpdate` for their own internal progress (build attempts, review cycles, fix loops).
- This is the existing pattern (item #13 solved visual separation via TaskCreate) — just ensure it's applied consistently to ALL coordinator phases and all forked skills.
- No new infrastructure needed — just skill file updates.
