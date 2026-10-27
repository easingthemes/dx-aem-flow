# SuperPlane vs dx plugins — evidence-based comparison

**Date:** 2026-10-27
**SuperPlane snapshot:** shallow clone of `superplanehq/superplane` (`main`, single commit dated 2026-10-27). Read only; nothing in it was built or executed.
**dx snapshot:** this repo (`dx-core`, `dx-hub`, `dx-aem`, `dx-automation`) at the same date.

Every SuperPlane claim cites a path relative to the SuperPlane repo root. Every dx claim cites a path in this repo. "Not verified" means the source did not answer the question in the files read; it does not mean the feature is absent.

---

## TL;DR

- **They are different kinds of product.** SuperPlane is a stateful, multi-tenant Go service (Postgres + RabbitMQ + workers + runner fleet + React UI) that *hosts* a "factory" turning backlog issues into PRs. dx is a set of Claude Code plugins (Markdown skills + shell/JS helpers) that run *inside* a developer's agent session or an ADO pipeline job, with no server of its own.
- **Azure DevOps: SuperPlane has no support; dx is ADO-first.** No ADO integration exists among SuperPlane's 51 integration packages, and a repo-wide grep for `azure devops`, `azuredevops`, `azure_devops`, `dev.azure.com` and `visualstudio.com` returns nothing. The `azure` integration is Azure *cloud* (VMs, blobs, container images). The factory's Git host seam is GitHub-only; Bitbucket returns `ErrNotSupported` (`pkg/factories/vcs/provider.go`).
- **SuperPlane is far stronger at durable orchestration, observability, cost accounting and RBAC.** These are database-backed (`pkg/models/canvas_run.go`, `pkg/models/workspace_usage_event.go`, `rbac/rbac_model.conf`). dx gets durability from git branches and visibility from pipeline logs and ADO comments.
- **dx is stronger on domain depth for its niche** (ADO work items, AEM/JCR, Figma, a11y), on zero-infrastructure deployment, and on per-skill guardrails for small changes (for example dx-simple's 9 confidence gates and hard scope caps).
- **Neither is complete.** SuperPlane's audit-log entitlement has no implementation yet (`pkg/licensing/features.go`). dx documents a token budget and a pipeline capability policy, but no code in this repo enforces either.

---

## Comparison table

| Dimension | SuperPlane | dx plugins |
|---|---|---|
| Form factor | Go modular monolith + React UI + runner/fleet manager (`docs/contributing/architecture.md`, `cmd/{server,runner,fleetmanager,cli,admin}`) | Claude Code plugins: Markdown skills/agents + bash/JS helpers (`plugins/*/skills/*/SKILL.md`) |
| Size (rough) | ~513k lines of non-test Go in `pkg/ ee/ cmd/`; ~397k lines of Go tests | ~27k lines of `SKILL.md`; ~17k lines of sh/js/mjs |
| Core unit | Factory → Work order → Line → Automation (Canvas app) → Run (`README.md`, `pkg/models/factory_*.go`) | Skill → spec dir `.ai/specs/<id>-<slug>/` → config `.ai/config.yaml` (`CLAUDE.md`) |
| Durable state | PostgreSQL rows: work orders, line dispatches, runs, executions, events (`pkg/models/`) | Git: per-ticket branch with committed `resume-state.json` (`plugins/dx-core/skills/dx-simple/scripts/save-state.sh`, `.../dx-bug-all/scripts/save-state.sh`) |
| Execution | Event router → RabbitMQ queue → node executor workers (`docs/contributing/architecture.md`, `pkg/workers/event_router.go`, `pkg/workers/node_executor.go`); agent tasks on runners (`pkg/runners/README.md`) | Claude Code session (local) or Agent SDK inside an ADO pipeline job (`plugins/dx-automation/data/scripts/pipeline-agent.js`) |
| Triggers | Webhook, schedule, manual start, onRun, onBroadcast, onError, onWorkOrder, plus integration triggers (`pkg/triggers/*`, `pkg/components/factory/on_work_order.go`) | ADO Service Hook → Incoming WebHook → `resources.webhooks` (`plugins/dx-automation/data/pipelines/cli/ado-cli-simple.yml`); optional Lambda routers (`data/lambda/wi-router.mjs`, `pr-router.mjs`); manual `/skill` |
| Intake sources | GitHub issues, Jira, Linear, Sentry, PagerDuty, Datadog, Dependabot, Productive (`pkg/models/factory_intake.go`) | ADO work items, Jira (`tracker.provider: ado \| jira`, `CLAUDE.md`) |
| Retry / recovery | Step retry on the same dispatch (`RetryLineStep`, `pkg/models/factory_work_order_line_dispatch.go:490`); PR feedback loops, default 3 attempts, range 1–10 (`pkg/grpc/actions/factories/pr_feedback_template.go:41-43`); canvas-wide `onError` trigger (`pkg/triggers/onerror/onerror.go`) | Human-re-triggered resume from branch state, `max-attempts` default 3 (`dx-simple/SKILL.md`, `dx-bug-all/SKILL.md`); Lambda retry + DLQ (`data/lambda/lib/retry.js`, `dlq.js`) |
| Approvals | `approval` component with anyone/user/role/group approvers (`pkg/components/approval/approval.go`) | Interactive checkpoints (`dx-agent-all/SKILL.md`); the PR reviewer never casts a blocking or approving vote when MUST-FIX exists (`dx-pr-review/SKILL.md:88`); humans merge |
| Agent CLIs | Claude Code, Codex, OpenRouter via OpenCode (`pkg/components/runner/{claude,codex,openrouter}/run.js`) | Claude Code (primary); Copilot CLI, VS Code Chat, Codex and Gemini via templates (`CLAUDE.md` § Cross-Platform) |
| Sandbox | Ephemeral runner per task: one VM per runner on AWS/Azure/GCP, or Docker (`pkg/fleets/README.md`, `pkg/runners/agent/docker_executor.go`) | Microsoft-hosted ADO agent (`pool: vmImage: ubuntu-latest`, `ado-cli-simple.yml`) or the developer's machine |
| Agent permissions | Claude: `--permission-mode acceptEdits`, `--allowedTools Bash,Read,Edit,Write` + MCP; planning sessions read-only (`pkg/components/runner/claude/run.js:98-186`). Codex: `--dangerously-bypass-approvals-and-sandbox` (`codex/run.js:199`) | `permissionMode: "bypassPermissions"` with `allowedTools` defaulting to `Skill,Read,Glob,Grep,Agent` (`pipeline-agent.js:41,312`); PreToolUse hooks (`plugins/dx-core/hooks/hooks.json`) |
| Verification feedback | Merge-confidence checks: risk, performance, security, drift, reversibility, scored 0–5 (`pkg/components/factory/merge_confidence_check.go`); CI/discussion feedback handlers (`pkg/models/factory_pr_feedback_handler.go`) | `dx-step-verify` 6-phase loop (max 3 cycles); dx-simple gates G1–G9 incl. visual diff (`dx-simple/SKILL.md`) |
| Integrations | 51 packages (list below); **no Azure DevOps** | MCP: ADO, Atlassian (project-level), Figma, axe (`plugins/dx-core/.mcp.json`), AEM, Playwright (`plugins/dx-aem/.mcp.json`) |
| ADO support | **No** (grep evidence above) | **Yes**, the only implemented SCM (`scm.provider: ado`, `CLAUDE.md`) |
| Observability | Run/event history in DB, live log streaming, OTel config (`otel-collector-config.dev.yaml`, `pkg/telemetry/`), per-automation run/fail/duration/cost (`pkg/models/factory_automation_runs.go`) | Pipeline logs with per-turn token counts and `total_cost_usd` (`pipeline-agent.js:129-150,432`); ADO comments; optional CloudWatch alarms (`auto-alarms`) |
| Cost tracking | Append-only `workspace_usage_events` for model tokens and VM seconds, BYOK vs hosted (`pkg/models/workspace_usage_event.go`) | Logged per run only. The `/auto-status` token budget relies on `eval/cost-report.js`, which this repo does not ship; no enforcing code found |
| RBAC / tenancy | Casbin, org-scoped; built-in roles `org_admin`, `org_maintainer`, `org_operator` (`rbac/rbac_model.conf`, `rbac/rbac_org_policy.csv`); custom roles and groups are EE (`ee/rbac/`) | None of its own: inherits the ADO identity, PAT or build-service permissions |
| Deployment | SaaS, Helm chart, or single-host tarball (app, Fleet Manager, Postgres, RabbitMQ, Caddy) (`docs/contributing/single-host-release.md`, `release/superplane-helm-chart`) | `/plugin install`; pipelines imported into ADO (`/auto-pipelines`); optional AWS (`/auto-provision`) |
| Extending | Go integration package + TS UI mapper + generated docs (`docs/contributing/integrations.md`, `building-an-integration.md`) | Add `skills/<name>/SKILL.md` (+ scripts); projects can shadow skills or override rules (`CLAUDE.md`) |
| Testing | ~1,589 `*_test.go` files, Playwright-Go E2E (`test/e2e/`), Semaphore CI (`.semaphore/semaphore.yml`) | 21 discovered bash/JS suites in CI, structural validators, 2 behavioral eval suites that are not in CI (`CLAUDE.md` § Testing) |
| License | Apache-2.0, except `ee/` under the proprietary EE license (`LICENSE`, `ee/LICENSE`) | MIT (`LICENSE`) |

---

## 1. Purpose and positioning

**SuperPlane** calls itself an "open source factory for one-shot engineering" that "turns high-confidence backlog issues into verified, review-ready pull requests" (`README.md`). It continuously decides which backlog items an agent can handle with high confidence and leaves ambiguous work with humans. That decision is a product feature: planning sessions score each task on Clarity, Complexity and Verifiability, 1–3 (`pkg/models/factory_planning_session_analysis.go`, rubric in `.agents/skills/refine-task-scoring/SKILL.md`). The wider engine is a general workflow canvas with 51 integrations (`AGENTS.md` § Project Overview).

**dx** is a toolkit for developers and pipelines on Azure DevOps (with optional Jira), with deep AEM support. It covers the whole story lifecycle (requirements → plan → steps → verify → PR → DoD) as composable skills (`docs/reference/skill-catalog.md`). It also ships autonomous ADO pipeline agents (DoR, DoD, PR review, PR answer, BugFix, QA, Dev, Doc, Estimation, Simple) (`plugins/dx-automation/data/pipelines/cli/`).

**Overlap:** both aim at "ticket → verified PR with guardrails." SuperPlane is the platform that runs agents. dx is the knowledge and procedure the agent follows. In principle, a dx skill could run *inside* a SuperPlane line as an agent prompt (not verified; it would need a GitHub repo, see §9).

## 2. Core abstractions

### SuperPlane

| Concept | Evidence |
|---|---|
| **Factory**: a team workspace with work orders, lines and policies | `README.md`; `pkg/models/factory.go` |
| **Work order**: one delegated task. States `draft/open/closed`; results `completed/rejected/failed/archived/pr_closed/manual_rejected`. Transitions are checked against an allow-list | `pkg/models/factory_work_order.go:18-66` |
| **Line**: ordered steps. Each step is `runApp` (a Canvas app + entrypoint, which must be the `onRun` trigger) with `MaxParallelism`, default 10, never unbounded | `pkg/models/factory_line.go:14-47` |
| **Automation**: a Canvas-backed app. Built-in catalog: Task analysis, Scheduled intake, Implement, Issue label intake, PR closure, Merge confidence, Visual Evidence, PR discussion, PR checks, plus one intake per source | `pkg/grpc/actions/factories/built_in_automation_catalog.go:18-34` |
| **Run**: `pending/started/cancelling/finished`, `passed/failed/cancelled`, with parent run, callbacks, input and error list (capped at 50) | `pkg/models/canvas_run.go:19-52,1217` |
| **Canvas**: a versioned graph of nodes and edges. Edits stage, then commit to go live | `docs/contributing/architecture.md` § Canvas |

### dx

| Concept | Evidence |
|---|---|
| **Skill**: a Markdown procedure. Branching skills use a DOT digraph as the flow | `CLAUDE.md` § Flow Control |
| **Agent**: a subagent definition with a model tier | `plugins/*/agents/*.md` |
| **Spec dir**: `.ai/specs/<id>-<slug>/` with conventional filenames. Skills find each other's output there | `CLAUDE.md` § Spec Directory |
| **Config**: `.ai/config.yaml`. Three-layer overrides (`.ai/rules/` > config > plugin defaults) | `CLAUDE.md` § Config-Driven |
| **Pipeline agent**: an ADO YAML pipeline that runs `pipeline-agent.js "<prompt>"` | `plugins/dx-automation/data/pipelines/cli/*.yml` |

**Assessment:** SuperPlane's abstractions are first-class database entities with state machines. dx's abstractions are conventions (filenames, YAML keys, branch names). Conventions are cheaper and easier to read, but nothing enforces them at runtime beyond the helper scripts and validators.

## 3. Execution model and durable state

**SuperPlane.** Events are stored as `pending`. An event-router worker routes them along graph edges into queue items, RabbitMQ delivers them, and executor workers run the components, which emit new events (`docs/contributing/architecture.md` § Core Event Processing). Agent work runs on **runners**. A runner exchanges a single-use registration token, connects over WebSocket, executes on a host or in Docker, uploads log chunks in order, and reports completion only after every chunk is acknowledged. An ephemeral runner exits after one task (`pkg/runners/README.md`). The default task timeout is 3600 s; a request may ask for up to 86400 s (`pkg/components/runner/spec.go:19-24`). The README claims that "a failed run can resume without custom glue or lost context" (`README.md`). The supporting mechanism found is step-level retry on an existing dispatch, with history kept (`pkg/models/factory_work_order_line_dispatch.go:484-490`). Mid-step resume of an agent conversation for line automations: **not verified**. `conversation_rewind.go` exists in `pkg/agents/`, but `follow_up_loop.js` says it is for planning sessions only.

**dx.** Each run is a single agent process. Durability is a design pattern on top: the per-ticket branch is the state store, `save-state.sh` commits and pushes `resume-state.json` at every checkpoint, and `resume-check.sh` finds the branch by an anchored ticket-id match. It dispatches `fresh | resume-forward | resume-blocked-input | resume-blocked-hard | done | ambiguous-branch` (`plugins/dx-core/skills/dx-simple/scripts/resume-check.sh:1-40`). Concurrent resumes are detected through a non-fast-forward push (exit 3, `dx-bug-all/scripts/save-state.sh`). Wall-clock limits: `timeoutInMinutes: 45` (`ado-cli-simple.yml:341`); `MAX_TURNS` defaults to 30 and `TIMEOUT_MINUTES` to 60 (`pipeline-agent.js`).

**Assessment:** SuperPlane has real workflow-engine durability: transactional DB state, queues, parallelism caps and cancellation. dx's git-as-state-store is clever and needs no infrastructure. But only `dx-simple` and `dx-bug-all` have it (DoR is stateless by design), it depends on `.ai/specs/` being tracked in git, and it covers coarse phases, not individual tool calls.

## 4. Triggers and events

- **SuperPlane:** core triggers `webhook`, `schedule`, `start`, `onRun`, `onBroadcast`, `onError` (`pkg/triggers/*`), plus `onWorkOrder` (`pkg/components/factory/on_work_order.go`). Integrations add their own, for example Jira `on_issue` and `on_issue_comment` (`pkg/integrations/jira/`). Bitbucket PR events arrive via Atlassian Forge (`forge/bitbucket/README.md`). Scheduled intake exists (`docs/contributing/scheduled-intake.md`).
- **dx:** an ADO comment containing an agent token (`@kai-simple`, `@kai-bugfix`, `@kai-dor`) fires a Service Hook → Incoming WebHook → `resources.webhooks` listener filtered by `eventType` and work-item type (`ado-cli-simple.yml:50-58`). The bot never writes the literal token, so it cannot trigger itself (`dx-simple/SKILL.md` § Recovery config). Other WI agents are routed by the hub pipeline or the optional `wi-router.mjs`, which matches tags (`wi-router.mjs:19-29`). The PR reviewer runs from a build-validation policy.

**Assessment:** SuperPlane triggers are general and composable. dx triggers are narrow but ADO-native and serverless.

## 5. Retries and recovery

- **SuperPlane:** `RetryLineStep` keeps earlier steps on the same history (`factory_work_order_line_dispatch.go:484-490`). PR feedback handlers (sources `pull-request-discussion` and `pull-request-checks`) send review comments and CI failures back to an agent canvas, with `MaximumAttempts` defaulting to 3 and bounded 1–10 (`pkg/models/factory_pr_feedback_handler.go`, `pkg/grpc/actions/factories/pr_feedback_template.go:41-43`). A canvas-wide `onError` trigger fires on any failed execution (`pkg/triggers/onerror/onerror.go`). Generic constant-wait retry helper: `pkg/retry/retry.go`. The only feedback-handler subject is `github-pull-request`.
- **dx:** in pipeline mode, recovery is **never automatic**. A blocked run posts a question; a human reply with the token resumes it, and attempts are capped by `*.recovery.max-attempts`, default 3 (`dx-simple/SKILL.md`, `dx-bug-all/SKILL.md:106-113`). Local `dx-bug-all` retries once (`dx-bug-all/SKILL.md:10`). `dx-step-all` stops after 2 consecutive fix failures on the same step (skill description). The Lambda routers have retry and a DLQ (`data/lambda/lib/retry.js`, `dlq.js`).

**Assessment:** SuperPlane closes the CI-failure → agent → re-push loop automatically. dx deliberately keeps a human in the loop for recovery, which is safer but slower, and it has no automatic "CI failed, fix it" loop wired to PR checks (`dx-pr-answer` handles review *comments*, not check failures).

## 6. Approvals and human-in-the-loop

- **SuperPlane:** an `approval` canvas component with approver items `anyone | user | role | group` and outputs `approved/rejected` (`pkg/components/approval/approval.go`). E2E coverage in `test/e2e/approvals_test.go`. Work orders can be rejected or sent back to draft (`factory_work_order.go:58-66`). The VCS seam can merge PRs (`MergePullRequest`, `pkg/factories/vcs/provider.go`). Whether merges are automatic by default: **not verified**.
- **dx:** `dx-agent-all` interactive mode pauses after each phase (`dx-agent-all/SKILL.md:72`). In automation the PR reviewer votes but is clamped: never a blocking vote, and never a positive vote while a MUST-FIX exists (`dx-pr-review/SKILL.md:88`). dx never merges. A pipeline approval gate in the ADO sense (environment checks) is not used by dx: **not verified** beyond the YAML files read.

## 7. Agent supervision

| Aspect | SuperPlane | dx |
|---|---|---|
| Invocation | `claude --bare -p --output-format stream-json ... --permission-mode acceptEdits --allowedTools ... --mcp-config ...` (`pkg/components/runner/claude/run.js:380-418`) | Claude Agent SDK `query()` with `permissionMode: "bypassPermissions"`, plugins loaded from disk, MCP from env (`pipeline-agent.js:303-317`) |
| Tool scope | `Bash,Read,Edit,Write` + SuperPlane MCP + workspace MCP; planning = `Read,Bash` only, with a long comment explaining why `plan` mode is not used (`claude/run.js:98-186`) | `Skill,Read,Glob,Grep,Agent` by default, extended per pipeline via `ALLOWED_TOOLS` (`pipeline-agent.js`) |
| Isolation | Ephemeral VM per runner (Azure: no public IP, NSG on the NIC, `pkg/fleets/README.md`) or a Docker container. The visible `docker run` args set no `--network`, `--cap-drop` or resource limits (`pkg/runners/agent/docker_executor.go:149-170`). `pkg/networkpolicy/http.go` blocks metadata/private hosts; whether it applies inside runner tasks or only to server-side HTTP: **not verified** | Microsoft-hosted ephemeral agent VM per job; no extra sandbox |
| Failure feedback | Structured: merge-confidence scores, check rows with score history (`pkg/models/factory_work_order_check.go`), CI/discussion feedback loops | Return contracts and ADO comments; `dx-step-fix` heals by inserting corrective steps; gate failures take the ABORT path with rollback (`dx-simple/SKILL.md` § ABORT, `scripts/rollback-authoring.sh`) |

Both grant broad shell access inside a throwaway machine. SuperPlane's Codex path explicitly disables Codex's own sandbox (`codex/run.js:199`), so the isolation is the runner and nothing else.

## 8. Guardrails and policies

- **SuperPlane:** parallelism caps per line step (`factory_line.go`); merge-confidence checks with server-owned thresholds, where checks not enabled in the runner token are rejected (`merge_confidence_check.go:35-90`); work-order transition allow-lists; task scoring before dispatch; network block lists (`pkg/networkpolicy/http.go`); repo-level rules such as "NEVER DROP LOCAL DATABASES" are for contributors, not the product (`AGENTS.md`).
- **dx:** hard gates in scripts, not prose. `dx-simple` caps scope at ≤5 files, ≤50 lines and ≤10 JCR writes (`scripts/scope-check.sh:15-17`), checks repo identity (`scripts/repo-guard.sh`), runs a visual diff (`scripts/visual-diff.sh`) and blocks `mvn deploy` (`hooks/block-mvn-deploy.sh`). Plugin hooks include a branch guard (`plugins/dx-core/hooks/scripts/branch-guard.sh`). The PR-answer gate is `data/scripts/pr-answer-gate.sh`. Lambda adds dedupe and per-pipeline/per-identity daily rate limits (`data/lambda/lib/dedupe.js`, `rate-limiter.js`), which fail open without AWS credentials (`rate-limiter.js:46`).
- **dx weakness:** `data/policy/pipeline-policy.yaml` describes fail-closed per-agent allowed/forbidden actions and risk levels, but no loader for it was found in this repo. Its only reference is a skip pattern in `plugins/dx-core/data/hooks/stop-guard.sh:47`. Treat it as documentation, not enforcement.

## 9. Integrations

**SuperPlane, all 51 packages under `pkg/integrations/`:** aws, azure, bitbucket, circleci, claude, cloudflare, cloudsmith, coolify, cursor, customllm, dash0, datadog, daytona, digitalocean, discord, dockerhub, elastic, firehydrant, gcp, github, gitlab, grafana, harness, hetzner, honeycomb, incident, jfrog_artifactory, jira, launchdarkly, linear, logfire, newrelic, oci, octopus, openai, openrouter, pagerduty, perplexity, productive, prometheus, render, rootly, semaphore, sendgrid, sentry, servicenow, slack, smtp, statuspage, teams, telegram.

**Azure DevOps: no.**
- No `pkg/integrations/azuredevops` (or similar) package.
- A repo-wide case-insensitive grep for `azure devops|azuredevops|azure_devops|dev.azure.com|visualstudio.com` returns zero files.
- `pkg/integrations/azure/` covers VM start/stop/restart/deallocate/delete/create and blob/image events only.
- **Factory** workflows (work order → PR) are GitHub-only. The VCS seam says "GitHub is the implementation used when the provider is empty. Bitbucket returns ErrNotSupported", and any other provider falls back to the GitHub client (`pkg/factories/vcs/provider.go:1-4,63-70`). PR feedback handlers accept only `github-pull-request` (`factory_pr_feedback_handler.go`). Factory app templates exist only for `github/` and `bitbucket/` (`pkg/grpc/actions/factories/templates/`). GitLab is a canvas integration (`pkg/integrations/gitlab/`), not a factory forge.

**dx:** ADO MCP and Atlassian MCP at project level; Figma and axe (`plugins/dx-core/.mcp.json`); AEM and Playwright (`plugins/dx-aem/.mcp.json`). SCM is ADO only, and no GitHub or GitLab code path exists by design (`CLAUDE.md` § Config-Driven). No observability, incident or chat integrations.

**Assessment:** SuperPlane is broad across DevOps tooling but missing ADO entirely. dx is narrow and deep on ADO and AEM. For an ADO shop SuperPlane would need a new integration *and* a new VCS provider implementation, which is a core change, not just a plugin.

## 10. Observability and cost tracking

- **SuperPlane:** every run, event and execution is persisted. Live logs are streamed and compacted (`pkg/workers/runner_task_log_compactor.go`). There is an OTel collector config and a telemetry package (`otel-collector-config.dev.yaml`, `pkg/telemetry/`). Per-automation window summaries cover runs, failures, mean duration and cost (`pkg/models/factory_automation_runs.go`). Spend is an append-only ledger of model tokens and runner VM-seconds, tagged BYOK or hosted, per org, factory and work order (`pkg/models/workspace_usage_event.go`). Velocity reports come from merged PRs (`pkg/models/factory_velocity.go`).
- **dx:** per-turn input, output and cache tokens plus the SDK's `total_cost_usd` go to the pipeline log (`pipeline-agent.js:129-150,432`). There are optional CloudWatch alarms on DLQ, errors and throttles (`/auto-alarms`). `/auto-status` presents a monthly token budget with `normal|suggest-only|halted` modes, but the script it calls (`eval/cost-report.js`) is not in this repo and no budget check was found in the Lambda routers. **Weakness:** no aggregated, queryable cost history across runs.

## 11. RBAC and multi-tenancy

- **SuperPlane:** Casbin with a domain-scoped model (`rbac/rbac_model.conf`). Default org roles are `org_admin`, `org_maintainer` and `org_operator` (`rbac/rbac_org_policy.csv`). It is enforced at the gRPC interceptor (`pkg/authorization/interceptor.go`, per `AGENTS.md`). Organizations are the tenant boundary; accounts map to per-org users; OIDC is optional (`docs/contributing/architecture.md`). Custom roles and groups are EE-licensed (`ee/rbac/`, `pkg/licensing/features.go`). An `audit_logs` entitlement is defined "without a product implementation yet" (`pkg/licensing/features.go:13-15`).
- **dx:** no RBAC layer. Agents act as the PAT or build-service identity, so access is whatever ADO grants that identity. Bot-loop and identity gates exist only for PR Answer, in `pr-router.mjs` (`CLAUDE.md`).

## 12. Deployment and operating cost

- **SuperPlane:** options are SaaS, a Helm chart (`release/superplane-helm-chart`), or a single-host tarball with app, Fleet Manager, Postgres, RabbitMQ and Caddy. Default runner capacity is 5 max and 1 warm (`docs/contributing/single-host-release.md`). Fleet Manager provisions runner VMs on AWS, Azure or GCP, or Docker containers (`pkg/fleets/README.md`). Ongoing costs: a database, a broker, an app host, runner VMs, LLM spend, and upgrades across separately versioned app, runner and fleet-manager artifacts. Dollar figures: **not verified**.
- **dx:** `/plugin install` and `/dx-init`. Pipeline agents cost ADO hosted-agent minutes plus LLM tokens. The Lambda path optionally adds DynamoDB, SQS, S3, SNS, Lambda and API Gateway (`/auto-provision`). There is no always-on service unless the Lambda path is chosen.

## 13. Extensibility

- **SuperPlane, new integration:** a Go package in `pkg/integrations/<name>/` that registers via `registry.RegisterIntegration`, with triggers and components implementing typed `Configuration()` specs, a TypeScript UI mapper, generated docs (`make gen.components.docs`), unit tests, a claimed ticket and a video demo in the PR (`docs/contributing/integrations.md`, `building-an-integration.md`, `component-implementations.md`). Users can also compose canvases in the UI without code. Bounties are offered (`docs/contributing/bounties.md`).
- **dx, new capability:** add `plugins/<p>/skills/<name>/SKILL.md` and optional scripts; structural validators check naming and frontmatter. Consumers can shadow any skill (`.claude/skills/<name>/SKILL.md`) or override rules (`.ai/rules/`) without forking (`CLAUDE.md`). A new SCM provider would mean rewriting every skill that calls `mcp__ado__*`.

The cost of extension is very different: Go, protobuf, UI and DB migration for SuperPlane against Markdown for dx. dx's extensibility is also less safe: a skill is model instructions, so a structural check cannot prove that it works.

## 14. Testing approach

- **SuperPlane:** about 1,589 `*_test.go` files; DB-backed E2E with Playwright-Go (`test/e2e/*`, for example `approvals_test.go`); UI unit tests with Bun and Happy DOM; Semaphore CI plus release pipelines (`.semaphore/`); a test-audit contributor skill (`.agents/skills/test-audit/`). Testing is conventional for deterministic code. No eval harness for agent *output quality* was found (no `*eval*` directories), so prompt-quality regression testing is **not verified**.
- **dx:** 21 discovered bash/JS suites, hermetic and run in CI; structural validators including `claude plugin validate`; 2 behavioral eval suites (`plugins/dx-core/evals/`) that are not wired to CI because of cost (`CLAUDE.md` § Testing). dx is weaker on breadth, but it has at least an explicit framework for measuring skill behavior.

## 15. License

- **SuperPlane:** Apache-2.0 for everything outside `ee/`. `ee/` uses a proprietary EE license: use requires agreeing to the SuperPlane Terms and holding a valid EE license for self-hosted deployments; modifications remain SuperPlane's property; copying, distributing and selling are forbidden; development and testing use is allowed (`ee/LICENSE`). `ee/` currently contains `billing/` (Polar-backed seats, credits and price books) and `rbac/` (custom roles and groups). EE code ships in the single binary and is gated at runtime; core must not import `ee/` (`ee/README.md`). The README states "available under the Apache License 2.0" without mentioning `ee/` (`README.md` § Community and license).
- **dx:** MIT for the whole repo (`LICENSE`).

## 16. Maturity signals

| Signal | SuperPlane | dx |
|---|---|---|
| Codebase scale | ~513k lines of Go plus a React app | ~27k lines of skills, ~17k lines of scripts |
| Schema evolution | 632 migration files (`db/migrations/`) | N/A |
| Release engineering | Separate versioned app, runner, fleet-manager and CLI releases, SBOMs, Helm and single-host (`release/`, `.semaphore/*release*.yml`) | semantic-release bumping plugin manifests (`CLAUDE.md`) |
| Community | Discord, bounties, contributor process with DCO (`README.md`, `AGENTS.md`) | Single copyright holder (`LICENSE`) |
| History depth | **Not verified**: shallow clone with 1 commit | **Not verified**: shallow clone with 50 commits |
| Known gaps stated in code | Bitbucket factory unsupported; audit logs unimplemented | Token budget and pipeline policy not enforced; PR Answer still Lambda-only |

---

## Where each is weaker

**dx is weaker at:**
1. Durable orchestration. There is no engine, queue or DB, and recovery exists in only two skills and needs a human to re-trigger it.
2. Observability and cost: logs only, no aggregated spend, and budget enforcement is documented but absent in this repo.
3. Multi-tenancy and RBAC: none of its own.
4. Automatic CI-failure feedback loops to the agent.
5. Integration breadth: one SCM, two trackers, no chat, incident or observability integrations.
6. Enforcement of declared policy (`pipeline-policy.yaml` is unenforced).

**SuperPlane is weaker at:**
1. Azure DevOps: none, in either the canvas integrations or the factory VCS seam.
2. Operating cost and complexity: a stateful service with Postgres, RabbitMQ, a fleet manager and runner VMs, against zero infrastructure for dx.
3. Domain depth: no AEM, Figma or a11y skills. Factory skills shipped in `templates/skills/` contain one file (`hetzner.s3.md`).
4. License clarity: the README advertises Apache-2.0, while billing and RBAC extensions sit under a restrictive EE license in the same binary.
5. Agent quality evaluation: no eval harness for agent output found.
6. Runner sandbox hardening in Docker mode: none visible in the run args, and Codex runs with its own sandbox disabled.

## Possible takeaways for dx (not commitments)

- **Automatic PR-check feedback loop** with a bounded attempt count, mirroring SuperPlane's `pull-request-checks` handler (default 3, max 10).
- **Pre-dispatch confidence scoring** (Clarity / Complexity / Verifiability) as a structured DoR output that gates autonomous agents.
- **Either enforce or remove** `pipeline-policy.yaml` and the token-budget claims, so the docs match the code.
- **Persist per-run usage** (tokens, cost, duration) to a durable sink, for example a committed `run-history[]` entry, which already exists in `resume-state.json` for dx-bug-all.
