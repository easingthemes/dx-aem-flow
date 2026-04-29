# Cursor SDK Integration

Tracking work to leverage `@cursor/sdk` (public beta, 2026-04-29) and the [cursor/cookbook](https://github.com/cursor/cookbook) examples. Background: [2026-04-29 Cursor SDK investigation](../research/2026-04-29-cursor-sdk-investigation.md).

## Provider abstraction in `pipeline-agent.js`

**Added:** 2026-04-29
**Problem:** `plugins/dx-automation/data/scripts/pipeline-agent.js` hardcodes `@anthropic-ai/claude-agent-sdk`. Customers with Cursor budget but no Anthropic API key can't run dx-automation pipelines, even though Cursor SDK exposes the same shape (`Agent.create` + `run.stream` ≈ `query()`) and auto-loads `.cursor/skills/` + `.cursor/mcp.json`.
**Scope:** `plugins/dx-automation/data/scripts/pipeline-agent.js`, `plugins/dx-automation/data/pipelines/cli/ado-cli-*.yml` (env wiring), `docs/reference/automation-providers.md` (new).
**Done-when:** Setting `DX_AGENT_PROVIDER=cursor` + `CURSOR_API_KEY` runs `pipeline-agent.js` against a sample DoR prompt and streams assistant text without invoking Anthropic. Default (`anthropic` / unset) keeps current behavior identical.
**Approach:** Add a thin provider switch at the top of the script. Anthropic path stays as-is. Cursor path: `Agent.create({ apiKey, model: { id: process.env.CURSOR_MODEL ?? "composer-2" }, local: { cwd: process.cwd() } })`, then `for await (const event of run.stream())` translating `assistant` blocks → stdout. Skills, MCP, hooks come from `.cursor/` filesystem (already in scaffold via `.cursor-plugin/`). Add model-tier mapping in CLAUDE.md ("Model Tier Strategy" section) — Cursor `composer-2` ↔ Sonnet, `gpt-5.5` ↔ Opus.

## Cloud Agents API path from Lambda router

**Added:** 2026-04-29
**Problem:** `plugins/dx-automation/data/lambda/wi-router.mjs` queues an ADO pipeline run per webhook. The pipeline then provisions a ubuntu VM, checks out the repo, installs Claude Code, and runs the agent — ~50 LOC of YAML per agent. Cursor's `POST /v1/agents` with `cloud: { repos, autoCreatePR: true }` collapses this to one HTTPS call: Cursor handles VM, checkout, env, and PR creation.
**Scope:** `plugins/dx-automation/data/lambda/wi-router.mjs`, `plugins/dx-automation/data/pipelines/cli/` (only for orgs that opt out of cloud), new `.ai/automation/infra.json` field `agentRuntime: ado-pipeline | cursor-cloud`.
**Done-when:** With `agentRuntime: cursor-cloud`, a workitem.updated webhook with TAG_GATE_DOR triggers `POST /v1/agents` to Cursor, the agent opens a PR with DoR analysis, and the run is observable via `GET /v1/agents/{id}/runs/{rid}/stream`. ADO pipeline path remains the default.
**Approach:** Cursor SDK auth uses `crsr_...` API key. Map per-agent fields: `model.id` from config, `repos[]` from `.ai/config.yaml` `scm.repo`, `autoCreatePR: true`, prompt = same prompt we'd send to Claude (`/dx-dor <id>`). For now skip ACL/observability gaps (tracked separately) — this is a runtime alternative, not a replacement for the audit story.

## Adopt `agent-kanban` shape for Hub status UI (TODO #42 enabler)

**Added:** 2026-04-29
**Problem:** TODO #42 ("Hub V2: rich status tracking — phase, steps, PRs") is open. Cursor's `sdk/agent-kanban` cookbook is a Linear-style Next.js board for cloud agents: groups by status/repo/branch, shows artifact previews and PR links, has a "create agent" form. It's a near-exact match for what Hub V2 needs.
**Scope:** `plugins/dx-hub/` (skills + future web UI), reference `cursor/cookbook/sdk/agent-kanban`.
**Done-when:** Hub V2 spec in `todo-hub.md` references the kanban cookbook as the UX baseline; if we proceed with V2, the implementation forks the kanban app rather than green-fielding.
**Approach:** Read-only deps inventory first — confirm the cookbook's licensing allows reuse. Then prototype with hardcoded data shaped like our `dx-hub-status` output to confirm the columns/cards map cleanly to our phases (DoR / Plan / Implement / Review / PR).

## `hooks-cursor.json` for SDK safety hooks

**Added:** 2026-04-29
**Problem:** Existing item in [todo-cross-platform.md](todo-cross-platform.md#cursor-hooks-cursorjson-for-dx-core-and-dx-aem) becomes blocking once Cursor SDK provider lands. Without `hooks-cursor.json`, an SDK-driven session loads our skills but skips branch-guard and Stop guard.
**Scope:** Cross-link only — work tracked in `todo-cross-platform.md`.
**Done-when:** Same as upstream item.
**Approach:** Bump priority once the provider abstraction (item 1 above) ships.

## Verify Cursor SDK skill / MCP compatibility (POC)

**Added:** 2026-04-29
**Problem:** Our claim that "skills are portable to Cursor" is unverified for advanced frontmatter (`effort`, `paths`, `agent`, `context: fork`) and prefixed MCP tool names (`mcp__plugin_dx-aem_AEM__...`). Need a smoke test before any production switch.
**Scope:** New `tests/cursor-sdk-poc/` with a script that:
1. Installs `@cursor/sdk`
2. Symlinks `plugins/dx-core/skills/` to `.cursor/skills/`
3. Runs `/dx-help` and `/dx-step` on a fixture ticket
4. Logs which frontmatter fields were honored, which were silently dropped
**Done-when:** `tests/cursor-sdk-poc/run.sh` produces a markdown report at `docs/reference/cursor-skill-compatibility.md` with a row per frontmatter field (honored / dropped / partial) and per MCP tool naming style.
**Approach:** Reuse the cookbook quickstart pattern. Fixtures already exist in `tests/evals/`. Output goes into the existing skill catalog so other contributors can see at a glance which platforms honor which fields.
