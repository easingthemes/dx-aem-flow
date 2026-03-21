# TODO — Future Plans

## Copilot CLI Dual-Support — Remaining Gaps

Copilot CLI (GA Feb 2026) reads plugins from `.claude-plugin/` — same directory as Claude Code. Full compatibility analysis is in `docs/architecture/cross-agents.md` (feature comparison tables) and `docs/authoring/technical-reference.md` (sections 12–14: tool alias mapping, agent inventory, frontmatter fields).

**What already works:** `plugin.json` path-based format, `marketplace.json` in `.claude-plugin/`, SKILL.md (agentskills.io standard), `.mcp.json`, plugin skill auto-discovery by both tools. Old `copilot_transform()` + `templates/skills/` pipeline was removed in v2.39.0 — no longer needed.

### Resolved in v2.47.0
- Superpowers soft-dependency integration — 6 skills now optionally invoke superpowers methodology (brainstorming, TDD, systematic debugging, verification, execution discipline, branch readiness) with inline fallback when superpowers is not installed.

**Resolved in v2.42.0 → v2.43.0:**

- ~~Hooks event casing~~ — v2.42.0 shipped dual files. v2.43.0 consolidated to single `hooks.json` with `version: 1` (Copilot CLI v1.0.6+ accepts PascalCase and Claude Code's nested `matcher`/`hooks` structure). `copilot-hooks.json` deleted.
- ~~`allowed-tools` missing~~ — `install-copilot-agents.sh` injects `allowed-tools` into all Copilot agent frontmatter during copy.
- ~~`AGENTS.md` missing~~ — Generated at repo root by `/dx-init` (step 5d-bis). 25 agents with descriptions.
- ~~`editFiles` alias~~ — `install-copilot-agents.sh` transforms `editFiles` → `edit` during copy.
- ~~`chrome-devtools/` prefix~~ — transforms `chrome-devtools/` → `chrome-devtools-mcp/` during copy.
- ~~Hook paths fragile~~ — `hooks.json` uses `$CLAUDE_PROJECT_DIR` absolute paths.
- ~~SessionStart validation~~ — v2.43.0 added `SessionStart` hook (checks config.yaml, Node version).
- ~~Worker agents visible~~ — v2.43.0 added `user-invocable: false` to 6 worker agents.
- ~~Zero-copy instructions~~ — v2.43.0 uses `COPILOT_CUSTOM_INSTRUCTIONS_DIRS=.claude/rules` — Copilot CLI reads rules from same location as Claude Code. `.github/instructions/` generation removed from init skills.
- ~~Project-level hooks~~ — v2.43.0 deploys `.github/hooks/hooks.json` via install script.
- ~~Branch guard~~ — v2.43.0 added standalone `branch-guard.sh` script for preToolUse deny.

**Copilot CLI v1.0.6 (2026-03-16) — Impact on dx plugins:**

- **Hooks fully compatible:** Single `hooks.json` serves both tools. PascalCase events, nested `matcher`/`hooks` structure, `type` field — all accepted.
- **`COPILOT_CUSTOM_INSTRUCTIONS_DIRS` works:** Zero-copy instruction setup is now viable — set env var to `.claude/rules` to skip `.github/instructions/` generation entirely (see §4.9 in sync plan).
- **Tool search for Claude models:** ToolSearch-based MCP discovery now works in Copilot CLI. Agents that use ToolSearch fallback patterns work on both platforms.
- **`applyTo` accepts arrays:** Instruction frontmatter `applyTo:` now accepts both string and array values — aligns with Claude Code's `paths:` array format.
- **Plugin discovery via `--plugin-dir`:** `.claude-plugin/plugin.json` plugins load correctly when specified via flag.
- **Open Plugins spec:** `.lsp.json`, PascalCase hooks, `exclusive` path mode, `:` namespace separator all supported.

**Remaining gaps:**

### 1. Agent file format divergence (dual files)

Claude Code agents (`agents/*.md`): PascalCase tools, `model:` alias, no `handoffs:`. Copilot agents (`templates/agents/*.agent.md`): lowercase tools, `handoffs:` navigation. See `technical-reference.md` §14 for full field comparison.

**`handoffs:` is broken in Copilot CLI.** The field is parsed (regression #1195 fixed in v0.0.402) but does NOT execute — agents cannot actually call other agents. Three open issues:
- [#561](https://github.com/github/copilot-cli/issues/561) — Feature request: support handoffs in CLI agent mode (open since Nov 2025, 13 upvotes, no milestone)
- [#1180](https://github.com/github/copilot-cli/issues/1180) — Context exhaustion during handoffs (open, no activity)
- Workaround: `*-all` coordinator agents include `handoffs:` in templates so they auto-activate when CLI adds support. Until then, users invoke skills sequentially or use `/fleet`.

**Current:** Dual files (approach A). `install-copilot-agents.sh` copies templates → `.github/agents/` with post-copy transforms (editFiles→edit, chrome-devtools→chrome-devtools-mcp, allowed-tools injection).
**Future:** Watch for #561 resolution AND VS Code/Copilot CLI supporting Claude-format tool names natively. If tool name mapping becomes automatic (VS Code already maps `Read` → `read` per §12), could switch to single-source agents.

### ~~2. Marketplace registration for Copilot CLI~~ (resolved)

Copilot CLI reads `extraKnownMarketplaces` from `.claude/settings.json` — same as Claude Code. ADO SSH URLs work. `/plugin marketplace browse dx-aem-flow` shows all 3 plugins. `/plugin install dx-core@dx-aem-flow` installs 55 skills. Documented in `docs/usage/installation.md`.

### 3. MCP tool names in agent frontmatter

Skills: no issue (prose references, both runtimes resolve independently). Agent `tools:` frontmatter: format differs (`Read, Bash` vs `read, execute`). Covered by gap #1 (dual agent files).

**References:** See `docs/architecture/cross-agents.md` §Plugins and `docs/authoring/technical-reference.md` §12–14.

## Consider renaming .ai/me.md → .me at project root

`.ai/me.md` is the developer's personal tone/style file — used by `dx-pr-answer` for persona-matching in PR replies. Currently lives in `.ai/` alongside project config.

**Idea:** Move it to `.me` at the project root (like `.env`) — makes it more discoverable, clearly personal. Implies gitignore by convention.

**Decision needed:** Does the `.me` filename conflict with any tools? How do skills reference it — by hardcoded path, so a rename requires updating all skill references.

## ~~Hide worker agents from Copilot dropdown~~ (done in v2.43.0)

Added `user-invocable: false` to 6 worker agents (dx-doc-searcher, dx-file-resolver, dx-figma-markup, dx-figma-styles, aem-page-finder, aem-file-resolver).

## Copilot CLI Experimental Features (watch list)

Three experimental features (`/experimental on`) are highly relevant for dx plugins. All are unstable and may change.

### MULTI_TURN_AGENTS — Persistent subagents with write_agent

**Impact: High.** Currently `DxStepAll` re-spawns `dx-step-executor` for each step, losing accumulated context. Multi-turn agents stay alive after responding — the coordinator can send follow-up messages ("now run step 2", "now run step 3") via `write_agent` to the same agent instance, preserving context across steps.

This is the missing piece for coordinator workflows — effectively a `handoffs:` alternative that works at the subagent level.

**Action when stable:**
1. Test with `DxStepAll` → `dx-step-executor`: spawn once, send step instructions via `write_agent`
2. If successful, update all coordinator agent templates (`DxStepAll`, `DxAgentAll`, `DxBugAll`, `DxReqAll`)
3. Measure context quality vs current re-spawn approach

### SUBAGENT_COMPACTION — Compaction instead of truncation for subagents

**Impact: Medium.** When subagents hit context limits, they currently truncate (lose early context). Compaction keeps structured summaries instead. Benefits every subagent-heavy workflow — especially `dx-agent-all` which chains 8+ skills through `dx-step-executor`.

Directly addresses [#1180](https://github.com/github/copilot-cli/issues/1180) (context exhaustion during handoffs).

**Action when stable:** No code changes needed — just enable the flag and test with a heavy workflow (`/dx-agent-all`).

### ASK_USER_ELICITATION — Structured form-based input

**Impact: Medium.** `/dx-init` and `/aem-init` ask 6-8 sequential questions (project name, build commands, Copilot support, AEM URLs, etc.). A structured form could present all fields at once — single form submission instead of 8 back-and-forth prompts.

**Action when stable:**
1. Prototype with `/dx-init` step 1-3 (project detection questions)
2. Map sequential questions to form fields with defaults
3. Update SKILL.md to use the structured elicitation tool when available, fall back to sequential questions otherwise

### Other experimental features (not actionable)

| Feature | Assessment |
|---------|------------|
| `PERSISTED_PERMISSIONS` | Complements `allowed-tools` — persists MCP tool approvals across sessions. Nice UX improvement but no code changes needed. |
| `SESSION_STORE` | SQLite cross-session history. Could complement Claude Code's `memory:` but our agents don't depend on cross-session state. |
| `EXTENSIONS` | Programmatic tools via `@github/copilot-sdk`. Could replace shell-script hooks with typed JS tools. Too early — our hooks work fine. |
| `CONFIGURE_COPILOT_AGENT` | Meta-agent for config management. Our `/dx-init` already handles this. |

## SubagentStart / SubagentStop project-level hooks

Add `SubagentStart` and `SubagentStop` hooks in `.claude/settings.json` to log which agents run, how long they take, and success/failure. Useful for optimizing pipeline performance and debugging.

## Rename /aem-demo to something clearer (e.g. /aem-editorial-guide)

`/aem-demo` captures dialog screenshots and writes an editor-friendly authoring guide. The name "demo" is misleading — it suggests a live demo, not documentation generation. "Editorial Guide" or "Authoring Guide" better describes what it produces.

**Scope:** Rename skill directory, SKILL.md name field, agent references, all coordinator references (dx-agent-all Phase 6.5), presentation website, and skill catalog.

## Revert to namespace-only naming once Claude Code fixes plugin:skill resolution

All skill directories were prefixed with their plugin abbreviation (`dx-init`, `aem-doctor`) to work around broken `plugin:skill` resolution in Claude Code CLI. Once the upstream bug is fixed (skills correctly show as `dx:init` not bare `init`), consider reverting to shorter directory names.

**Tracking:** https://github.com/anthropics/claude-code/issues

## Better visual separation in multi-step skill logs

Coordinator skills (`dx-req-all`, `dx-step-all`, `dx-agent-all`, `dx-bug-all`) run many steps sequentially. In the terminal output, step boundaries blend together — it's hard to see where one step ends and the next begins.

**Idea:** Print a long horizontal rule (`────────────────────────────────`) above and below each step title, e.g.:

```
────────────────────────────────────────────────────
  Phase 2: dx-req-explain
────────────────────────────────────────────────────
```

**Scope:** All `-all` coordinators that delegate to `dx-step-executor`. The print happens in the coordinator SKILL.md before each delegation call.

## Investigate `updatedMCPToolOutput` not replacing inline image

The `PostToolUse` hook for `mcp__figma__get_screenshot` correctly returns `updatedMCPToolOutput` (a text string with the saved file path), but Claude Code still sends the original base64 image inline to the LLM. The `additionalContext` field works — it appears as a system reminder. But the image replacement doesn't take effect.

**Possible causes:**
- Claude Code may send MCP image content to the LLM before processing hook output
- `updatedMCPToolOutput` may only work for text content, not image content types
- The hook output format may need a different structure for image replacement

**Impact:** Low — the screenshot still gets saved to disk (hook works), and `additionalContext` tells the skill where the file is. The only downside is the LLM also receives the large base64 image (token waste). If replacement worked, we'd save ~500K tokens per screenshot call.

## Remote Figma support for CI/CD pipelines

DevAgent's Figma design-to-code works locally via the Figma MCP server (connects to the local Figma desktop app — no token needed). However, in headless CI/CD pipeline environments (ADO pipelines running on Linux VMs), there is no local Figma app.

**Needed:** A way for pipeline DevAgent to access Figma designs remotely. Options to investigate:
- **Figma REST API** with a Personal Access Token — simpler but limited compared to MCP
- **Figma MCP with browser-based OAuth** — unclear if this works headless
- **Figma Dev Mode API** — may provide richer design context

The pipeline YAML (`ado-cli-dev-agent.yml`) already has a `FIGMA_PERSONAL_ACCESS_TOKEN` env var placeholder. If the REST API approach works, the pipeline just needs the token set as a pipeline variable. The DevAgent prompt would need a fallback path: try Figma MCP first → if unavailable, use REST API with token.

## Pipeline pause-and-resume for human-in-the-loop

When Claude CLI runs headless in a pipeline and needs human input (e.g., "Want me to run a post-merge review?"), the pipeline currently just exits. A pause-and-resume mechanism would catch the question, pause the pipeline, and resume after a human answers.

**Architecture (Approach B — multi-job):**

1. **Stop hook** (`Stop` event) — fires when Claude finishes responding. Receives `last_assistant_message`. If message ends with a question and `stop_hook_active` is false, save the question to a file and let Claude exit.
2. **Runner detects question** — `pipeline-agent.js` checks for the saved question file after Claude exits. Sets ADO output variable `HAS_QUESTION=true` + the question text.
3. **ManualValidation job** — a second `pool: server` (agentless) job with `ManualValidation@1` task. Displays the question as instructions, sends email notification, waits up to N days.
4. **Resume job** — third job runs `claude --resume <session-id> -p "<answer>"` to continue the session.

**Key constraints:**
- `ManualValidation@1` only works in agentless (`pool: server`) jobs — cannot be a step in the same agent job
- Programmatic approval via REST API: `PATCH {org}/{project}/_apis/pipelines/approvals?api-version=7.1` with `approvalId` from build timeline `Checkpoint.Approval` record
- Stop hooks work in headless `-p` mode (only `PermissionRequest` is documented as not firing in headless)
- Must check `stop_hook_active` to prevent infinite loops
- Requires passing session ID between jobs (pipeline artifacts or output variables)

**Pipeline YAML sketch:**
```yaml
stages:
- stage: AI
  jobs:
  - job: RunClaude
    pool: { vmImage: ubuntu-latest }
    steps:
      - bash: |
          node pipeline-agent.js "..." ...
          # runner sets ##vso output vars if question detected

  - job: WaitForAnswer
    dependsOn: RunClaude
    condition: eq(dependencies.RunClaude.outputs['checkQuestion.HAS_QUESTION'], 'true')
    pool: server
    timeoutInMinutes: 4320
    steps:
      - task: ManualValidation@1
        inputs:
          notifyUsers: '$(NOTIFY_USERS)'
          instructions: '$(CLAUDE_QUESTION)'

  - job: ResumeClaude
    dependsOn: WaitForAnswer
    pool: { vmImage: ubuntu-latest }
    steps:
      - bash: node pipeline-agent.js --resume $SESSION_ID "$ANSWER" ...
```

**Current mitigation:** `.ai/rules/headless-autonomy.md` instructs Claude to never ask questions in pipeline mode. This TODO is for cases where human input is genuinely needed.

**References:**
- [ManualValidation@1 docs](https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/reference/manual-validation-v1)
- [Approvals REST API](https://learn.microsoft.com/en-us/rest/api/azure/devops/approvalsandchecks/approvals/update)
- [Claude Code Stop hook](https://code.claude.com/docs/en/hooks) — `last_assistant_message`, `stop_hook_active`, `decision: "block"`


