# TODO: Copilot CLI Compatibility

Background: Copilot CLI (GA Feb 2026) reads plugins from `.claude-plugin/`. Full analysis in `docs/architecture/cross-agents.md`, `docs/authoring/technical-reference.md` §12–14, and `internal/learnings/2026-03-22-cross-platform-gap-tracker.md`.

**What already works:** `plugin.json`, `marketplace.json`, SKILL.md, `.mcp.json`, hooks (`hooks.json` serves both), `COPILOT_CUSTOM_INSTRUCTIONS_DIRS`, ToolSearch MCP discovery, `applyTo` arrays, plugin discovery via `--plugin-dir`, Open Plugins spec, Skill-to-Skill invocation (verified 2026-03-22).

**Latest version:** v1.0.12 (2026-03-26). Key additions since v1.0.10:
- v1.0.11: Hook merging across multiple plugins, `additionalContext` injection for SessionStart, `~/.agents/skills/` personal skill directory, monorepo skill discovery.
- v1.0.12: `CLAUDE_PROJECT_DIR` and `CLAUDE_PLUGIN_DATA` env vars in plugin hooks, `{{project_dir}}` and `{{plugin_data_dir}}` template variables, workspace MCP servers loaded correctly.

**Claude Code-only hook fields (silently ignored by Copilot CLI):** `if`, `async`, `statusMessage`, HTTP/prompt/agent hook types. Safe to use in plugin hooks — Copilot CLI ignores unknown JSON fields.

## MCP Tool Prefix Normalization

**Added:** 2026-03-22 (rewritten — was "MCP tool names in agent frontmatter")
**Problem:** Skill files use Claude Code-specific `mcp__ado__`, `mcp__atlassian__`, `mcp__plugin_*__` prefixes for MCP tool names (213 occurrences). Copilot CLI and VS Code Chat register bare names (`wit_get_work_item`). However, this is **not a functional blocker** — the LLM reads prefixed names as prose hints and maps them to the actual registered tool names on each platform. Confirmed: `/dx-req` ran all 5 phases on Copilot CLI (2026-03-22), calling bare-name tools successfully despite skills referencing prefixed names.
**Scope:** 213 occurrences across 38 skill files:
- `mcp__ado__` — 84 occurrences in 22 files
- `mcp__atlassian__` — 44 occurrences in 12 files
- `mcp__plugin_*__` — 85 occurrences in 16 files (AEM, Chrome DevTools, Figma, axe)
Also: `plugins/dx-core/shared/*.md` reference files, `docs/reference/agent-catalog.md`
**Done-when:** `grep -rn "mcp__ado__\|mcp__atlassian__\|mcp__plugin_" plugins/*/skills/*/SKILL.md plugins/*/shared/*.md | wc -l` returns 0.
**Approach:** Cosmetic cleanup — normalize to bare tool names for consistency across platforms. Low priority since the LLM resolves either format. Risk: Claude Code may need `ToolSearch` to resolve bare names — test on one skill first.
**Why not a blocker:** MCP tool names in SKILL.md are prose instructions to the LLM, not literal function calls. The LLM maps `mcp__ado__wit_get_work_item` → `wit_get_work_item` when the actual tool registry uses bare names (Copilot CLI, VS Code Chat), and uses the full prefix when the registry has it (Claude Code).
**Evidence:** `internal/learnings/2026-03-22-copilot-cli-compatibility.md` §2, `internal/learnings/2026-03-22-skill-simplification-refactor.md` (Copilot CLI PASS — all 5 phases)

## Agent Format Divergence

**Added:** 2026-03-03
**Problem:** Claude Code agents (`agents/*.md`) use PascalCase tools and `model:` alias. Copilot agents (`templates/agents/*.agent.md`) use lowercase tools and `handoffs:`. These are maintained as dual files. `handoffs:` is parsed but does NOT execute in Copilot CLI — agents can't actually call other agents.
**Scope:** `plugins/dx-core/agents/*.md` (12 files) AND `plugins/dx-core/templates/agents/*.agent.md.template` (15 files). Also `plugins/dx-aem/agents/` and `plugins/dx-aem/templates/agents/`. Install script: `plugins/dx-core/data/lib/install-copilot-agents.sh`.
**Done-when:** Either (a) single-source agent files work on both platforms (check: `ls plugins/dx-core/templates/agents/` returns empty or doesn't exist), OR (b) Copilot CLI `handoffs:` works (check: GitHub issue [#561](https://github.com/github/copilot-cli/issues/561) is closed).
**Approach:** Watch for #561 resolution AND VS Code/Copilot CLI supporting Claude-format tool names natively. Current: `install-copilot-agents.sh` copies templates → `.github/agents/` with post-copy transforms (editFiles→edit, chrome-devtools→chrome-devtools-mcp, allowed-tools injection).

## Shared Path Resolution

**Added:** 2026-03-22
**Problem:** Copilot CLI looks for `shared/*.md` reference files at `~/.copilot/installed-plugins/.../skills/shared/` instead of the correct `~/.copilot/installed-plugins/.../shared/`. This means `shared/provider-config.md`, `shared/external-content-safety.md`, `shared/hub-dispatch.md` all fail to load. Non-blocking (skills continue without them) but means provider detection, safety rules, and hub dispatch logic are silently skipped.
**Scope:** `plugins/dx-core/shared/` (all reference files) — currently: `provider-config.md`, `external-content-safety.md`, `hub-dispatch.md`, `pr-review.md`, `pr-answer.md`.
**Done-when:** Either (a) Copilot CLI fixes plugin path resolution for `shared/`, OR (b) critical logic from reference files is moved into main SKILL.md bodies (check: `grep -rn "Read.*shared/" plugins/*/skills/*/SKILL.md | wc -l` — if zero, all critical logic has been inlined).
**Approach:** May be upstream Copilot CLI bug. Workaround: inline critical reference file logic (like DoR dedup checks) into SKILL.md. Non-critical context (provider detection) can remain in reference files.
**Evidence:** `internal/learnings/2026-03-22-skill-simplification-refactor.md` bug #2

## Attachment Download

**Added:** 2026-03-22
**Problem:** Copilot CLI ignores the skill instruction "preserve URLs as-is" and tries to download ADO image attachments via HTTP. Gets HTML login page instead of images (saved as garbage `.bin` files in spec directory). Claude Code correctly skips downloads.
**Scope:** `plugins/dx-core/skills/dx-req/SKILL.md` — Phase 1 (fetch work item) where attachments are processed.
**Done-when:** `grep -n "Do NOT download\|NEVER download\|preserve.*attachment.*URL" plugins/dx-core/skills/dx-req/SKILL.md` returns a match with explicit "Do NOT download attachments" instruction.
**Approach:** Add stronger instruction to SKILL.md Phase 1: "Do NOT download attachments — ADO requires browser auth. Preserve `<img>` URLs as-is in the raw story." Current wording is too soft for Copilot CLI to follow.
**Evidence:** `internal/learnings/2026-03-22-skill-simplification-refactor.md` bug #3

## Hooks Porting

**Added:** 2026-03-22
**Problem:** 5 plugin hooks are not ported to Copilot CLI's `.github/hooks/hooks.json`. Only branch guard was deployed (dx-init step 9i). The remaining hooks (SessionStart, Stop guard, 2× Figma PostToolUse, Edit PostToolUse) only work in Claude Code.
**Scope:**
- Source: `plugins/dx-core/hooks/hooks.json` (all hooks defined here)
- Target: `plugins/dx-core/templates/hooks/` or dx-init step that copies to `.github/hooks/`
- Constraint: Copilot CLI 1.0.10 supports PreToolUse, PostToolUse, SessionStart, PreCompact, SubagentStart — but **no Stop event**
**Done-when:** `grep -c "SessionStart\|PostToolUse" .github/hooks/hooks.json` (in a consumer repo after `/dx-init`) returns ≥3 (SessionStart + 2 Figma PostToolUse at minimum). Stop guard cannot be ported until Copilot CLI adds Stop event support.
**Approach:**
1. Port SessionStart hook (config validation) — Copilot CLI supports the event
2. Port Figma PostToolUse hooks — Copilot CLI supports PostToolUse
3. Port Edit PostToolUse hook — same
4. Stop guard: blocked until Copilot CLI adds Stop event
**Evidence:** `internal/learnings/2026-03-22-cross-platform-gap-tracker.md` GAP 6

## Project MCP Discovery

**Added:** 2026-03-22
**Problem:** Copilot CLI does NOT read project-level `.mcp.json` at startup. Plugin MCP servers (figma, axe, AEM, chrome-devtools) load correctly, but project-specific servers (ADO, Atlassian) are invisible. This blocks all ADO/Jira operations in Copilot CLI without a manual workaround.
**Scope:** Copilot CLI internals — not fixable in this repo. Workaround already documented on website (`website/src/pages/setup/copilot-cli.mdx`).
**Done-when:** [github/copilot-cli#2198](https://github.com/github/copilot-cli/issues/2198) is closed AND `copilot` loads `.mcp.json` from project root without `--additional-mcp-config` flag.
**Approach:** Blocked on upstream. Current workaround: add ADO MCP to `~/.copilot/mcp-config.json` (global) or use `copilot --additional-mcp-config @.mcp-copilot.json` per session. Already documented in setup guide.
**Evidence:** `internal/learnings/2026-03-22-cross-platform-gap-tracker.md` GAP 1

## Experimental Features

**Added:** 2026-03-03
**Problem:** Three Copilot CLI experimental features would significantly improve coordinator workflows if they stabilize. Need to monitor and prototype when ready.
**Scope:** Coordinator skills (`dx-step-all`, `dx-agent-all`, `dx-bug-all`, `dx-req`) and init skills (`dx-init`, `aem-init`).
**Done-when:** Each feature is individually actionable — check `/experimental` in Copilot CLI for GA status.

### MULTI_TURN_AGENTS — Persistent subagents with write_agent

**Impact: High.** Currently coordinators invoke skills via Skill tool for each step, losing context. Multi-turn agents stay alive — coordinator sends follow-ups via `write_agent`.

**Done-when:** `dx-step-all` uses `write_agent` to send step instructions to a persistent subagent instead of re-spawning per step.
**Action when stable:**
1. Test with `DxStepAll` → persistent subagent
2. Update all coordinator agent templates
3. Measure context quality vs current re-spawn approach

### SUBAGENT_COMPACTION — Compaction instead of truncation

**Impact: Medium.** Benefits subagent-heavy workflows — especially `dx-agent-all` (8+ skills). Addresses [#1180](https://github.com/github/copilot-cli/issues/1180).

**Done-when:** `/experimental` shows SUBAGENT_COMPACTION as stable. No code changes needed — enable flag, test with `/dx-agent-all`.

### ASK_USER_ELICITATION — Structured form-based input

**Impact: Medium.** `/dx-init` and `/aem-init` ask 6-8 sequential questions. A form presents all fields at once.

**Done-when:** `dx-init` SKILL.md uses structured elicitation tool for step 1-3 questions, with fallback to sequential.
**Action when stable:**
1. Prototype with `/dx-init` step 1-3
2. Map sequential questions to form fields with defaults
3. Update SKILL.md with fallback

### Other (not actionable)

| Feature | Assessment |
|---------|------------|
| `PERSISTED_PERMISSIONS` | Nice UX, no code changes needed |
| `SESSION_STORE` | Our agents don't depend on cross-session state |
| `EXTENSIONS` | Too early — our hooks work fine |
| `CONFIGURE_COPILOT_AGENT` | `/dx-init` already handles this |
