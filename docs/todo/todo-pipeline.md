# TODO: Pipeline & CI/CD

## Remote Figma for CI/CD

**Added:** 2026-03-03
**Problem:** DevAgent's Figma design-to-code works locally via Figma MCP (connects to desktop app — no token needed). Headless CI/CD environments (ADO pipelines on Linux VMs) have no local Figma app, so Figma MCP doesn't work.
**Scope:**
- DevAgent skill: `plugins/dx-automation/skills/auto-init/SKILL.md` (pipeline config)
- Pipeline YAML: consumer repo `.ai/automation/pipelines/cli/ado-cli-dev-agent.yml`
- DevAgent prompt: would need a fallback path (try MCP first → REST API if unavailable)
- Env var: `FIGMA_PERSONAL_ACCESS_TOKEN` placeholder already exists in pipeline YAML
**Done-when:** `grep -n "FIGMA_PERSONAL_ACCESS_TOKEN\|figma.*REST\|figma.*fallback" plugins/dx-automation/skills/auto-init/SKILL.md` shows a fallback mechanism for headless Figma access, AND the DevAgent prompt includes "try Figma MCP first, if unavailable use REST API".

**Approach options:**
- **Figma REST API** with Personal Access Token — simpler but limited vs MCP
- **Figma MCP with browser-based OAuth** — unclear if works headless
- **Figma Dev Mode API** — may provide richer design context

## Pause and Resume

**Added:** 2026-03-03
**Problem:** When Claude CLI runs headless in a pipeline and needs human input (e.g., "Want me to run a post-merge review?"), the pipeline exits. No way to pause, collect a human answer, and resume the session.
**Scope:**
- Stop hook: would be added to `plugins/dx-automation/hooks/hooks.json`
- Pipeline runner: consumer repo `.ai/automation/scripts/pipeline-agent.js`
- Pipeline YAML: consumer repo `.ai/automation/pipelines/cli/*.yml` (need ManualValidation job)
- Rule: `.ai/rules/headless-autonomy.md` (current mitigation — "never ask questions")
**Done-when:** A pipeline YAML exists with a `ManualValidation@1` job that fires when Claude's last message was a question, AND `pipeline-agent.js` supports `--resume <session-id>`.

**Approach (multi-job):**

1. **Stop hook** — fires when Claude finishes. If message ends with a question and `stop_hook_active` is false, save question to file
2. **Runner detects question** — `pipeline-agent.js` checks for saved question, sets ADO output `HAS_QUESTION=true`
3. **ManualValidation job** — `pool: server` (agentless) with `ManualValidation@1`. Displays question, sends email, waits up to N days
4. **Resume job** — `claude --resume <session-id> -p "<answer>"`

**Key constraints:**
- `ManualValidation@1` only works in agentless (`pool: server`) jobs
- Programmatic approval via REST API: `PATCH {org}/{project}/_apis/pipelines/approvals?api-version=7.1`
- Must check `stop_hook_active` to prevent infinite loops
- Requires passing session ID between jobs (pipeline artifacts or output variables)

**Current mitigation:** `.ai/rules/headless-autonomy.md` instructs Claude to never ask questions in pipeline mode.

**References:**
- [ManualValidation@1 docs](https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/reference/manual-validation-v1)
- [Approvals REST API](https://learn.microsoft.com/en-us/rest/api/azure/devops/approvalsandchecks/approvals/update)
- [Claude Code Stop hook](https://code.claude.com/docs/en/hooks)

---

## Pipeline Parity with Local CLI — Goal

**Goal:** A pipeline run should have the same capabilities as a developer running the same skill locally with `claude` — same plugins, same skills (including superpowers), same MCP servers, same tools (subject to safety constraints). Today the pipeline runs in a stripped-down sandbox and many skills silently degrade.

The next 5 items are sub-goals contributing to this. Each is independently shippable.

## Auto-discover plugins instead of hardcoded list

**Added:** 2026-05-06
**Problem:** `plugins/dx-automation/data/scripts/pipeline-agent.js:51` hardcodes `["dx-core", "dx-aem", "dx-automation"]`. Adding a new plugin (e.g. `dx-hub`, `superpowers`, `plugin-dev`) requires editing the runner. Skills that soft-depend on `superpowers:*` skills silently fall through to inline fallbacks in pipelines, which is a quieter, lower-quality path than what runs locally.

**Important context (researched 2026-05-06):** The Claude *Agent SDK* does NOT honor `enabledPlugins` / `extraKnownMarketplaces` from `.claude/settings.json` — that's a CLI-only feature. Per [code.claude.com/docs/en/agent-sdk/plugins](https://code.claude.com/docs/en/agent-sdk/plugins): "To use a plugin distributed through a marketplace or remote repository, download it first and provide the local directory path." So even though consumer repos declare plugins via `settings.json` and the marketplace is now public on github (`easingthemes/dx-aem-flow`), the pipeline still needs plugins materialized on disk before invoking `query()`. `settingSources: ["project"]` only pulls in CLAUDE.md, `.claude/skills/`, hooks, and `.mcp.json` — not `enabledPlugins`.

**Scope:**
- `plugins/dx-automation/data/scripts/pipeline-agent.js` (the `pluginNames` constant + plugin discovery loop)
- `plugins/dx-automation/data/pipelines/cli/*.yml` (the `checkout: dx-hub` step — should checkout the public marketplace repo instead)
- `plugins/dx-automation/skills/auto-init/SKILL.md` (document the discovery model)
- `.ai/automation/scripts/pipeline-agent.js` in consumer repos (deployed via `auto-init`)
**Done-when:** `grep -n "pluginNames\s*=\s*\[" plugins/dx-automation/data/scripts/pipeline-agent.js` returns no hits AND a new plugin dropped in `$PLUGIN_BASE_DIR` is loaded by the next pipeline run without code changes.

**Approach (two-phase):**

1. **Short-term (low risk):** Switch the pipeline checkout from the private `dx-hub` repo to the public marketplace repo (`https://github.com/easingthemes/dx-aem-flow`), then auto-discover plugin dirs under it. Replace the hardcoded array with `fs.readdirSync(pluginBaseDir).filter(d => fs.existsSync(path.join(pluginBaseDir, d, '.claude-plugin', 'plugin.json')))`. Allow a `PIPELINE_PLUGINS` env var override (comma-separated allowlist) for cases where a pipeline wants to deliberately exclude a plugin. Precedence: env-var allowlist > directory scan.

2. **Long-term (settings.json parity):** Read `.claude/settings.json` from the consumer repo's checkout, parse `enabledPlugins` + `extraKnownMarketplaces`, and `git clone` each marketplace repo into a temp dir at pipeline start. Pass the resulting paths to the SDK as `{type:"local", path:...}`. This makes the pipeline drive plugin loading from the same `settings.json` a developer uses locally — true CLI parity. Most code, but eliminates the "checkout step" entirely from a developer's mental model. Defer until phase 1 is stable.

**Why not "just use the CLI":** Switching to `claude -p` would let `settings.json` work natively, but loses everything `pipeline-agent.js` does — per-skill token attribution, ToolSearch loop detection, partial-message streaming, cost alerts, 60s heartbeat, structured event logging. That's a big observability regression for the 24/7 automation use case.

## Install superpowers in pipelines

**Added:** 2026-05-06
**Problem:** Six skills (`dx-plan`, `dx-step`, `dx-step-fix`, `dx-step-verify`, `dx-agent-all`, `dx-pr`) reference `superpowers:*` skills via the soft-dependency pattern (CLAUDE.md "Superpowers Soft-Dependency Pattern"). Locally the user has superpowers installed and the rich methodology runs (TDD, brainstorming, verification-before-completion, systematic-debugging). In pipelines, superpowers is not present — every soft-dependency falls back to its condensed inline guidance. The pipeline DevAgent / DoD / BugFix path is therefore consistently lower-quality than what a developer gets locally for the same skill.
**Scope:**
- The `dx-hub` repo (or wherever `$PLUGIN_BASE_DIR` points) must contain a checkout of superpowers alongside the four dx plugins
- `plugins/dx-automation/data/pipelines/cli/*.yml` — install / clone superpowers into `$PLUGIN_BASE_DIR` as a pipeline step
- After [Auto-discover plugins](#auto-discover-plugins-instead-of-hardcoded-list) lands, no runner change is needed
**Done-when:** `node .ai/automation/scripts/pipeline-agent.js "/dx-plan 12345"` in CI logs `[sdk] plugins:` containing `superpowers` AND `Skill superpowers:test-driven-development` resolves successfully when invoked from `dx-step`.
**Approach:** Two options:
1. **Vendor:** Add superpowers as a git submodule under `dx-hub` so it's checked out alongside the dx plugins. Simplest, works offline, version-pinned.
2. **Install at pipeline start:** `git clone https://github.com/obra/superpowers $PLUGIN_BASE_DIR/superpowers` as a pipeline step. Latest version, no submodule maintenance, slower cold start.
   Pick (1) for reproducibility unless the team specifically wants floating versions.

## Expand `ALLOWED_TOOLS` to match local capability

**Added:** 2026-05-06
**Problem:** Pipeline YAMLs set `ALLOWED_TOOLS: "Skill,Read,Write,Edit,Glob,Grep,Bash(git *),Agent"` (e.g. `ado-cli-bug-fix.yml:69`). Locally, Claude has unrestricted Bash, plus `WebFetch`, `WebSearch`, `TaskCreate`/`TaskUpdate` (for live progress UI), `NotebookEdit`, `AskUserQuestion`, `EnterPlanMode`. As a result:
- DevAgent cannot run `mvn`, `npm test`, `node`, or any non-git Bash → cannot self-verify builds before opening a PR.
- Coordinator skills cannot use `TaskCreate` — the `task-progress.md` rule (CLAUDE.md "Visual Separation in Logs") falls back to plain text in pipeline logs, hurting observability.
- Skills that need to fetch a URL (e.g. checking a Confluence page) have no `WebFetch`.
**Scope:** All YAMLs under `plugins/dx-automation/data/pipelines/cli/*.yml` (10 files) — the `ALLOWED_TOOLS:` env var.
**Done-when:** `grep -n "ALLOWED_TOOLS:" plugins/dx-automation/data/pipelines/cli/*.yml` shows tool sets matched to each agent's needs (DevAgent gets build commands, DoR/DoD get `WebFetch`, all coordinators get `TaskCreate`) AND a DevAgent run in CI executes `mvn clean install` (or the project's `build.command`) without permission errors.
**Approach:** Build a per-agent matrix. Sketch:
| Agent | Bash | Web | Tasks | Notebook |
|---|---|---|---|---|
| DoR / DoD / Estimation | `Bash(git *)` | `WebFetch`, `WebSearch` | yes | no |
| BugFix / DevAgent | `Bash(*)` (full) | `WebFetch`, `WebSearch` | yes | yes |
| PR Review / PR Answer | `Bash(git *)` | `WebFetch` | yes | no |
| QA / DOC | `Bash(*)` | `WebFetch` | yes | no |
Safety: keep `permissionMode: bypassPermissions` but rely on the allowlist + headless-autonomy rule to constrain blast radius. Do NOT remove `Bash(git *)` filter in agents that don't need full Bash.

## Expose more MCP servers (parity with local + Chrome DevTools headless)

**Added:** 2026-05-06
**Problem:** `pipeline-agent.js` configures only two MCP servers: `ado` (when `ADO_MCP_AUTH_TOKEN` is set) and `AEM` (when AEM env vars are set). Local dev has many more — `atlassian`, `figma`, `axe-mcp-server`, `chrome-devtools-mcp`, `context7`, `microsoft-docs`, `mongodb`, `playwright`. Concrete consequences in CI:
- `aem-fe-verify` and `aem-qa` need `chrome-devtools-mcp` to screenshot rendered components and compare to Figma — currently skipped silently.
- `dx-axe` accessibility audit needs `axe-mcp-server` — currently fails or skipped.
- `dx-figma-extract` / `dx-figma-prototype` need Figma MCP — already covered by [Remote Figma for CI/CD](#remote-figma-for-cicd) but the wiring to the SDK runner is missing.
- DoR / DoD checks against Confluence need `atlassian` MCP for non-ADO tracker projects.
**Scope:**
- `plugins/dx-automation/data/scripts/pipeline-agent.js` (the `mcpServers` block at lines 58–76)
- `plugins/dx-automation/data/pipelines/cli/*.yml` (env vars per agent — only enable what each agent needs)
- `plugins/dx-automation/skills/auto-lambda-env/SKILL.md` (document new env vars)
**Done-when:** `pipeline-agent.js` registers an MCP server when its corresponding env var is present (e.g. `CHROME_DEVTOOLS_HEADLESS=1` enables chrome-devtools-mcp launched against headless Chromium installed in the same pipeline step) AND `ado-cli-qa.yml` runs `aem-qa` end-to-end including page-load screenshots in CI.
**Approach:**
- **Chrome DevTools headless:** install Chromium in the pipeline (`apt-get install -y chromium-browser` or use a container image with it pre-installed), launch headless with `--headless=new --remote-debugging-port=9222 --no-sandbox`, point chrome-devtools-mcp at it. The MCP server is just a Chrome DevTools Protocol client — it doesn't care if Chrome is windowed or headless. Caveat: AEM author mode pages may behave differently in headless (no GPU, different fonts) — capture in a known-baseline screenshot folder before relying on visual diffs.
- **Atlassian / context7 / microsoft-docs / mongodb:** stdio MCP servers, just need `command` + `args` in `mcpServers` and the right credential env vars piped from ADO library variables. No infrastructure changes.
- **Figma:** see [Remote Figma for CI/CD](#remote-figma-for-cicd). Solve via REST API fallback because Figma MCP requires the desktop app.
- **axe-mcp-server:** needs a running browser instance — share the headless Chromium from the chrome-devtools step.
- Make each MCP optional (env-var-gated) and lazy: a pipeline that only needs ADO shouldn't pay the cold-start cost of spinning up Chrome.

## Install branch-guard and safety hooks in pipelines

**Added:** 2026-05-06
**Problem:** Local Claude has `branch-guard` (blocks commits to `main`/`develop`) and source/rule file warnings (CLAUDE.md "Hook Profiles"). Pipelines have zero hooks installed. The pipeline runs in `bypassPermissions` mode with a service-account PAT that can push to protected branches — the only thing stopping a runaway agent from committing to `main` is the headless-autonomy rule and ADO branch policies. Both are advisory. Branch-guard would be a hard stop.
**Scope:**
- `plugins/dx-automation/hooks/hooks.json` — pipeline-specific hook config
- `plugins/dx-automation/data/scripts/pipeline-agent.js` (the SDK `query()` options need to load hooks; currently hooks are not wired in)
- `plugins/dx-core/hooks/hooks.json` — the existing branch-guard, may need a `DX_PIPELINE_MODE=true`-aware variant
**Done-when:** `DX_PIPELINE_MODE=true node pipeline-agent.js "<prompt that tries git push origin main>"` exits non-zero with the branch-guard message before the push happens.
**Approach:** The Agent SDK's `query()` does load hooks from `settingSources: ["user", "project"]`. The runner can drop a `.claude/settings.json` into the workspace at pipeline start that points to the plugin hooks. Verify hook execution in CI with a dry-run YAML before relying on it for safety.

## Verify CLAUDE.md / AGENTS.md auto-load in SDK

**Added:** 2026-05-06
**Problem:** Locally, Claude auto-loads `CLAUDE.md` from the working directory (the system prompt confirms this). Unclear whether `pipeline-agent.js` (SDK) does the same — `settingSources: ["user", "project"]` is set at line 268 but no test confirms `CLAUDE.md` content actually reaches the model in the pipeline. If it doesn't, every pipeline run is operating without the project's contributor guide.
**Scope:** `plugins/dx-automation/data/scripts/pipeline-agent.js`, plus a smoke test under `plugins/dx-automation/skills/auto-test/`.
**Done-when:** A pipeline run with a prompt like `"What does CLAUDE.md say about hardcoding values?"` returns a correct answer referencing the actual file content. Add this as a fixture in `auto-eval`.
**Approach:** If SDK does NOT auto-load CLAUDE.md, add an explicit `systemPrompt` parameter that reads `CLAUDE.md` (and `AGENTS.md` as fallback) from `cwd` at startup. Document the behavior in `auto-init`.
