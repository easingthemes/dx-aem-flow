# SuperPlane ideas for the dx plugins: value or hype?

**Date:** 2026-10-27
**Source:** a read-only clone of SuperPlane (Apache-2.0, "open source factory for one-shot engineering"). We only read files. Nothing was built or run.
**Status:** Research only. No TODO rows were added. Each ADOPT/ADAPT item names the existing TODO it extends, or says it would need a new one.

## What SuperPlane is

SuperPlane is a Go + Postgres + RabbitMQ server with a React UI (`AGENTS.md`, "Project Overview"). Its "Software Factory" sits behind the experimental feature flag `factories` (`docs/design/factory.md`). The factory has these parts:

- **Work orders**: a durable record per task, with an append-only `factory_work_order_events` timeline.
- **Lines**: ordered steps. Each step runs one canvas app.
- **Intake**: a backlog scorer.
- **Merge confidence**: PR scoring.
- **PR feedback handlers**: comment mentions and failed checks are routed back to an agent.
- **Usage ledger**: per-run token and compute cost.

Most of this needs a server, a database and a UI. dx has none of those. The test here is narrow: **which ideas still hold when the "server" is ADO (work items, PR threads, pipeline runs, build tags) plus Markdown skills and bash?**

## Ground rules for the verdicts

- **SKIP** an idea that needs a server, a DB or a UI, duplicates what ADO already gives, or has no concrete dx failure behind it.
- **ADAPT** an idea that solves a real dx problem but only in a smaller, ADO-native form.
- **ADOPT** an idea that fits as-is.
- dx constraints that shape every sketch:
  - Config lives in `.ai/config.yaml`.
  - The three-layer override puts `.ai/rules/` above config, and config above plugin defaults.
  - Helper scripts must be hermetic and tested (`*.test.sh` / `run-tests.sh` are discovered by CI).
  - The skill-listing budget is already over (TODO #238), so **extend existing skills rather than add new ones**.
  - Prefer a deterministic grader over an LLM judge.

---

## Candidates, ranked by value ÷ effort

| # | Idea | Verdict | Value | Effort | Extends |
|---|------|---------|-------|--------|---------|
| 1 | Stale-head guard + explicit push lease | **ADOPT** | Medium | Very low | #216 (adjacent) |
| 2 | Enforce the declared cost cap; record cost + outcome per run on the ADO build | **ADAPT** | High | Low | #50, #144, unblocks #251 |
| 3 | Agent-fit score (Clarity / Complexity / Verifiability, weakest wins) | **ADAPT** | High | Low–Med | #219, #68 |
| 4 | Failed-build repair loop for agent-authored PRs | **ADAPT** | High | Medium | new (pairs with #211, #217) |
| 5 | Path-based PR risk tier with AEM category floors (+ reversibility) | **ADAPT** | Medium | Low | #237 |
| 6 | Drift from the linked work item in the PR Reviewer | **ADAPT** | Medium | Low | #237 |
| 7 | Structured result file + deterministic outcome check | **ADAPT** | Medium | Low | #218 |
| 8 | "Evidence, or the attempts you made" rule for UI changes | **ADAPT** (small) | Low–Med | Low | new (small) |
| 9 | "Do not invent a token/time budget" prompt line | **SKIP** (watch) | Unproven | Trivial | — |
| 10 | Approval steps / pause-and-resume as a product feature | **SKIP** | — | — | #15 stays as scoped |
| 11 | Work-order timeline, board, line-metrics UI | **SKIP** | — | — | — |
| 12 | Multi-source intake (Sentry, Dependabot, scheduled proposer) | **SKIP** | — | — | — |
| 13 | Their prompt testing approach | **SKIP** (dx is ahead) | — | — | — |
| 14 | Per-PR exclusive-access lock | **SKIP** (covered) | — | — | #216 + item 1 |

---

## 1. Stale-head guard + explicit push lease: ADOPT

**What SuperPlane does.** The failed-checks fixer prompt says: *"Verify the remote pull request head before you push. Stop without pushing when the remote head differs from this revision."* The revision is pinned from the triggering event (`pkg/grpc/actions/factories/pr_feedback_checks_template.go`, `prFeedbackChecksPrompt`). The design doc says this about revisions: *"A newer head updates the current revision. It does not cancel a run that is still bound to an older SHA"*. Activities are bound to one head SHA (`docs/design/factory.md`, "Revisions").

**What dx has today.**
- `dx-pr-answer` pushes fixes onto a human's PR branch in automation mode (`docs/todo/todo-automation.md`, "PR-Answer fully autonomous mode").
- `dx-pr-commit` step 3 says *"If rejected after rebase, use `--force-with-lease`"* (`plugins/dx-core/skills/dx-pr-commit/SKILL.md:147`).
- `dx-pr-answer/SKILL.md:928` repeats the rule.
- The PR Reviewer posts line-anchored threads with no check that the PR moved during the review.
- No TODO covers this. #216 is about duplicate *work-item* triggers, not PR heads.

**Value test.**
- **Problem.** A bare `--force-with-lease` uses the remote-tracking ref as its lease. The rebase that precedes it has just fetched that ref, so the lease checks nothing. A human commit pushed during the agent run can be overwritten.
- **Second problem.** Separately, review comments anchored to lines of a superseded iteration land on the wrong code.
- **Who benefits.** Every team running PR Answerer or PR Reviewer unattended.
- **Cost.** A few lines plus one hermetic git test.
- **Risk.** Near zero. The worst case is a skipped run, and the next PR-update trigger reruns it.

**Verdict: ADOPT.** It is cheap and fixes a real correctness hole that exists today.

**Sketch.**
- At run start, record the PR's `lastMergeSourceCommit.commitId` to `$SPEC_DIR/pr-head.sha`.
- Before posting threads or pushing:
  - Re-fetch the PR.
  - If the head changed, post nothing line-anchored.
  - Exit `verdict: warn` with "superseded by `<sha7>`".
- In `dx-pr-commit`, replace the implicit lease with an explicit one: `git push --force-with-lease=<branch>:<recorded-sha>`.
- Test: `plugins/dx-core/data/lib/push-lease.test.sh` seeds a bare remote and two clones. It shows that the explicit lease rejects and the implicit one does not. Use `GIT_CONFIG_GLOBAL=/dev/null`.

---

## 2. Enforce the declared cost cap; record cost + outcome per run on the ADO build: ADAPT

**What SuperPlane does.**
- **Records** usage per run: input, output, cache read/write and reasoning tokens, plus the cost (`pkg/components/runner/agent_usage.go`, `llm_usage.js`, which writes a `llm_usage.json` sidecar).
- **Rolls usage up** per work order (`task_report.go`).
- **Computes per-line 30-day metrics** (`docs/design/factory.md`, "Line metrics"):
  - Success rate counts **merged PRs**, not agent self-reports.
  - Median run time.
  - **Cost per success** = total execution cost ÷ merged count.
- It does **not** enforce a per-run budget.

**What dx has today.**
- `pipeline-agent.js:432-450` prints `total_cost_usd` and warns over `COST_ALERT_USD` (default $4). The figure goes to the log only.
- dx-simple declares **G8 Cost ≤ $2** and **G9 Time ≤ 12 min** (`dx-simple/SKILL.md:150-151`). No code enforces G8: grep finds only the table row.
- Related TODOs:
  - #50 (budget tracking) plans DynamoDB/CloudWatch.
  - #144 (metrics roll-up) has only one producer (#219).
  - #251 says `/auto-status` calls scripts deleted in March and fails on every run.

**Value test.**
- **Problem.** Nobody can answer "what does a merged agent PR cost us, per agent?" One gate is advertised but not enforced.
- **The key ADO-native insight.** ADO already stores durable run history: result, start/finish time, definition and source. Only **cost** and **verdict** are missing from that data. **Build tags** carry both, can be queried, and need no AWS.
- **Who benefits.** Leads deciding which agents to keep. Also needed to tune the dx-simple gates and item 3's threshold with data.
- **Cost.** Low: logging lines in `pipeline-agent.js` plus one aggregation script.
- **Risk.** A hard budget can kill a run mid-write. Mitigate by keeping the per-skill fallback comment that `ado-cli-simple.yml` already posts when the agent dies.

**Verdict: ADAPT.** Copy the *definitions* (outcome = merged PR, cost per success). Skip the ledger DB. Add enforcement, which SuperPlane lacks.

**Sketch.**
- **`pipeline-agent.js`.**
  - If `COST_LIMIT_USD` is set, pass the Agent SDK's per-run budget option (`maxBudgetUsd` in recent SDKs; confirm against the pinned version).
  - On `result`, print `##vso[build.addbuildtag]dx-verdict:<pass|warn|fail>`, `dx-cost:<0.00>` and `dx-wi:<id>`.
  - Also upload `run-summary.json` as a build artifact.
- **Config.**
  - `automation.agents.<name>.cost-limit-usd` (exported as `COST_LIMIT_USD` by `/auto-pipelines`).
  - `dx-simple.gates.max-cost-usd` replaces the hardcoded $2.
- **`/auto-status`.**
  - Rewrite it on ADO data. Fixes #251 with no AWS.
  - List builds per agent definition for 30 days and read their tags.
  - Join agent-created PRs by `createdBy` ∈ bot identities, with status `completed` + merged.
  - Print runs, verdict mix, median duration, total cost, merged rate and cost per merged PR.
- **Tests.**
  - Tag formatting in the existing `plugins/dx-automation/data/scripts/__tests__/`.
  - The aggregation script runs against fixture JSON for the builds and PR lists.

---

## 3. Agent-fit score (Clarity / Complexity / Verifiability, weakest wins): ADAPT

**What SuperPlane does.** Backlog "intake" scores every draft task for *fit for one unattended agent run* (`pkg/components/runner/analysis_user_prompt_review.md`, `analysis_protocol_review.md`, `.agents/skills/refine-task-scoring/SKILL.md`):

- **Three integer axes, 1–3:**
  - **Clarity** (outcome, scope and done are decided).
  - **Complexity** (one agent finishes it in one run without steering).
  - **Verifiability** (checks the agent can run cover the acceptance criteria).
- The headline is **the weakest axis**, and the model "never invent[s] the headline number". A default threshold gates auto-start (`DefaultIntakeConfidencePct = 65`, `intake_template.go:51`).
- **Calibration rules fight the usual LLM failure modes:**
  - "A long task description is not a large task."
  - Lower a score only for "a concrete obstacle … found in the code".
  - "Do not soften a 1 … a wrong 3 costs them a failed run."
- Each summary is one sentence of ≤14 words naming the decisive fact.
- Explicit **moves that raise a score**: narrow the scope, add a failing test first, or put the risky step behind human review.
- Questions are asked only when the answer changes outcome, scope or acceptance.

**What dx has today.**
- `dx-dor` scores a story against the team's **wiki DoR checklist**, which measures readiness for *humans* (`plugins/dx-core/skills/dx-dor/SKILL.md`).
- `dx-estimate` produces hours and story points.
- `dx-simple` has G3 classification and G1–G9 gates, but only after it has started.
- Nothing answers "should we hand this story to DevAgent / BugFix unattended?" before a pipeline spends money on it.
- `dx-req-dod:172` already separates "Agent-verifiable" criteria, so the concept exists, just at the wrong end.
- Nearest TODOs: #219 (confidence gates for every writing agent) and #68 (plan testability review, which is the Verifiability axis applied to plans).

**Value test.**
- **Problem.** For AEM teams, Verifiability is the axis that bites. Pipelines have no AEM (#127). A story whose acceptance criteria are visual or authoring-only cannot be proven in a pipeline run. Today that is only discovered at the end, after a full DevAgent spend.
- **Who benefits.** The person tagging stories for agents, and the cost line in item 2.
- **Cost.** A section in an existing skill plus a 20-line gate script. No new skill.
- **Risk.**
  - LLM self-scores are poorly calibrated. The integer 1–3 scale, weakest-wins headline and "name the decisive fact" rule are the mitigations.
  - Validate with item 2's data: do stories scored 3 merge more often than those scored 2?

**Verdict: ADAPT.** Reuse the rubric and its calibration text. Skip the planning-session UI and survey tool.

**Sketch.**
- **`dx-dor`.** Add an "Agent fit" block after the checklist verdict. It writes `$SPEC_DIR/agent-fit.json`:
  ```json
  {"clarity":{"score":3,"summary":"…"},"complexity":{"score":2,"summary":"…"},"verifiability":{"score":2,"summary":"…"},"headline":2}
  ```
  The ADO comment shows only the weakest axis and the move that raises it, as SuperPlane does in chat.
- **AEM calibration** goes in plugin `rules/agent-fit.md`, overridable via `.ai/rules/agent-fit.md`:
  - **Verifiability** caps at 2 when acceptance criteria need rendered AEM and neither `aem.author-url-qa` nor visual checks are reachable from pipelines.
  - **Complexity** caps at 2 when one story mixes JCR authoring and code. That is the dx-simple split.
- **Config.**
  - `dor.agent-fit.enabled` (default `false`).
  - `dor.agent-fit.min-for-autonomous` (default `3`).
- **Gate.**
  - `data/lib/agent-fit-gate.sh <spec-dir> <min>` exits 0 or 3 and prints the weakest axis.
  - `dx-agent-dev` and `dx-bug-all` call it at Phase 0 in `DX_PIPELINE_MODE`.
  - On a block, post the weakest-axis comment and exit `warn`.
- **Tests.**
  - `agent-fit-gate.test.sh` with fixture JSONs: min wins, a missing file means fail-open with a notice, and a malformed file fails.
  - One eval case in `dx-core/evals/`: a vague story must get Clarity 1. A clear story with visual-only acceptance criteria must get Verifiability ≤2. Use regex graders on `agent-fit.json`.

---

## 4. Failed-build repair loop for agent-authored PRs: ADAPT

**What SuperPlane does.** "Check handlers wait for GitHub Checks … on one revision, then start one agent run when selected checks fail" (`docs/design/factory.md`).

- The fixer gets `FAILED_CHECKS`. It must "address every failed check … push at most one commit … do not create a new branch" (`pr_feedback_checks_template.go`).
- **Attempt cap:**
  - Default 3, range 1–10 (`pr_feedback_template.go:41-43`).
  - Over the cap, the run emits `limitReached` and pauses.
  - A human "continue" resets the count (`continue_factory_pull_request_fixes.go`).
- "Waiting activities do not consume automatic-fix attempts."
- The per-PR concurrency key serialises one PR without blocking others (`prFeedbackConcurrencyKey`).

**What dx has today.**
- DevAgent, BugFix and SimpleAgent open PRs.
- In pipelines, the agents can only run `build.compile` (#126). Full lint, unit tests and the AEM build run in the **PR build validation** policy. When that build fails, nothing reacts: the PR sits red until a human notices.
- `dx-step-fix` and `dx-pr-answer`'s `apply-fixes.md` (lint+compile gate, headless `dx-pr-commit`) already contain the fixing machinery.
- `auto-webhooks` subscribes only to work-item and PR-comment events.
- No TODO covers this.

**Value test.**
- **Problem.** This is the most likely way an agent PR dies today. The CI that matters runs *after* the agent exits. That is SuperPlane's "sends failures back to the agent with actionable context", and it holds up.
- **Who benefits.** Every team using a writing agent.
- **Cost.** Medium:
  - One pipeline YAML with a `resources.webhooks` listener on the ADO *Build completed* Service Hook (Azure-native, no Lambda).
  - Two deterministic scripts.
  - A pipeline-mode prompt that reuses `apply-fixes.md`.
- **Risk.**
  - A fix loop that "fixes" by deleting tests. Mitigate:
    - Restrict to PRs whose `createdBy` is a bot identity. Never touch human PRs.
    - Reuse dx-simple's `scope-check.sh` caps.
    - Add a rule that skipped, removed or `@Ignore`d tests block the commit.
    - Apply the attempt cap.

**Verdict: ADAPT.** Same loop, with ADO as the state store. There is no DB: attempts are counted from PR threads, the same pattern as the `[DoRAgent]` signature.

**Sketch.**
- **Config** `automation.build-fix`:
  - `enabled` (default `false`).
  - `max-attempts` (default `3`).
  - `trigger-token` (default `@kai-buildfix`, used for the human "continue").
  - `validation-definitions` (a list of build definition names).
- **`build-fix-gate.sh`** (no tokens, like `pr-answer-gate.sh`). It exits 0 unless all of these hold:
  - The build failed and its definition is in the list.
  - The PR is active and was created by a bot identity.
  - The build's source commit equals the PR's current head (item 1; read the PR source SHA from the build's trigger info and confirm the field name).
  - Prior `[BuildFixAgent] attempt N/M` threads number fewer than the max.
  - When the cap is reached, the gate posts one "attempts exhausted, reply `@kai-buildfix continue`" thread and stops.
- **`fetch-build-failure.sh`.**
  - Calls the REST build timeline with `$SYSTEM_ACCESSTOKEN`.
  - Collects the failed task records and keeps the last N lines of each log.
  - Writes `$SPEC_DIR/build-failure.md`, marked as untrusted per `shared/external-content-safety.md`.
- **Agent.** Runs `dx-pr-answer`'s apply-fixes path with `build-failure.md` as the "review comment", then posts `[BuildFixAgent] attempt N/M`.
- **Tests.**
  - Gate fixtures: human author, stale SHA, cap reached, continue-reset.
  - Timeline-to-log extraction from fixture JSON.
- **Pairs with:**
  - #211: this is one more listener to mirror from `ado-cli-dor.yml`.
  - #217: the shared resume primitive.

---

## 5. Path-based PR risk tier with AEM category floors (+ reversibility): ADAPT

**What SuperPlane does.**
- **Merge confidence** (`templates/github/risk-score.canvas.yaml`) scores a PR on blast radius, performance, security, drift and reversibility, each 1–5. It reports each score through a typed MCP tool (`report_merge_check`, with required `check`/`score`/`summary` fields, in `merge_confidence_mcp.js`).
- **Risk uses configurable category floors** (`defaultRiskScoreRules`, `factory_app_templates.go:29`), for example "Documentation only = 1 … Infrastructure changes = 4 … Secrets and credentials = 5".
  - If a change matches a category, the score is at least that category's score. Several matches take the highest.
  - An LLM judges only when nothing matches.
- **Reversibility** has its own 1–5 scale: "5 means a revert undoes the change … 1 means you cannot undo the change without data loss".

**What dx has today.**
- `rules/pr-review.md`, `dx-pr-review` and the `dx-code-reviewer` agent find defects.
- None of them gives a risk tier. grep finds no `risk score`, `blast radius` or `reversib`.
- #237 (split finding from filtering) is the right home.

**Value test.**
- **Problem.** In AEM the dangerous diffs are recognisable by **path**, not by reading code:
  - dispatcher config
  - OSGi configs
  - `META-INF/vault/filter.xml` (especially `mode="replace"` on `/content`)
  - Oak index definitions (they reindex)
  - repoinit (ACLs, service users)
- Most of those are also the hard-to-revert ones. So a **deterministic** path classifier does most of SuperPlane's LLM risk check and most of its reversibility check, and a regex cannot be argued out of its rubric.
- **Skepticism.** ADO branch policies already add path-filtered **required reviewers**, so routing is solved. The tier's value is triage: a one-line "Higher risk: touches dispatcher filters" at the top of the review. It is also a deterministic input for any future "bot PR may auto-complete" rule.
- **Cost.** Low.
- **Risk.** Low. The output is informational.

**Verdict: ADAPT.** Keep the category floors and reversibility. Drop the LLM scoring of performance and security, which the reviewer already covers.

**Sketch.**
- **Rules.** Plugin default `rules/pr-risk.md`, overridable in `.ai/rules/pr-risk.md`. Each line is `glob = score (label)`. Defaults:
  - `**/dispatcher/** = 4 (dispatcher)`
  - `**/*.cfg.json = 4 (osgi-config)`
  - `**/META-INF/vault/filter.xml = 4 (package-filter)`
  - `**/_oak_index/** = 4 (index)`
  - `**/repoinit*` = `5 (acl/service-user)`
  - `ui.frontend/** = 2`
  - `**/*.md = 1`
- **`classify-risk.sh <base> <head>`.**
  - Runs `git diff --name-only`, matches the globs and prints `score`, `labels` and `unmatched-count`.
  - It also flags `mode="replace"` in a changed `filter.xml` as reversibility 2.
- **dx-pr-review.** Prepends one sentence in SuperPlane's format, starting "Higher/Moderate/Lower risk because …". An LLM adds a judgement only when files are unmatched.
- **Tests.** `classify-risk.test.sh` on a seeded repo: a docs-only diff gives 1; a dispatcher + JS diff gives 4; an unmatched file is flagged; a custom rule overrides the default.

---

## 6. Drift from the linked work item in the PR Reviewer: ADAPT

**What SuperPlane does.** This is the merge-confidence "drift" check: compare the diff with the task title and description.

- The scale runs from 1 ("does what the task asks") through 3 ("adds work that raises risk past the task") to 5 ("does something different").
- If the task is empty, the score is 1 (`risk-score.canvas.yaml`, "Drift from Specification").

**What dx has today.**
- The local flow's `dx-code-reviewer` checks "scope creep" against the *plan* (`agents/dx-code-reviewer.md:112`).
- The pipeline **PR Reviewer** (`dx-pr-review`) never reads the PR's linked work item: grep finds no work-item reference in its `SKILL.md`.
- `dx-pr-review-report` §2a already resolves linked work items with `includeWorkItemRefs: true`, so the code to copy exists.

**Value test.**
- **Problem.** For human PRs, which are most PRs the reviewer sees, there is no plan, only the ticket. "This PR also changes an unrelated OSGi config" is the kind of finding reviewers miss and the ticket makes obvious.
- **Cost.** Low: one fetch and one scored finding.
- **Risk.** Vague tickets give noisy drift. Mitigations:
  - Skip when there is no linked work item or the acceptance criteria are empty.
  - Report drift as an info-level finding through the #237 report-all-then-filter path.
  - Never block on it.

**Verdict: ADAPT.**

**Sketch.**
- `dx-pr-review` gets the linked work items (pattern from `dx-pr-review-report` §2a).
- It adds one `scope` finding with a drift score from 1 to 5 and one sentence: "the ticket asked X, the change also does Y".
- Config: `pr-review.drift-check` (default `true`) and `pr-review.drift-post-min` (default `3`).
- Eval: add a case to `dx-core/evals/` where the fixture PR adds an unrelated file. A regex grader checks for a `scope` finding, and a clean PR is the precision distractor.

---

## 7. Structured result file + deterministic outcome check: ADAPT

**What SuperPlane does.**
- **Scheduled intake** writes `/tmp/proposal.json`. A deterministic step validates it: "A missing file, invalid JSON, or incomplete proposal fails the run. The prompt's final text is not used as structured output" (`docs/contributing/scheduled-intake.md`).
- **The implement line** ends with a bash step that commits leftovers. It fails with "No commits to push" when the branch has no commits ahead of base (`line-implementation.canvas.yaml`, "Commit and Push").
- **The agent writes the PR title and body to files.** The automation, not the agent, creates the PR.

**What dx has today.**
- `pipeline-agent.js` finds the verdict with a regex over the final assistant text (`detectVerdict`).
- `ado-cli-simple.yml` already has a deterministic fallback step for "agent died without commenting".
- #218 names the failure: format drift leads to `Steps: 0 total`, and the coordinator then reports success on an unexecuted plan.

**Value test.**
- **Problem.** A self-reported `verdict: pass` with no pushed commits counts as success today. Item 2's metrics would inherit that lie.
- **Cost.** Low.
- **Risk.** Low.

**Verdict: ADAPT** into #218. Not a separate effort.

**Sketch.**
- Writing skills end by writing `$SPEC_DIR/result.json`, with fields `agent`, `wi`, `verdict`, `pr_id`, `branch` and `reason`.
- A pipeline post-step `verify-outcome.sh` fails the run in three cases:
  - The file is missing or invalid.
  - `verdict=pass` but `git rev-list --count origin/<base>..<branch>` is 0.
  - A claimed `pr_id` does not exist.
- `detectVerdict` becomes the fallback only.
- `verify-outcome.test.sh` covers all three cases with seeded repos.

---

## 8. "Evidence, or the attempts you made" for UI changes: ADAPT (small)

**What SuperPlane does.** The visual-evidence protocol (`pkg/components/runner/visual_evidence_protocol.md`) has these parts:

- UI changes need a screenshot, and interactions need a short video.
- Capture the real component, not a static recreation.
- Remove temporary stories and fixtures before commit.
- Before reporting evidence as unavailable, "attempt at least one isolated preview and one Playwright capture", and list each attempt.
- A tool enforces that the agent inspects a screenshot before it uploads it (`task_artifact_mcp_test.js`: "inspect_screenshot before upload_artifact").

**What dx has today.**
- Screenshots exist: dx-simple before/after with the G5/G6 visual diff, `dx-bug-verify` before/after, `aem-fe-verify`, and `aem-verify` test pages.
- `dx-pr` / `dx-bug-fix` PR descriptions list screenshot *counts* (`dx-bug-fix/SKILL.md:319-323`). They do not link the images, and nothing explains a missing image.
- `aem-verify` creates test pages on AEM. The "clean up evidence scaffolding" idea applies there.

**Value test.**
- **Who benefits.** Reviewers, who rarely run AEM locally, get a link or an honest reason instead of silence.
- **Skepticism.** The tool-enforced inspection needs an MCP server we don't ship. The PR-attachment upload depends on ADO MCP support we have not verified. So adopt only the **rule**.
- **Cost.** Low.

**Verdict: ADAPT (small).**
- Add a shared rule, `shared/ui-evidence.md`, read by `dx-pr` and `dx-bug-fix`. A UI-affecting PR description must either link the spec-dir screenshots or list each capture attempt and its outcome.
- `aem-verify` records any test page it created in `$SPEC_DIR`, so cleanup is explicit.
- This needs a new small TODO if pursued.

---

## 9. "Do not invent a token/time budget" prompt line: SKIP (watch)

**What SuperPlane does.** It appends to every factory agent prompt: "Do not invent a token budget, a time budget, a step limit, or a remaining context size … Do not stop early" (`pkg/components/runner/factory_imagined_limit.go`).

**Why skip.**
- We have no observed dx run that stopped early for an imagined limit.
- dx deliberately *does* give coordinators context-budget rules (#241 inline-chain budget lint). A blanket "no limits exist" line would contradict them.
- Unverified instructions are exactly what #113 / #162 remove.
- **Revisit** if pipeline logs show "given limited context, I'll stop". Then add the line only to the pipeline system-prompt wrapper, with an eval.

## 10. Approval steps / pause-and-resume as a product feature: SKIP

- SuperPlane has a generic canvas `approval` component (`pkg/components/approval/`). Its own design doc lists "Full PRD approval flow (gated approvals on `open → closed`)" under **Not implemented yet** (`docs/design/factory.md`).
- For dx, ADO already provides the human gates: PR required reviewers, path-filtered auto-reviewers, and environment approvals.
- The comment-token re-trigger (`dx-simple.recovery.*`, `dx-bug-all.recovery.*`) already provides "pause, human answers, resume" with no server.
- #15 stays as scoped.

## 11. Work-order timeline, board, line-metrics UI: SKIP

- This is the core of SuperPlane's product. It needs Postgres tables, websockets and a React board (`docs/design/factory.md`, "UI").
- An ADO work item already has history, discussion, linked PRs and board columns.
- The only part worth having is the *metric definitions*, and item 2 takes them without the UI.

## 12. Multi-source intake (Sentry, Dependabot, scheduled proposer): SKIP

- SuperPlane creates work orders from Sentry, Dependabot, Jira, Linear and a cron agent that proposes one task per run (`sentry_intake.go`, `linear_intake.go`, `docs/contributing/scheduled-intake.md`).
- Its own doc concedes the scheduled template has no "cross-run deduplication".
- dx is ADO-only by design (`scm.provider: ado`). ADO Advanced Security and Dependabot-for-ADO already file their findings.
- A cron agent that invents backlog items is noise generation unless it has dedup, and dedup needs state we don't have.

## 13. Their prompt testing approach: SKIP (dx is ahead)

- SuperPlane tests prompt **assembly** deterministically. For example, it asserts that a custom risk rule survives a template reset (`reset_built_in_automation_settings_test.go`), and that a template prompt no longer contains `install_params.riskRules` (`factory_app_templates_test.go:181`).
- We found **no behavioural evals** of agent output.
- dx already has `claude plugin eval` suites with deterministic graders, plus the sync-clobber guard (#151) for "customization survives upgrade".
- Nothing to import.

## 14. Per-PR exclusive-access lock: SKIP (covered)

- SuperPlane lets one "exclusive" activity change a PR while "concurrent" ones only wait on checks (`docs/design/factory.md`, "Activity access").
- In dx, item 1's explicit lease covers the correctness half on PRs.
- #216 (a `workItemId`-keyed `lockBehavior` plus a run marker) covers the concurrency half on work items.
- A separate lock primitive would add a third mechanism for one problem.

---

## Cross-cutting observations

- **The headline claims hold, but only narrowly.**
  - "Continuously evaluates which backlog issues agents can handle with high confidence" is item 3's rubric plus a 65% threshold.
  - "Sends failures back to the agent with actionable context" is item 4's check handler plus PR-comment mentions.
  - "Resume without custom glue" is a Postgres-backed run plus re-emitting the stored trigger event.
  - All three are real. All three translate to ADO comments, threads and build tags without a server.
- **Where SuperPlane is weaker than dx:**
  - No per-run budget enforcement.
  - No behavioural evals.
  - The approval flow is unbuilt.
  - The scheduled intake has no dedup.
  - Do not import those parts.
- **The pattern worth copying everywhere is SuperPlane's prompt discipline:**
  - integer scales with anchors
  - a "name the one decisive fact" summary
  - a weakest-wins headline
  - "do not soften a low score"
  - structured output through a validated file or tool, never prose
  - It fits with #237 and #218.

## Prioritised shortlist

1. **Stale-head guard + explicit `--force-with-lease=<branch>:<sha>`** (ADOPT, very low effort). It fixes a real overwrite hole in the autonomous PR Answerer today.
2. **Cost cap enforcement + `dx-verdict`/`dx-cost` build tags + `/auto-status` on ADO data** (ADAPT, low). It closes #50/#144 without AWS, fixes #251, and makes every later threshold tunable with merged-PR outcome data.
3. **Agent-fit score in `dx-dor` + Phase-0 gate for DevAgent/BugFix** (ADAPT, low–medium). It stops paying for runs that cannot prove their acceptance criteria in a pipeline without AEM. Its threshold is validated by item 2's data.
4. **Failed-build repair loop for bot-authored PRs** (ADAPT, medium). It has the highest ceiling: it rescues agent PRs that die in PR validation. It is limited to bot PRs, capped attempts and ADO threads as state.
5. **Path-based AEM risk tier + linked-work-item drift in the PR Reviewer** (ADAPT, low). Both are deterministic-first and fold into #237.
6. **`result.json` + `verify-outcome.sh`** (ADAPT, low). Fold into #218. Items 2 and 3 depend on it for honest outcomes.

Skip: approvals-as-feature, the work-order UI/timeline, multi-source intake, the imagined-limit prompt line (watch only), their test approach, and a separate PR lock.
