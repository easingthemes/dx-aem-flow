# TODO: Universal ADO Skill Trigger

## Universal ADO skill trigger (`@kai /dx-skill`)

**Added:** 2026-06-05
**Problem:** Every pipeline-based agent (SimpleAgent, BugFix, PR-Reviewer, PR-Answerer) requires its own dedicated ADO pipeline and Service Hook. Adding a new skill to the automation catalogue means authoring a full pipeline YAML, creating a new Service Hook, and wiring a new Incoming WebHook service connection. There is no way to invoke an arbitrary `dx-*` skill from an ADO work-item comment without this per-skill ceremony. This bottleneck makes the automation footprint O(skills) instead of O(1).
**Scope:**
- `plugins/dx-automation/data/pipelines/cli/ado-cli-universal.yml` (new)
- `plugins/dx-automation/skills/auto-webhooks/SKILL.md` — new §3 "Universal trigger setup" (one Service Hook, one service connection)
- `plugins/dx-core/skills/dx-simple/scripts/pipeline-agent.js` — already generic; only prompt construction changes
- `docs/reference/agent-catalog.md` — add universal-trigger row
**Done-when:**
- `test -f plugins/dx-automation/data/pipelines/cli/ado-cli-universal.yml`
- `grep -n 'universalHook' plugins/dx-automation/data/pipelines/cli/ado-cli-universal.yml` → webhook resource declared
- `grep -n 'ALLOWLIST' plugins/dx-automation/data/pipelines/cli/ado-cli-universal.yml` → skill allowlist enforced
- Manual smoke test: comment `@kai /dx-plan 12345` on an ADO story → pipeline queues → `implement.md` written to spec dir → ADO comment posted with result

**Approach:**

### Trigger syntax

```
@kai /<skill-name> [args] [extra prompt text]
```

Examples:
```
@kai /dx-plan 12345
@kai /dx-step 12345 focus only on the CSS change in step 3
@kai /dx-pr 12345
@kai /dx-req 12345 skip the interview loop if DoR passes
```

The pipeline auto-injects the work item ID as the first argument, so `@kai /dx-plan` (no ID) also works — the pipeline reads `WI_ID` from the webhook payload and prepends it.

### Service Hook change

One new Service Hook, event `workitem.commented`, comment filter: contains `@kai /`. Maps to Incoming WebHook service connection `kai-trigger-sc` (or reuse existing `kai-simple-trigger-sc` with an OR filter if ADO supports it — check `/auto-webhooks` implementation).

### Pipeline skeleton (`ado-cli-universal.yml`)

```yaml
resources:
  webhooks:
    - webhook: universalHook
      connection: kai-trigger-sc
      filters:
        - path: eventType
          value: workitem.commented

steps:
  - bash: |
      COMMENT="${{ parameters.universalHook.resource.fields['System.History'] }}"
      WI_ID="${{ parameters.universalHook.resource.id }}"
      MANUAL_WI="${{ parameters.workItemId }}"
      MANUAL_SKILL="${{ parameters.skill }}"

      # Webhook path: parse "@kai /dx-plan extra text"
      if [ -n "$MANUAL_SKILL" ]; then
        SKILL="/$MANUAL_SKILL"
        EXTRA="${{ parameters.extraPrompt }}"
        WI_ID="${MANUAL_WI:-$WI_ID}"
      else
        SKILL=$(echo "$COMMENT" | grep -oP '(?<=@kai )/[\w-]+' | head -1)
        EXTRA=$(echo "$COMMENT" | sed -E 's/.*@kai\s+\/[\w-]+\s*//' | xargs)
      fi

      # Guard: skill must be in allowlist
      ALLOWLIST="dx-plan dx-step dx-req dx-pr dx-step-verify"
      SKILL_NAME="${SKILL#/}"
      if ! echo "$ALLOWLIST" | grep -qw "$SKILL_NAME"; then
        echo "##[error]Skill '$SKILL_NAME' not in allowlist: $ALLOWLIST"
        exit 1
      fi

      # Inject WI_ID + extra prompt
      PROMPT="$SKILL $WI_ID${EXTRA:+ $EXTRA}"
      echo "##vso[task.setvariable variable=PROMPT]$PROMPT"
      echo "##vso[task.setvariable variable=WI_ID]$WI_ID"
    displayName: Parse skill + args

  - bash: |
      node .ai/automation/scripts/pipeline-agent.js "$(PROMPT)"
    displayName: AI Universal Agent
    env:
      ANTHROPIC_API_KEY: $(ANTHROPIC_API_KEY)
      ADO_MCP_AUTH_TOKEN: $(ADO_PAT)
      DX_PIPELINE_MODE: "true"
      DX_HOOK_PROFILE: minimal
      CI: "true"
      MAX_TURNS: "200"
```

### MCP server selection

Start with **Option A: start all MCP servers always**. Each skill uses only what it needs; idle servers cost nothing beyond cold-start time (~10–15 s). Revisit with Option B (skill-to-MCP config map) only if cold-start degrades pipeline SLA below acceptable.

### Authorization

Pre-flight step checks the commenter's ADO identity against a configured group (default: project contributors). Configurable in `.ai/config.yaml`:

```yaml
dx-universal:
  allowed-groups: ["Contributors"]   # ADO group names allowed to trigger
  skill-allowlist: [dx-plan, dx-step, dx-req, dx-pr, dx-step-verify]
```

---

## Pipeline compatibility matrix and best candidates

**Added:** 2026-06-05
**Problem:** The universal trigger runs any skill as a pipeline agent. Skills assume a human is at the terminal and may call `AskUserQuestion`, print interactive menus, or block on "confirm?" prompts. None of these work in a headless pipeline. This section documents which skills are pipeline-safe today, which need small changes, and which need the async re-ask pattern before they qualify.

**Scope:** All dx-core coordinator skills: `dx-plan`, `dx-req`, `dx-step`, `dx-pr`, `dx-step-verify`, `dx-simple` (reference).

**Done-when:** Each skill row below marked Pipeline-ready has a passing smoke test via the universal trigger.

### Compatibility matrix

| Skill | Model | Interactive? | AskUserQuestion? | DX_PIPELINE_MODE guarded? | Pipeline-ready | Tier |
|-------|-------|-------------|-----------------|--------------------------|---------------|------|
| `/dx-plan` | opus/high | No | No | N/A — no prompts | ✅ Ready now | 1 |
| `/dx-pr` | (default) | No | No | N/A — no prompts | ✅ Ready now | 1 |
| `/dx-step` | sonnet | No | No (no AskUserQuestion found) | Partial — compile auto-retry already headless | ✅ Ready with `DX_PIPELINE_MODE=true` | 2 |
| `/dx-step-verify` | opus/xhigh | Unknown | Audit needed | Unknown | ⚠️ Audit first | 2 |
| `/dx-req` | sonnet | YES — interview loop | YES — `AskUserQuestion` in Phase 2 DoR gate | No | ❌ Requires #155 | 3 |
| `/dx-simple` | sonnet | Async only | No (posts ADO comments) | Yes — template for all others | ✅ Already deployed | — |
| `/dx-bug-all` | sonnet | Async only | No (posts ADO comments) | Yes | ✅ Already deployed | — |

### Tier 1 — Ready immediately (no skill changes)

**`/dx-plan`** is the best first candidate:
- Pure generative skill. Reads `research.md` + `explain.md` from existing spec dir; outputs `implement.md`.
- No user interaction of any kind. Optional brainstorming superpower is auto-skipped if not installed.
- The `@kai /dx-plan 12345` comment triggers planning for a ticket that already has `/dx-req` output.
- Typical pipeline run: 3–6 min, ~$0.15 (opus/high).

**`/dx-pr`** is the best second candidate:
- Pure ADO write. Reads `implement.md`, verifies all steps are `done`, pushes branch, creates PR.
- No interaction. Hard gates (`all steps done`, `verified=true`) fail fast with a clear message — the pipeline can post this as an ADO comment and exit non-zero.
- The `@kai /dx-pr 12345` comment closes the loop after a dev runs `/dx-step` locally or via the universal trigger.
- Typical pipeline run: 1–2 min, ~$0.02.

### Tier 2 — Ready with minor verification

**`/dx-step`** needs a one-pass audit to confirm no hidden interactive prompts:
- No `AskUserQuestion` or interactive patterns found in SKILL.md.
- Compile-fail auto-retry (1 attempt) is already headless.
- With `DX_PIPELINE_MODE=true`, any "are you sure?" patterns must auto-proceed or abort.
- Change needed: add `DX_PIPELINE_MODE` guard to any "proceed?" prompt, if found during audit.
- Risk: if the compilation auto-fix fails twice, the skill posts a blocked status to `implement.md` and exits — this is the right headless behavior.

**`/dx-step-verify`** — audit required before adding to allowlist:
- Not reviewed yet. Uses opus/xhigh (expensive); verify it doesn't call `AskUserQuestion`.
- If clean, add to allowlist after audit pass.

### Tier 3 — Requires async interview bypass first (#155)

**`/dx-req`** is the most valuable but needs the most work:
- Phase 2 DoR gate calls `AskUserQuestion` in a round-trip interview loop.
- In pipeline mode this blocks forever.
- Fix: when `DX_PIPELINE_MODE=true`, replace `AskUserQuestion` with the dx-simple async re-ask pattern (post ADO comment → commit `resume-state.json` → exit; re-trigger fires the pipeline again with the answer). See #155 below.
- Once #155 is done, `@kai /dx-req 12345` fully automates the requirements phase end-to-end, including human Q&A via ADO comments.

### Recommended rollout sequence

1. **Now:** Add `/dx-plan` and `/dx-pr` to the universal trigger allowlist. Ship `ado-cli-universal.yml` with only these two enabled.
2. **After audit:** Add `/dx-step` and `/dx-step-verify` to allowlist.
3. **After #155:** Add `/dx-req` to allowlist. This unlocks the full "comment → requirements → plan → steps → PR" chain, all driven by ADO comments.

---

## Pipeline-safe interactive skill mode (bypass `AskUserQuestion` in autonomous runs)

**Added:** 2026-06-05
**Problem:** `/dx-req` contains a synchronous interview loop in Phase 2 (DoR gate). When the DoR verdict is "Needs more detail", it calls `AskUserQuestion` in themed rounds (max 3 questions per round, up to 3 rounds). In a pipeline there is no human at the terminal — `AskUserQuestion` blocks forever or errors. The existing `DX_PIPELINE_MODE=true` env var suppresses interactive prompts in PR-Review, PR-Answer, and BugFix, but `/dx-req` does not respect it. The fix must preserve the interview loop for local interactive use while substituting the dx-simple async re-ask pattern for pipeline runs.
**Scope:**
- `plugins/dx-core/skills/dx-req/SKILL.md` — Phase 2 interview loop; add `DX_PIPELINE_MODE` branch
- `plugins/dx-core/skills/dx-req/scripts/resume-check.sh` (create) — same pattern as dx-simple; discovers per-ticket `req/` branch
- `plugins/dx-core/skills/dx-req/scripts/save-state.sh` (create or symlink) — checkpoint resume-state.json
- `.ai/specs/<id>-<slug>/resume-state.json` — add `phase: req-interview`, `blocked-at: G-dor`, `comment-cursor` fields
**Done-when:**
- `grep -n 'DX_PIPELINE_MODE' plugins/dx-core/skills/dx-req/SKILL.md` → interview loop is gated
- `grep -n 'AskUserQuestion' plugins/dx-core/skills/dx-req/SKILL.md` → only under `## Interactive mode` block
- `test -f plugins/dx-core/skills/dx-req/scripts/resume-check.sh`
- Triggering `@kai /dx-req 12345` on a ticket where DoR fails → pipeline posts DoR blocking questions to ADO comments → human replies with answers → `@kai /dx-req 12345` re-triggers → pipeline reads the answer from comments → resumes from Phase 2

**Approach:**

```
DX_PIPELINE_MODE=true branch of /dx-req Phase 2:

1. Run /dx-dor as normal → get verdict
2. If verdict = "Ready" or "Minor gaps":
   → continue to Phase 3 (no change from interactive mode)
3. If verdict = "Needs more detail":
   a. Format blocking questions as ADO comment (loop-safe, no literal trigger token):
      "🔍 /dx-req paused on #<id> — answers needed for DoR
       
       **Blocking questions:**
       1. <question from dor-report.md>
       2. ...
       
       Reply on this ticket beginning your comment with the trigger keyword
       (prefix with @) followed by your answers.
       
       <!-- dx-req:blocked phase=G-dor comment-cursor=<id> -->"
   b. Commit resume-state.json: { status: blocked-needs-input, blocked-at: G-dor, comment-cursor: <id> }
   c. Post ADO comment via mcp__ado__wit_add_work_item_comment
   d. Exit non-zero

4. On re-trigger:
   a. resume-check.sh finds branch → reads state → DISPATCH=resume-blocked-input
   b. Fetch comments, find highest-id comment authored by non-bot after comment-cursor containing trigger token
   c. Extract answers → update interview.md
   d. Re-run DoR gate with answers as context
   e. If passes → continue to Phase 3
   f. If still failing → loop (up to dx-req.recovery.max-attempts, default 3) or escalate to hard-blocked
```

Cross-ref: #154 (universal trigger — dx-req is the Tier 3 candidate), #141 (dx-simple recovery — template for this pattern).
