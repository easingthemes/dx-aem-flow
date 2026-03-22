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
