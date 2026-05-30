# TODO: `/dx-simple` Resumable Error Recovery

> Design doc for TODO #141. Status: **design — not yet implemented.**
> Settled with the requester on 2026-05-30 (see "Decisions locked" below).
> **Revised 2026-05-30** after a design review (accepted in full). The review
> corrected the trigger model (Azure-native filtered Service Hook, not the
> Lambda) and closed several resume-state holes — see "Review revisions
> (accepted 2026-05-30)" below. Where this doc's older prose and the revisions
> section disagree, **the revisions section governs**; inline text has been
> updated to match.

## `/dx-simple` resumable error recovery (branch-as-state + classified blocker loop)

**Added:** 2026-05-30
**Problem:** `/dx-simple` runs autonomously in an ADO pipeline (`plugins/dx-automation/data/pipelines/cli/ado-cli-simple.yml`), triggered by a webhook. Every run is a **fresh container** with a clean `checkout: self` — nothing from a prior run survives. Three consequences make blockers unrecoverable today:

1. **No durable state.** The per-ticket spec dir (`.ai/specs/<id>-<slug>/`) is written during the run but only committed at Phase 6, and only on the *code* path (via `/dx-pr-commit`). The authoring-only path commits nothing. On the ABORT path, `git checkout -- .` actively **wipes** the uncommitted report + state files. A second run starts from zero — it cannot know what the first run already discovered or where it got stuck.
2. **The fail report is shallow and terminal.** Phase 7 (success) or the ABORT path posts one ADO comment; the pipeline `failed()` step posts a generic "didn't finish" note otherwise. None of them say *what kind* of failure it was, whether a re-run could fix it, or what input the human must supply. There is no way for a human to answer a blocker and have the work continue.
3. **No resume path.** Even if a human knew the answer, there's no mechanism to feed it back in and continue from the failed step rather than re-running the whole pipeline from scratch (re-paying for Phase 2 discovery, re-locating the component, etc.).

The fix: make the **per-ticket git branch the durable state store**, commit to it constantly, classify every blocker, and let a human resolve blockers by replying on the ticket — the next run wakes up, reads where it stopped + the new input, and continues.

**Scope:**
- Skill body: `plugins/dx-core/skills/dx-simple/SKILL.md` (add Phase 0; resume-state lifecycle; checkpoint calls; comment-read in Phase 1; rewritten ABORT path; resume jump table; updated flow digraph + state-files table).
- New scripts: `plugins/dx-core/skills/dx-simple/scripts/save-state.sh` (per-write authoring checkpoint + rebase-before-push — H1/H2), `.../scripts/resume-check.sh` (Phase 0 anchored discovery + reverse branch→spec-dir mapping; **delegates only the create-fresh path** to `plugins/dx-core/shared/ensure-feature-branch.sh` and does NOT modify it — M2).
- New template: `plugins/dx-core/skills/dx-simple/templates/resume-state.json.tmpl`.
- New: behavioral fixture harness under `.../scripts/__tests__/` (M6 — see Done-when).
- Modified template: `plugins/dx-core/skills/dx-simple/templates/report.md.tmpl` (add a **Recovery** section; uses `@<keyword>` placeholder, never the literal token — H4).
- Config (M7): new `.ai/config.yaml` fields under `dx-simple.recovery.` — `trigger-token` (default `@kai-simple`) and `max-attempts` (default `3`). The skill reads these instead of hardcoding; the **documented ADO Service Hook filter string must match `trigger-token`** (single source of truth — note this wherever the hook is documented).
- Pipeline: `plugins/dx-automation/data/pipelines/cli/ado-cli-simple.yml` — reword the `failed()` fallback comment to **instruct the human to reply with the `@kai-simple` keyword to resume** (recovery is human-re-triggered, **not** automatic — H3).
- Phase 6 idempotency (M5): detect an existing open PR for the branch and switch `/dx-pr-commit` to update-mode rather than creating a second PR; checkpoint `last-completed = Phase 6` before the create.
- Docs: `CLAUDE.md` SimpleAgent blurb, `docs/reference/skill-catalog.md`, a website page. **Plus a consumer prerequisite note:** to use SimpleAgent recovery, `.ai/specs/` must be tracked (remove it from `.gitignore` — it's ignored by default in the `/dx-init` template). Document this wherever SimpleAgent setup is described (website + `auto-init` / `dx-init` notes).
- **Untouched on purpose:** the Lambda router (`wi-router.mjs`). It is **not in the SimpleAgent trigger path at all** (C1) — both the initial tag trigger and the `@kai-simple` comment trigger are Azure-native Service Hooks (the comment hook carries a "comment contains `@kai-simple`" subscription filter). `dx-pr-commit` is reused (extended to update-mode per M5, not rewritten). `ensure-feature-branch.sh` is reused unchanged for the create-fresh path.

**Done-when** (verifiable once implemented):

*File / structure (necessary, not sufficient):*
- `test -x plugins/dx-core/skills/dx-simple/scripts/save-state.sh` and `test -x plugins/dx-core/skills/dx-simple/scripts/resume-check.sh`.
- `test -f plugins/dx-core/skills/dx-simple/templates/resume-state.json.tmpl`.
- `grep -q "Phase 0" SKILL.md` AND `grep -q "resume-state.json" SKILL.md` AND `grep -q "@kai-simple" SKILL.md`.
- `grep -qi "Recovery" .../templates/report.md.tmpl`.
- The ABORT section commits state **before** `git checkout -- .` (grep order), and classifies the blocker (`needs-user-input` / `transient` / `hard`).

*Loop-safety (H4) — must pass:*
- The **rendered blocker comment** (template substituted with sample values) does **NOT** contain the literal `@kai-simple` — only the `@<keyword>` placeholder: `! grep -q '@kai-simple' <rendered-comment>`. Run the same grep over `report.md.tmpl`.

*Behavioral fixture (M6) — the real verification.* A committed shell harness under `plugins/dx-core/skills/dx-simple/scripts/__tests__/` (or an eval fixture) that, **without live ADO/AEM**, seeds a throwaway git repo + a `resume-state.json` and asserts `resume-check.sh` dispatches correctly:
- `status: in-progress`, `last-completed-phase: Phase 1` → dispatch = resume forward at Phase 2, no code-edit replay.
- `status: in-progress`, `last-completed-phase: Phase 5` → dispatch includes the **replay-code-edits** step before re-entry (C2).
- `status: blocked-needs-input`, `blocked-at-phase: G4` → dispatch = re-enter Phase 3b, **authoring NOT rolled back** (C3).
- `status: done` → dispatch = no-op.
- Two `feature/<id>-*` refs present → `ambiguous-branch` exit (M1); a `123` id does **not** match a seeded `feature/1234-x` branch (anchored match, M1).
- `answer-attempts: 3` + still-failing gate → downgrade to `blocked-hard` (M4); a simulated crash resume does **not** increment `answer-attempts`.

*Concurrency / persistence:*
- `save-state.sh` rebases before push and exits non-zero with the "branch advanced" message when the remote ref is ahead and un-rebasable (H2) — assert in the fixture by advancing the seeded remote.
- After a simulated block, `resume-state.json` is present in `git show <branch>:<spec-dir>/resume-state.json` (committed **and** pushed), not just on disk.

---

## Decisions locked (with the requester)

| # | Decision | Choice |
|---|----------|--------|
| 1 | Recovery input channel | **ADO comment containing `@kai-simple`.** The trigger is an **Azure-native Service Hook** on the *"work item commented on"* event, **with a subscription filter requiring the comment body to contain `@kai-simple`** → service connection → pipeline re-runs. This path **does not go through the Lambda** (`wi-router.mjs`) at all — the SimpleAgent trigger (both initial tag-based and comment-based) is configured in ADO, not in the Lambda router. The pipeline receives `workItemId` from the hook resource mapping; the agent **reads the comment itself** from the work item. No router change. |
| 2 | Self-trigger / loop prevention | Trigger token is **`@kai-simple` (with the `@`).** Two composing layers: (a) the **hook filter** only fires on comments containing `@kai-simple`, and the bot writes the keyword **without** the `@` (placeholder `@<keyword>` in examples) so its own comments don't match the filter; (b) an agent-side `comment-cursor` + **author-identity** dedupe (skip comments authored by the bot identity). The **one residual loop hazard** is the re-ask flow *quoting the human's prior answer verbatim* — that can re-introduce the literal token. The re-ask MUST placeholder-ize the token when quoting (see "Reading the answer + the re-ask loop"), and a Done-when asserts no literal `@kai-simple` appears in any bot-emitted text. |
| 3 | State persistence granularity | **Spec md/json only** (text). Code edits are NOT committed mid-run; a resume re-applies them deterministically from `work-plan.json`. |
| 4 | PR history | **`chore(dx-simple): checkpoint …` commits on the branch are accepted** — no squashing, no side ref. |
| 5 | Branch timing | **Branch created early at Phase 0**, not Phase 6. |

---

## Review revisions (accepted 2026-05-30)

These amend the approach below and are authoritative. Each row is a hole the
review found in the first-pass design; the inline sections have been updated to
match.

| # | Finding | Resolution (now reflected inline) |
|---|---------|-----------------------------------|
| C1 | Trigger model was described as Lambda-mediated ("the existing webhook → the Lambda passes workItemId"). It isn't — the comment trigger is an **Azure-native filtered Service Hook**, bypassing `wi-router.mjs` (which has no `simple` agent and matches `workitem.updated` by tag, never comment text). | Decision #1 rewritten. Lambda confirmed out of scope **because it was never in this path**, not because we chose not to touch it. |
| C2 | **Resume-forward onto an empty tree.** Code edits are never committed (decision #3), so a crash *after* Phase 3b can't "resume forward reusing committed artifacts" — the edits aren't on the branch. | Resume of any phase **after 3b** must first **replay code edits from `work-plan.json`** onto the clean committed base, *then* re-enter the target phase. New "replay code edits" preamble + digraph node. Authoring (external/persisted) is skipped on resume; code (ephemeral/local) is always replayed. |
| C3 | **Combined-change authoring loss.** ABORT rolled back authoring *unconditionally*, but a `needs-input` block at G4 re-enters Phase 3b (past 3a) → the rolled-back JCR write is never re-applied → PR ships only the code half. | Roll back authoring **only on terminal abort** (`hard` / final fail). On a **recoverable** block (`needs-input` / `transient`) leave JCR writes in place (recorded in committed `authoring-diff.json`); resume skips Phase 3a. |
| H1 | **AEM writes not transactional with the checkpoint.** A crash mid-Phase-3a (write 2 of 3) leaves writes live on AEM but `authoring-diff.json` uncommitted → resume re-enters 3a → before-value check sees the already-applied value → spurious `value drifted` abort. | `save-state.sh` checkpoints `authoring-diff.json` **per JCR write**, not per phase. Phase 3a before-check treats `actual == target-after` as **already-applied → skip** (idempotent). |
| H2 | **No dedup on the comment path** (Lambda bypassed). Double `@kai-simple` reply or hook redelivery → concurrent runs racing the checkpoint push. Low probability (deliberate human action) but real. | `save-state.sh` does **`git pull --rebase` before each push** and bails with a clear "branch advanced under another run" message on a non-fast-forward it can't rebase. No heavyweight lock. |
| H3 | **Silent crash has no auto-resume trigger.** A MAX_TURNS kill leaves `status: in-progress` but posts no `@kai-simple` comment, so nothing re-fires the filtered hook. Resume is **not automatic** — it needs a human to type the token. | The pipeline `failed()` fallback comment must **explicitly instruct the human to reply with the `@kai-simple` keyword to resume**. Recovery is documented as *human-re-triggered*, never "automatic." |
| H4 | Loop-safety residual = the re-ask **quoting the human's answer** can re-emit the literal token. | Re-ask placeholder-izes the token in quotes; Done-when greps that no literal `@kai-simple` appears in the comment text or `report.md.tmpl`. |
| M1 | **Unsafe branch matching.** `'*<id>*'` substring matches unrelated tickets (`123` ↔ `1234`); "reuse any" is undefined for >1 match. | Anchored discovery only: `refs/heads/feature/<id>-*` and `refs/heads/bugfix/<id>-*`. **>1 match → `ambiguous-branch` blocker**, not "pick any." |
| M2 | Phase 0 is a *different operation* from `ensure-feature-branch.sh` (remote-glob discovery + reverse branch→spec-dir mapping vs current-branch match + spec-dir→branch derivation); extending the shared helper risks other consumers. | **New `resume-check.sh`** owns discovery/ambiguity/checkout/reverse-mapping; delegates **only the create-fresh path** to `ensure-feature-branch.sh` (contract unchanged). |
| M3 | "flaky compile" mis-listed as `transient` — Phase 4 already retries compile 3× against a deterministic edit; a cross-run retry won't compile any better. | Compile failure after the in-run 3× retry is **`hard`**. `transient` reserved for infra (MCP/network) + MAX_TURNS. |
| M4 | One `attempt` field conflated human-answer count with run count → crashes burn the needs-input cap and over-escalate to DevAgent. | Split: **`answer-attempts`** (capped at 3) vs `run-history[]` length (observability). Crashes/transients never increment `answer-attempts`. |
| M5 | **PR creation not idempotent.** Crash between PR-create and the post-Phase-6 checkpoint → resume re-runs Phase 6 → duplicate-PR attempt. | Checkpoint `last-completed = Phase 6` **before** the irreversible create, **and** Phase 6 detects an existing open PR for the branch → update-mode instead of create. |
| M6 | Done-when items were file-existence / grep-order, not behavioral; the one behavioral check ("walkthrough **or** fixture") wasn't concrete; loop-safety + push invariants uncovered. | Done-when rewritten around a **committed fixture harness** (seed each `status`, assert Phase 0 dispatch + jump target) plus concrete loop-safety and commit-and-push asserts. |
| M7 | Hardcoded `@kai-simple` token, keyword, and `attempt cap = 3` violate config-driven rule and risk drift between the hook filter and the skill. | Trigger token + `max-attempts` move to `.ai/config.yaml` (`dx-simple.recovery.*`); skill and the documented hook-filter string read from one source of truth. |
| L1 | Flow given only as a "sketch." | Implementation must ship the **full DOT digraph** (Phase 0 entry + 3 out-edges, replay-code-edits preamble, `answer-attempts < 3?` diamond, re-ask edge, ABORT classify/persist/comment nodes) with a matching `### Section` per node, per CLAUDE.md. |
| L2 | comment-cursor selection ordering + atomicity unstated. | Select **newest by ADO comment id** (ids are monotonic), authored by a non-bot identity, id > cursor. Commit the updated cursor **before / atomically with** re-entering the phase, else a crash reprocesses the same answer. |
| L3 | No-squash checkpoints (decision #4) pollute `main` if merged un-squashed. | Consequence noted; decision #4 is locked. Recommend squash-on-merge for the PR even while the branch retains checkpoints. |

---

## Approach (the settled design)

### Phase 0 — Resume (new; runs first; creates/reuses the branch)

Runs immediately after pre-flight, before Phase 1.

1. **Find the ticket branch (slug-agnostic).** A fresh container can't recompute run 1's title-derived slug, so resume keys on the **ticket id only** — but matched with an **anchored prefix**, never a bare substring (a bare `*<id>*` matches unrelated tickets: `123` ↔ `1234`):
   ```bash
   git fetch origin --quiet
   # Anchored: only feature/<id>-… or bugfix/<id>-… (note the trailing hyphen).
   git ls-remote --heads origin "refs/heads/feature/${ID}-*" "refs/heads/bugfix/${ID}-*"
   ```
   - **Exactly one** match → check it out (the committed spec dir + `resume-state.json` come with it).
   - **No** match → create `feature/<ID>-simple` from the fresh base branch.
   - **More than one** match → `ambiguous-branch` blocker (do NOT "pick any"); post a `needs-user-input` comment asking which branch to resume, exit.
   This logic lives in a **new `resume-check.sh`** (see below), *not* in `shared/ensure-feature-branch.sh`: discovery here is remote-glob-by-id + a reverse branch→spec-dir mapping (the fresh container doesn't know the slug), which is the inverse of what `ensure-feature-branch.sh` does (current-branch match + spec-dir→branch derivation). `resume-check.sh` delegates **only the create-fresh path** to `ensure-feature-branch.sh` so the shared helper's contract stays unchanged for its other consumers (dx-step, etc.).
2. **Read `resume-state.json.status`** and branch accordingly (table below).

> **Why a new script, not an extension (M2).** `ensure-feature-branch.sh` is shared. Changing its matching semantics to do remote-glob discovery risks every consumer. Keep discovery + reverse-mapping in `resume-check.sh`; reuse the helper only for "create fresh from base."

> **git-rules.md exception:** `git-rules.md` says "never reuse old feature/bugfix branches for new work." `/dx-simple` resume is a deliberate, scoped exception — it reuses the branch for the **same ticket, same work, continued** (not new work), and only when the **anchored** `feature/<id>-*` / `bugfix/<id>-*` match is **unique** (ambiguous → blocker, not reuse). Note this in `git-rules.md` so the two don't appear to contradict.

### One status model covers "blocked" *and* "crashed"

`resume-state.json` carries a `status` that Phase 0 dispatches on. The payoff: **a crashed run needs no special detection** — a run that died mid-flight left `status: in-progress`, so the next run resumes forward.

> **But "the next run" is not automatic (H3).** A MAX_TURNS/timeout kill posts no `@kai-simple` comment, so the filtered hook never re-fires on its own. The crashed ticket sits at `in-progress` until **a human re-triggers it by replying with the keyword**. The pipeline `failed()` fallback comment must say exactly that. Do **not** describe crash recovery as "automatic resume" — it is *human-re-triggered* resume.

> **Resume forward ≠ jump straight to the phase (C2).** Code edits are never committed (decision #3), so on resume the working tree has none of them. Before re-entering **any phase after Phase 3b**, the resume MUST **replay the code edits from `work-plan.json`** onto the clean committed base (deterministic — same base + unique `match-context` → identical diff). Authoring writes are the opposite: they persist in AEM, so resume **skips** Phase 3a (reconciling via the committed `authoring-diff.json`) rather than replaying it.

| `status` | who set it | Phase 0 action |
|----------|-----------|----------------|
| `in-progress` (updated every checkpoint with `last-completed-phase`) | the running agent | Prior run **crashed** (MAX_TURNS / timeout / error — the *transient* case). **Replay committed code edits if `last-completed-phase` > 3b (C2)**, then resume forward from `last-completed-phase`, reusing committed discovery artifacts. Does **not** consume an `answer-attempt`. |
| `blocked-needs-input` | ABORT on a recoverable gate | Read the newest non-bot `@kai-simple` comment (id > cursor) → apply it to `blocked-at-phase` → **replay code edits if re-entering past 3b** → re-enter that phase. |
| `blocked-hard` | ABORT on an unrecoverable gate | Re-post the "needs manual fix / re-tag DevAgent" note; exit (unless the new comment explicitly overrides). |
| `done` | Phase 7 success | No-op / "already completed in PR #x; open a new ticket for further changes." |

### `resume-state.json` schema

```json
{
  "ticket": "9999999",
  "answer-attempts": 1,
  "status": "blocked-needs-input",
  "last-completed-phase": "Phase 1",
  "blocked-at-phase": "G1",
  "blocker": {
    "class": "needs-user-input",   // needs-user-input | transient | hard
    "recoverable": true,
    "reason": "ambiguous-locator: 'Language Selector' matched 3 elements",
    "needs": "a jcr-path= or a more specific element description"
  },
  "comment-cursor": "<id of the last non-bot @kai-simple comment this run processed>",
  "run-history": [
    { "attempt": 1, "ended": "<ISO>", "outcome": "blocked", "phase": "G1" }
  ]
}
```

- **`answer-attempts` (M4)** counts only **human-answer cycles** to a `needs-input` block; it gates the cap of 3 → downgrade to `hard`. **Crashes / transient resumes do NOT increment it** (otherwise two unlucky MAX_TURNS kills would prematurely escalate a recoverable ticket). The total run count lives in `run-history[]` and is observability-only.
- Initialized as `status: in-progress` in pre-flight; `last-completed-phase` updated by every checkpoint; set to a terminal/blocked status by Phase 7 / ABORT.

### Commit cadence — `save-state.sh`

New `scripts/save-state.sh <spec-dir> <phase>`:
- Stages (plain `git add`, specific paths — no `git add .`/`-A` per git-rules.md) the recovery set under the ticket's spec dir (text files: `resume-state.json`, `simple-block.yaml`, `work-plan.json`, `dialog-map.json`, `file-list.json`, `confidence.json`, `simple-progress.md`, `report.md`). PNGs are skipped from checkpoints (large, not needed to resume the decision; Phase 6 commits them normally).
- Commits `chore(dx-simple): checkpoint <phase> [#<id>]`.
- **Rebase-before-push (H2).** Before pushing, `git pull --rebase origin <branch>` (the branch has no uncommitted code edits at checkpoint time, so a rebase is safe). Then push `-u origin <branch>` with exponential backoff (2s/4s/8s/16s) per the repo's git-push policy. If the push is still rejected non-fast-forward after rebase, **bail with a clear "branch advanced under another run — concurrent `@kai-simple` resume in flight" message** rather than force-pushing. This is the only dedup layer on the comment path (the Lambda's `body.id` dedup does **not** apply here — see decision #1 / H2).

Called after Phases 1, 2, 3b, after every gate, and — critically — **before the ABORT `git checkout -- .`** so the report + state survive (today they're wiped).

**Phase 3a is checkpointed per JCR write, not per phase (H1).** AEM writes are external side-effects that aren't transactional with the git commit. If `save-state.sh` only ran after Phase 3a completed, a crash after write 2 of 3 would leave the writes live on AEM but `authoring-diff.json` uncommitted → on resume the before-value check sees the already-applied value and aborts with a spurious `value drifted`. So Phase 3a commits `authoring-diff.json` **after each `updateComponent`**, and the Phase 3a before-check treats `actual == target-after` as **already-applied → skip** (idempotent re-entry).

> **Assumption — `.ai/specs/` is tracked.** We assume the consumer repo tracks `.ai/specs/` (a plain `git add` works; no `-f`, no `rm --cached`, no state branch needed). The `/dx-init` gitignore template ignores `.ai/specs/` only as an *initial default*; consumers who enable SimpleAgent recovery must remove that line so the per-ticket state can be committed. **This is a documentation note for plugin users, not a code change** — see Scope (docs) below.

### ABORT path (rewritten)

Order matters now. **Classify first, then roll back authoring only if the blocker is terminal (C3):**
1. **Classify the blocker** → set `blocker.class` / `recoverable` / `reason` / `needs` in `resume-state.json`; set `status`.
2. **Conditional authoring rollback (C3).** Roll back JCR writes (`rollback-authoring.sh`) **only when the blocker is terminal** (`hard`, or final fail). On a **recoverable** block (`needs-input` / `transient`), **leave the authoring writes in place** — they are recorded in the committed `authoring-diff.json`, and the resume run skips Phase 3a. (Rolling back here would lose the authoring half of a combined authoring+code change, because resume re-enters at Phase 3b, past 3a.)
3. Write the failure `report.md` (Recovery section populated).
4. **`save-state.sh` — commit + push state** (the report + resume-state + `authoring-diff.json`).
5. **Then** `git checkout -- .` to discard the (now-irrelevant) *source* edits. Spec files are committed → they survive the checkout. (In pipeline mode the container is ephemeral so this mainly matters for local-dev resume; the code edits are replayed from `work-plan.json` on resume regardless — C2.)
6. Post the classified ADO comment (loop-safe; see format) + `touch .ai/run-context/ado-comment-posted.flag`.
7. Exit non-zero.

### Blocker taxonomy

| class | examples | recovery |
|-------|----------|----------|
| `needs-user-input` | G1 ambiguous/no match, missing `page-url`, G3 low classification, authoring value drifted, **`ambiguous-branch` (M1)** | human replies `@kai-simple <answer>` → resume at blocked phase |
| `transient` | MAX_TURNS / step timeout / MCP unreachable / network blip — **infra only** | re-trigger (any `@kai-simple` reply, or re-run) → resume forward from `last-completed-phase` (replaying code edits if past 3b) |
| `hard` | scope-check exceeded (>5 files / >50 lines / >10 writes), G7 real review blocker, **any compile failure surviving Phase 4's in-run 3× retry (M3)**, `answer-attempts` cap reached | not recoverable here → recommend re-tag `KAI-DEV-AUTOMATION` (DevAgent) |

> **Compile is not `transient` (M3).** Phase 4 already retries compile 3× against a *deterministic* edit. A cross-run re-trigger replays the identical edit, so it won't compile any better — re-classifying a compile failure as `transient` just burns runs. After the in-run retry budget, a compile failure is `hard`. `transient` is reserved for infrastructure (MCP/network) and MAX_TURNS, which a genuinely fresh run can fix.

### Reading the answer + the re-ask loop

On a resume run:
1. Fetch comments; select the comment that is (a) **authored by a non-bot identity** (skip anything authored by the bot identity — second loop-safety layer, since the Lambda's author filter doesn't run on this path), (b) contains `@kai-simple`, (c) has the **highest ADO comment id** (ids are monotonic — order by id, not timestamp), and (d) id > `comment-cursor`. If none qualifies → cheap exit (a stray re-trigger; nothing to do).
2. Strip the token; the remainder is `continue-input`. Apply it to `blocked-at-phase` (e.g. set `simple-block.yaml` `component-locator` for a G1 ambiguity; add a file/line/anchor hint for G4). **Commit the updated `comment-cursor` before / atomically with re-entering the phase (L2)** — otherwise a crash after applying the answer reprocesses the same comment next run.
3. Re-enter that phase (replaying code edits first if past 3b — C2). **If the gate still fails**, `answer-attempts++`, post a *sharper* question. **When quoting the prior answer, never echo the literal token (H4)** — render it as `@<keyword>` (e.g. "you gave `/content/x`, but that node doesn't exist on QA — reply again with `@<keyword>` and an existing JCR path or exact visible text"). Echoing the literal `@kai-simple` would both re-fire the filtered hook *and* make the next run mistake the bot's quote for a fresh human answer. Set `blocked-needs-input` again; update `comment-cursor`.
4. **`answer-attempts` cap = 3 (configurable — M7).** After the 3rd failed answer cycle, downgrade to `blocked-hard` and recommend DevAgent — prevents an infinite human↔bot ping-pong. Crashes/transient resumes do **not** count against this cap (M4).

### Resume jump table

| blocked at | needs from human | re-enters at | reuses / notes |
|------------|------------------|--------------|--------|
| G1 (0 or >1 locator matches) | jcr-path / exact visible text | Phase 1 step 3 (re-locate) | — |
| `ambiguous-branch` (M1) | which branch to resume | Phase 0 discovery | — |
| G3 (classification low) | which path: content vs code | Phase 2 | persisted `dialog-map.json`, `file-list.json` |
| G4 (edit confidence <0.85) | which file / line / anchor | Phase 3b (re-fill + re-apply work-plan) | `work-plan.json`, `file-list.json`. **If 3a authoring was applied: it was NOT rolled back (C3) — do not re-run 3a; reconcile via committed `authoring-diff.json`.** |
| compile fails (survives Phase 4 3× retry) | `hard` → DevAgent (M3) | — | — |
| G7 (review blocker) | guidance, or `hard` | Phase 3b re-edit (**replay code edits first — C2**) | `work-plan.json` |
| crashed mid-flow after 3b (`in-progress`) | nothing (transient) | `last-completed-phase` + 1 | committed artifacts **+ replay code edits from `work-plan.json` before re-entering (C2)** |
| crashed mid-flow at/before 3b (`in-progress`) | nothing (transient) | `last-completed-phase` + 1 | committed artifacts (no code edits exist yet — re-fill 3b from scratch) |
| crashed after Phase 6 PR-create (`in-progress`) | nothing (transient) | Phase 6 | **Phase 6 must detect an existing open PR for the branch → update-mode, not a second create (M5).** Checkpoint `last-completed = Phase 6` *before* the create so a crash doesn't re-enter pre-create. |

### Blocker comment format (human + machine, loop-safe)

The literal `@kai-simple` token **never appears** in the bot's own text (loop safety) — the bot says the keyword bare and instructs the user to prefix it with `@`.

```
⚠️ /dx-simple paused on #<id> — needs your input

**What failed:** G1 locator — "Language Selector" matched 3 elements on the page.
**Recoverable:** yes (answer-attempt 1 of <max-attempts>)
**What I need:** reply on this ticket, beginning your comment with the kai-simple keyword
   (prefixed with @ so it re-triggers me), followed by a precise target, e.g.
   @<keyword> jcr-path=/content/site/.../languagenavigation

<!-- dx-simple:blocked phase=G1 reason=ambiguous-locator attempt=1 comment-cursor=<id> -->
```

The HTML marker lets the next run parse `phase` / `attempt` / `comment-cursor` deterministically without re-reading its own prose. (Rendering of the keyword in the example line must avoid the literal `@`-prefixed form; use a placeholder like `@<keyword>` so the example doesn't self-trigger.)

### `report.md.tmpl` — new Recovery section

Add below the existing tables:
```markdown
## Recovery
- Status: {STATUS}
- Blocker class: {BLOCKER_CLASS} (recoverable: {RECOVERABLE})
- Failed at: {BLOCKED_AT_PHASE} — {BLOCKER_REASON}
- Answer-attempt: {ANSWER_ATTEMPTS} of {MAX_ATTEMPTS}
- To continue: {RECOVERY_INSTRUCTION}
<!-- dx-simple:blocked phase={BLOCKED_AT_PHASE} reason={BLOCKER_SLUG} answer-attempts={ANSWER_ATTEMPTS} comment-cursor={COMMENT_CURSOR} -->
```

### Updated flow digraph

> **L1 — ship the full DOT, not a sketch.** Per CLAUDE.md, the graph IS the flow for a branching skill, and **every digraph node must have a matching `### Section` heading**. The implementation must update the existing `SKILL.md` digraph (it currently lacks even the ABORT classify/persist/comment nodes) to include all of the following, each with its own Node Details section:

- **Phase 0** entry node with out-edges: `fresh → Phase 1`, `in-progress → Replay code edits (if past 3b) → last-completed-phase+1`, `blocked-needs-input → read comment → Replay code edits (if past 3b) → blocked-at-phase`, `blocked-hard → re-post + exit`, `done → no-op exit`, and `ambiguous-branch → blocked-needs-input`.
- A **"Replay code edits from work-plan.json"** node on every resume edge that re-enters a phase after 3b (C2).
- The **ABORT** terminal expanded into: `classify → (terminal? rollback authoring : keep authoring) → write report → save-state (commit+push) → checkout -- . → comment → exit` (C3, H1 ordering).
- A **re-ask loop**: failed resumed gate → `answer-attempts < 3?` diamond → (`yes` → post sharper question, `blocked-needs-input`) / (`no` → `blocked-hard` → DevAgent).

---

## Constraints / gotchas

- **`.ai/specs/` must be tracked** in the consumer repo (it's an initial-default gitignore in `/dx-init`; consumers using recovery remove that line). Plain `git add` — no `-f`. Documentation note only.
- **Slug drift** → resume keys on ticket id, not slug — but with an **anchored** `feature/<id>-*` / `bugfix/<id>-*` match, never a bare `*<id>*` substring (`123` must not match `1234`). >1 match → `ambiguous-branch` blocker, not "reuse any" (M1).
- **Code edits are ephemeral, not committed (C2)** → `work-plan.json` carries filled `match-context`/`replacement` so edits regenerate identically on a clean committed base. Any resume re-entering a phase **after 3b** must replay them first; a resume at/before 3b re-fills from scratch.
- **Authoring writes are external/persisted (C3/H1)** → not rolled back on a *recoverable* block; checkpointed per-write; before-check treats `actual == target-after` as already-applied. The two halves of the resume contract are asymmetric — code replays, authoring reconciles.
- **comment-cursor idempotency** → select newest non-bot `@kai-simple` comment by **id**, id > cursor; commit cursor atomically with re-entry (L2). The hook filter already keeps stray field edits / non-`@kai-simple` comments from triggering at all.
- **Concurrency (H2)** → the comment path has **no Lambda dedup**; a double reply or hook redelivery can start a second run. `save-state.sh` rebases before push and bails on an un-rebasable non-fast-forward rather than racing.
- **Bot self-trigger (H4)** → never emit literal `@kai-simple` (use `@<keyword>`), *including when quoting the human's prior answer in a re-ask*; Done-when greps the rendered comment + `report.md.tmpl`.
- **Crash recovery is human-re-triggered, not automatic (H3)** → nothing re-fires the filtered hook after a silent crash; the `failed()` fallback comment must ask the human to reply with the keyword.
- **Authoring-only path now also branches/commits** — previously it created no branch at all; Phase 0 changes that for every path.
- **No hardcoded token / cap (M7)** → `trigger-token` + `max-attempts` come from `.ai/config.yaml`; the documented hook-filter string must match `trigger-token`.

## Related items
- **#15** Pipeline pause-and-resume (`ManualValidation@1` approach) — this is a lighter, comment-driven, branch-state alternative specific to `/dx-simple`; the two can coexist.
- **#129** Interactive prompts in autonomous pipeline mode — the `@kai-simple` reply channel is a concrete answer to "how does a pipeline ask a question and get an answer" for this skill.
- **#136** `disallowed-tools` / `dx-simple` authoring vs code path split — touches the same skill; coordinate edits.
