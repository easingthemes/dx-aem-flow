# dx-rfp Plugin — Design Spec v2

**Date:** 2026-04-14
**Status:** Draft — supersedes v1 (`2026-04-14-dx-rfp-plugin-design.md`)
**Target:** Fifth plugin in the `dx-aem-ai-flow` marketplace
**Primary audience:** Formal enterprise RFPs (multi-million, public-sector, large-corp procurement)

## 0. What Changed from v1

| Area | v1 | v2 |
|---|---|---|
| Skill names | `rfp-questions`, `rfp-narrative`, `rfp-ai-usage` | `rfp-clarifications`, `rfp-approach`, `rfp-ai-approach` (optional) |
| Override model | Three-layer (`.ai/rules/` > `config.yaml` overrides > plugin defaults) | Two primitives: **shadow** (mirror file replaces plugin file) + **`{{include}}`** directive |
| Specialists | Plugin-defined archetype list (FE/BE/Platform/AI/Generic) | Free-form, user-owned agent files. Plugin ships starter templates only. |
| Perspectives | Not explicit | First-class: multiple agents per category across **all** pipeline steps + independent reviewer agent per step |
| Estimation | "Five-way reconciliation" mentioned but not structured | Formal: bottom-up, analogous, parametric, PERT, perspective views → reconciliation |
| Memory between steps | Not addressed | `.state/` directory: locks, context summaries, cross-task registers, manifest, run snapshots |
| Re-run | "Idempotent re-runs" handwave | Five re-run scopes, manifest-driven delta detection, cascade invalidation, full snapshotting, `/rfp status` |
| Determinism | Not addressed | Strict templates (tiered: YAML hard, prose soft) + deterministic hooks (step-scoped blocking) |
| User extensibility | Limited to `.ai/rules/` | Shadow any file, include any file, add any agent, add any hook, add any template |

## 1. Purpose

Generic, platform-agnostic Claude Code plugin for responding to formal enterprise RFPs. Ships a proven pipeline — decomposition, estimation with cross-validation, narrative, clarification questions, red-team review — with zero client-specific content. Consumer projects bootstrap their own RFP workspace via an interactive init skill; all client data stays in the consumer repo.

Optimized for **rigor, auditability, and defensibility** over token efficiency. Multi-million bids justify heavy inference.

## 2. Hard Constraints

- **No client data** in plugin source, commits, examples, templates, or test fixtures
- **No secrets.** Plugin does not read, store, or transmit credentials. Remote publishing (Drive/ADO/S3) is v2 scope.
- **Generic archetypes only.** Roles, multipliers, phases, scope categories derive from RFP methodology research, not any specific client
- **Config-driven.** No hardcoded task counts, specialist names, category lists, role lists, or deliverable formats in skills. Everything reads from `.ai/rfp/config.yaml` and `.ai/rfp/registry.yaml`.
- **Idempotent re-runs** with manifest-driven change detection and full snapshotting
- **Deterministic where possible.** Arithmetic, schema, references validated by shell-based hooks, not LLM judgment.

## 3. Skill Roster

| Skill | Purpose | Model | Effort |
|---|---|---|---|
| `/rfp-init` | Interactive bootstrap. Scaffolds `.ai/rfp/`, config, registry, specialist agents, gitignore, hook samples. | sonnet | medium |
| `/rfp` | Orchestrator. Reads registry + manifest, routes tasks to specialists + perspectives + reviewers, runs pipeline, consolidates. Supports `all`, `<task-id>`, `--from <step>`, `--step <step>`, `--agent <id>`, `--no-cascade`, `--force`. | sonnet | medium |
| `/rfp status` | Show what's stale per task × step based on manifest hash diffs. | haiku | low |
| `/rfp-analysis` | Discovery pipeline root. Produces primary + perspectives + reviewer + consolidated shards. | sonnet | medium |
| `/rfp-work-packages` | WBS with 5–15 PD work packages, per-perspective additions, reviewer pass. | sonnet | medium |
| `/rfp-estimate` | Five-way estimation: bottom-up, analogous, parametric, PERT, perspective. Reconciliation. | opus | high |
| `/rfp-approach` | Technical approach: 5 blocks (Categorization, Assumptions, Exclusions, Uncertainties, Delivery). Per-perspective contributions. | sonnet | medium |
| `/rfp-ai-approach` | **Optional** (enabled via `rfp.skills.ai_approach.enabled: true`). Dedicated AI & Automation approach narrative. | sonnet | medium |
| `/rfp-clarifications` | Generate clarification questions with three-gate filter + cross-task dedup via register. | sonnet | medium |
| `/rfp-red-team` | Evaluator + critic simulation: cost-critic, timeline-critic, risk-critic, evaluator-critic, compliance-critic. | opus | high |

All pipeline skills implement **review mode** (when task status is `done`) and **generate mode** (when `pending`). Orchestrator skips `parked` tasks unless `--force`.

## 4. Architecture Overview

```
plugins/dx-rfp/
├── .claude-plugin/plugin.json
├── .cursor-plugin/plugin.json
├── assets/logo.png
├── skills/                        # skill directories
│   ├── rfp-init/SKILL.md
│   ├── rfp/SKILL.md               # orchestrator (also handles /rfp status)
│   ├── rfp-analysis/SKILL.md
│   ├── rfp-work-packages/SKILL.md
│   ├── rfp-estimate/SKILL.md
│   ├── rfp-approach/SKILL.md
│   ├── rfp-ai-approach/SKILL.md
│   ├── rfp-clarifications/SKILL.md
│   └── rfp-red-team/SKILL.md
├── agents/                        # shipped generic agents
│   ├── rfp-tech-researcher.md
│   ├── rfp-client-researcher.md
│   └── rfp-reviewer-bid-manager.md
├── templates/
│   ├── config.yaml.template
│   ├── registry.yaml.template
│   ├── agents/                    # starter specialist templates (user edits)
│   │   ├── rfp-fe-specialist.md.template
│   │   ├── rfp-be-specialist.md.template
│   │   ├── rfp-platform-specialist.md.template
│   │   ├── rfp-ai-specialist.md.template
│   │   ├── rfp-qa-specialist.md.template
│   │   └── rfp-generic-specialist.md.template
│   └── results/                   # strict fill-in templates per step
│       ├── analysis/
│       │   ├── _primary.md.template
│       │   ├── perspective.md.template
│       │   ├── _reviewer.md.template
│       │   └── _consolidated.md.template
│       ├── work-packages/…
│       ├── estimation/
│       │   ├── _primary.md.template
│       │   ├── _analogous.md.template
│       │   ├── _parametric.md.template
│       │   ├── _pert.md.template
│       │   ├── perspective.md.template
│       │   ├── _reviewer.md.template
│       │   ├── _reconciliation.md.template
│       │   └── _consolidated.md.template
│       ├── approach/…
│       ├── ai-approach/…
│       ├── clarifications/…
│       └── red-team/…
├── shared/                        # read at runtime, shadow-overridable
│   ├── methodology.md
│   ├── estimation-framework.md
│   ├── question-filter.md
│   ├── narrative-blocks.md
│   ├── red-team-criteria.md
│   └── pitfalls.md
├── rules/                         # default prompt rules, shadow-overridable
├── hooks/                         # deterministic validation
│   ├── hooks.json                 # plugin hook registry
│   └── lib/                       # shell scripts (see §9)
├── lib/                           # shared shell helpers
│   ├── include-resolver.sh        # {{include:}} expansion
│   ├── shadow-resolver.sh         # shadow path resolution
│   ├── manifest.sh                # read/write .state/manifest.yaml
│   └── hash.sh                    # deterministic hashing for change detection
└── README.md
```

**Dependencies:** standalone. No dx-core, dx-aem, or dx-automation dependency. Optional ADO integration deferred to v2.

## 5. Override Model (Shadow + Include)

**Two primitives. No precedence hierarchy, no merge logic.**

### 5.1 Shadow rule

> If `.ai/rfp/<path>` exists, the plugin uses it. Otherwise, the plugin uses `plugins/dx-rfp/<path>`.

Example:

| Plugin file | Consumer override |
|---|---|
| `plugins/dx-rfp/shared/methodology.md` | `.ai/rfp/shared/methodology.md` |
| `plugins/dx-rfp/rules/pragmatism.md` | `.ai/rfp/rules/pragmatism.md` |
| `plugins/dx-rfp/templates/results/analysis/_primary.md.template` | `.ai/rfp/templates/results/analysis/_primary.md.template` |
| `plugins/dx-rfp/hooks/hooks.json` | Merged with `.ai/rfp/hooks/hooks.json` (hook merge is additive — see §9) |

User never partial-overrides — they take the whole file or none. Diff vs. plugin original is visible via git.

### 5.2 Include directive

> Inside any markdown file (plugin or consumer), `{{include: <path>}}` expands inline to the contents of the shadow-resolved file.

```markdown
{{include: shared/methodology.md}}

Our team additions:
- Include a DR checklist on every estimate
```

- Same shadow resolution applies recursively (consumer's file included if present, else plugin's)
- Circular includes error out with a clear message
- Resolver is `plugins/dx-rfp/lib/include-resolver.sh` — ~30 lines of shell, uses `awk`/`sed`

### 5.3 What's overridable

Everything under `plugins/dx-rfp/` except `skills/*/SKILL.md` itself (skill logic is not user-overridable; behavior is controlled via templates, rules, shared refs, and hooks).

Specifically overridable:
- `shared/*.md` — methodology, frameworks, criteria
- `rules/*.md` — prompt rules
- `templates/results/**/*.md.template` — strict output templates
- `templates/agents/*.md.template` — starter specialist templates
- `hooks/hooks.json` + `hooks/lib/*.sh` — via additive merge, not shadow (see §9)

## 6. Specialists (User-Owned Agent Files)

**Plugin ships only starter templates.** User defines their own specialists via free-form agent files.

### 6.1 Starter templates (plugin ships)

| Template | Angle |
|---|---|
| `rfp-fe-specialist.md.template` | Frontend senior |
| `rfp-be-specialist.md.template` | Backend senior |
| `rfp-platform-specialist.md.template` | DevOps/Infra/Platform |
| `rfp-ai-specialist.md.template` | AI/ML/Automation |
| `rfp-qa-specialist.md.template` | QA/Test automation |
| `rfp-generic-specialist.md.template` | Blank slate with required sections |

### 6.2 Init flow

1. User declares specialists free-form during `/rfp-init`: `fe-lead`, `aem-content-lead`, `seo-lead`, `integration-lead`, `accessibility-lead`, …
2. For each: offer starter template or blank; scaffold to `.claude/agents/rfp-<id>-specialist.md`
3. User edits the scaffolded agent with domain knowledge (what "AEM Content" means in their org)
4. Plugin never overwrites these on re-run without explicit confirmation

### 6.3 Referenced from config

```yaml
rfp:
  specialists:
    - { id: fe-lead,          agent: rfp-fe-specialist,            grade: senior }
    - { id: aem-content-lead, agent: rfp-aem-content-specialist,   grade: senior }
    - { id: seo-lead,         agent: rfp-seo-specialist,           grade: mid }
    - { id: integration-lead, agent: rfp-integration-specialist,   grade: senior }
    - { id: accessibility,    agent: rfp-accessibility-specialist, grade: mid }

  categories:
    - { id: aem-authoring,  label: "AEM Content Authoring",  specialist: aem-content-lead,  perspectives: [accessibility, seo-lead] }
    - { id: aem-dam,        label: "AEM DAM & Assets",       specialist: aem-content-lead,  perspectives: [] }
    - { id: aem-publishing, label: "AEM Publishing",         specialist: aem-content-lead,  perspectives: [seo-lead] }
    - { id: seo-technical,  label: "Technical SEO",          specialist: seo-lead,           perspectives: [fe-lead] }
    - { id: be-api,         label: "BE API",                 specialist: be-lead,            perspectives: [security-lead, perf-lead] }
    # … 13 total typical for enterprise RFP
```

Orchestrator reads category → looks up specialist id → finds agent → invokes it. Plugin has no hardcoded specialist list anywhere.

### 6.4 Capability matrix

The N categories × M specialists mapping is a **capability matrix** — standard enterprise bid-management practice. Every specialist typically covers 2–4 adjacent categories. Plugin exposes the mapping mechanism; user fills in domain knowledge.

## 7. Multi-Perspective Model

Each category has:
- **One primary specialist** (required) — owns the lead deliverable
- **0..N perspectives** (optional) — other specialists contribute from their angle (security, performance, accessibility, SEO, compliance, cost, …)

Perspectives run on **all 6 pipeline steps** (analysis, work-packages, estimation, approach, clarifications, red-team). Per user decision — multi-million enterprise bids warrant heavy inference at every step.

### 7.1 Per-step composition

Each step produces, per category task:

| Shard | Producer | Purpose |
|---|---|---|
| `_primary.md` | Primary specialist | Lead view |
| `<perspective-id>.md` | Each perspective agent | From-angle addition |
| Step-specific additions | Specialized methods (e.g., `_analogous.md`, `_pert.md` for estimation) | Rigor |
| `_reviewer.md` | Independent reviewer agent | Critique, gap detection |
| `_consolidated.md` | Consolidator (orchestrator-managed) | Synthesis for downstream consumption |

### 7.2 Reviewer agents

Plugin ships `rfp-reviewer-bid-manager`. Additional reviewer agents can be shipped or added by the user (e.g., `rfp-reviewer-solution-architect`).

Reviewer is dispatched **after** primary + perspectives complete, with context:
- RFP scope (from `.state/locks/scope.md`)
- All step-N shards for this task
- Prior-step summaries for this task

Reviewer's job: independent critique. Catches gaps, circular reasoning, inflated/deflated estimates, missing clarifications. This is the "pink team / green team / shred review" practice from enterprise bid management.

### 7.3 Five-way estimation

`/rfp-estimate` produces five independent PD views:

1. `_primary.md` — bottom-up from WBS (the specialist's main estimate)
2. `_analogous.md` — comparison to similar past projects (analogous estimation)
3. `_parametric.md` — function-point / complexity-driven (parametric estimation)
4. `_pert.md` — three-point estimate (O + 4M + P) / 6 with stddev
5. `<perspective>.md` — domain-specific views (security-lead's security-only PD, perf-lead's perf-only PD, etc.)

Then `_reconciliation.md` — reconciles deltas across methods, flags outliers (|delta| > 15%), produces the defensible number.

### 7.4 Red-team critic roles

For `/rfp-red-team`, "perspectives" are critic archetypes, not domain specialists:

- `_cost-critic.md` — attacks pricing, asks "too cheap / too expensive relative to scope"
- `_timeline-critic.md` — attacks schedule, asks "can this really be done in X months"
- `_risk-critic.md` — attacks risk posture, asks "what are you not seeing"
- `_evaluator-critic.md` — simulates the RFP evaluator reading the proposal
- `_compliance-critic.md` — reads RFP compliance matrix, flags gaps

Declared separately in config:

```yaml
rfp:
  red_team:
    critics: [cost, timeline, risk, evaluator, compliance]
```

## 8. Plugin Internal Memory (`.state/`)

### 8.1 Purpose

Separate plugin-managed working memory from user-facing deliverables. `.state/` is gitignored, regenerable from `results/` + `config.yaml` + `registry.yaml`.

### 8.2 Layout

```
.ai/rfp/
├── results/                        # user-facing, git-tracked deliverables
│   └── task-<id>/
│       ├── analysis/ {shards}
│       ├── work-packages/ {shards}
│       ├── estimation/ {shards}
│       ├── approach/ {shards}
│       ├── ai-approach/ {shards}   # only if enabled
│       ├── clarifications/ {shards}
│       ├── red-team/ {shards}
│       └── _final.md
├── .state/                         # plugin-internal, gitignored
│   ├── manifest.yaml               # run log, input hashes, output paths
│   ├── locks/                      # invariants frozen at step boundaries
│   │   ├── scope.md                # locked after /rfp-analysis (global)
│   │   ├── roles.md                # locked after /rfp-work-packages
│   │   └── wbs.md                  # locked after /rfp-work-packages
│   ├── context/                    # compact structured summaries per task × step
│   │   └── task-<id>/
│   │       ├── analysis.yaml
│   │       ├── work-packages.yaml
│   │       └── estimation.yaml
│   ├── registers/                  # cross-task aggregates, incrementally built
│   │   ├── clarifications.yaml     # dedup'd across all tasks
│   │   ├── assumptions.yaml
│   │   ├── risks.yaml
│   │   └── dependencies.yaml
│   ├── runs/                       # pre-overwrite snapshots (see §10.4)
│   │   └── <ISO-timestamp>/
│   │       └── task-<id>/<step>/…
│   └── logs/                       # per-invocation audit trails
│       └── <ISO-timestamp>-task-<id>-<step>-<agent>.log
└── client-docs/                    # user-provided, gitignored by default
```

### 8.3 Context summaries

At the end of each step for each task, the orchestrator runs a summarization pass:

- Input: all step-N shards for the task (`_primary`, perspectives, reviewer, consolidated)
- Output: `.state/context/task-<id>/<step>.yaml` — structured ~200-word-equivalent extraction

Example `estimation.yaml`:

```yaml
task: be-api
step: estimation
produced_at: 2026-04-14T21:44:00Z
headline:
  bottom_up_pd: 29
  multiplier: 3.14
  top_line_pd: 91
  reconciled_pd: 88
  reconciled_range: [82, 97]
  confidence: medium
key_drivers:
  - "integration complexity with SAP"
  - "performance SLAs require 3 rounds of optimization"
open_risks:
  - id: R-003
    text: "third-party API latency unknown"
    impact_pd_range: [3, 8]
perspective_deltas:
  security-lead: "+12 PD on auth/audit"
  perf-lead: "+8 PD on caching layer"
```

Later steps' agents read these YAMLs, not the raw shards. Raw shards remain reachable on demand.

### 8.4 Locks

Global invariants frozen at step boundaries. Later steps receive them as read-only.

| Lock | Frozen after | Consumed by |
|---|---|---|
| `scope.md` | `/rfp-analysis` (all tasks) | every downstream step |
| `roles.md` | `/rfp-work-packages` (all tasks) | estimation, approach |
| `wbs.md` | `/rfp-work-packages` (all tasks) | estimation, clarifications, red-team |

Lock invalidation: re-running a step invalidates its lock **globally** — scope drift must propagate, not be hidden per-task. See §10 (re-runs).

### 8.5 Cross-task registers

As each task's clarifications/risks/assumptions/dependencies emerge, they're merged into dedup'd cross-task YAMLs. The `/rfp-clarifications` step reads `registers/clarifications.yaml` to avoid asking duplicate questions across 13 tasks.

Dedup is fuzzy (cosine similarity of question text, threshold configurable).

### 8.6 Manifest

Single source of truth for "what ran, what were the inputs, what are the outputs":

```yaml
# .state/manifest.yaml
schema_version: 1
runs:
  - id: run-001
    task: be-api
    step: estimation
    agent: _primary
    started_at: 2026-04-14T21:14:22Z
    finished_at: 2026-04-14T21:16:03Z
    inputs:
      config_section_hash: abc123
      locks:
        scope_hash: def456
        roles_hash: 789abc
        wbs_hash: fed321
      context_prior:
        analysis_hash: 0a1b2c
        work_packages_hash: 3d4e5f
      agent_file_hash: 6g7h8i
      template_hash: 9j0k1l
      rules_hashes: [rule-pragmatism:m2n3o4]
    output:
      path: results/task-be-api/estimation/_primary.md
      sha: 5p6q7r
    hooks_run: [rfp-validate-pd-matrix-sums, rfp-validate-wp-pd-range]
    hook_results: all_passed
```

Manifest drives re-run logic (see §10).

### 8.7 Agent input protocol

Each agent receives exactly the context it needs — never raw shards from prior steps unless explicitly fetched:

| Agent type | Reads |
|---|---|
| Primary, step N | `locks/*` + `context/<task>/<step>.yaml` for steps < N + relevant `registers/*` |
| Perspective, step N | Same as primary + primary's step-N raw output |
| Reviewer, step N | Same as primary + **all** step-N raw outputs (to critique) |
| Consolidator, step N | All step-N raw outputs + `locks/*` |

This is enforced by the skill's prompt construction — not by filesystem permissions. Skills explicitly assemble the context bundle before invoking an agent.

## 9. Strict Templates + Deterministic Hooks

### 9.1 Strict templates (tiered)

Every shard is a template-fill. Two tiers of strictness:

- **Hard:** frontmatter + fenced YAML/table blocks — hooks depend on them, `post-agent` hook fails if missing/malformed
- **Soft:** prose sections — guidance only, warnings logged but non-blocking

Example — `templates/results/estimation/_primary.md.template`:

```markdown
---
task: {{task}}
step: estimation
agent: _primary
version: 1
---

## Summary
{free prose, ~150 words}

## PD Matrix

```yaml
roles:
  - id: {{role-id}}
    wps:
      - { wp: WP-NN, pd: 0 }
totals:
  by_role:   {}
  by_wp:     {}
  bottom_up: 0
  multiplier: 0
  top_line:  0
```

## Assumptions
- {bullet}

## Risks
- {bullet}
```

Templates exist for every shard type (primary, each perspective flavor, each estimation method, reviewer, consolidated) in every step.

### 9.2 Hook framework

**Layout:**

```
plugins/dx-rfp/hooks/
├── hooks.json                    # plugin registry
└── lib/
    ├── validate-pd-matrix-sums.sh
    ├── validate-bottom-up-times-multiplier.sh
    ├── validate-pert-formula.sh
    ├── validate-wp-pd-range.sh
    ├── validate-multiplier-range.sh
    ├── validate-word-counts.sh
    ├── validate-every-wp-has-owner.sh
    ├── validate-every-scope-covered.sh
    ├── validate-every-role-used.sh
    ├── validate-all-perspectives-present.sh
    ├── validate-wp-ids-match-wbs.sh
    ├── validate-scope-items-in-lock.sh
    ├── validate-specialist-exists-in-config.sh
    ├── validate-no-duplicate-wp-ids.sh
    ├── validate-clarification-dedup.sh
    ├── validate-template-frontmatter.sh
    ├── validate-yaml-blocks-parse.sh
    ├── validate-required-sections-present.sh
    ├── validate-estimation-wps-match-wbs.sh
    ├── validate-reconciliation-within-tolerance.sh
    ├── validate-no-client-name-leak.sh
    ├── validate-date-format.sh
    └── validate-no-placeholder-tokens.sh
```

### 9.3 Registry format

```json
{
  "hooks": [
    {
      "id": "rfp-validate-pd-matrix-sums",
      "event": "post-agent",
      "steps": ["estimation"],
      "agents": ["_primary", "security-lead", "perf-lead"],
      "script": "${DX_RFP_ROOT}/hooks/lib/validate-pd-matrix-sums.sh",
      "blocking": true,
      "description": "Verify role×WP matrix row/column sums equal declared totals"
    }
  ]
}
```

Events supported:

| Event | When |
|---|---|
| `pre-step` | Before any agent runs for a step (prereq check) |
| `post-agent` | After each agent produces a shard (fast fail) |
| `post-step` | After all shards + consolidation for a step |
| `pre-consolidation` | Before consolidator runs (all perspectives present?) |
| `post-consolidation` | After consolidated shard produced |
| `pre-final` | Before `_final.md` assembly (full green gate) |

### 9.4 Hook contract

- Script receives env vars: `RFP_TASK_ID`, `RFP_STEP`, `RFP_AGENT`, `RFP_SHARD_PATH`, `RFP_CONFIG_PATH`, `RFP_STATE_DIR`
- Exit codes: `0` = pass, `2` = blocking fail, other = warning
- stdout = human-readable report
- stderr = structured diagnostics for the failure case (key: value pairs)

### 9.5 User-owned hooks

Additive merge, not shadow:

```
.ai/rfp/hooks/
├── hooks.json                    # user registry (appended)
├── our-company-pd-cap.sh         # e.g., no WP > 20 PD per internal policy
├── our-min-qa-ratio.sh           # e.g., QA PD ≥ 25% of dev PD
└── our-client-naming.sh
```

**Merge semantics:**
- Plugin registry + user registry concatenated
- Execution order per event/step: plugin first, user second
- User disables plugin hooks by id via config (not by editing plugin file):
  ```yaml
  rfp:
    hooks:
      disabled: [rfp-validate-word-counts]
  ```
- Collision (user redefines plugin hook id) → error

### 9.6 Failure semantics — step-scoped blocking

Per user decision (Q2 = C):

- Within a task × step: blocking hooks block that step's completion and downstream steps for **that task**
- Across tasks: one task's hook failure does **not** block other tasks
- Parallelism preserved; bad data does not propagate within a task

## 10. Re-Run Model

### 10.1 Five re-run scopes

| Command | Scope |
|---|---|
| `/rfp all` | Delta mode — detect stale outputs via manifest hash diffs, re-run only those |
| `/rfp <task-id>` | Re-run remaining steps for one task |
| `/rfp <task-id> --from <step>` | Re-run from specific step onward for one task |
| `/rfp --step <step>` | Re-run one step across all tasks |
| `/rfp <task-id> --step <step> --agent <id>` | Re-run one specific shard (surgical) |
| `/rfp --force` | Full regen from scratch |

### 10.2 Cascade invalidation (default)

Re-running step S for task T invalidates downstream steps for T and any cross-task state derived from T. Explicit confirmation required:

```
You're re-running ANALYSIS for task "be-api".
This will invalidate:
  - work-packages, estimation, clarifications, approach, red-team (for be-api)
  - cross-task registers (clarifications, assumptions, risks, dependencies)
  - locks: scope, roles, wbs (will be regenerated)

Proceed? [y/N]
```

`--no-cascade` flag — surgical, no downstream invalidation (rarely correct; explicit opt-in).

### 10.3 Manifest-driven delta detection

`/rfp all` without flags walks the manifest, recomputes input hashes, re-runs any entry whose input hash changed.

Implicit triggers:
- `config.yaml` edited → affected tasks detected via config section hashing
- `client-docs/` changed → all analysis re-runs
- Specialist agent file edited → that agent's contributions re-run
- Shadowed `.ai/rfp/shared/*.md` changed → dependent runs re-flow
- Template edited → runs using that template re-flow

### 10.4 Snapshotting (history preserved)

Before overwriting any output, affected paths are moved to `.state/runs/<ISO-timestamp>/`:

```
.state/runs/
├── 2026-04-14T14:22:00Z/               # before scope change
│   └── task-be-api/…
├── 2026-04-14T21:14:22Z/               # after addendum, analysis re-run
│   └── task-be-api/analysis/…
└── 2026-04-15T09:03:11Z/               # after partner review, estimation re-run
    └── task-be-api/estimation/…
```

User can diff runs — "why did the PD move?" has a concrete answer.

### 10.5 `/rfp status`

Shows per task × step freshness based on manifest hash diffs:

```
Task: be-api
  analysis:         FRESH     (last run 2026-04-14T21:14:22Z)
  work-packages:    STALE     (locks changed in analysis re-run)
  estimation:       STALE
  clarifications:   STALE
  approach:         STALE
  red-team:         NOT_RUN

Task: fe-perf
  analysis:         FRESH
  ...
```

### 10.6 Lock invalidation rules

| Event | Locks invalidated |
|---|---|
| Analysis re-run (any task) | `scope.md` (rebuilt after all tasks re-run) |
| Work-packages re-run (any task) | `roles.md`, `wbs.md` |
| `config.scope` edit | `scope.md` + `wbs.md` + `roles.md` |
| `config.roles` edit | `roles.md` + cascades to estimation |

Locks are global across tasks — scope drift must propagate.

## 11. Config Schema

### 11.1 `.ai/rfp/config.yaml`

```yaml
rfp:
  project_name: ""
  client_name: ""                 # kept in consumer repo only; never in plugin
  deadline: ""                    # ISO date
  internal_handoff: ""            # ISO datetime (optional)

  specialists:                    # free-form, user-defined
    - { id: fe-lead,          agent: rfp-fe-specialist,            grade: senior }
    - { id: aem-content-lead, agent: rfp-aem-content-specialist,   grade: senior }
    # …

  categories:                     # free-form, user-defined
    - id: aem-authoring
      label: "AEM Content Authoring"
      specialist: aem-content-lead
      perspectives: [accessibility, seo-lead]
    # … (13 typical for enterprise RFP)

  roles:                          # estimation roles, referenced by agents
    - { id: solution-architect, grade: senior, cluster: architecture }
    - { id: fe-senior,          grade: senior, cluster: development }
    - { id: fe-mid,             grade: mid,    cluster: development }
    - { id: be-senior,          grade: senior, cluster: development }
    - { id: qa-automation,      grade: mid,    cluster: quality }
    # …

  estimation:
    multiplier: 3.14              # Cockburn pi baseline
    multiplier_justification: ""
    work_package_range: [5, 15]   # PD per WP
    reconciliation_tolerance: 0.15

  paths:
    client_docs: .ai/rfp/client-docs/
    results:     .ai/rfp/results/
    state:       .ai/rfp/.state/
    specs:       .ai/specs/

  skills:
    ai_approach:
      enabled: false              # optional step, opt-in per project

  red_team:
    critics: [cost, timeline, risk, evaluator, compliance]

  hooks:
    disabled: []
    fail_on_warning: false
    extra_dirs: [".ai/rfp/hooks"]

  deliverables:
    format: markdown              # v1 only
```

### 11.2 `.ai/rfp/registry.yaml`

Tasks are derived from categories × special flags; registry is the per-task tracker:

```yaml
tasks:
  - id: aem-authoring             # matches category.id
    status: pending               # pending | done | parked
    owner: ""
    notes: ""
```

## 12. Init Idempotency Matrix

| File category | Re-run behavior |
|---|---|
| `config.yaml` | Preserve user edits; offer to add new keys from template; never remove user keys |
| `registry.yaml` | Never modified on re-run |
| `.claude/agents/rfp-*-specialist.md` | Never modified without confirmation (diff + prompt) |
| `.ai/rfp/shared/*.md` (shadows) | Diff + prompt |
| `.ai/rfp/rules/*.md` (shadows) | Diff + prompt |
| `.ai/rfp/templates/**/*.template` (shadows) | Diff + prompt |
| `.ai/rfp/hooks/**` | Never modified (sample files only provided if absent) |
| `.ai/rfp/.state/` | Preserved — never touched by init |
| `.ai/rfp/client-docs/` | Never touched by init |
| `.gitignore` | Check and add if missing: `.ai/rfp/client-docs/`, `.ai/rfp/.state/` |

## 13. Shared References

Plugin content in `plugins/dx-rfp/shared/` (shadow-overridable, include-able):

| File | Content |
|---|---|
| `methodology.md` | 5-phase process, role archetypes, effort distribution benchmarks |
| `estimation-framework.md` | Cockburn calibration, overhead factors, PERT, five-way reconciliation |
| `question-filter.md` | Three-gate filter, "ASSUME not ASK" philosophy, target density |
| `narrative-blocks.md` | 5-block spec, word-count guidance |
| `red-team-criteria.md` | Critic rubrics, weak-section heuristics, evaluator simulation |
| `pitfalls.md` | 10 named anti-patterns |

## 14. Versioning & Conventions

- Conventional commits: `feat(dx-rfp): …`, `fix(dx-rfp): …`, `docs(dx-rfp): …`
- semantic-release handles version bumps
- Skill naming: `{plugin}-{name}` → `rfp-init`, `rfp-analysis`, `rfp-work-packages`, etc.
- Branching skills use DOT digraphs with matching `### Node Details` sections (dx-core pattern)
- Linear skills use numbered steps
- Shell scripts: `chmod +x`, POSIX-compatible where possible, bash where not

## 15. v2 Backlog (Deferred)

| # | Item | Done-when |
|---|---|---|
| 1 | Remote deliverable publishing | `/rfp-publish --target gdrive\|ado\|s3` works against ≥1 target |
| 2 | xlsx filler subsystem with `mapping.yaml` | Generic filler produces xlsx from `results/*.md` |
| 3 | docx generation per task | `/rfp-publish --format docx` produces one docx per task |
| 4 | `/rfp-qualify` go/no-go + compliance matrix | Skill produces `qualification.md` with 5-dimension scoring |
| 5 | ADO integration (work items per task/WP) | `/rfp-estimate --ado` populates ADO |
| 6 | Cross-RFP learning (estimation calibration across past bids) | Manifest-linked corpus with calibration suggestions |

## 16. v1 Done-When

- `plugins/dx-rfp/` exists with 9 skills, shipped agents, starter agent templates, result templates, shared refs, hook lib, lib helpers
- `validate-skills.sh` passes for dx-rfp (naming, collisions)
- `/rfp-init` on clean test project generates `.ai/rfp/config.yaml`, `.ai/rfp/registry.yaml`, scaffolded specialist agents, updates `.gitignore`
- `/rfp` with a 2-task registry runs end-to-end, producing all 7 steps (analysis, work-packages, estimation, approach, clarifications, red-team; ai-approach if enabled) with primary + perspectives + reviewer + consolidated shards per step
- `/rfp-red-team` produces all 5 critic shards + consolidated scored summary
- `/rfp status` correctly flags stale tasks after config/client-docs/agent edits
- Re-running `/rfp-init` does not overwrite user edits
- Re-running `/rfp <task>` cascades invalidation with confirmation, snapshots prior outputs
- Shadow override works: a `.ai/rfp/shared/methodology.md` replaces plugin's version at runtime
- `{{include:}}` directive expands recursively with circular-include detection
- All plugin-shipped hooks pass on a clean fixture run
- User hooks merge additively with plugin hooks; disabled list honored
- Grep of `plugins/dx-rfp/` returns zero matches for any known client name, URL, or domain term
- Plugin installs cleanly via marketplace alongside existing 4 plugins
