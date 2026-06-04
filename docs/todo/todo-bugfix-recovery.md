# TODO: BugFix agent — Azure-native trigger + resumable recovery

> Detail for TODO #150. Status: **implemented 2026-06-03**. Brings the autonomous
> BugFix agent (`/dx-bug-all`) to parity with SimpleAgent (#141): no Lambda in the
> trigger path, and full resumable recovery over the bug pipeline's three steps.

## BugFix agent — Azure-native comment trigger (no Lambda) + full resumable recovery

**Added:** 2026-06-03
**Problem:** The BugFix pipeline (`ado-cli-bug-fix.yml`, `/dx-bug-all`) was Lambda-routed (WI-Router on tag `KAI-BUGFIX-AUTOMATION`) and had **no recovery**: every run was a fresh container with a clean checkout, `MAX_TURNS=60` was far too tight for a 3-skill chain (triage→verify→fix), there was no Chromium/AEM env so verify couldn't run, no fallback comment (silent crashes), and a crash mid-fix could create a duplicate PR on re-trigger. The user wanted the SimpleAgent model: **no Lambda — trigger via an ADO comment** — plus dx-simple-grade resumable recovery, **without changing local (interactive) behavior**.

**Scope:**
- Pipeline: `plugins/dx-automation/data/pipelines/cli/ado-cli-bug-fix.yml` — `resources.webhooks` (`bugfixHook`, `workitem.commented` + WorkItemType=Bug filter), manual/webhook id resolution, env prep ported from the simple pipeline (Playwright cache, MCP merge, AEM-QA reachability **warn** (verify is non-blocking), MCP health + Chromium install, Node/Maven pre-warm), `MAX_TURNS=250`, fallback `failed()` comment + flag.
- Lambda: `plugins/dx-automation/data/lambda/wi-router.mjs` — `bugfix` removed from `AGENTS`.
- Recovery layer (new): `plugins/dx-core/skills/dx-bug-all/scripts/{resume-check,save-state,preflight,update-progress}.sh` + `templates/{resume-state.json,progress.md}.tmpl` + `scripts/__tests__/resume-recovery.test.sh`.
- Skill: `plugins/dx-core/skills/dx-bug-all/SKILL.md` — **dual-mode**. Local mode = the original flow, unchanged. Pipeline mode (`DX_PIPELINE_MODE=true`) = preflight → USER_INPUT from trigger comment → Phase 0 dispatch → per-step checkpoints → finalize/ABORT with blocker taxonomy (`needs-user-input`/`transient`/`hard`), re-ask loop with attempt cap, reopen-on-follow-up, and never-go-silent (ADO comment + `ado-comment-posted.flag`).
- Idempotent PR: relies on existing `/dx-pr-commit` ORCHESTRATED update-mode; `orchestrating.flag` is touched **unconditionally at pipeline start** (not just fresh-init) so a resume container also updates rather than duplicates.
- Config: `plugins/dx-core/templates/config.yaml.template` — `dx-bug-all.recovery.{trigger-token,max-attempts}` (default `@kai-bugfix`, 3).
- Infra/docs: `/auto-webhooks` §2c (+ retired §2 wi-bug), `infra.template.json` `webhooks.bugfix`, `auto-doctor`/`auto-lambda-env` WI-Router key lists, `auto-provision` router comment, `README.md`, `rules/ado-service-hooks.md`, `CLAUDE.md`.

**Done-when:**
- `bash plugins/dx-core/skills/dx-bug-all/scripts/__tests__/resume-recovery.test.sh` → `14 passed, 0 failed`.
- `grep -q 'resources:' plugins/dx-automation/data/pipelines/cli/ado-cli-bug-fix.yml && grep -q 'bugfixHook' plugins/dx-automation/data/pipelines/cli/ado-cli-bug-fix.yml` → both present.
- `! grep -q '"bugfix"' plugins/dx-automation/data/lambda/wi-router.mjs` → bugfix gone from the router.
- `grep -q 'dx-bug-all.recovery.trigger-token' plugins/dx-core/skills/dx-bug-all/SKILL.md` and the config template.
- `bash scripts/validate-structure.sh` → PASS.

**Approach (decisions of record):**
- **Coarse-step recovery, not dx-simple's 8 phases.** `/dx-bug-all` is a coordinator over 3 sub-skills, so `last-completed-step ∈ {Step 0, triage, verify, fix, finalize}`. No code-edit replay (the fix commits via PR; resume re-runs the whole fix step, made safe by idempotent PR update-mode). This is a deliberately smaller surface than #141.
- **Triage keeps creating the branch** on fresh runs (its existing step 7) — `resume-check.sh` only *discovers* an already-pushed `bugfix/<id>-*` for resume; it does NOT create a fresh branch (unlike dx-simple's). Keeps the sub-skills' local behavior untouched.
- **Dual-mode skill** is the "don't break local" guarantee: the recovery machinery is entirely gated on `DX_PIPELINE_MODE=true`; the local path is the pre-recovery flow.
- **AEM reachability is a warning, not a hard fail** — `/dx-bug-all` treats verify as non-blocking, so triage+fix must proceed even when QA is unreachable.

**Residual / follow-ups (not blocking):**
- Real-ADO verification: create the `kai-bugfix-trigger-sc` Incoming WebHook + the `workitem.commented` Service Hook in a live project and confirm a `@kai-bugfix` comment fires the pipeline and a re-comment resumes.
- Consumer sync: consumers pick up the new `ado-cli-bug-fix.yml` + `dx-bug-all` skill via marketplace plugin update + pipeline git checkout (not `dx-sync`).
- Double-post-on-failure was resolved by routing every terminal path through the `ado-comment-posted.flag` handshake.
