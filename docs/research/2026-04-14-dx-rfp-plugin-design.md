# dx-rfp Plugin — Design Spec v2

**Date:** 2026-04-14
**Status:** Draft — supersedes v1 (`2026-04-14-dx-rfp-plugin-design.md`)
**Target:** Fifth plugin in the `dx-aem-ai-flow` marketplace
**Primary audience:** Formal enterprise RFPs (multi-million, public-sector, large-corp procurement)

## 0. What Changed from v1

| Area | v1 | v2 |
|---|---|---|
| Skill names | `rfp-questions`, `rfp-narrative`, `rfp-ai-usage` | `rfp-clarifications`, `rfp-approach` (AI block folded in — no separate skill) |
| Override model | Three-layer (`.ai/rules/` > `config.yaml` overrides > plugin defaults) | Two primitives: **shadow** (mirror file replaces plugin file) + **`{{include}}`** directive (with glob expansion + `<task>` substitution — see §5.3) |
| Feedback ingestion | Not addressed (assumed bid-team would hand-edit shards) | First-class: `feedback/shared/*.md` + `feedback/<task>/*.md` auto-included into specialist prompts via glob, hashed into manifest, surfaced in shards (§6.5) |
| Specialists | Plugin-defined archetype list (FE/BE/Platform/AI/Generic) | Free-form, user-owned agent files. Plugin ships starter templates only. |
| Perspectives | Not explicit | First-class: multiple agents per category across **all** pipeline steps + independent reviewer agent per step |
| Estimation | "Five-way reconciliation" mentioned but not structured | Formal: bottom-up, analogous, parametric, PERT, perspective views → reconciliation |
| Memory between steps | Not addressed | `.state/` directory: locks, context summaries, cross-task registers, manifest, run snapshots |
| Re-run | "Idempotent re-runs" handwave | Five re-run scopes, manifest-driven delta detection, cascade invalidation, full snapshotting, `/rfp status` |
| Determinism | Not addressed | Strict templates (tiered: YAML hard, prose soft) + deterministic hooks (step-scoped blocking) |
| User extensibility | Limited to `.ai/rules/` | Shadow any file, include any file, add any agent, add any hook, add any template |

## 1. Purpose

Generic, platform-agnostic Claude Code plugin for responding to formal enterprise RFPs. Ships a proven pipeline — decomposition, estimation with cross-validation, narrative, clarification questions, red-team review — with zero client-specific content. Consumer projects bootstrap their own RFP workspace via an interactive init skill; all client data stays in the consumer repo.

### 1.1 Design principle — quality first, cost is not a tradeoff

**Rigor is primary. Cost is secondary and deliberately so.**

The target workload is enterprise RFPs worth millions of euros per year, typically leading to multi-year client relationships. A one-hour meeting with a bid manager, solution architect, or senior lead costs more than a thousand euros in fully-loaded time. The plugin replaces roughly ten such meetings per RFP, plus the research time around them, plus the manual narrative writing — and the downstream value of winning versus losing one bid is orders of magnitude larger again. Optimizing token spend at the expense of rigor inverts every side of that equation.

Concretely:
- **No default model downgrades.** `/rfp-estimate` and `/rfp-red-team` run on `opus` in every mode. Downgrading to `sonnet` saves tokens but gives back the defensibility that motivated the five-way estimation in the first place.
- **No default skipping of perspectives, reviewers, or critics.** Every configured perspective, both reviewer archetypes, and every configured critic runs on every step, every full regen.
- **Reduced-rigor modes are opt-in previews for drafts, not the default posture.** See `todo-dx-rfp.md` for the narrow-scope preview flag design (deferred; does **not** degrade the core pipeline when absent).
- **Cost visibility, not cost-gating.** The orchestrator prints a pre-run estimate ("N primary + M perspectives + P reviewers + Q critics"); it does not refuse to run below a threshold. Users decide what's worth spending.
- **Cascade invalidation errs on the side of re-running.** When scope drifts, re-running the full downstream pipeline is cheaper than discovering later that a downstream shard silently kept a stale assumption from pre-drift scope.

The summarization, dedup, and validation infrastructure in §8–§9 is sized for the full-rigor pipeline. Any future light-mode feature is mechanism on top of that mechanism, never a replacement for it.

## 2. Hard Constraints

- **No client data** in plugin source, commits, examples, templates, or test fixtures
- **No secrets.** Plugin does not read, store, or transmit credentials. Remote publishing (Drive/ADO/S3) is v2 scope.
- **Generic archetypes only.** Roles, multipliers, phases, scope categories derive from RFP methodology research, not any specific client
- **Config-driven.** No hardcoded task counts, specialist names, category lists, role lists, or deliverable formats in skills. Everything reads from `.ai/rfp/config.yaml` (single file — see §11.2).
- **Idempotent re-runs** with manifest-driven change detection and full snapshotting
- **Deterministic where possible.** Arithmetic, schema, references validated by shell-based hooks, not LLM judgment.
- **Quality is never traded for cost in the default pipeline.** See §1.1.

## 3. Skill Roster

| Skill | Purpose | Model | Effort |
|---|---|---|---|
| `/rfp-init` | Interactive bootstrap. Scaffolds `.ai/rfp/`, config, registry, specialist agents, gitignore, hook samples. | sonnet | medium |
| `/rfp` | Orchestrator. Reads registry + manifest, routes tasks to specialists + perspectives + reviewers, runs pipeline, consolidates. Supports `all`, `<task-id>`, `--from <step>`, `--step <step>`, `--agent <id>`, `--no-cascade`, `--force`. | sonnet | medium |
| `/rfp status` | Show what's stale per task × step based on manifest hash diffs. | haiku | low |
| `/rfp-analysis` | Discovery pipeline root. Produces primary + perspectives + reviewer + consolidated shards. | sonnet | medium |
| `/rfp-work-packages` | WBS with 5–15 PD work packages, per-perspective additions, reviewer pass. | sonnet | medium |
| `/rfp-estimate` | Five-way estimation: bottom-up, analogous, parametric, PERT, perspective. Reconciliation. | opus | high |
| `/rfp-approach` | Technical approach: 6 blocks (Categorization, Assumptions, Exclusions, Uncertainties, Delivery, **AI & Automation**). Per-perspective contributions. | sonnet | medium |
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
│   ├── rfp-approach/SKILL.md       # includes AI & Automation as 6th block
│   ├── rfp-clarifications/SKILL.md
│   └── rfp-red-team/SKILL.md
├── agents/                        # shipped generic agents
│   ├── rfp-tech-researcher.md
│   ├── rfp-client-researcher.md
│   ├── rfp-reviewer-bid-manager.md
│   ├── rfp-reviewer-solution-architect.md
│   ├── rfp-critic-cost.md
│   ├── rfp-critic-timeline.md
│   ├── rfp-critic-risk.md
│   ├── rfp-critic-evaluator.md
│   └── rfp-critic-compliance.md
├── templates/
│   ├── config.yaml.template        # per-category status/owner/notes; no separate registry
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
│       ├── approach/…              # primary/perspective/reviewer/consolidated (incl. AI block)
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
├── validations/                   # deterministic validation system
│   │                              # (named validations/ to avoid collision
│   │                              #  with Claude Code's hooks/hooks.json)
│   ├── validations.json           # plugin validation-hook registry
│   └── lib/                       # shell scripts (see §9)
├── lib/                           # shared shell helpers
│   ├── include-resolver.sh        # {{include:}} expansion
│   ├── shadow-resolver.sh         # shadow path resolution
│   ├── manifest.sh                # read/write .state/manifest.yaml
│   └── hash.sh                    # deterministic hashing for change detection
└── README.md
```

**Plugin root env var:** scripts and registry entries use `${CLAUDE_PLUGIN_ROOT}` (set by Claude Code at runtime — see existing plugins such as `plugins/dx-core/hooks/hooks.json`). Shell libraries `source`d from other scripts derive their own path from `${BASH_SOURCE[0]}` and must not depend on env vars being pre-set.

**Dependencies:** standalone. No dx-core, dx-aem, or dx-automation dependency. **No MCP servers in v1** (no `.mcp.json` — the plugin does no ADO/Jira/Figma/AEM integration). Optional ADO integration deferred to v2.

**Terminology note:** throughout §9 and §10, "hook" / "validation hook" refers to this plugin's internal validation system (the `validations/` directory), **not** Claude Code's tool-event hooks (`hooks/hooks.json`, which dx-rfp does not use in v1).

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
| `plugins/dx-rfp/validations/validations.json` | Merged with `.ai/rfp/validations/validations.json` (additive merge — see §9) |

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
- Resolver is `plugins/dx-rfp/lib/include-resolver.sh` — uses `awk`/`sed`/`find`/`sort`

### 5.3 Glob includes and `<task>` substitution

> `{{include:}}` accepts glob patterns and a literal `<task>` placeholder that the orchestrator substitutes per dispatch.

This single primitive enhancement covers the **feedback layer** (§6.5) — the daily, high-cardinality stream of bid-team memos and reviewer comments that accumulates across an active RFP cycle. Without glob support, every memo would require either a new shadow file (cardinality nightmare) or hand-maintained concatenation (provenance loss). With it, the shipped specialist starter template stays generic and the consumer just drops files into `.ai/rfp/feedback/` as the cycle progresses.

**Example — a shipped specialist starter template:**

```markdown
## Cross-cutting bid-team policies
{{include: feedback/shared/*.md}}

## Task-scoped feedback for this category
{{include: feedback/<task>/*.md}}
```

**Behaviour:**

- **Glob expansion:** matched files are sorted lexically (POSIX `sort`), then concatenated. Each file's content is preceded by `> source: <relative-path>` on its own line — a markdown blockquote that is human-readable, parser-ignorable, and gives the reviewer agent a per-file provenance trail it can cite back via `> Applied feedback: <path> — <reason>` lines in generated shards.
- **Empty match is not an error:** `feedback/<task>/*.md` with no files expands to empty string. Critical for tasks early in the cycle that have no feedback yet, and for the `/rfp-init`-bootstrap state where every directory is empty.
- **Shadow resolution applies per match:** the glob's directory part is shadow-resolved (so `feedback/shared/*.md` resolves against `.ai/rfp/feedback/shared/` if present, else `plugins/dx-rfp/feedback/shared/`). Plugin can ship default cross-cutting policies; consumer additions stack on top by virtue of being in the consumer's shadow directory. There is no merge logic — each directory is resolved separately by shadow rule, and only one directory's matches are concatenated per glob. To union both, write two `{{include:}}` lines.
- **`<task>` substitution:** the orchestrator exports `RFP_TASK_ID` per step dispatch (§9.4); the resolver replaces literal `<task>` in include paths with this value before glob expansion. Outside a task-dispatch context (e.g. when `/rfp-init` previews a template), `<task>` substitutes to empty and the include emits a single warning comment, no error.
- **Circular detection per file:** each matched file enters the visited set. Cycles through globs (a file in the glob result `{{include:}}`s back into the same dir) are detected and reported with the chain.
- **Manifest fingerprint:** the manifest's `inputs.includes_hash` for a run records the sha256 of the post-expansion content (not the glob pattern string). Adding, editing, or removing a feedback file changes the expansion → hash differs → `manifest_is_stale()` flags the run → re-dispatch on next `/rfp`. This is what makes feedback a first-class input rather than a side-channel.

**Why this fits the §0 two-primitive invariant:** still two primitives — shadow and include. Include just learned to expand globs. No new directory layer, no precedence engine, no merge semantics. Glob expansion is deterministic concatenation, not a merge.

### 5.4 What's overridable

Everything under `plugins/dx-rfp/` except `skills/*/SKILL.md` itself (skill logic is not user-overridable; behavior is controlled via templates, rules, shared refs, and hooks).

Specifically overridable:
- `shared/*.md` — methodology, frameworks, criteria
- `rules/*.md` — prompt rules
- `templates/results/**/*.md.template` — strict output templates
- `templates/agents/*.md.template` — starter specialist templates
- `validations/validations.json` + `validations/lib/*.sh` — via additive merge, not shadow (see §9)

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

### 6.5 Feedback layer — daily operating mode

`feedback/` is **not a customization point. It is the default daily operating mode** for an active RFP. Bid teams accumulate dozens of memos and reviewer comments per task across a multi-week cycle; every regen must re-ingest them as input to the specialist, with provenance preserved.

**Two-directory convention:**

```
.ai/rfp/feedback/
├── shared/                       # cross-cutting policy memos (apply to all tasks)
│   ├── compliance-gates.md
│   ├── grade-mapping.md
│   └── …
└── <task>/                       # task-scoped memos and overrides
    ├── scope-correction.md
    ├── role-allocation.md
    └── …
```

`<task>` is the category id from `config.yaml` (e.g. `be-api`, `aem-authoring`). Reserved name: a task may not be named `shared`. Both subdirectories are tracked in git (the team's work product, not generated state) and never gitignored.

**How it ingests automatically:**

Specialist starter templates (and any user-edited specialist agent) include two lines near the top of their prompt:

```markdown
{{include: feedback/shared/*.md}}
{{include: feedback/<task>/*.md}}
```

The orchestrator substitutes `<task>` per dispatch (§5.3). Glob expansion sorts files lexically and prefixes each with `> source: <relative-path>` for provenance. The specialist sees every memo applicable to its current category, in deterministic order, with sources annotated. Empty match (no feedback yet) → empty expansion → no error.

**Manifest awareness:** the post-expansion content is part of `inputs.includes_hash` (§5.3, §11.3). Adding a memo on Tuesday afternoon makes the next `/rfp <task>` re-dispatch the affected specialists automatically. No manual `--force`, no separate ingestion step, no out-of-band file watcher.

**Provenance surfacing:** every consolidated shard is expected to surface applied feedback via `> Applied feedback: <path> — <one-line reason>` lines in its markdown body. The reviewer agent's charter (`rules/reviewer-charter.md`) instructs it to flag missing or fabricated `Applied feedback:` claims. Optional v1, mandatory by v2 — see `todo-dx-rfp.md`.

**Precedence (recommended, documented in `shared/feedback-precedence.md`):**

```
RFP scope (locked)
  > standing rules (.ai/rfp/rules/*.md)
    > feedback (this layer)
      > client docs (.ai/rfp/client-docs/*)
        > skill defaults
```

Higher tiers override lower. Feedback sits above client docs because feedback is what corrects client-doc misinterpretations. Sits below standing rules because rules are the team's invariants (e.g. "always include a DR checklist") that survive any single bid. Precedence is conveyed by prompt ordering in the specialist template — there is no merge engine, no precedence YAML, no resolver code. Just consistent slot order in starter templates, documented in shared refs, shadow-overridable per project.

**What the plugin does NOT ship in v1:**

- No Drive (or other cloud-collab) ingestion skill — `feedback/` is populated by whatever flow the user chooses (manual paste, third-party tool, custom skill). Drive comment ingestion + triage + reply-posting is parked as v2 work in `todo-dx-rfp.md`.
- No automatic feedback file generator. The plugin consumes; the user (or their separate tooling) produces.
- No feedback-file schema. They are free-form markdown. The reviewer agent enforces semantic quality at the consolidation pass.

## 7. Multi-Perspective Model

Each category has:
- **One primary specialist** (required) — owns the lead deliverable
- **0..N perspectives** (optional) — other specialists contribute from their angle (security, performance, accessibility, SEO, compliance, cost, …)

Perspectives run on **all 6 pipeline steps** (analysis, work-packages, estimation, approach, clarifications, red-team). Per user decision — enterprise bids warrant heavy inference at every step. AI & Automation is folded into `/rfp-approach` as one of 6 narrative blocks (§13) — no separate skill, no opt-in flag, no multi-perspective exemption.

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

Plugin ships **two** reviewer archetypes so reviews get at least two adversarial angles:
- `rfp-reviewer-bid-manager` — commercial angle: pricing, margin, scope creep, compliance coverage
- `rfp-reviewer-solution-architect` — technical angle: feasibility, integration risk, architecture gaps

Both reviewers run on every step. Additional reviewers can be added by the user via config.

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

Separate plugin-managed working memory from user-facing deliverables. `.state/` is gitignored, regenerable from `results/` + `config.yaml`.

### 8.2 Layout

```
.ai/rfp/
├── results/                        # user-facing, git-tracked deliverables
│   └── task-<id>/
│       ├── analysis/ {shards}
│       ├── work-packages/ {shards}
│       ├── estimation/ {shards}
│       ├── approach/ {shards}     # includes AI & Automation as 6th block
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

**Numbers-vs-prose split (hallucination guard):**
Summaries contain both numeric fields (PDs, ranges, percentages) and prose fields (key_drivers, narratives, rationale). The numeric fields are **copies, not authorities** — every number in a summary must be byte-equal to the same field in either the consolidated shard's fenced YAML block or the manifest's `output.metrics` field. A post-summarize validation hook (`validate-summary-numbers-match-shards.sh`) enforces this on every `.state/context/*.yaml` write. Downstream agents are instructed — and the orchestrator's input-bundle assembly verifies — that **numbers are read from the manifest / consolidated shard, prose is read from the summary**.

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
  - "integration complexity with third-party ERP"
  - "performance SLAs require 3 rounds of optimization"
open_risks:
  - id: R-003
    text: "external API latency unknown"
    impact_pd_range: [3, 8]
perspective_deltas:
  security-lead: "+12 PD on auth/audit"
  perf-lead: "+8 PD on caching layer"
```

Later steps' agents read these YAMLs for prose context and the manifest for numbers. Raw shards remain reachable on demand.

**Summary schema:** `plugins/dx-rfp/shared/context-summary.schema.yaml` defines the allowed fields per step. The summarizer rule (`rules/summarizer-charter.md`) references the schema; a `validate-context-summary-schema.sh` hook rejects summaries that add fields or omit required ones.

**Mid-flight shard edits — output→context re-summarization:**
The manifest hashes *inputs* (config, locks, prior context, agent file, template, rules). If a user hand-edits `results/task-<id>/<step>/*.md` between runs, the shard's sha changes but its inputs do not, so `manifest_is_stale()` returns false for that shard — yet the downstream `.state/context/<task>/<step>.yaml` is now stale because it was summarized from the pre-edit shard. The asymmetry is: inputs→output is tracked, output→context is not.

**Fix (two-layer, topological):**

1. **Auto-detect on every orchestrator run** — before dispatching any step, the orchestrator performs a **topological sweep** in step order (analysis → work-packages → estimation → approach → clarifications → red-team) across every task. For each `(task, step)` it evaluates:

   ```
   context_is_stale(task, step) :=
     (any contributing shard's current sha != manifest.output.sha)
     OR
     (any upstream-step context yaml in the same task was rewritten
      during THIS sweep, i.e. upstream.mtime > this.mtime after the
      upstream was re-summarized)
   ```

   If stale, re-summarize in place (no specialist/reviewer re-dispatch). Logged as `context-resummarized-due-to-shard-edit` (direct edit) or `context-resummarized-due-to-upstream-drift` (cascade) in `.state/logs/`.

   The sweep is single-pass and monotone: once step N's context is re-summarized, its mtime is advanced, so step N+1's staleness check sees the upstream drift on the same pass. No second traversal needed.

   Why topological (not flat): the shard-drift check catches direct edits, but the downstream context was summarized from the *old* upstream context (§8.7 — downstream agents read prior-step context yaml). Drift at step N implies drift at N+1..N+k even when no shard at those steps changed. The upstream-mtime OR-clause is the dual of the shard-sha clause; without it the cascade is silent.

2. **Explicit command** — `/rfp <task> --step <step> --resummarize` runs the topological sweep starting at the specified step, not just the one task×step. Useful after multiple manual edits when the user wants to flush contexts without a full orchestrator run.

A post-step hook `validate-shard-sha-matches-manifest.sh` asserts no drift at the end of each step (catches the reverse case — a specialist wrote a shard but the manifest wasn't updated). **Count bumped: 25 → 26.**

### 8.4 Locks

Global invariants frozen at step boundaries. Later steps receive them as read-only.

| Lock | Frozen after | Consumed by |
|---|---|---|
| `scope.md` | `/rfp-analysis` (all tasks) | every downstream step |
| `roles.md` | `/rfp-work-packages` (all tasks) | estimation, approach |
| `wbs.md` | `/rfp-work-packages` (all tasks) | estimation, clarifications, red-team |

Lock invalidation: re-running a step invalidates its lock **globally** — scope drift must propagate, not be hidden per-task. See §10 (re-runs).

### 8.5 Cross-task registers

As each task's clarifications/risks/assumptions/dependencies emerge, they're merged into dedup'd cross-task YAMLs. The `/rfp-clarifications` step reads `registers/clarifications.yaml` to avoid asking duplicate questions across N tasks.

**Dedup algorithm:** jaccard similarity (not cosine — keeps the no-MCP/no-embeddings constraint from §2). Tokenizer is deterministic and documented in `shared/question-filter.md`:
1. Lowercase
2. Strip punctuation
3. Tokenize on whitespace
4. Remove a fixed stop-word list (`shared/question-filter.md` ships the list)
5. Compare as sets; `similarity = |A ∩ B| / |A ∪ B|`

Threshold is `config.rfp.clarifications.dedup_threshold` (default `0.8`). Hook `validate-clarification-dedup.sh` reads the same algorithm from `lib/jaccard.sh` to enforce post-hoc.

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
      includes_hash: 7s8t9u           # sha256 of all post-glob-expansion {{include:}} content
                                      #   (covers feedback/, shared refs, etc. — see §5.3)
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

**Classifying sections** — to avoid "is an assumption list hard or soft" debates:

| Section example | Tier | Reason |
|---|---|---|
| YAML frontmatter (`task`, `step`, `agent`, `version`) | Hard | Every hook keys off these |
| Fenced YAML `## PD Matrix` with `roles`, `totals`, `by_role`, `by_wp`, `bottom_up`, `top_line` | Hard | `validate-pd-matrix-sums.sh` and `validate-bottom-up-times-multiplier.sh` parse this |
| Fenced YAML `## PERT` with `o`, `m`, `p`, `expected`, `stddev` | Hard | `validate-pert-formula.sh` recomputes `(O+4M+P)/6` |
| Fenced YAML `## Risks` list (`id`, `likelihood`, `impact_pd_range`) | Hard | Cross-task risk register merges from this |
| Fenced YAML `## Assumptions` list (`id`, `text`, `source`) | Hard | Reviewer cross-checks against clarifications register |
| Prose `## Summary` (~150 words) | Soft | `validate-word-counts.sh` warns on overruns but never blocks |
| Prose `## Narrative` blocks | Soft | Reviewed subjectively by reviewer agents |
| Bullet list `## Findings` under a prose heading | Soft | Structure hint; hook does not parse |

Rule of thumb: **if a hook needs to parse it, it's hard and lives in a fenced YAML block. If only humans or LLMs read it, it's soft prose.**

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
plugins/dx-rfp/validations/
├── validations.json              # plugin validation-hook registry
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
    ├── validate-no-placeholder-tokens.sh
    ├── validate-context-summary-schema.sh        # §8.3 schema conformance
    ├── validate-summary-numbers-match-shards.sh  # §8.3 hallucination guard
    └── validate-shard-sha-matches-manifest.sh    # §8.3 output→context drift guard
```

**Count: 26 built-in validation hooks** (canonical). Count is enforced programmatically by `scripts/validate-rfp-validations.sh` (plan E9) — file-count, registry-count, and declared `EXPECTED` must all equal 26 or CI fails.

### 9.3 Registry format

```json
{
  "validations": [
    {
      "id": "rfp-validate-pd-matrix-sums",
      "event": "post-agent",
      "steps": ["estimation"],
      "agents": ["_primary", "security-lead", "perf-lead"],
      "script": "${CLAUDE_PLUGIN_ROOT}/validations/lib/validate-pd-matrix-sums.sh",
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
.ai/rfp/validations/
├── validations.json              # user registry (appended)
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
    validations:
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

  categories:                     # free-form, user-defined; per-category status replaces the old registry.yaml
    - id: aem-authoring
      label: "AEM Content Authoring"
      specialist: aem-content-lead
      perspectives: [accessibility, seo-lead]
      status: pending             # pending | done | parked — orchestrator skips `parked` unless --force
      owner: ""                   # optional bid-team owner
      notes: ""                   # free-form
    # … (13 typical for large enterprise RFP)

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
    feedback:    .ai/rfp/feedback/      # bid-team daily memos + comments (§6.5)
    results:     .ai/rfp/results/
    state:       .ai/rfp/.state/
    specs:       .ai/specs/

  red_team:
    critics:                      # user-extensible; starter set ships with plugin
      - { id: cost,       agent: rfp-critic-cost }
      - { id: timeline,   agent: rfp-critic-timeline }
      - { id: risk,       agent: rfp-critic-risk }
      - { id: evaluator,  agent: rfp-critic-evaluator }
      - { id: compliance, agent: rfp-critic-compliance }

  clarifications:
    dedup_threshold: 0.8          # jaccard similarity threshold for cross-task dedup
                                  # (consumed by validate-clarification-dedup.sh)

  validations:
    disabled: []
    fail_on_warning: false
    extra_dirs: [".ai/rfp/validations"]

  deliverables:
    format: markdown              # v1 only
```

### 11.3 `config_section_hash` — manifest fingerprint map

The manifest's `config_section_hash` (§8.6) is computed per run from a subset of `config.yaml`. The mapping below is the source of truth for stale detection:

| Section hash | `yq` expression | Invalidates |
|---|---|---|
| `rfp_specialists` | `.rfp.specialists` | all tasks' analysis + work-packages onward |
| `rfp_categories_schema` | `.rfp.categories[] \| {id, label, specialist, perspectives}` | all tasks matching affected ids (perspectives may change) |
| `rfp_roles` | `.rfp.roles` | all tasks' estimation onward |
| `rfp_estimation` | `.rfp.estimation` | all tasks' estimation onward |
| `rfp_red_team` | `.rfp.red_team` | all tasks' red-team step |
| `rfp_clarifications` | `.rfp.clarifications` | all tasks' clarifications step |
| `rfp_validations` | `.rfp.validations` | hook-dependent shards re-validated (no regen) |
| `rfp_run_mode` | runtime value of any future `--preview`/reduced-scope flag ⊕ `config.rfp.cost.*` toggles | all context summaries (not shards) — summarizer rubric differs per mode |

**Note — feedback hashing is per-run, not per-config-section:** the feedback layer (§6.5) is hashed via the manifest's `inputs.includes_hash` field on each individual run (§8.6), not via `config_section_hash`. That is the right level: feedback files attach to specialist invocations, not to global config; hashing per-run gives task-granular invalidation when memos land, without invalidating unrelated tasks.

**Schema vs state split on `categories[]`:** the per-category `status`, `owner`, `notes` fields (§11.2) are *state*, not schema. They drive orchestrator gating (`parked`/`done`) but do not change what any agent would produce for a task. They must **not** contribute to `config_section_hash`. The fingerprint map above intentionally projects only the schema fields (`id`, `label`, `specialist`, `perspectives`). Flipping a task from `pending` to `done` or adding a note must not invalidate analysis.

`manifest_is_stale()` compares the stored hash against the current hash of the matching yq subtree. `lib/hash.sh` exports `hash_config_section(path, yq_expr)` for this. The two-selector pattern (one yq expression over the same array for invalidating fields, state fields omitted entirely) is the standard approach — avoids moving state into a sibling file.

**`rfp_run_mode` — mode as cache key (future-proof mechanism):** v1 ships only full-rigor mode (§1.1). The hash row exists so that any future opt-in reduced-scope flag (e.g. the deferred `--preview` in `todo-dx-rfp.md`) automatically invalidates context summaries when toggled. A reduced-scope run writes thinner summaries; without mode-aware invalidation, a subsequent full run would read those summaries silently. Encoding the effective mode as a `config_section_hash` input means: mode toggle → all context yamls flagged stale → topological sweep (§8.3) re-summarizes from (unchanged) shards under the new rubric. Cost is summarizer-only, no specialist re-dispatch. Keeps the parallel build graph — shards vs contexts — coherent across any future mode additions without further spec changes.

### 11.2 Task tracking lives in `categories[]`

v1 collapses the previously-separate `registry.yaml` into `config.yaml`: per-task state (`status`, `owner`, `notes`) lives directly on each `categories[]` entry (§11.1). One file, one authority. The orchestrator skips `status: parked` categories unless `--force` is passed, and treats `status: done` as review-mode (per §3).

## 12. Init Idempotency Matrix

| File category | Re-run behavior |
|---|---|
| `config.yaml` | Preserve user edits; offer to add new keys from template; never remove user keys |
| `.claude/agents/rfp-*-specialist.md` | Never modified without confirmation (diff + prompt) |
| `.ai/rfp/shared/*.md` (shadows) | Diff + prompt |
| `.ai/rfp/rules/*.md` (shadows) | Diff + prompt |
| `.ai/rfp/templates/**/*.template` (shadows) | Diff + prompt |
| `.ai/rfp/validations/**` | Never modified (sample files only provided if absent) |
| `.ai/rfp/.state/` | Preserved — never touched by init |
| `.ai/rfp/client-docs/` | Never touched by init |
| `.ai/rfp/feedback/shared/` | Created if absent; never overwritten. Tracked in git. |
| `.ai/rfp/feedback/<task>/` | Created (empty) per declared task in `categories[]`; never overwritten. Tracked in git. |
| `.gitignore` | Check and add if missing: `.ai/rfp/client-docs/`, `.ai/rfp/.state/`. **`feedback/` is NOT gitignored** — bid-team work product is part of the project history. |

## 13. Shared References

Plugin content in `plugins/dx-rfp/shared/` (shadow-overridable, include-able):

| File | Content |
|---|---|
| `methodology.md` | 5-phase process, role archetypes, effort distribution benchmarks |
| `estimation-framework.md` | Cockburn calibration, overhead factors, PERT, five-way reconciliation |
| `question-filter.md` | Three-gate filter, "ASSUME not ASK" philosophy, target density |
| `narrative-blocks.md` | 6-block spec (Categorization, Assumptions, Exclusions, Uncertainties, Delivery, **AI & Automation**), word-count guidance |
| `red-team-criteria.md` | Critic rubrics, weak-section heuristics, evaluator simulation |
| `pitfalls.md` | 10 named anti-patterns |
| `context-summary.schema.yaml` | JSON-Schema for `.state/context/<task>/<step>.yaml` (consumed by `validate-context-summary-schema.sh`) |
| `feedback-precedence.md` | Documented precedence ladder for the feedback layer (§6.5). Not enforced by code — conveyed via prompt ordering in starter specialist templates. |

## 14. Versioning & Conventions

- Conventional commits: `feat(dx-rfp): …`, `fix(dx-rfp): …`, `docs(dx-rfp): …`
- semantic-release handles version bumps across **all** plugins in lockstep — dx-rfp's first release will publish at the same version as the other four plugins (e.g., `2.104.0`), not `0.1.0`. README should say so to avoid confusing first-time users.
- Skill naming: `{plugin}-{name}` → `rfp-init`, `rfp-analysis`, `rfp-work-packages`, etc. Short plugin-prefix is consistent with dx-aem (`aem-*`) and dx-automation (`auto-*`).
- Branching skills use DOT digraphs with matching `### Node Details` sections (dx-core pattern)
- Linear skills use numbered steps
- Shell scripts: `chmod +x`, bash 3.2+ target (macOS default), POSIX-compatible where possible
- **Windows support:** WSL is required. README states this. CI runs on Linux.
- **Mid-flight team overrides:** bid-team decisions made between runs (e.g. "bump BE PDs by 15%") are expressed via shadow files under `.ai/rfp/rules/*.md` or `{{include:}}` directives from per-task addenda — no third primitive. Direct edits to `results/*.md` are preserved by the snapshotting layer (§10.4); the manifest records the edited SHA so downstream staleness detection still works.

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

- `plugins/dx-rfp/` exists with **8 skills** (`/rfp-init`, `/rfp`, `/rfp-analysis`, `/rfp-work-packages`, `/rfp-estimate`, `/rfp-approach`, `/rfp-clarifications`, `/rfp-red-team`), shipped agents (2 reviewer archetypes, 5 critics, 2 researchers), starter agent templates, result templates, shared refs, validations lib, lib helpers
- `validate-skills.sh` passes for dx-rfp (naming, collisions) **and** validates the 26-entry validation-hook count against `validations/validations.json` programmatically (fails on drift)
- `/rfp-init` on clean test project generates `.ai/rfp/config.yaml` (including per-category `status/owner/notes`), scaffolded specialist agents, updates `.gitignore`
- `/rfp` with a 2-category config runs end-to-end, producing all 6 steps (analysis, work-packages, estimation, approach [6 blocks incl. AI], clarifications, red-team) with primary + perspectives + reviewer + consolidated shards per step
- `/rfp-red-team` produces all configured critic shards + consolidated scored summary (starter set = 5, user-extensible)
- `/rfp status` correctly flags stale tasks after config/client-docs/agent edits
- Re-running `/rfp-init` does not overwrite user edits
- Re-running `/rfp <task>` cascades invalidation with confirmation, snapshots prior outputs
- Shadow override works: a `.ai/rfp/shared/methodology.md` replaces plugin's version at runtime
- `{{include:}}` directive expands recursively with circular-include detection
- All plugin-shipped validation hooks pass on a clean fixture run
- Committed reference fixture (`plugins/dx-rfp/tests/fixtures/reference/`) exercises a 2-category pseudo-RFP end-to-end; CI runs it on every PR
- User validation hooks merge additively with plugin hooks; disabled list honored
- Context summaries pass `validate-summary-numbers-match-shards.sh` — no numeric drift between summary and manifest/consolidated shards
- Grep of `plugins/dx-rfp/` returns zero matches for any known client name, URL, or domain term
- Plugin installs cleanly via marketplace alongside existing 4 plugins
