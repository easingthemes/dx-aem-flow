# Ruflo-Inspired Improvements

> Ideas extracted from [ruvnet/ruflo](https://github.com/ruvnet/ruflo) (claude-flow v3.5.48) — an enterprise multi-agent orchestration framework built on Claude Code plugins. Assessed for practical value in dx-aem-flow context.

## PreCompact Hook for Workflow State Preservation

**Added:** 2026-03-26
**Problem:** When Claude Code compacts context during long sessions, critical dx workflow state is lost — the active ticket ID, current spec directory, config path, which step of a multi-step plan the user is on. Users have to re-explain context after compaction. Ruflo solves this with a PreCompact hook that injects a "golden rules" reminder + active state summary before compaction runs.
**Scope:** `plugins/dx-dev-experience/hooks/hooks.json` — add a `PreCompact` event handler. Needs a small shell script that reads `.ai/config.yaml` and recent spec directory to build a context summary.
**Done-when:** `grep -q "PreCompact" plugins/dx-dev-experience/hooks/hooks.json` returns 0, and a long session with compaction retains awareness of the active ticket/spec directory.
**Approach:**
- Add `PreCompact` hook to dx-core's `hooks.json`
- Script reads: config.yaml (project name, base branch, build command), latest spec dir from `.ai/specs/`, and any active plan file
- Output a terse summary (under 500 tokens) injected into compacted context
- Also inject the "always read config, never hardcode" golden rule
- Consider adding to Copilot CLI hooks too (`.github/hooks/hooks.json`) once supported

## Multi-Lens PR Review Decomposition

**Added:** 2026-03-26
**Problem:** `dx-pr-review` runs a single monolithic review pass. Ruflo decomposes code review into 5 parallel specialized lenses: security, performance, style/conventions, architecture, and accessibility. This catches category-specific issues that a generalist pass misses — especially security and accessibility, which require different mental models than general code quality.
**Scope:** `plugins/dx-dev-experience/skills/dx-pr-review/SKILL.md`, potentially new agents in `plugins/dx-dev-experience/agents/`.
**Done-when:** `dx-pr-review` produces review output with clearly separated sections for at least: security, performance, architecture, and conventions — either via parallel subagents or structured prompt sections.
**Approach:**
- **Option A (lightweight):** Restructure `dx-pr-review` prompt to explicitly require separate analysis passes per lens within the same agent. No new agents needed. Less thorough but simpler.
- **Option B (parallel agents):** Create specialized review agents (`dx-security-reviewer`, `dx-perf-reviewer`, etc.) spawned in parallel by the review skill. More thorough but adds agent count.
- Option A is recommended first — move to B only if quality isn't sufficient
- The dx-automation `auto-pr-review` pipeline should also benefit from whichever approach is chosen
- Accessibility lens should use axe MCP where available

## Cross-Session Pattern Memory

**Added:** 2026-03-26
**Problem:** Every dx session starts from scratch. When a developer finds that a particular test strategy, component pattern, or debugging approach works well for their project, that knowledge is lost. Ruflo's "ultralearn" background worker extracts patterns from successful completions and stores them for retrieval. We don't need neural networks or vector search — simple Markdown files with grep-friendly tags would work.
**Scope:** New concept: `.ai/patterns/` directory. Skills like `dx-step`, `dx-step-fix`, `dx-bug-fix` would write patterns on success. Skills like `dx-plan`, `dx-step` would read patterns for context.
**Done-when:** A directory convention exists, at least one skill writes patterns on successful completion, and at least one skill reads patterns when starting work.
**Approach:**
- Define a simple pattern format: `## {title}\n**Tags:** component, test, aem\n**Context:** {when this applies}\n**Pattern:** {what worked}\n**Source:** {ticket-id, date}`
- `dx-step-verify` (on success) or `dx-step` (on completion) appends to `.ai/patterns/{topic}.md`
- `dx-plan` reads matching patterns when planning similar work
- Keep it opt-in via config.yaml flag (`patterns.enabled: true`)
- No vector search needed — grep by tags is sufficient at project scale
- Consider `.gitignore`-ing patterns (they're developer-specific) vs committing (team knowledge)

## Concurrent Agent Work-Ownership (Claims)

**Added:** 2026-03-26
**Problem:** As dx-automation scales (DoR checker, DoD checker, PR reviewer, BugFix agent all running as Lambda-triggered pipelines), multiple agents could modify the same files concurrently — especially spec files in `.ai/specs/`. Ruflo has a "claims" system for work ownership with load balancing. For dx-automation, a simpler lock-file mechanism would prevent conflicts.
**Scope:** `plugins/dx-automation/` — applies to all auto-* skills that write to spec directories or modify code.
**Done-when:** Automation agents check for and create lock files before modifying shared resources, and release them on completion.
**Approach:**
- Use `.ai/specs/{id}/.lock` files with agent name + timestamp
- Automation agents check for lock before writing; if locked by another agent, skip or queue
- Lock expires after configurable timeout (default: 30 minutes)
- Simple shell-based implementation in a shared script
- This only matters for dx-automation pipelines — interactive dx-core sessions don't need it (single user)

## Intelligent Model Tier Routing

**Added:** 2026-03-26
**Problem:** dx currently assigns model tiers statically in agent/skill frontmatter (Opus for deep reasoning, Sonnet for execution, Haiku for lookups). Ruflo routes dynamically based on detected task complexity. For dx, the main opportunity is within skills that handle variable-complexity work — e.g., `dx-step` could use Haiku for a simple CSS change but Sonnet for a complex refactor.
**Scope:** Agent/skill frontmatter `model:` field, potentially a routing helper.
**Done-when:** At least one skill demonstrates dynamic model selection based on task characteristics.
**Approach:**
- **Not recommended for now.** Static tier assignment in frontmatter is working well and is predictable. The cost savings from dynamic routing don't justify the complexity and unpredictability.
- Revisit if: (a) Claude Code adds native complexity-based routing, or (b) token costs become a significant concern for specific customers.
- If pursued: start with `dx-step` only — classify by diff size, file count, and language to pick Haiku vs Sonnet.

## Background Worker Concept (Deferred)

**Added:** 2026-03-26
**Problem:** Ruflo runs 12 background workers (ultralearn, audit, testgaps, etc.) alongside the main session. Some are interesting: `testgaps` identifies untested code paths, `audit` tracks security concerns, `document` generates docs for changed code. However, Claude Code doesn't support true background agent execution — ruflo's "workers" are hook-triggered, not concurrent processes.
**Scope:** Conceptual — no immediate implementation target.
**Done-when:** N/A — this is a "watch" item for when Claude Code adds background agent support.
**Approach:**
- Most valuable worker concepts: test gap analysis, security audit on changed files
- These could be implemented today as PostToolUse hooks on Edit/Write — but the overhead of running analysis on every file save would be excessive
- Better approach: integrate into `dx-step-verify` (runs once per step completion) or `dx-pr-review` (runs once per PR)
- Already partially covered: `dx-step-verify` validates implementation, `dx-pr-review` checks quality
- Watch for Claude Code daemon/background-agent features
