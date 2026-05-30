# TODO: `/dx-simple` Resumable Error Recovery

> Design doc for TODO #141. Status: **design — not yet implemented.**
> Settled with the requester on 2026-05-30 (see "Decisions locked" below).

## `/dx-simple` resumable error recovery (branch-as-state + classified blocker loop)

**Added:** 2026-05-30
**Problem:** `/dx-simple` runs autonomously in an ADO pipeline (`plugins/dx-automation/data/pipelines/cli/ado-cli-simple.yml`), triggered by a webhook. Every run is a **fresh container** with a clean `checkout: self` — nothing from a prior run survives. Three consequences make blockers unrecoverable today:

1. **No durable state.** The per-ticket spec dir (`.ai/specs/<id>-<slug>/`) is written during the run but only committed at Phase 6, and only on the *code* path (via `/dx-pr-commit`). The authoring-only path commits nothing. On the ABORT path, `git checkout -- .` actively **wipes** the uncommitted report + state files. A second run starts from zero — it cannot know what the first run already discovered or where it got stuck.
2. **The fail report is shallow and terminal.** Phase 7 (success) or the ABORT path posts one ADO comment; the pipeline `failed()` step posts a generic "didn't finish" note otherwise. None of them say *what kind* of failure it was, whether a re-run could fix it, or what input the human must supply. There is no way for a human to answer a blocker and have the work continue.
3. **No resume path.** Even if a human knew the answer, there's no mechanism to feed it back in and continue from the failed step rather than re-running the whole pipeline from scratch (re-paying for Phase 2 discovery, re-locating the component, etc.).

The fix: make the **per-ticket git branch the durable state store**, commit to it constantly, classify every blocker, and let a human resolve blockers by replying on the ticket — the next run wakes up, reads where it stopped + the new input, and continues.

**Scope:**
- Skill body: `plugins/dx-core/skills/dx-simple/SKILL.md` (add Phase 0; resume-state lifecycle; checkpoint calls; comment-read in Phase 1; rewritten ABORT path; resume jump table; updated flow digraph + state-files table).
- New scripts: `plugins/dx-core/skills/dx-simple/scripts/save-state.sh`, `.../scripts/resume-check.sh` (Phase 0; likely extends `plugins/dx-core/shared/ensure-feature-branch.sh` id-match logic).
- New template: `plugins/dx-core/skills/dx-simple/templates/resume-state.json.tmpl`.
- Modified template: `plugins/dx-core/skills/dx-simple/templates/report.md.tmpl` (add a **Recovery** section).
- Pipeline: `plugins/dx-automation/data/pipelines/cli/ado-cli-simple.yml` — reword the `failed()` fallback comment to mention automatic resume.
- Docs: `CLAUDE.md` SimpleAgent blurb, `docs/reference/skill-catalog.md`, a website page.
- **Untouched on purpose:** the Lambda router (`wi-router.mjs`) and `dx-pr-commit`. The `@kai-simple` comment webhook already exists; `ensure-feature-branch.sh` already no-ops on an existing branch.

**Done-when** (verifiable once implemented):
- `test -x plugins/dx-core/skills/dx-simple/scripts/save-state.sh` and `test -x plugins/dx-core/skills/dx-simple/scripts/resume-check.sh`.
- `test -f plugins/dx-core/skills/dx-simple/templates/resume-state.json.tmpl`.
- `grep -q "Phase 0" plugins/dx-core/skills/dx-simple/SKILL.md` (resume phase present) AND `grep -q "resume-state.json" plugins/dx-core/skills/dx-simple/SKILL.md` AND `grep -q "@kai-simple" plugins/dx-core/skills/dx-simple/SKILL.md`.
- `grep -qi "Recovery" plugins/dx-core/skills/dx-simple/templates/report.md.tmpl`.
- The ABORT section in `SKILL.md` commits state **before** `git checkout -- .` (grep order check), and classifies the blocker (`needs-user-input` / `transient` / `hard`).
- A dry-run walkthrough (or eval fixture) shows: run 1 blocks → branch + `resume-state.json` pushed → run 2 (after a `@kai-simple` reply) checks out the branch, reads the comment, re-enters the blocked phase.

---

## Decisions locked (with the requester)

| # | Decision | Choice |
|---|----------|--------|
| 1 | Recovery input channel | **ADO comment containing `@kai-simple`.** That comment fires the existing webhook → service connection → pipeline re-runs. The Lambda passes only `workItemId`; the agent **reads the comment itself** from the work item. No tag dance, no router change. |
| 2 | Self-trigger / loop prevention | Trigger token is **`@kai-simple` (with the `@`).** The bot writes the keyword **without** the `@` in its own comments, so its blocker comments never re-trigger the webhook. Plus an agent-side `comment-cursor` dedupe as a second layer. |
| 3 | State persistence granularity | **Spec md/json only** (text). Code edits are NOT committed mid-run; a resume re-applies them deterministically from `work-plan.json`. |
| 4 | PR history | **`chore(dx-simple): checkpoint …` commits on the branch are accepted** — no squashing, no side ref. |
| 5 | Branch timing | **Branch created early at Phase 0**, not Phase 6. |

---

## Approach (the settled design)

### Phase 0 — Resume (new; runs first; creates/reuses the branch)

Runs immediately after pre-flight, before Phase 1.

1. **Find the ticket branch (slug-agnostic).** A fresh container can't recompute run 1's title-derived slug, so resume keys on the **ticket id only**:
   ```bash
   git fetch origin --quiet
   git ls-remote --heads origin '*'"$ID"'*'   # reuse any feature/<id>-… or bugfix/<id>-… branch
   ```
   - Match found → check it out (the committed spec dir + `resume-state.json` come with it).
   - No match → create `feature/<ID>-simple` from the fresh base branch.
   This extends `shared/ensure-feature-branch.sh` (which already matches the *current* branch by id-substring and reuses local/remote branches).
2. **Read `resume-state.json.status`** and branch accordingly (table below).

> **git-rules.md exception:** `git-rules.md` says "never reuse old feature/bugfix branches for new work." `/dx-simple` resume is a deliberate, scoped exception — it reuses the branch for the **same ticket, same work, continued** (not new work). Note this in `git-rules.md` so the two don't appear to contradict.

### One status model covers "blocked" *and* "crashed"

`resume-state.json` carries a `status` that Phase 0 dispatches on. The elegant payoff: **transient crashes need no special detection** — a run that died mid-flight left `status: in-progress`, so the next run simply resumes forward.

| `status` | who set it | Phase 0 action |
|----------|-----------|----------------|
| `in-progress` (updated every checkpoint with `last-completed-phase`) | the running agent | Prior run **crashed** (MAX_TURNS / timeout / error — the *transient* case). Resume forward from `last-completed-phase`, reusing committed discovery artifacts. |
| `blocked-needs-input` | ABORT on a recoverable gate | Read the newest `@kai-simple` human comment → apply it to `blocked-at-phase` → re-enter that phase. |
| `blocked-hard` | ABORT on an unrecoverable gate | Re-post the "needs manual fix / re-tag DevAgent" note; exit (unless the new comment explicitly overrides). |
| `done` | Phase 7 success | No-op / "already completed in PR #x; open a new ticket for further changes." |

### `resume-state.json` schema

```json
{
  "ticket": "9999999",
  "attempt": 1,
  "status": "blocked-needs-input",
  "last-completed-phase": "Phase 1",
  "blocked-at-phase": "G1",
  "blocker": {
    "class": "needs-user-input",   // needs-user-input | transient | hard
    "recoverable": true,
    "reason": "ambiguous-locator: 'Language Selector' matched 3 elements",
    "needs": "a jcr-path= or a more specific element description"
  },
  "comment-cursor": "<id of the last @kai-simple comment this run processed>",
  "run-history": [
    { "attempt": 1, "ended": "<ISO>", "outcome": "blocked", "phase": "G1" }
  ]
}
```

Initialized as `status: in-progress` in pre-flight; `last-completed-phase` updated by every checkpoint; set to a terminal/blocked status by Phase 7 / ABORT.

### Commit cadence — `save-state.sh`

New `scripts/save-state.sh <spec-dir> <phase>`:
- Stages **only** the recovery set under the ticket's spec dir (text files: `resume-state.json`, `simple-block.yaml`, `work-plan.json`, `dialog-map.json`, `file-list.json`, `confidence.json`, `simple-progress.md`, `report.md`). **Not** PNGs (large, not needed to resume the decision).
- Commits `chore(dx-simple): checkpoint <phase> [#<id>]`.
- Pushes `-u origin <branch>` with exponential backoff (2s/4s/8s/16s) per the repo's git-push policy.

Called after Phases 1, 2, 3a/3b, after every gate, and — critically — **before the ABORT `git checkout -- .`** so the report + state survive (today they're wiped).

> **Key constraint — `.ai/specs/` is gitignored.** Both this repo and consumer repos (`/dx-init` template) gitignore `.ai/specs/`. So `save-state.sh` must `git add -f` the recovery files. Two ways to keep them out of the eventual PR diff (decide at implementation; the requester already accepted `chore` commits on the branch):
> - **(recommended)** force-add the minimal text recovery set in `chore` commits; at Phase 6 the final code commit is the only thing that matters for the PR, and a `git rm --cached -r .ai/specs/<id>-*` step can drop the state from the PR's net diff while leaving it in branch history for resume.
> - **(alt)** keep recovery state on a dedicated `dx-simple-state/<id>` branch so the PR branch stays pristine — cleaner PRs, more orchestration. Not chosen now (requester is fine with `chore` commits on the work branch).

### ABORT path (rewritten)

Order matters now:
1. Rollback authoring (existing `rollback-authoring.sh`).
2. **Classify the blocker** → set `blocker.class` / `recoverable` / `reason` / `needs` in `resume-state.json`; set `status`.
3. Write the failure `report.md` (Recovery section populated).
4. **`save-state.sh` — commit + push state** (the report + resume-state).
5. **Then** `git checkout -- .` to discard the (now-irrelevant) source edits. Spec files are committed → they survive the checkout.
6. Post the classified ADO comment (loop-safe; see format) + `touch .ai/run-context/ado-comment-posted.flag`.
7. Exit non-zero.

### Blocker taxonomy

| class | examples | recovery |
|-------|----------|----------|
| `needs-user-input` | G1 ambiguous/no match, missing `page-url`, G3 low classification, authoring value drifted | human replies `@kai-simple <answer>` → resume at blocked phase |
| `transient` | MAX_TURNS / step timeout / MCP unreachable / flaky compile | re-trigger (any `@kai-simple` reply, or re-run) → resume forward from `last-completed-phase` |
| `hard` | scope-check exceeded (>5 files / >50 lines / >10 writes), G7 real review blocker, compile fails on genuine complexity, attempt cap reached | not recoverable here → recommend re-tag `KAI-DEV-AUTOMATION` (DevAgent) |

### Reading the answer + the re-ask loop

On a resume run:
1. Fetch comments; select the **newest human-authored comment containing `@kai-simple`** whose id ≠ `comment-cursor`.
2. Strip the token; the remainder is `continue-input`. Apply it to `blocked-at-phase` (e.g. set `simple-block.yaml` `component-locator` for a G1 ambiguity; add a file/line/anchor hint for G4).
3. Re-enter that phase. **If the gate still fails**, `attempt++`, post a *sharper* question that quotes the prior answer ("you gave `/content/x`, but that node doesn't exist on QA — I need an existing JCR path or exact visible text"), set `blocked-needs-input` again, update `comment-cursor`.
4. **Attempt cap = 3.** After the 3rd failed attempt, downgrade to `blocked-hard` and recommend DevAgent — prevents an infinite human↔bot ping-pong.

### Resume jump table

| blocked at | needs from human | re-enters at | reuses |
|------------|------------------|--------------|--------|
| G1 (0 or >1 locator matches) | jcr-path / exact visible text | Phase 1 step 3 (re-locate) | — |
| G3 (classification low) | which path: content vs code | Phase 2 | persisted `dialog-map.json`, `file-list.json` |
| G4 (edit confidence <0.85) | which file / line / anchor | Phase 3b (re-fill + re-apply work-plan) | `work-plan.json`, `file-list.json` |
| compile fails ×3 | usually `hard` → DevAgent | — | — |
| G7 (review blocker) | guidance, or `hard` | Phase 3b re-edit | `work-plan.json` |
| crashed mid-flow (`in-progress`) | nothing (transient) | `last-completed-phase` + 1 | all committed artifacts |

### Blocker comment format (human + machine, loop-safe)

The literal `@kai-simple` token **never appears** in the bot's own text (loop safety) — the bot says the keyword bare and instructs the user to prefix it with `@`.

```
⚠️ /dx-simple paused on #<id> — needs your input

**What failed:** G1 locator — "Language Selector" matched 3 elements on the page.
**Recoverable:** yes (attempt 1 of 3)
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
- Attempt: {ATTEMPT} of 3
- To continue: {RECOVERY_INSTRUCTION}
<!-- dx-simple:blocked phase={BLOCKED_AT_PHASE} reason={BLOCKER_SLUG} attempt={ATTEMPT} comment-cursor={COMMENT_CURSOR} -->
```

### Updated flow digraph (sketch)

Phase 0 becomes the entry node with three out-edges (`fresh → Phase 1`, `in-progress → last-completed-phase+1`, `blocked → blocked-at-phase`), and the ABORT terminal gains the "classify + persist + comment" steps before exit. Re-ask loop adds an edge from a failed resumed gate back to `blocked-needs-input` with an `attempt < 3?` diamond gating the `hard` downgrade.

---

## Constraints / gotchas

- **`.ai/specs/` is gitignored** → `git add -f` required (see Key constraint above).
- **Slug drift** → resume must key on ticket id, not slug; reuse any existing `*<id>*` branch.
- **Deterministic re-apply** → `work-plan.json` must carry filled `match-context`/`replacement` so code edits regenerate identically on resume (already true post-Phase-3b; ensure it's committed before any abort that happens after 3b).
- **comment-cursor idempotency** → a stray webhook (field edit, duplicate delivery) must not reprocess an old answer; compare against the stored cursor.
- **Bot self-trigger** → never emit literal `@kai-simple`; verify in a test that the rendered comment does not contain it.
- **Authoring-only path now also branches/commits** — previously it created no branch at all; Phase 0 changes that for every path.

## Related items
- **#15** Pipeline pause-and-resume (`ManualValidation@1` approach) — this is a lighter, comment-driven, branch-state alternative specific to `/dx-simple`; the two can coexist.
- **#129** Interactive prompts in autonomous pipeline mode — the `@kai-simple` reply channel is a concrete answer to "how does a pipeline ask a question and get an answer" for this skill.
- **#136** `disallowed-tools` / `dx-simple` authoring vs code path split — touches the same skill; coordinate edits.
