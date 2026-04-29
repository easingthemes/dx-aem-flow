# Cursor SDK Investigation — 2026-04-29

How `@cursor/sdk` (public beta, announced 2026-04-29) and the [cursor/cookbook](https://github.com/cursor/cookbook) examples could improve dx-aem-flow's automation, multi-platform support, and hub UX.

Companion to [agent-standards-landscape-2026.md](agent-standards-landscape-2026.md) and [2026-04-25 platform state update](2026-04-25-platform-state-update.md).

---

## TL;DR

- **Cursor shipped a programmatic SDK** with the same harness that powers the IDE — codebase indexing, MCP, skills, hooks, subagents — runnable locally or in Cursor-hosted cloud VMs (each agent gets a dedicated sandboxed VM with the repo cloned and the dev env configured).
- **Drop-in replacement opportunity for `pipeline-agent.js`.** The cookbook's quickstart is structurally identical to our `@anthropic-ai/claude-agent-sdk` runner (`Agent.create() + run.stream()` ≈ `query()`). Adding a Cursor backend would let dx-automation pipelines run on Anthropic *or* Cursor budget without changing skills.
- **Cloud Agents API removes ADO pipeline plumbing.** `POST /v1/agents` with `cloud: { repos, autoCreatePR: true }` replaces the ADO pipeline + ubuntu VM + git push + PR creation chain. The Lambda router (`wi-router.mjs`) could call this directly instead of queueing pipelines.
- **`agent-kanban` is a ready reference for Hub V2.** TODO #42 ("Hub V2: rich status tracking — phase, steps, PRs") matches the cookbook's Linear-style board for cloud agents almost 1:1. Worth forking / adapting.
- **No urgency.** Cursor SDK is *beta* (no SLA), Anthropic-side automation is mature, and Cursor support in our repo today is manifest-only (`.cursor-plugin/plugin.json`, no hooks). We should add a tracked TODO and a tiny POC, not a production switch.

---

## 1. What `@cursor/sdk` provides

| Capability | API | Notes |
|---|---|---|
| Local agent | `Agent.create({ apiKey, model, local: { cwd } })` | Same harness as Cursor IDE, runs against local files |
| Cloud agent | `Agent.create({ apiKey, model, cloud: { repos, autoCreatePR } })` | Dedicated Cursor-managed VM, repo cloned, env configured |
| Self-hosted | "Self-hosted workers" mentioned in announcement | Keeps code & tools inside customer network — interesting for enterprise AEM |
| Streaming | `for await (const event of run.stream())` — events: `assistant`, `thinking`, `tool`, `status`, `task`, `result` | SSE under the hood; resumable via `Last-Event-ID` |
| Models | `composer-2` (default in cookbook), `gpt-5.5`, "every model in Cursor" | List via `Cursor.models.list({ apiKey })` |
| Tools | Auto-loads `.cursor/mcp.json`, `.cursor/skills/`, `.cursor/hooks.json`, subagents | Same conventions as Cursor IDE |
| Auth | `CURSOR_API_KEY` (`crsr_...`) | Basic auth on REST API |
| Runtime | Node 22+ (quickstart) or Bun 1.3+ (TUI cookbook) | Pure ESM |

### Cloud Agents REST API v1 (relevant subset)

```
POST   /v1/agents                          create + initial run
GET    /v1/agents                          list (filter by archive, PR URL)
GET    /v1/agents/{id}                     metadata
POST   /v1/agents/{id}/archive             stop accepting new runs
POST   /v1/agents/{id}/runs                follow-up prompt (one run at a time)
GET    /v1/agents/{id}/runs/{rid}/stream   SSE — assistant text, thinking, tools, errors
POST   /v1/agents/{id}/runs/{rid}/cancel   permanent cancel
GET    /v1/agents/{id}/artifacts           list artifacts
GET    /v1/agents/{id}/artifacts/download  presigned S3 URL
GET    /v1/models                          model IDs for `Agent.create`
```

### Cookbook examples

| Example | Stack | What it shows |
|---|---|---|
| `sdk/quickstart` | Node 22, pnpm, ~25 LOC | Minimal local agent + streamed assistant text. Identical shape to our `pipeline-agent.js` but ~10× shorter |
| `sdk/coding-agent-cli` | Bun, OpenTUI/React | One-shot prompt + interactive TUI. Switches local↔cloud at runtime; lists models via `Cursor.models.list` |
| `sdk/agent-kanban` | Next.js | Linear-style board for cloud agents — group by status/repo/branch, artifact previews, "create agent" form |
| `sdk/app-builder` | Next.js | Iterative chat → hot-reloading React preview iframe. "App-building loop" demo |

Quickstart, verbatim:

```ts
import { Agent } from "@cursor/sdk"

const agent = await Agent.create({
  apiKey: process.env.CURSOR_API_KEY,
  name: "SDK quickstart",
  model: { id: process.env.CURSOR_MODEL ?? "composer-2" },
  local: { cwd: process.cwd() },
})

const run = await agent.send("Explain this project in one paragraph.")

for await (const event of run.stream()) {
  if (event.type !== "assistant") continue
  for (const block of event.message.content) {
    if (block.type === "text") process.stdout.write(block.text)
  }
}
await run.wait()
```

Compare to the relevant slice of `plugins/dx-automation/data/scripts/pipeline-agent.js`:

```js
const { query } = require("@anthropic-ai/claude-agent-sdk")
// build mcpServers, allowedTools, plugins, system prompt …
for await (const message of query({ prompt, options: { maxTurns, mcpServers, allowedTools, plugins } })) {
  // print assistant text, tool calls, results
}
```

The shape is the same — both stream events from a long-running agent run. The wrapper differences are MCP wiring and plugin registration, both of which Cursor handles via `.cursor/` filesystem conventions.

---

## 2. Where it fits in dx-aem-flow

### Mapping vs. current architecture

| Area | Today | Cursor SDK option | Verdict |
|---|---|---|---|
| Pipeline runner (`pipeline-agent.js`) | `@anthropic-ai/claude-agent-sdk`, MAX_TURNS, custom MCP wiring, plugin discovery | `@cursor/sdk` `Agent.create` + auto-discovery from `.cursor/` | **Worth POC.** Skills are mostly portable; MCP servers reuse `.cursor/mcp.json` |
| ADO pipeline → ubuntu VM → checkout → install Claude Code → run | YAML in `data/pipelines/cli/ado-cli-*.yml` | Cloud Agents API: one POST replaces VM, checkout, install, PR creation | **Big win if adopted.** Eliminates ~50 LOC of pipeline YAML per agent and `autoCreatePR: true` replaces our `dx-pr` push step |
| Lambda webhook router (`wi-router.mjs`) | Maps tag → ADO pipeline ID → `az pipelines run` | Map tag → `POST /v1/agents` with prompt + repo | Trade-off: gain portability, lose ADO observability |
| Hub status (`dx-hub-status` text) | Markdown table per repo | `agent-kanban` Linear-style board | **Direct match for TODO #42** |
| Local user CLI | `claude`, `copilot`, `gemini`, etc. | `coding-agent-cli` Bun TUI | Optional — users who prefer Cursor get parity |
| Cursor plugin support | `.cursor-plugin/plugin.json` + planned `hooks-cursor.json` | SDK auto-loads `.cursor/skills/` + `.cursor/hooks.json` | Already aligned at filesystem level — no skill rewrites needed |

### Concrete integration ideas, ranked

1. **Provider abstraction in `pipeline-agent.js`** *(highest ROI, lowest risk)*
   Add `DX_AGENT_PROVIDER=anthropic|cursor` env. Branch on the value: keep `query()` for Anthropic, use `Agent.create({ local: { cwd } })` + `run.stream()` for Cursor. Skills, MCP, plugins are read from `.cursor/` instead of `--plugins`. Single file change, opt-in via env. Lets one customer with Cursor budget run dx-automation today without touching ADO infra.

2. **New TODO: `todo-cursor-sdk.md`** with three sub-items
   - Cursor SDK provider in `pipeline-agent.js` (item 1 above)
   - Cloud Agents API direct path from `wi-router.mjs` (replaces ADO pipeline for orgs that want it)
   - Adopt `agent-kanban` shape for `dx-hub-status` web UI (Hub V2 / TODO #42)

3. **`hooks-cursor.json` materialization** *(already in `todo-cross-platform.md`, now blocking)*
   Without this file, the Cursor SDK loads our skills but no safety hooks. Branch-guard / Stop guard exist for Claude Code + Copilot CLI; need camelCase `version: 1` mirror.

4. **Model tier mapping** in `CLAUDE.md` "Model Tier Strategy"
   Add a column for Cursor equivalents — `composer-2` ≈ Sonnet for execution, `gpt-5.5` ≈ Opus for reasoning. Skills with `model: sonnet` translate cleanly.

5. **Tool-name mapping** *(extends `todo-cross-platform.md` "Tool name reference")*
   Cursor's MCP tool naming behavior is undocumented in our repo. Quickstart code suggests prefixed names work like Claude Code. Verify and add a row to the "Plugin MCP Tool Naming" table in `CLAUDE.md`.

6. **Self-hosted workers (watch)**
   Cursor announcement mentions self-hosted workers keeping code/tools inside the customer's network. AEM customers regularly require on-prem execution (license servers, internal repos). If/when this stabilizes, it could be a differentiator vs. Anthropic's cloud-only Agent SDK.

### What we should *not* do (yet)

- **Don't replace `@anthropic-ai/claude-agent-sdk`.** It's the production runner; Cursor SDK is beta with no SLA. Add it as an alternative, not a swap.
- **Don't build the kanban UI from scratch.** Wait until TODO #42 is prioritized; then fork `sdk/agent-kanban` rather than green-fielding.
- **Don't push for `cloud:` runtime in regulated AEM environments.** Cursor's cloud VMs run outside customer networks — same constraint that today blocks many ADO-hosted Microsoft agents from prod AEM access.

---

## 3. Open questions

| Question | Why it matters | How to resolve |
|---|---|---|
| Pricing per token vs. per agent-hour? | Determines whether Cursor cloud agents are cheaper than ADO ubuntu + Anthropic API | Run a 1-day cost test: same DoR ticket on ADO+Claude vs. Cursor cloud |
| Does `.cursor/skills/` honor our YAML frontmatter (`model`, `effort`, `paths`, `agent`, `context: fork`)? | Skill portability claim depends on this | Install dx-core to a Cursor session, run `/dx-step` on a sample ticket |
| MCP tool naming — prefixed or bare? | Affects skills that call `mcp__plugin_dx-aem_AEM__...` | Reproduce against Cursor SDK; document in CLAUDE.md table |
| Hooks schema overlap with Copilot CLI? | If `hooks-cursor.json` is close to `hooks.json`, we may be able to share scripts | Read superpowers' `hooks-cursor.json` |
| Skill auto-activation (`paths:`) in Cursor? | We use it in AEM skills | Check `.cursor/skills/` discovery rules in Cursor docs |

---

## Sources

- [Build programmatic agents with the Cursor SDK](https://cursor.com/blog/typescript-sdk) — 2026-04-29 announcement
- [Cursor SDK & Cloud Agents API updates (forum)](https://forum.cursor.com/t/cursor-sdk-cloud-agents-api-updates/159284) — release notes, beta status
- [Cloud Agents API endpoints](https://cursor.com/docs/cloud-agent/api/endpoints) — REST surface
- [cursor/cookbook](https://github.com/cursor/cookbook) — `sdk/quickstart`, `sdk/coding-agent-cli`, `sdk/agent-kanban`, `sdk/app-builder`
- Internal: [agent-standards-landscape-2026.md](agent-standards-landscape-2026.md), [2026-04-25-platform-state-update.md](2026-04-25-platform-state-update.md), [todo-cross-platform.md](../todo/todo-cross-platform.md)
