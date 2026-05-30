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

## `/dx-simple` multi-repo trigger routing (fe / be / both)

**Added:** 2026-05-30
**Problem:** The SimpleAgent trigger is per-repo. A `@kai-simple` comment fires an ADO Service Hook → Incoming WebHook service connection → the `resources.webhooks` listener in `ado-cli-simple.yml`, which only runs in **the one repo where that pipeline is defined**. Projects that split frontend and backend into **separate repos** (e.g. a React/SPA FE repo + a Maven/AEM BE repo) have no way to route a single ticket's `@kai-simple` request to the *correct* repo's dx-simple pipeline. A backend-only change must run the BE pipeline; a frontend-only change must run the FE pipeline; a change touching both must run both. Today the human would have to know which repo's pipeline to trigger, and there's no path for a both-repos change.

There are **two layers** to this: (1) a **router** that dispatches the right repo(s) — the original ask; and (2) a **skill-side self-guard** so each child `/dx-simple` run independently knows whether it's running in the *right* repo. The guard matters even when the router is correct (a human can trigger a child pipeline directly, or the router can misroute), and it owns the case the router can't: when scope is `both` and the skill is in the FE repo, the skill must **not** treat the missing BE work as "out of scope → abort" — it must *know* the BE half is being handled in another repo and confidently apply only its FE slice. Without this awareness a conservative skill bails on legitimate work. Three cases: **wrong repo** (e.g. BE-only change, FE-only repo) → fail-fast + post a comment explaining *why* it stopped; **partial match** (`both`, this is one half) → do this repo's slice, aware the other half runs elsewhere; **fullstack repo** (`role: fullstack`) → do everything, no change from today.
**Scope:**
  - **Skill self-guard:** `plugins/dx-core/skills/dx-simple/SKILL.md` (a new Phase 0.5 identity guard between resume-check and analysis; the ABORT path must post a *why-stopped* comment), `plugins/dx-core/skills/dx-simple/scripts/parse-simple-block.sh` (add a **`platform`** field — `brand` is already parsed; add conditional-required validation for both), `plugins/dx-core/skills/dx-simple/templates/simple-block.md.tmpl` (surface `platform`/`brand`/`scope` in the DoR block), `plugins/dx-automation/data/pipelines/cli/ado-cli-simple.yml` (set `SOURCE_REPO_NAME=$(Build.Repository.Name)` in `env:` so the skill can self-locate — the var is already documented in `config-reference.md` but not wired into this pipeline).
  - **Config schema:** add a top-level **`project.platform`** (self-platform; today only `aem.platform` exists) and **`repos[].brand`** (sibling brand identity) — documented in `docs/reference/config-reference.md`. Reconcile `role` vs `capabilities` via `hub-dispatch.md:107`.
  - **Router:** a new thin router pipeline YAML (e.g. `ado-cli-simple-router.yml`) in `plugins/dx-automation/data/pipelines/cli/`, **declaring `CROSS_REPO_PIPELINE_MAP`** (today only BugFix/DevAgent/DoD-Fix declare it — `infra.template.json:49,55,67`); `plugins/dx-automation/skills/auto-webhooks/` (point the Service Hook at the router); `plugins/dx-automation/skills/auto-pipelines/` + `infra.template.json` (set the map for the dx-simple/router pipeline). Resolution is a two-step lookup: config `(platform,brand,scope)→repo name`, then `CROSS_REPO_PIPELINE_MAP` `repo name→pipeline-id`.
  - **Schema reconciliation:** `docs/reference/config-reference.md` + `plugins/dx-core/shared/hub-dispatch.md` — non-hub config uses `repos[].role: frontend|backend|fullstack`, hub config uses `repos[].capabilities: [fe,be]`. The guard derives role from `repos[]` (decision A, below), so both shapes must map to the same fe/be/both notion; reuse the existing role→capabilities table in `hub-dispatch.md:107`.
**Done-when:** A multi-platform project can post a single `@kai-simple` comment and have **only** the declared repo(s)' dx-simple pipeline run; a single-repo project is unaffected (no new required fields). Verify:
  1. `grep -n 'platform\|brand\|scope' plugins/dx-core/skills/dx-simple/scripts/parse-simple-block.sh` shows the block parses `platform` + `brand` (+ `scope`), with **conditional** required-validation (a single-platform/single-repo fixture passes with only `page-url`; a >1-platform fixture fails with a "add `platform:`" message).
  2. A router exists (new `ado-cli-simple-router.yml` **or** a documented router-repo pipeline) that does the two-step lookup (config `(platform,brand,scope)→repo`, then `CROSS_REPO_PIPELINE_MAP`→pipeline-id) and queues child runs via the ADO REST API passing `workItemId`; a dry-run with `platform: <P>, scope: be` queues only `<P>`'s BE pipeline.
  3. `grep -n 'SOURCE_REPO_NAME' plugins/dx-automation/data/pipelines/cli/ado-cli-simple.yml` shows the child pipeline exports its own repo name; `grep -n 'CROSS_REPO_PIPELINE_MAP' <router yaml>` shows the router declares the map.
  4. The skill self-guard exists and branches — `grep -n 'SOURCE_REPO_NAME\|platform\|wrong' plugins/dx-core/skills/dx-simple/SKILL.md` shows a Phase 0.5 identity guard, and the behavioral fixture (`plugins/dx-core/skills/dx-simple/scripts/__tests__/`) covers: wrong-platform → ABORT + comment; wrong-brand → ABORT; `both` in one half → proceed; single-fullstack-repo → proceed.
**Approach:** Keep the router **thin and stateless** — this is the legitimate "one logical project, two repos" case, **not** a revival of the dead central-hub model (cross-ref #133: don't build a stateful cross-project brain). Concretely:
  - The `@kai-simple` Service Hook fires a small **router pipeline** (in a dedicated router/hub repo *or* a new pipeline in the primary/BE repo — packaging choice, not architecture).
  - Router classifies **platform first, then scope (+ brand for split platforms)**: prefer explicit `platform` / `scope: fe|be|both` / `brand` fields in the `simple` DoR block (deterministic, cheapest); fall back to a lightweight classifier that maps the component path / market / file list to platform + `repos[].role` + brand. See the **Platform-first routing model** subsection below — this is the structure real consumers actually have (one platform = single fullstack repo; another = BE repo + per-brand FE repos), and tickets never mix platforms.
  - Router resolves targets via a **two-step lookup**: config `(platform, brand, scope) → repo name(s)`, then `CROSS_REPO_PIPELINE_MAP` `repo name → pipeline-id` (reuse the existing env var, unchanged shape). It then **queues the child pipeline run(s) via the ADO REST API** (`Runs - Run Pipeline`, passing `workItemId`) and **exits** — no waiting, no aggregation.
  - Each child repo's existing `ado-cli-simple.yml` runs unchanged. dx-simple's whole resumable recovery model (#141) works **per repo** as-is — the per-ticket branch lives in each child repo independently.
  - **Recovery interaction:** a `@kai-simple <answer>` recovery comment hits the router again; classification is stable (story + simple block don't change), so it re-queues the same repo(s). Each child's Phase 0 `resume-check.sh` decides fresh / resume-blocked / `done` idempotently — a finished child no-ops, a blocked child resumes. So the router needs no memory of prior dispatches.
  - **Distinct from the `dx-hub` plugin**, which orchestrates multiple repos over local VS Code terminals (macOS, interactive). This is the pipeline/automation-layer equivalent for the unattended `@kai-simple` path only.
  - Out of scope for now (per request): the other auto-* agents and any Lambda involvement — there is no Lambda in the dx-simple path.

**Platform-first routing model (the real-world shape that drives the design):**
  - Routing is **platform-primary**, not flat fe/be. A ticket belongs to **exactly one platform** (an opaque, consumer-defined identifier — surfaced today as `repos[].platform` and `aem.platform`); **platforms are never mixed in one ticket.** This invariant keeps the router simple: classify the platform, pick that platform's repo set, ignore the rest.
  - A platform has one of two shapes:
    - **single-repo fullstack** — one repo holds both FE and BE → route there; it does everything (FE + BE + authoring). No split, no dedup; the guard only fires on a wrong-platform misroute.
    - **split** — a BE repo + one-or-more **per-brand FE repos**. The FE repo is chosen by the ticket's **brand** (from `aem.brands` / `active-markets` or ticket content). Within the platform, `scope: fe|be|both` decides which of {BE repo, the brand's FE repo} run.
  - **Out of scope:** backend-**config** repos (`role: config`) are never dx-simple targets — skip them in routing and the candidate set. (Per request, backend config is not in play for now.)

**Skill self-guard (defense-in-depth — runs in every child, independent of the router):**
  - A new **Phase 0.5 identity guard** runs after `resume-check.sh` (Phase 0) and before analysis. It compares the **ticket target** — `platform`, `scope: fe|be|both`, and (split platforms) `brand` — against **this repo's identity** (`platform` + `role` + `brand`, from config), and branches:
    - **wrong platform** (ticket targets platform A, this repo is platform B) → **ABORT** + why-stopped comment. Strongest guard — since tickets never span platforms, a platform mismatch is always a misroute.
    - **wrong brand** (split-platform FE: ticket is brand X, this is brand Y's FE repo) → **ABORT** + comment.
    - **wrong role** (ticket is be-only, this is the FE repo of the right platform/brand, or vice-versa) → **ABORT** + comment.
    - **partial match** (scope `both`, this repo is one half of a split platform) → **proceed** with this repo's slice only; record in `resume-state.json` that the sibling half runs elsewhere so the run doesn't flag missing cross-repo work as incomplete.
    - **single-repo platform / exact match** (platform is one fullstack repo, or scope == this repo's role) → **proceed** unchanged — today's behavior.
  - Every ABORT reuses #141's blocker-report mechanism (classified-fail comment, no code/JCR writes).
  - **Decision A — self-identity derivation (CHOSEN: from config).** Self comes from config: **`project.role`** (present in real consumers) + a **platform** value (today `aem.platform`; likely promote to a top-level `project.platform` for clarity) + **brand** (`aem.brands`). `SOURCE_REPO_NAME` (set by the child pipeline) looks up *sibling* identity in `repos[]` — used to name the correct target in abort comments. Schema work — **two distinct `brand` notions, don't conflate:** (i) the **ticket's target brand** = the `brand` field in the `simple` block, *already parsed today*; (ii) a **repo's brand identity** = a new **`repos[].brand`** field so a split-platform ticket can map to the correct brand FE repo (today brand is only implied by an FE repo's own `aem.brands`). The guard matches (i) against (ii). Normalize `role: frontend|backend|fullstack` (non-hub) vs `capabilities: [fe,be]` (hub) via the `hub-dispatch.md:107` table. If platform/role can't be resolved (single repo, nothing configured) → **proceed** (today's behavior, never block).
  - **Decision B — authoring owner (RESOLVED, generalized).** Authoring is **one logical unit assigned to the repo that has AEM author access for that platform** — the repo whose config carries `aem.author-url` — **not** "the BE repo." In a single-repo fullstack platform that's the one repo; in a split platform the AEM-author-capable repo is often the **brand FE repo** (the AEM frontend lives there), so authoring can legitimately belong to the FE side. The owner runs **authoring + its code**; every other repo runs **code-only** (toggled via an `authoring: true|false` template param). Code always splits per repo. Conflict only arises in a **split platform with `scope: both`**. See **Authoring de-duplication** below.
  - **Decision C — routing input (RESOLVED: explicit, conditionally-required fields; deterministic config lookup, not an LLM classifier).** Routing is driven by **explicit `platform` / `brand` / `scope` fields in the `simple` block**, not by classifying prose. `brand` is **already parsed today** (`parse-simple-block.sh` field list + duplicate-check); add **`platform`** the same way (one line in each), and surface both in `simple-block.md.tmpl`. With these declared, routing is a deterministic two-step lookup (no model call, no misroute):
    1. `(platform, brand, scope)` → target **repo name(s)** via config (`repos[].platform`, `repos[].role`, `repos[].brand`).
    2. repo name → **pipeline-id** via `CROSS_REPO_PIPELINE_MAP` (existing var, unchanged shape).
    - **Conditional requirement (CHOSEN — never burden single-repo projects):** `platform` and `brand` are **required only when they're ambiguous**, and **never required for a single-repo / single-platform project** (today's `page-url`-only flow is untouched). Tiered:
      - **`platform`** required only if the project has **>1 reachable platform** (>1 distinct `platform` among `CROSS_REPO_PIPELINE_MAP`-enabled repos).
      - **`brand`** required only if the resolved platform is **split with >1 brand FE repo**.
      - Otherwise neither is required — the single candidate is unambiguous, so the parser must **not** hard-fail on their absence.
    - When required-but-missing, `parse-simple-block.sh` fails like a missing `page-url` (exit 3) with a clear *"add `platform:` / `brand:` — this project has N platforms/brands"* message, surfaced via the #141 blocker comment.
    - **Optional backstop only:** a lightweight prose classifier (reuse `dx-hub-dispatch`'s keyword logic) may *suggest* platform/brand when fields are absent in a multi-platform project, but it never silently routes — it proposes and asks, or fails to the comment above. Explicit fields are the contract.
  - **Reachability rule.** Candidate repos = **`CROSS_REPO_PIPELINE_MAP` keys** (repos that actually have a dx-simple pipeline), filtered by **platform → role → brand**. `scope: be` is never "the backend repo" generically — a project can have multiple backend/config repos across platforms; only the matching platform's pipeline-enabled BE repo is reachable. The router uses each `repos[].ado-project` for the cross-project REST `runs` POST (siblings can live in different ADO projects). **`CROSS_REPO_PIPELINE_MAP` is currently declared only on the BugFix/DevAgent/DoD-Fix pipelines (`infra.template.json:49,55,67`) — not `ado-cli-simple.yml`; the router pipeline must declare it** (and `auto-pipelines` must set it for dx-simple). A project with one repo never sets it → single-repo flow, no routing.

**Authoring de-duplication (only when a *split* platform routes `scope: both` → two pipelines on one AEM instance):**
  - **Primary — declared owner (Decision B):** authoring goes to the one AEM-author-capable repo; the other runs code-only. Eliminates doubled activation, doubled ticket comments, and additive-op corruption. Near-zero new logic (dx-simple already splits authoring/code).
  - **Safety net — read-before-write idempotency (always):** each authoring write does `getNodeContent` first and **skips** if the target value already matches. Cheap (extra MCP reads only) and also makes **recovery re-runs (#141) idempotent**. Defense-in-depth, not the primary mechanism.
  - **Rejected — distributed lock / claim node:** prevents all duplication but adds a cross-repo coordination point, contradicting the stateless-children principle (cross-ref #133). The conflict window is narrow (split platform + `scope: both`) and owner-routing already closes it.
  - **Why safe for the common case:** typical writes (aria-label, color, copy, spacing) are **idempotent property sets** — parallel duplicates converge to the same state. The owner model exists for the *non*-idempotent edges (additive `css-class`/`icon`/multifield) and cosmetic noise (double comments/activation).

**Worked example (anonymized):** Two platforms. **Platform A** = a single fullstack AEM repo (FE + BE together) → any platform-A ticket routes to that one repo, which does FE + BE + authoring; no split, no dedup. **Platform B** = a BE repo + per-brand FE repos (brand X, brand Y), where the **FE/brand repos carry AEM author access**. A platform-B ticket: router classifies platform = B, brand = X, scope; `scope: both` → queues the BE repo (code-only) **and** brand X's FE repo (authoring owner + its code) via REST `runs` POSTs into their respective ADO projects; `scope: fe` → only brand X's FE repo; `scope: be` → only the BE repo. A brand-Y ticket never touches brand X's repo (guard aborts on misroute). Backend-config repos are skipped entirely.

## Pipelines clone `--branch main`, no release pinning

**Added:** 2026-05-28
**Problem:** All 11 ADO CLI pipeline YAMLs (`plugins/dx-automation/data/pipelines/cli/ado-cli-*.yml`) clone the dx-aem-flow plugins repo with `git clone --depth 1 --branch main`. Any push to `main` — including routine `chore:` commits or accidental breakage — affects every consumer's running agents the next time a webhook fires. There is no documented rollback procedure when `main` breaks. Surfaced by PR #147 review.
**Scope:** All 11 pipeline YAMLs in `plugins/dx-automation/data/pipelines/cli/`.
**Done-when:** `grep -n '\\-\\-branch main' plugins/dx-automation/data/pipelines/cli/*.yml` shows no matches (replaced with a release tag or pinned SHA), OR a section in `plugins/dx-automation/README.md` documents the rollback procedure when `main` breaks.
**Approach:** Two viable options: (1) Pin to a release tag (`--branch v2.106.7`) — semantic-release already bumps version files on every merge, so the pipeline can read the tag from a pipeline variable updated as part of release cuts. (2) Document a manual rollback (`git revert` on `main`, delete affected pipeline runs). Option 1 is safer but requires release-cut tooling; option 2 is cheaper. Decide at the project level — not changing in PR #147 because all 11 pipelines share this pattern; fixing only `ado-cli-simple.yml` would diverge from the established convention.
