# Orchestration Context Pollution — Research

**Date:** 2026-05-05
**Trigger:** User report from a real `/dx-agent-all 2490722` run on a consumer repo. Session burned 27% of a 1M-context window (≈265k tokens) on a single ticket — fine for Opus 4.7 1M, but would have crashed an Opus/Sonnet 200k session at the same workload, and weekly-quota usage hit 17% with reset 3d 19h away.
**Branch:** `fix/scaffold-cross-repo-orphan` (research-only — no code changes here)

## Executive summary

`dx-agent-all` already declares the right policy ("every phase MUST run via Skill tool calls", "never read spec files in the main orchestrator", "trust skill return summaries"). The reality observed in the user's log violates that policy in three concrete ways:

1. **Half the orchestrated skills are NOT forked.** Of 13 skills `dx-agent-all` invokes, only 8 use `context: fork` today. The unforked ones — most painfully `dx-step-all` (Phase 3 = Execution) and `dx-req` (Phase 1 = Requirements) — run in the orchestrator's own context, dragging every file edit, every Bash output, every diff into the main window.
2. **The orchestrator itself does context-heavy work it doesn't need to do.** The log shows it reading `.claude/rules/be-*.md` files in main context, running repeated `git status`, dumping full mvn output, printing a "Plan validation report" as a wide ASCII table, and re-emitting a "Final Summary" multi-row table at every checkpoint and again on user-asked recap.
3. **There is no compact return contract.** Skills today produce free-form output (often verbose), and the orchestrator includes all of it in its visible output, which the user then sees and asks follow-ups against — quoting the table back into context. There is no machine-readable `return.json`/`summary.md` contract that the orchestrator could load *only when needed* and otherwise ignore.

The good news: the `context: fork` mechanism is already supported (eight skills use it), the policy is already written, and `DX_LOW_CONTEXT=1` already reroutes some choices. This is mostly an enforcement-and-coverage problem, not a missing-primitive problem.

## What context-bloat looked like in the user's run

Reconstructed by counting the artifacts visible in the partial transcript:

| Source | Approx. tokens | Notes |
|---|---|---|
| Plan-validation table (5×3 grid + req→step mapping 9 rows) printed inline twice | ~3k | Printed once by `/dx-plan-validate`, repeated when user asked recap |
| Final Summary phase tables (15 rows × 3 cols) printed 3×: end of run, after VPN retry, on user recap | ~5k | Each emit re-quotes the prior text |
| `git status -s` / `git log --oneline -3` / `git diff` outputs dumped fully | ~2k | Most calls only needed the count, not the file list |
| Background mvn outputs (build1 ~80 lines, build2 ~5 lines, build3 ~5 lines) | ~3k | Full Maven log → only "EXIT:0" mattered |
| `npm run build:js` output (webpack manifest) twice | ~1k | Only "exit 0" mattered |
| `cat .claude/rules/be-components.md`, `be-dialog.md`, `be-aem-component-structure.md`, `be-htl.md` reads in main context | ~3k | These are convention rules — `dx-step` should fork its rule loading |
| Inline file edit diffs from `Update(...)` (3 source files, ~150 lines of patch text) | ~2k | Could live in the spec, not main context |
| Repeated "Updated plan / /plan to preview" stub lines (≥10×) | ~0.5k | Stub harness output with no payload |
| Stop-hook anti-rationalization message | ~0.3k | One-shot — fine, but reads as user-visible |
| Recap blocks ("※ recap: …") | ~1k | Useful, but they pin the prior text into context |
| Free-form post-phase summaries, "Pipeline Complete" tables (×2) | ~6k | Would be 1 line each if compact-return were enforced |
| **Total estimated bloat above what was actually load-bearing** | **~26k** | Out of ~265k session — ≈10% pure waste |

The 10% number is conservative. Most of the bloat comes from the *redundancy* of restating the same status: if the orchestrator wrote results once to disk (already done — `dev-all-progress.md`) and never quoted them back, the savings are larger because the model also stops having to re-read the table when answering follow-ups.

## What `dx-agent-all` already does right (and where it falls down)

`SKILL.md:50-58` already documents the rule:

> **Critical:** Every phase MUST run via Skill tool calls to keep the orchestrator context lean.
> - Never read spec files in the main orchestrator — trust skill return summaries
> - Keep dev-all's own context to orchestration only: phase status, short summaries, user interaction

It also documents `DX_LOW_CONTEXT=1` and per-phase token-trace instrumentation (`DX_TOKEN_TRACE=1` writes `dev-all-tokens.tsv`). Neither is on by default.

### Skills that do/don't isolate context today

| Phase | Skill | `context: fork` today | Should fork? |
|---|---|---|---|
| 1 | `/dx-req` | ❌ no | ✅ yes — runs 4 parallel research subagents in main context |
| 1.5-enrich | `/dx-ticket-analyze` | ❌ no | ✅ yes — already uses subagents internally; main only needs the summary |
| 1.5 | `/dx-figma-all` | ❌ no | ⚠ partial — image extracts shouldn't enter main; verify forks internally |
| 2 | `/dx-plan` | ❌ no | ✅ yes — extended-thinking skill produces the full plan, only needs to return file path |
| 2 | `/dx-plan-validate` | ❌ no | ✅ yes — currently prints a 9×3 + 5×3 ASCII table to main; should write a verdict file and return PASS/WARN/FAIL only |
| 2 | `/dx-plan-resolve` | ❌ no | ✅ yes — same shape as validate |
| 3 | `/dx-step-all` | ❌ no | ✅ **yes — biggest single offender.** Coordinates 3-10 step executions, each reading rules + producing diffs + running build/test/review |
| 4 | `/dx-step-build` | ✅ yes |  |
| 4.5 | `/dx-step-verify` | ✅ yes |  |
| 4.5-heal | `/dx-step-fix` | ❌ no | ✅ yes (currently only invoked by step-all internally) |
| 5 | `/aem-snapshot` | ✅ yes |  |
| 5+ | `/aem-verify` | ✅ yes |  |
| 5++ | `/aem-fe-verify` | ✅ yes |  |
| 5a | `/dx-pr-commit` | ❌ no | ✅ yes — runs git/ado mcp calls; only needs to return commit SHA + branch |
| 6.5 | `/aem-editorial-guide` | ✅ yes |  |
| 7 | `/dx-doc-gen` / `/aem-doc-gen` | ✅ yes (`aem-doc-gen`); ❌ no (`dx-doc-gen`) | ✅ yes for both |

Eight forked, eight not. The unforked set is *exactly* the long-running phases — Requirements, Planning, Execution, Commit, Docs — which is where pollution comes from.

### Policy violations visible in the user's log

Three things the orchestrator did that its own SKILL.md says not to:

1. **It read rule files (`be-components.md`, `be-htl.md`, etc.) in main context.** Those reads belonged inside `/dx-step` (which is forked from `dx-step-all`'s perspective if step-all itself were forked, but it isn't, so the chain leaks).
2. **It re-emitted full `git status` / `git diff` / `git log` output**. Only the file count and the SHA were load-bearing.
3. **It printed the same Pipeline-Complete table three times.** Each emission pins the prior emission into the context window because the model uses the recap to answer the user's follow-ups.

## Mechanisms available (what we have to work with)

### 1. `context: fork` (skill frontmatter)

Documented at `code.claude.com/docs/en/skills`. Causes a skill to execute in an isolated subagent context window. Only the skill's *return value* enters the parent's context. Confirmed working: 8 skills in this repo use it.

**Limit:** the return value is whatever the forked skill emits as final text. There is no schema. So the orchestrator still receives whatever prose the forked skill happens to produce. We rely on each forked skill being well-behaved.

### 2. The Agent tool (subagent dispatch)

`Agent({subagent_type, prompt})` runs a subagent in its own context. The Agent tool's documentation is explicit: "the result returned by the agent is not visible to the user. To show the user the result, you should send a text message back to the user with a concise summary." This is the right primitive for "do verbose work, return one line."

### 3. Skill return contract (currently informal)

There is no enforced format for what a skill returns. Forked skills today often return paragraphs of prose. We could standardize a compact-return contract: `## Verdict: PASS|WARN|FAIL`, then a 1-sentence rationale, then a path to a written report. The orchestrator reads only the verdict line.

### 4. Spec directory (already canonical)

Per-ticket output already lands in `.ai/specs/<id>-<slug>/`. The orchestrator could *trust files over text*: read `dev-all-progress.md` only when the user asks for a recap, not on every phase boundary.

### 5. `DX_LOW_CONTEXT=1` (already partial)

Already cuts research subagents from 4 → 2 (issue #136), already logs token deltas. Coverage is incomplete — it doesn't yet (a) suppress the validation tables, (b) silence rule-file reads in main, (c) force `context: fork` on skills that lack it.

### 6. Prompt cache (model side)

5-minute TTL, refreshes on hit. Long single sessions stay cached as long as new turns arrive within 5 minutes — but only for the *static prefix*. As the orchestrator's running text grows, the cache moves with it; new content costs full input price. So context bloat hurts twice: bigger prompt now AND no cache help on the bloated middle.

## Recommendations

Ordered by ROI (impact ÷ effort). All of these are deferred — the user asked for research, not implementation.

### R1. Fork the five remaining inner-loop skills (high ROI, low risk)

Add `context: fork` to:
- `/dx-step-all` — biggest single win. All step iterations + build/review/commit chatter leave main context.
- `/dx-req` — 4 parallel research agents currently dispatch from main; fork pulls the dispatch into the subagent.
- `/dx-plan` — extended-thinking output is a large file write; main only needs "wrote implement.md".
- `/dx-plan-validate` — currently the worst tabular emitter (5×3 + 9×3 grid). Forking + compact-return drops ~3k per call.
- `/dx-pr-commit` — git/ado MCP traffic shouldn't touch main.

**Risk:** forked skills lose access to the orchestrator's TaskList/TaskUpdate calls — they have to manage state via files. `dx-step-all` already writes `run-state.json` and `dev-all-progress.md`, so this works. Other skills may need a small migration.

**Verification:** `DX_TOKEN_TRACE=1` before/after on the same fixture ticket. Expect Phase 3 (`dx-step-all`) to drop 30-50k tokens for a 4-step plan.

### R2. Compact-return contract for forked skills (high ROI, low risk)

Standardize a single section every forked orchestrated skill must emit *last*:

```markdown
## Return
verdict: pass|warn|fail
summary: <one sentence — under 200 chars>
artifacts:
  - .ai/specs/<id>/<file>.md
next_action: <one phrase or "none">
```

The orchestrator reads only this block. Anything above it is for the forked-context developer who's debugging. This is enforceable in CI with a grep.

### R3. Stop reading files in the orchestrator (medium ROI, low risk)

Audit `dx-agent-all` for `Read` / file-cat patterns. The user's log shows it reading rule files and git outputs that belonged to the inner skills. Add a hook (`PreToolUse` matcher `Read` with `if: "Read(.claude/rules/**)"` or `if: "Read(**/*.{xml,html,js,java})"` while inside `dx-agent-all`) that warns or blocks. Cheap CI lint: `grep -E "^\s*Read\(" plugins/dx-core/skills/dx-agent-all/SKILL.md` should be empty for source-file paths.

### R4. Status-table-once policy (medium ROI, trivial)

Rule: emit the Pipeline Phase table exactly once — at Final Summary. Update `dev-all-progress.md` after each phase (already happens), but reference it: "phase 4 done — see dev-all-progress.md". When the user asks for recap, *read the file* and emit a fresh single table. Don't quote the prior emission.

This alone would have saved ~5k in the user's log (3 emissions of a 15-row table).

### R5. Quiet-mode for status checks (low ROI, trivial)

The orchestrator does many `git status -s` / `git log -1` / `git rev-parse` calls. Pipe through `wc -l` / `cut -c1-7` so only the load-bearing bytes return. Equivalent for `mvn` (background, then read only `tail -1`). Bash tool already supports `run_in_background` + `Read` of small slices.

### R6. Promote `DX_LOW_CONTEXT` to default for ≤200k models (medium ROI, low risk)

Detect model from session and auto-set `DX_LOW_CONTEXT=1` when `model in {sonnet-*, haiku-*, opus-4-6}` (anything not 1M). The 1M Opus user case (the user's run) doesn't need it, but every other model does. Today it's manual.

### R7. "Resume from spec" continuation skill (high user value, medium effort)

The user's transcript ends with them hand-crafting a continuation prompt to start a new session for the missed Code Review phase. Automate that: `/dx-agent-resume <ticket>` reads `dev-all-progress.md` + `run-state.json`, prints a self-contained brief, and starts at the first non-`done` phase. This is what they wanted; it's also a context-isolation feature because it lets the user *start a fresh session* on demand instead of pushing through a polluted one.

### R8. Token-trace on by default for `dx-agent-all` (low ROI, trivial)

Flip `DX_TOKEN_TRACE=1` to default-on. Per-phase TSV is invisible to the user but lets us close the empirical loop on R1-R6 with real numbers, not estimates.

## Things explicitly *not* worth doing

- **Reduce overall verbosity in the orchestrator's prose.** The user-visible status updates (`Phase 4: Build — passed`) are valuable and small. The bloat is in *quoted* outputs, not Claude's narration.
- **Move to multi-session orchestration (Agent Teams / session-driver / tmux dispatch).** That's already researched in `multi-session-orchestration.md` and solves a different problem (cross-repo, not single-session bloat). Forking solves single-session bloat at lower cost.
- **Aggressive `/compact`.** Compaction is destructive — the model loses information. Forking is non-destructive — the information was never in the parent context to begin with.
- **Larger context model (e.g., default to Opus 1M).** The user's run was already on 1M and still felt heavy at 27%. Bigger context masks the problem; it doesn't fix the redundancy.

## Confidence and caveats

- Forking-fixes-pollution is **confirmed** by the existing 8 forked skills — they don't appear in the user's main-context bloat. Direct extrapolation to the 5 unforked skills is sound.
- The token estimates above are reconstructed from the visible transcript, not measured from a real `DX_TOKEN_TRACE` log. Confidence: medium. Recommend running R8 before committing to R1-R7 priorities.
- `context: fork` for `/dx-plan` may interact with the "ultrathink" extended-thinking budget — needs to be tested. The skill currently prints reasoning to main; forking hides it (which is the goal) but also means the user can't watch it think.
- `dx-step-all`'s TaskList behavior (real-time per-step task updates visible in the user's status line) will move into the subagent if forked. The user loses live progress unless the forked skill writes status to a file the parent polls. Mitigation: parent reads `dev-all-progress.md` between steps and emits a one-liner.

## Files referenced

- `plugins/dx-core/skills/dx-agent-all/SKILL.md` (lines 50-82, 105-122, 128-152, 155-228) — the orchestrator and its existing context policy
- `plugins/dx-core/skills/dx-step-all/SKILL.md` — coordinator, currently unforked
- `plugins/dx-core/skills/dx-{req,plan,plan-validate,plan-resolve,pr-commit,doc-gen}/SKILL.md` — the unforked phases
- `plugins/dx-core/skills/dx-{step-build,step-verify}/SKILL.md` — working examples of `context: fork`
- `plugins/dx-aem/skills/aem-{snapshot,verify,fe-verify,editorial-guide,doc-gen,qa-handoff}/SKILL.md` — also working examples
- `docs/research/multi-session-orchestration.md` — different problem (cross-session)
- `docs/research/token-cache-deep-research.md` — cache mechanics that compound the bloat penalty
