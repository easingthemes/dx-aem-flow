# TODO: Clean Up Old Automation

## Clean Up Old Automation in Plugin — DONE

**Added:** 2026-03-22
**Completed:** 2026-03-22 — commit `1800b25`
**Problem:** `plugins/dx-automation/data/` contained ~40 files of obsolete custom JS agents, old pipelines, old eval framework, old runner scripts. Only CLI approach (`pipelines/cli/` + `pipeline-agent.js`) was current. Dead code caused confusion.
**Scope:** `plugins/dx-automation/data/agents/` (22 files), `data/eval/` (9 files), `data/docs/` (5 files), `data/pipelines/eval/` (1 file), `data/run.sh`, `data/setup-cli.sh`, `data/repos.template.json`.
**Done-when:** `ls plugins/dx-automation/data/agents/ 2>&1` returns "No such file or directory" AND `grep -r "agents/lib" plugins/dx-automation/skills/auto-init/SKILL.md` returns no matches.
**Resolution:** Deleted 40 files (-6,370 lines). Updated `auto-init` to stop scaffolding deleted files. Updated `auto-test` to use `pipeline-agent.js`.

**Note:** Existing consumer repos may still have old files in `.ai/automation/agents/`, `.ai/automation/eval/`, etc. That's a per-repo cleanup task, not a plugin issue.

## Budget Tracking

**Added:** 2026-03-28
**Problem:** Automation agents (DoR checker, PR reviewer, DevAgent, etc.) run 24/7 on ADO pipelines with no visibility into token consumption per agent. Cost overruns are invisible until the monthly bill arrives. Paperclip (companies.sh) solves this with per-agent monthly token budgets that halt agents when exhausted.
**Scope:** `plugins/dx-automation/` — all `auto-*` skills, `pipeline-agent.js`, `.ai/config.yaml` schema, `.ai/automation/prompts/`.
**Done-when:** `grep -r "budget" plugins/dx-automation/skills/auto-init/SKILL.md` returns a match AND `.ai/config.yaml` template contains an `automation.budget:` section AND `pipeline-agent.js` tracks and enforces token limits per agent run.
**Approach:** (1) Add `automation.agents.<name>.budget:` section to config.yaml schema with monthly token cap per agent. (2) Instrument `pipeline-agent.js` to log token usage per run to a DynamoDB table or CloudWatch metric. (3) Add a pre-run budget check that skips execution if monthly cap is reached. (4) Add `/auto-budget` skill to report usage across agents. Defer until local flow is solid — this is a post-stabilization improvement.

## CI/CD pipeline portability (non-ADO)

**Added:** 2026-04-25
**Problem:** dx-automation pipelines target Azure DevOps exclusively — pipeline YAMLs in `plugins/dx-automation/data/pipelines/cli/` are ADO-specific (`azure-pipelines` schema, ADO service-hook triggers, ADO task-group references). Projects on GitHub Actions, GitLab CI, Jenkins, or CircleCI cannot install dx-automation. dx-core and dx-aem are CI-agnostic — only dx-automation is locked to ADO.
**Scope:** `plugins/dx-automation/data/pipelines/cli/`, `plugins/dx-automation/skills/auto-pipelines/`, `plugins/dx-automation/skills/auto-webhooks/` (service hook → API Gateway plumbing), `plugins/dx-automation/skills/auto-init/SKILL.md` (Platform Compatibility section already documents the constraint).
**Done-when:** `ls plugins/dx-automation/data/pipelines/` shows at least one non-`cli/` subdirectory (e.g., `github-actions/`) AND `auto-init` Phase 2 picks the right pipeline template based on `scm.provider` from `.ai/config.yaml` AND a non-ADO project can run `/auto-init` end-to-end without producing ADO-flavored YAMLs.
**Approach:** GitHub Actions is the highest-value second target (dx-init already has provider-aware work tracked in `todo-provider-support.md`). Lambda agent runtime stays the same — only the pipeline YAML and webhook plumbing differ. Service hook → API Gateway becomes `repository_dispatch` → API Gateway, or alternatively a workflow-side direct invoke. Defer until at least one consumer asks; current installs are ADO-only.

## `build.compile` deploys to localhost in pipelines

**Added:** 2026-05-28
**Problem:** `build.command` in `.ai/config.yaml` is typically `mvn clean install -PautoInstallPackage` which DEPLOYS to localhost AEM. Pipelines that invoke `/dx-step-build` use this command and fail because localhost AEM isn't reachable from the pipeline VM. Skills should honor `DX_PIPELINE_MODE=true` and prefer `build.compile` (e.g., `mvn compile`) — no deploy.
**Scope:** `plugins/dx-core/skills/dx-step-build/SKILL.md`, `plugins/dx-core/skills/dx-agent-dev/SKILL.md`, `plugins/dx-core/skills/dx-agent-all/SKILL.md`.
**Done-when:** `grep -n 'build.compile' plugins/dx-core/skills/dx-step-build/SKILL.md` finds an explicit branch on `DX_PIPELINE_MODE` that prefers compile over `build.command`. `grep -n 'autoInstallPackage' plugins/dx-automation/data/pipelines/` finds no matches in active pipeline YAMLs.
**Approach:** Add `is_pipeline_mode` check at the top of dx-step-build. Read `build.compile-fast` → `build.compile` → fallback. Never `build.command` in pipeline mode.

## AEM MCP localhost dependency in pipelines

**Added:** 2026-05-28
**Problem:** Phases 5, 5+, 5++ of `/dx-agent-all` and `/aem-editorial-guide` assume AEM is at `localhost:4502` (from `aem.author-url`). In pipeline mode, AEM is not available locally. Currently these phases either time out or "succeed" silently with empty results.
**Scope:** `plugins/dx-aem/skills/aem-snapshot/`, `aem-verify/`, `aem-fe-verify/`, `aem-editorial-guide/`. Possibly add an `aem.qa-author-url` config key alongside the existing `aem.author-url`.
**Done-when:** Run any of these skills with `DX_PIPELINE_MODE=true` and an unreachable `aem.author-url` — skill exits non-zero with clear message instead of silently producing empty output.
**Approach:** Each AEM skill should detect pipeline mode and either use `aem.qa-author-url` or skip with a comment.

## Pipeline `ALLOWED_TOOLS` missing MCP tools

**Added:** 2026-05-28
**Problem:** `plugins/dx-automation/data/pipelines/cli/ado-cli-dev-agent.yml` sets `ALLOWED_TOOLS: "Skill,Read,Write,Edit,Glob,Grep,Bash(git *),Agent"` — no MCP tools at all. Skills that call AEM MCP / Chrome MCP / ADO MCP would silently fail. The new `ado-cli-simple.yml` has the right whitelist; other pipelines should match.
**Scope:** All YAMLs in `plugins/dx-automation/data/pipelines/cli/`.
**Done-when:** `grep 'ALLOWED_TOOLS' plugins/dx-automation/data/pipelines/cli/*.yml` shows explicit MCP tool prefixes in every pipeline that uses MCP.
**Approach:** Per pipeline, enumerate the MCP tools the underlying skill calls and append to `ALLOWED_TOOLS`. Wildcards are fine for `mcp__ado__*` if the skill needs many ADO operations.

## Interactive prompts in autonomous pipeline mode

**Added:** 2026-05-28
**Problem:** Several skills (editorial-guide, FE-only confirmation in dx-agent-all) ask "y/n" prompts that block forever in pipeline mode. The pipeline times out and the run hangs.
**Scope:** Audit all skills under `plugins/dx-core/skills/` and `plugins/dx-aem/skills/` for `(y/n)` patterns. Each should detect `DX_PIPELINE_MODE=true` and auto-default (typically "no" / skip).
**Done-when:** `grep -rn '(y/n)\|(yes/no)' plugins/dx-core/skills plugins/dx-aem/skills` finds no patterns without a paired `DX_PIPELINE_MODE` branch.
**Approach:** Sweep each match, add a `DX_PIPELINE_MODE` branch that picks the safe default and continues.

## MCP health check before agent run

**Added:** 2026-05-28
**Problem:** When AEM MCP or Chrome MCP fails to start in a pipeline, the agent doesn't notice — it tries to call tools, gets errors, retries, and burns turns. The first step after MCP startup should be a deterministic health check (e.g., `fetchSites` for AEM, `list_pages` for Chrome) that exits the run if MCP isn't healthy.
**Scope:** `plugins/dx-core/data/lib/mcp-health-check.sh` (extend), pipeline YAMLs (add step before agent invocation).
**Done-when:** Every pipeline YAML has a `health check` step that fails fast if MCP startup didn't succeed.
**Approach:** Run `mcp-health-check.sh aem chrome` as a pre-agent bash step in each pipeline.

## QA AEM network reachability

**Added:** 2026-05-28
**Problem:** Microsoft-hosted ADO agents (`ubuntu-latest`) have egress to the public internet. If your QA AEM is on a private network (VPN-only, IP-allowlisted), pipelines will fail to reach it. Solution: self-hosted agent pool with network access, OR public-but-authed QA AEM, OR IP-allowlist Microsoft-hosted ranges.
**Scope:** Infra documentation (`plugins/dx-automation/README.md`); possibly add a `/auto-doctor` check that hits `aem.qa-author-url` from the pipeline VM and reports reachability.
**Done-when:** README has a "Network requirements" section that explains the three options. `/auto-doctor` (or a new dry-run mode) confirms reachability before /dx-simple is enabled.
**Approach:** Document. Optionally extend `/auto-doctor` to spawn a one-shot pipeline that curls `$AEM_QA_URL/libs/granite/core/content/login.html` and reports 200.

## Pipelines clone `--branch main`, no release pinning

**Added:** 2026-05-28
**Problem:** All 11 ADO CLI pipeline YAMLs (`plugins/dx-automation/data/pipelines/cli/ado-cli-*.yml`) clone the dx-aem-flow plugins repo with `git clone --depth 1 --branch main`. Any push to `main` — including routine `chore:` commits or accidental breakage — affects every consumer's running agents the next time a webhook fires. There is no documented rollback procedure when `main` breaks. Surfaced by PR #147 review.
**Scope:** All 11 pipeline YAMLs in `plugins/dx-automation/data/pipelines/cli/`.
**Done-when:** `grep -n '\\-\\-branch main' plugins/dx-automation/data/pipelines/cli/*.yml` shows no matches (replaced with a release tag or pinned SHA), OR a section in `plugins/dx-automation/README.md` documents the rollback procedure when `main` breaks.
**Approach:** Two viable options: (1) Pin to a release tag (`--branch v2.106.7`) — semantic-release already bumps version files on every merge, so the pipeline can read the tag from a pipeline variable updated as part of release cuts. (2) Document a manual rollback (`git revert` on `main`, delete affected pipeline runs). Option 1 is safer but requires release-cut tooling; option 2 is cheaper. Decide at the project level — not changing in PR #147 because all 11 pipelines share this pattern; fixing only `ado-cli-simple.yml` would diverge from the established convention.
