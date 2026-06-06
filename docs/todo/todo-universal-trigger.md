# TODO: Universal ADO Skill Trigger

## Universal ADO skill trigger (`@kai /dx-skill`)

**Added:** 2026-06-05
**Problem:** Every pipeline-based agent (SimpleAgent, BugFix, PR-Reviewer, PR-Answerer) requires its own dedicated ADO pipeline and Service Hook. Adding a new skill to the automation catalogue means authoring a full pipeline YAML, creating a new Service Hook, and wiring a new Incoming WebHook service connection. There is no way to invoke an arbitrary automation skill from an ADO work-item comment without this per-skill ceremony. This bottleneck makes the automation footprint O(skills) instead of O(1).

**Scope:**
- `plugins/dx-automation/data/pipelines/cli/ado-cli-universal.yml` (new)
- `plugins/dx-automation/skills/auto-webhooks/SKILL.md` — new §3 "Universal trigger setup" (one Service Hook `@kai /`, one Incoming WebHook service connection `kai-trigger-sc`)
- `plugins/dx-automation/data/scripts/pipeline-agent.js` — already generic; only prompt construction changes
- Per-skill changes documented in #156

**Done-when:**
- `test -f plugins/dx-automation/data/pipelines/cli/ado-cli-universal.yml`
- `grep -n 'universalHook' plugins/dx-automation/data/pipelines/cli/ado-cli-universal.yml` → webhook resource declared
- `grep -n 'ALLOWLIST' plugins/dx-automation/data/pipelines/cli/ado-cli-universal.yml` → skill allowlist enforced
- Smoke test: comment `@kai /dx-doc-retro 12345` on a completed story → wiki page created + ADO comment posted with link

---

### Trigger syntax

```
@kai /<skill-name> [extra prompt]
```

The pipeline auto-injects the work item ID from the webhook payload — no need to include it in the comment. Extra prompt text is passed directly to the skill as additional context.

Examples:
```
@kai /dx-agent-all
@kai /dx-doc-gen focus on the dialog authoring section
@kai /dx-doc-retro
@kai /aem-qa-handoff hero
```

---

### What this is NOT

The universal trigger is **not** a wrapper for the local dev flow. Skills that produce intermediate markdown files consumed by a human developer (`/dx-req`, `/dx-plan`, `/dx-step`, `/dx-pr`) are **not candidates** — triggering them from a comment produces files no one reads. They remain local-only tools.

The trigger is only for skills that produce a **real-world artifact**: an ADO Wiki page, an ADO comment, or a PR.

---

### Skill candidate map

Already deployed with dedicated comment hooks (not candidates — they have their own Azure-native triggers):

| Existing trigger | Skill | Already has |
|-----------------|-------|-------------|
| `@kai-dor` | dx-dor | Azure-native Service Hook |
| `@kai-simple` | dx-simple | Azure-native Service Hook |
| `@kai-bugfix` | dx-bug-all | Azure-native Service Hook |

Universal trigger candidates — skills that produce a real ADO artifact and work sequentially in the post-implementation flow:

| `@kai /skill` | Output | Pre-requisites | Changes needed | Status |
|---------------|--------|----------------|----------------|--------|
| `/dx-agent-all` | PR + ADO comment | None (starts from scratch) | DX_PIPELINE_MODE audit (#155) | Pending #155 |
| `/dx-doc-gen` | ADO Wiki page | Spec files from dx-agent-all run | Pre-req guard: linked PR → branch → spec file check; ADO comment on failure (#156) | Pending #156 |
| `/dx-doc-retro` | ADO Wiki page | None (discovers from WI + linked PRs) | Minimal: WI_ID injection + result notification comment | Near-ready |
| `/aem-qa-handoff` | ADO comment (QA notes) | Component name (from comment text) + QA URLs configured | Minimal: parse component from `@kai /aem-qa-handoff <component>` | Near-ready |

---

### Sequencing: how skills chain in practice

```
Ticket created
  → @kai-dor (already deployed, own hook)

Implementation
  → @kai /dx-agent-all   (implements story → opens PR → posts ADO comment)
    produces: spec files in .ai/specs/<id>-<slug>/
              PR linked to work item
              ADO comment with PR link

Documentation (after PR is opened)
  → @kai /dx-doc-gen     (uses spec files from dx-agent-all run → writes wiki page)
    or:
  → @kai /dx-doc-retro   (discovers context from WI + linked PRs → writes wiki page, no spec files needed)

QA handoff
  → @kai /aem-qa-handoff hero   (posts QA notes + test plan as ADO comment)
```

`dx-doc-gen` depends on `dx-agent-all` having run first. This is acceptable — it's a sequential flow, not a race. If spec files are missing, the pre-req guard (#156) reports this as an ADO comment so the developer knows what step is missing.

---

### Pipeline skeleton (`ado-cli-universal.yml`)

```yaml
resources:
  webhooks:
    - webhook: universalHook
      connection: kai-trigger-sc
      filters:
        - path: eventType
          value: workitem.commented

parameters:
  - name: workItemId
    type: string
    default: ""
  - name: skill
    type: string
    default: ""
  - name: extraPrompt
    type: string
    default: ""

steps:
  - bash: |
      COMMENT="${{ parameters.universalHook.resource.fields['System.History'] }}"
      WI_ID="${{ parameters.universalHook.resource.id }}"
      MANUAL_WI="${{ parameters.workItemId }}"
      MANUAL_SKILL="${{ parameters.skill }}"

      if [ -n "$MANUAL_SKILL" ]; then
        SKILL="/$MANUAL_SKILL"
        EXTRA="${{ parameters.extraPrompt }}"
        WI_ID="${MANUAL_WI:-$WI_ID}"
      else
        SKILL=$(echo "$COMMENT" | grep -oP '(?<=@kai )/[\w-]+' | head -1)
        EXTRA=$(echo "$COMMENT" | sed -E 's/.*@kai\s+\/[\w-]+\s*//' | xargs)
      fi

      ALLOWLIST="dx-agent-all dx-doc-gen dx-doc-retro aem-qa-handoff"
      SKILL_NAME="${SKILL#/}"
      if ! echo "$ALLOWLIST" | grep -qw "$SKILL_NAME"; then
        echo "##[error]Skill '$SKILL_NAME' not in allowlist: $ALLOWLIST"
        exit 1
      fi

      PROMPT="$SKILL $WI_ID${EXTRA:+ $EXTRA}"
      echo "##vso[task.setvariable variable=PROMPT]$PROMPT"
      echo "##vso[task.setvariable variable=WI_ID]$WI_ID"
    displayName: Parse skill + args from comment

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

---

## Pre-requisite guard pattern for universal trigger skills (#156)

**Added:** 2026-06-06
**Problem:** Skills with pre-requisites (spec files, linked PRs, configured URLs) currently fail silently or ask the user interactively when those pre-requisites are missing. In a pipeline there is no user to answer, and silent failure produces no feedback in ADO. The automation-safe pattern is: check pre-requisites, then report back to ADO via comment if anything is missing, then exit non-zero. This needs to be implemented in every universal trigger skill that has pre-requisites.

**Scope:**
- `plugins/dx-core/skills/dx-doc-gen/SKILL.md` — replace "print error and STOP" with ADO comment + STOP; add linked PR discovery
- `plugins/dx-core/skills/dx-doc-retro/SKILL.md` — add result notification comment (nice-to-have); WI_ID injection already works
- `plugins/dx-aem/skills/aem-qa-handoff/SKILL.md` — component name must be parseable from comment text; already posts ADO comments

**Done-when:**
- `grep -n 'wit_add_work_item_comment' plugins/dx-core/skills/dx-doc-gen/SKILL.md` → skill posts ADO comment on pre-req failure
- `grep -n 'DX_PIPELINE_MODE' plugins/dx-core/skills/dx-doc-gen/SKILL.md` → WI_ID injection, no "ask user" path
- Triggering `@kai /dx-doc-gen 12345` on a ticket with no linked PR → ADO comment posted explaining what's missing
- Triggering `@kai /dx-doc-gen 12345` on a ticket with a completed dx-agent-all PR → wiki page created

---

### Pattern: pre-requisite guard

Every universal trigger skill that has dependencies follows this structure:

```
## Pre-flight (pipeline mode)

1. Read WI_ID from $ARGUMENTS (injected by pipeline — do NOT ask user)
2. Fetch work item: mcp__ado__wit_get_work_item workItemId=$WI_ID, expand=relations
3. Check pre-requisites (skill-specific, see below)
4. If any pre-req missing:
   a. Format a clear ADO comment: "⚠️ <skill> blocked — <what is missing> <how to fix>"
   b. Post via mcp__ado__wit_add_work_item_comment
   c. Exit non-zero
5. If all pre-reqs met → proceed with normal skill flow
```

The comment format follows the dx-simple blocker pattern — actionable, explains what to do next, never echoes the literal trigger token.

---

### Changes per skill

#### `dx-doc-gen` — significant changes needed

**Current behavior:**
- Step 1: calls `dx-common.sh find-spec-dir` → if spec dir not found, prints error and STOPs (no ADO comment)
- Does not fetch the work item or its relations at all
- If spec files are missing, fails locally with no ADO artifact

**Changes needed:**

1. **Add pre-flight when `DX_PIPELINE_MODE=true`** (new Step 0):
   ```
   Step 0 (pipeline only):
   a. Fetch work item: mcp__ado__wit_get_work_item workItemId=$WI_ID, expand=relations
   b. Find linked PRs in relations (type: ArtifactLink, url contains "pullRequest")
   c. If no linked PR:
      → post ADO comment: "⚠️ doc gen blocked — no implementation PR linked to this ticket.
         Link the PR or run @kai /dx-agent-all to implement first."
      → exit non-zero
   d. From PR link, extract branch name via mcp__ado__repo_get_pull_request_by_id
   e. Check if spec files exist on that branch:
      - Option A: git fetch origin <branch> && git checkout origin/<branch> -- .ai/specs/<id>-*/
      - Option B: mcp__ado__repo_get_items (ADO file tree API) to list .ai/specs/<id>-*/ contents
   f. If spec dir not found on branch:
      → post ADO comment: "⚠️ doc gen blocked — no spec files found in branch '<branch>'.
         Spec files are generated by @kai /dx-agent-all. Run that first."
      → exit non-zero
   g. If spec files found → continue to Step 1 with spec dir path resolved
   ```

2. **WI_ID injection**: Step 1 currently asks user for ID if not found via find-spec-dir. In pipeline mode, WI_ID is always provided in `$ARGUMENTS` — remove the "ask user" branch when `DX_PIPELINE_MODE=true`.

3. **Result notification**: After wiki page is created (final step), post an ADO comment:
   `"📄 Wiki page created: <wiki-url>"` — so the developer sees the result in the ticket.

**No changes** to the wiki posting logic itself — it already uses `mcp__ado__wiki_create_or_update_page` correctly.

---

#### `dx-doc-retro` — minimal changes needed

**Current behavior:**
- Step 1: fetches work item directly (`mcp__ado__wit_get_work_item`) — no interactive ask needed if WI_ID is in `$ARGUMENTS`
- Already handles missing linked PRs gracefully (warns and continues with reduced context)
- Already checks work item type (STOPs on non-Story/Bug)
- Does NOT post ADO comments — generates wiki page only

**Changes needed:**

1. **Result notification** (Step N, new): after wiki page is created, post ADO comment:
   `"📄 Wiki page created: <wiki-url> — generated from work item content and linked PR context."`

2. **STOP → ADO comment**: the one STOP path (non-Story/Bug work item type) should post an ADO comment before exiting when `DX_PIPELINE_MODE=true`:
   `"⚠️ doc retro blocked — work item type '<type>' is not supported. Only User Story and Bug are supported."`

Otherwise this skill is near-ready for the universal trigger — no structural changes needed.

---

#### `aem-qa-handoff` — minimal changes needed

**Current behavior:**
- Requires `<component-name>` as argument
- If component name missing: tries to infer from `implement.md` / `aem-after.md`; if still unclear, STOPs and asks user
- Already posts ADO comments (posts `[QAHandoff]` comment with QA notes + test plan)
- Already fetches work item via `mcp__ado__wit_get_work_item`
- Requires `aem.author-url-qa` and `aem.publish-url-qa` configured

**Changes needed:**

1. **Component name from comment text**: the trigger syntax `@kai /aem-qa-handoff hero` passes `hero` as extra prompt text, which becomes part of `$ARGUMENTS`. The skill should parse this cleanly when `DX_PIPELINE_MODE=true`.

2. **STOP → ADO comment**: when config URLs are missing and `DX_PIPELINE_MODE=true`, replace the STOP with an ADO comment:
   `"⚠️ QA handoff blocked — aem.author-url-qa or aem.publish-url-qa not configured in .ai/config.yaml."`

3. **Lightweight mode requirement**: the full mode (live QA AEM MCP calls + Playwright screenshot) requires a running QA AEM instance. In pipeline this is acceptable only if the pipeline has QA AEM credentials configured. If not, the skill should default to lightweight mode (using existing `demo/authoring-guide.md` screenshots) and note the fallback in the ADO comment.

No structural changes to the wiki or ADO comment posting logic needed.

---

## Pipeline-safe audit: `dx-agent-all` and subskill `DX_PIPELINE_MODE` propagation

**Added:** 2026-06-06
**Problem:** `/dx-agent-all` is the full story orchestrator (Phase 1–9: requirements → planning → execution → build → review → commit → PR). It is marked "configurable" for pipeline safety but not verified. The known blocker is `/dx-req` Phase 2: the DoR gate calls `AskUserQuestion` in a synchronous interview loop, which blocks forever in a headless pipeline. Before adding `/dx-agent-all` to the universal trigger allowlist, every subskill invocation must be verified to either skip interactive prompts or use the async ADO re-ask pattern when `DX_PIPELINE_MODE=true`.

**Scope:**
- `plugins/dx-core/skills/dx-agent-all/SKILL.md` — verify DX_PIPELINE_MODE propagated to all subskill invocations
- `plugins/dx-core/skills/dx-req/SKILL.md` — Phase 2 interview loop; add async ADO path for pipeline mode
- `plugins/dx-core/skills/dx-step/SKILL.md` — verify no hidden interactive prompts
- `plugins/dx-core/skills/dx-step-verify/SKILL.md` — audit for AskUserQuestion

**Done-when:**
- `grep -rn 'AskUserQuestion' plugins/dx-core/skills/` → only appears under `## Interactive mode` blocks gated on `! DX_PIPELINE_MODE`
- `grep -n 'DX_PIPELINE_MODE' plugins/dx-core/skills/dx-agent-all/SKILL.md` → env var forwarded to all subskill invocations
- Triggering `@kai /dx-agent-all` on a story with a failing DoR check posts the DoR blocking questions to ADO comments (async) instead of hanging

**Approach:**

`/dx-req` Phase 2 when `DX_PIPELINE_MODE=true`: replace `AskUserQuestion` with the dx-simple async re-ask pattern:

1. Format DoR blocking questions as ADO comment (loop-safe, no literal trigger token)
2. Commit `resume-state.json` to per-ticket branch (`status: blocked-needs-input`, `blocked-at: G-dor`, `comment-cursor: <id>`)
3. Exit non-zero
4. Human replies with `@kai /dx-agent-all` → pipeline re-fires → `resume-check.sh` reads branch + state → extracts answer → resumes Phase 2

Requires new files:
- `plugins/dx-core/skills/dx-req/scripts/resume-check.sh`
- `plugins/dx-core/skills/dx-req/scripts/save-state.sh`
- `.ai/specs/<id>-<slug>/resume-state.json` gains `phase: req-interview`, `blocked-at`, `comment-cursor` fields

Cross-ref: #154 (universal trigger), #141 (dx-simple recovery — template for this pattern), #150 (dx-bug-all recovery — same model).
