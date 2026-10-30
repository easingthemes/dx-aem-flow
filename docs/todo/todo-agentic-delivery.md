# TODO: Agentic Delivery Operating Model

Intake from McKinsey, "Rewiring software delivery for the agentic era" (2026-05-28), and two public critiques of it (Mneme HQ, NetworkGain). The article describes 24-hour delivery: agents run structured work overnight, humans review at defined gates by morning, and handoffs are machine-readable. Most of that already exists here (`.ai/specs/` handoffs, `dx-automation` agents, review gates). What follows is the part that does not.

Already tracked elsewhere, not repeated here: metrics roll-up → #144, per-run caps and `confidence.json` for every writing agent → #219, PR-feedback → rules learning loop → #143, Azure-native triggers for the remaining agents → #211, context graph → #189–#194 (done), evals on release tags → [todo-testing.md](todo-testing.md).

## Evidence check (2026-10-30)

The article's numbers ("3–5x productivity", "60% smaller teams") are reports from unnamed client companies, not measurements. Independent data points the other way on the parts that matter here:

| Source | Finding | What it means for dx |
|--------|---------|----------------------|
| Faros AI telemetry 2026 (22k devs; vendor) | epics/dev +66%, but PR size +51%, review time +91% on high-adoption teams, bugs/dev +54%, incidents per PR more than tripled, unreviewed code to prod +31% | Output is not the constraint. Human review and quality are. |
| DORA 2025 (~5k respondents) | AI now goes with higher throughput **and** higher instability (change fail rate, rework). "AI is an amplifier" | Measure instability, not only speed |
| RAMP, arXiv 2608.25241 (441 repos) | commits +28–38% at every maturity level; repos **without** committed AI config: ~2x cognitive-complexity growth (+53% vs +27%), 1.7x static-analysis warnings. 73.8% of AI config files committed once, never changed | Committed rules pay off, but they rot if nobody updates them |
| Microsoft CLI-agent rollout, arXiv 2607.01418 | ~24% more merged PRs over 4 months, not a novelty effect; adoption spreads through peers | Real, moderate gain. Not 3–5x |
| METR 2025 RCT / 2026 follow-up | 2025: experienced devs 19% slower while they felt 24% faster. 2026: RCT could not run (devs refused to work without AI); survey only | Self-reported gains are not evidence. Measure. |
| arXiv 2607.26375 (54 users) | agents speed up first delivery but hurt comprehension; auto-accept goes with the lowest understanding | Reviewers of agent PRs need help to understand the change |

**Real value:** machine-readable handoffs, a standard requirements-to-code structure, committed rules, defined human gates, overnight runs that leave PRs for morning review (practitioners report doing this). **Hype:** 3–5x, 60% smaller teams, "continuous 24h delivery" as a goal on its own. More overnight output only lengthens the review queue the data already points to as the bottleneck.

So the priority order for dx: quality and review capacity first, then measurement, then more autonomy.

## Deterministic architecture-rule enforcement

**Added:** 2026-10-29
**Problem:** Architecture and convention rules live as prose in `.ai/rules/*.md` and in `dx-step-verify` phase 5 ("file naming, package structure, convention checks"), so a model checks them. A model can be argued out of a rule, and pipeline agents (DevAgent, BugFix, SimpleAgent) write code with no human in the loop until PR review. The critique of the McKinsey model makes the same point: an operating model does not run at the moment an agent writes code, and only a deterministic check gives a binary verdict on the output. A rule that a model checks fails silently. A rule that a script checks fails loudly. The quality data above (bugs, complexity, warnings rising with agent adoption) is why this is High.
**Scope:** `plugins/dx-core/skills/dx-step-verify/SKILL.md` (phase 5), `plugins/dx-core/skills/dx-scan/SKILL.md` (discovers conventions), `.ai/config.yaml` schema (new optional `verify.arch-command` or similar), `plugins/dx-core/templates/rules/`.
**Done-when:** `grep -n 'arch-command\|architecture.command' plugins/dx-core/skills/dx-step-verify/SKILL.md` finds phase 5 running a configured command and failing on a non-zero exit before any model judgement, AND `docs/reference/` documents the config field, AND `/dx-scan` proposes such a command when it detects a known tool (e.g. ArchUnit, dependency-cruiser, eslint boundaries) in the project.
**Approach:** Config-driven, as everything else: the plugin does not ship rule engines, it runs the consumer's own. Phase 5 order: configured command first (hard fail), then model review for what no tool covers. Do not convert `.ai/rules/` prose into regexes. Cross-ref #242 (verification layering): this adds a deterministic layer, so it should remove a model layer, not stack another one.
**Done 2026-10-30:** `build.arch-command` (config key under `build:`, like the other commands) runs in `pre-review-checks.sh` phase 5 with `DX_BASE_SHA`/`DX_CHANGED_FILES`; a failure is marked `"blocking": true`, and `dx-step-verify` routes it to a new **Report FAIL (blocking architecture check)** node after the 2 fix attempts, skipping code review. The skill forbids weakening the check to pass. `/dx-scan` 3f detects ArchUnit, dependency-cruiser, ESLint boundaries and arch npm scripts and proposes the command. Suite `dx-step-verify/tests/run-tests.sh` +10 checks; 4 fail on the old gate. Not done: removing a model layer (#242 decides that).

## Review-load budget for agent PRs

**Added:** 2026-10-30
**Problem:** Every writing agent can open a PR whenever it is triggered, and nothing limits how much unreviewed agent work piles up. Faros 2026 telemetry shows the effect: PRs got 51% bigger and review time went up 91% on high-adoption teams, while code reaching production unreviewed rose 31%. #219 caps one run (files, lines). Nothing caps the **queue**: ten small agent PRs a night are still more than one reviewer can read with care, and a reviewer under load approves without reading.
**Scope:** `plugins/dx-automation/data/pipelines/cli/*.yml` (writing agents: dev-agent, bug-fix, simple, dod-fix), `plugins/dx-automation/data/scripts/pipeline-agent.js`, `.ai/config.yaml` schema (`automation.review-budget.*`), `docs/reference/config-reference.md`. Cross-ref #219, #254.
**Done-when:** a writing agent checks the number of its own open, not-yet-reviewed PRs in the target repo before it starts writing, and when `automation.review-budget.max-open-prs` is reached it posts one ADO comment ("waiting: N agent PRs need review first") and stops without writing, AND a hermetic test stubs the ADO PR list and asserts both paths (under budget → runs, at budget → comment + exit 0).
**Approach:** A WIP limit, the Kanban way. Count open PRs created by the agent identity with no human vote. Default off (no value set), so nothing changes for existing installs. Optional second limit: total changed lines across open agent PRs.

## Reviewer guide in agent PR descriptions

**Added:** 2026-10-30
**Problem:** The person reviewing an agent PR did not write the code and often did not write the plan. Research on coding agents (arXiv 2607.26375) finds they speed up delivery but hurt understanding, and that low-effort acceptance goes with the lowest comprehension. `dx-pr` builds the description from `share-plan.md` (what was planned) and only warns on `confidence: low`. It does not tell the reviewer where the risk is, what was not tested, or which decisions the agent made on its own.
**Scope:** `plugins/dx-core/skills/dx-pr/SKILL.md`, `plugins/dx-core/skills/dx-pr-commit/SKILL.md`, the PR description template, inputs it already has: `implement.md` key decisions (#190), `confidence.json` (#219), `dx-step-verify` results.
**Done-when:** `grep -n 'Reviewer guide' plugins/dx-core/skills/dx-pr/SKILL.md` finds a required section with at least: files ordered by risk with one line why each, decisions the agent took that the spec did not settle, what was not verified (e.g. no AEM run, no browser check), and an explicit "start reading here" pointer, AND an eval case under `plugins/dx-core/evals/` checks the section is present and names the known risky file in a fixture.
**Approach:** Keep it short (≤10 lines). It replaces nothing in the description, it goes first. Same section helps the automated PR Reviewer, which can start from the listed risks.

## AI rules freshness check

**Added:** 2026-10-30
**Problem:** The RAMP study (arXiv 2608.25241, 441 repos) finds that repos with committed AI configuration had about half the complexity growth of those without, but 73.8% of those files were committed once and never changed. Our `.ai/rules/*.md`, `.ai/config.yaml` and seed data follow the same pattern: `/dx-init` and `/dx-scan` write them once, and the code moves on. Stale rules are worse than none, because agents follow them with confidence.
**Scope:** `plugins/dx-core/skills/dx-doctor/SKILL.md`, `.ai/rules/`, `.ai/project/` seed data, cross-ref #143 (learning loop that would keep rules current).
**Done-when:** `/dx-doctor` reports, per file in `.ai/rules/` and `.ai/project/`, the date it last changed in git and the number of commits to the code paths it describes since then, and flags a file as stale above a threshold (config, default e.g. 90 days and 200 commits), verified by a hermetic `*.test.sh` on a seeded repo with one fresh and one stale rule file.
**Approach:** Only `git log` and counting, no model call. The fix for a stale file stays human or goes through `/dx-scan` and #143. This is the cheap detector; #143 is the expensive cure.
**Done 2026-10-30:** `plugins/dx-core/skills/dx-doctor/scripts/rules-freshness.sh` (stale = older than `max-days` **and** more than `max-commits` commits outside `.ai/`/`.claude/` since; untracked files reported). Wired as `/dx-doctor` step 2c; thresholds under `doctor.rules-freshness.*`. Suite `scripts/__tests__/rules-freshness.test.sh` (14 checks) fails 3 checks on a mutant that drops the exclusion and ORs the thresholds.

## Overnight agent chain with a morning digest

**Added:** 2026-10-29
**Re-scoped 2026-10-30:** priority Medium → Low. The evidence check above shows review capacity, not agent output, is the bottleneck. A chain that produces more PRs overnight makes that worse. Do this only after #255 (review budget), #219 (caps on every writing agent) and #144 (metrics) exist, and start with the digest alone: it has value even with no chain.
**Problem:** Each `dx-automation` agent runs on its own trigger (comment token, Service Hook, build policy). Nothing connects them into the flow the article describes: a story becomes Ready in the evening and in the morning it has an RE spec, a draft PR, a PR review and QA notes waiting at one human gate. Today a human has to start each next step, and nobody gets one summary of what agents did overnight and what waits for a decision.
**Scope:** `plugins/dx-automation/data/pipelines/cli/ado-cli-hub.yml` (hub router), `plugins/dx-automation/data/pipelines/cli/*.yml`, `.ai/automation/registries/agents.json` (consumer agent registry), `plugins/dx-automation/skills/auto-status/SKILL.md`, cross-ref #15 (pause-and-resume), #154 (universal trigger), #211 (trigger parity), #255.
**Done-when:** (phase 1) a scheduled digest step writes one summary per project (tickets touched, PRs opened, gates that stopped a run and why, items waiting for a human), verified by a hermetic `*.test.sh` that feeds recorded agent outputs and asserts the digest content. (phase 2) a documented, opt-in chain config (e.g. `automation.chain:` in `.ai/config.yaml`) where a passing DoR verdict starts the RE agent and a finished RE spec starts DevAgent, each stopping at its existing gates and at the #255 review budget.
**Approach:** Chain through ADO state the agents already write (tags, comments, linked PRs), not a new orchestrator service, so it stays Azure-native. Every link is opt-in per project; default stays one agent per trigger. The digest reads `.ai/specs/*/` and pipeline results; it is the natural consumer of #144's `metrics.json`. Human gates stay human: the chain never merges and never re-runs a blocked step on its own (same rule as `dx-simple` recovery).
