# TODO: Universal ADO Skill Trigger

## Universal ADO skill trigger (`@kai /dx-skill`)

**Added:** 2026-06-05
**Problem:** Every pipeline-based agent (SimpleAgent, BugFix, PR-Reviewer, PR-Answerer) requires its own dedicated ADO pipeline and Service Hook. Adding a new skill to the automation catalogue means authoring a full pipeline YAML, creating a new Service Hook, and wiring a new Incoming WebHook service connection. There is no way to invoke an arbitrary automation skill from an ADO work-item comment without this per-skill ceremony. This bottleneck makes the automation footprint O(skills) instead of O(1).

**Scope:**
- `plugins/dx-automation/data/pipelines/cli/ado-cli-universal.yml` (new)
- `plugins/dx-automation/skills/auto-webhooks/SKILL.md` — new §3 "Universal trigger setup" (one Service Hook `@kai /`, one Incoming WebHook service connection `kai-trigger-sc`)
- `plugins/dx-automation/data/scripts/pipeline-agent.js` — already generic; only prompt construction changes
- `docs/reference/agent-catalog.md` — add universal-trigger row

**Done-when:**
- `test -f plugins/dx-automation/data/pipelines/cli/ado-cli-universal.yml`
- `grep -n 'universalHook' plugins/dx-automation/data/pipelines/cli/ado-cli-universal.yml` → webhook resource declared
- `grep -n 'ALLOWLIST' plugins/dx-automation/data/pipelines/cli/ado-cli-universal.yml` → skill allowlist enforced
- Manual smoke test: comment `@kai /dx-doc-retro 12345` on a completed ADO story → pipeline queues → wiki page created in ADO Wiki

---

### Trigger syntax

```
@kai /<skill-name> [work-item-id] [extra prompt]
```

The pipeline auto-injects the work item ID from the webhook payload, so the ID in the comment is optional (pipeline falls back to the webhook's `resource.id`).

Examples:
```
@kai /dx-agent-all
@kai /dx-doc-retro
@kai /dx-doc-retro focus on the dialog authoring section
@kai /aem-qa-handoff include screenshots from the last QA session
```

---

### What this is NOT

The universal trigger is **not** a wrapper for the local dev flow. Skills that produce intermediate markdown files consumed by a human developer (`/dx-req`, `/dx-plan`, `/dx-step`, `/dx-pr`) are **not candidates** — triggering them from an ADO comment produces files no one reads. They remain local-only tools.

The trigger is only for skills that produce a **real-world artifact**: an ADO Wiki page, an ADO comment, or a PR.

---

### Skill candidate analysis

Skills already deployed with dedicated comment hooks (not candidates — they have their own Azure-native triggers):

| Existing trigger | Skill | Already has |
|-----------------|-------|-------------|
| `@kai-dor` | dx-dor | Azure-native Service Hook |
| `@kai-simple` | dx-simple | Azure-native Service Hook |
| `@kai-bugfix` | dx-bug-all | Azure-native Service Hook |

Skills currently triggered by adding the `KAI-TRIGGER` **tag** to a work item (Lambda WI-Router), not by a comment. The universal trigger gives these a comment-based alternative:

| `@kai /skill` | Skill | Real-world output | Pipeline-safe |
|---------------|-------|-------------------|---------------|
| `/dx-agent-all` | DevAgent | PR + ADO comment (full story implementation) | Configurable — needs `DX_PIPELINE_MODE` audit |
| `/dx-doc-retro` | Retroactive wiki doc gen | ADO Wiki page (or Confluence) | Yes — uses `mcp__ado__wiki_create_or_update_page`; discovers context from WI + linked PRs + codebase, no spec files needed |
| `/aem-qa-handoff` | QA handoff | ADO comment with QA notes + test plan | Yes — uses ADO MCP |

Skills that produce files only and are **not pipeline-useful** without additional commit+PR wiring:
- `/dx-doc-gen` — requires pre-existing spec files (explain.md, implement.md from local dev flow); outputs to `.ai/specs/` only; not standalone automation
- `/aem-doc-gen`, `/aem-editorial-guide` — produce authoring guides + screenshots; files only; require AEM + Playwright

---

### Workflow the trigger enables

```
Ticket created / refined
  → @kai /dx-dor             (already deployed, own hook)
  → @kai /dx-agent-all       (universal trigger: comment-based DevAgent)

Implementation merged, QA picking up
  → @kai /aem-qa-handoff     (universal trigger: post QA notes + test plan to ADO)

Story completed
  → @kai /dx-doc-retro       (universal trigger: write ADO Wiki page)
```

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

      # Guard: skill must be in allowlist
      ALLOWLIST="dx-agent-all dx-doc-retro aem-qa-handoff"
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

### MCP server selection

Start with Option A: start all MCP servers (ADO, AEM, Playwright). Idle servers cost only cold-start time (~10–15 s). Revisit with a skill-to-MCP config map if cold-start becomes a problem.

### Authorization

Pre-flight step checks commenter identity against a configured ADO group (default: project contributors). Configurable in `.ai/config.yaml`:

```yaml
dx-universal:
  allowed-groups: ["Contributors"]
  skill-allowlist: [dx-agent-all, dx-doc-retro, aem-qa-handoff]
```

---

## Pipeline-safe interactive skill mode (`dx-agent-all` audit)

**Added:** 2026-06-05
**Problem:** `/dx-agent-all` is the full story orchestrator (Phase 1–9: requirements → planning → execution → build → review → commit → PR). It is "configurable" for pipeline safety but not verified. The existing `DX_PIPELINE_MODE=true` env var suppresses interactive prompts in PR-Review, PR-Answer, BugFix, and SimpleAgent, but it is unknown whether `dx-agent-all` and its subskills (particularly `/dx-req` which has an `AskUserQuestion` interview loop in Phase 2) respect it end-to-end.

Before adding `/dx-agent-all` to the universal trigger allowlist, every phase must be verified to either:
- Skip interactive prompts when `DX_PIPELINE_MODE=true`, or
- Use the async ADO re-ask pattern (post comment → commit resume-state → exit → re-trigger on human reply)

**Scope:**
- `plugins/dx-core/skills/dx-agent-all/SKILL.md` — verify DX_PIPELINE_MODE propagation across all phases
- `plugins/dx-core/skills/dx-req/SKILL.md` — Phase 2 interview loop (calls `AskUserQuestion`); needs async ADO path
- `plugins/dx-core/skills/dx-step/SKILL.md` — verify no hidden interactive prompts
- `plugins/dx-core/skills/dx-step-verify/SKILL.md` — audit for AskUserQuestion

**Done-when:**
- `grep -rn 'AskUserQuestion' plugins/dx-core/skills/` → only appears under `## Interactive mode` blocks gated on `! DX_PIPELINE_MODE`
- `grep -n 'DX_PIPELINE_MODE' plugins/dx-core/skills/dx-agent-all/SKILL.md` → env var propagated to all subskill invocations
- Triggering `@kai /dx-agent-all` on a story with a failing DoR check posts blocking questions to ADO comments (async, like dx-simple) instead of hanging

**Approach:**

`/dx-req` Phase 2 interview loop: when `DX_PIPELINE_MODE=true`, replace `AskUserQuestion` with the dx-simple async re-ask pattern:

1. Format DoR blocking questions as ADO comment (loop-safe format, no literal trigger token)
2. Commit `resume-state.json` (`status: blocked-needs-input`, `blocked-at: G-dor`, `comment-cursor: <id>`)
3. Exit non-zero
4. Human replies with `@kai /dx-agent-all` → pipeline re-fires → `resume-check.sh` reads branch + state → extracts answer from new comment → resumes Phase 2

This mirrors exactly how dx-simple handles G1/G3/G4 ambiguity — the async ADO comment loop is the canonical pipeline-safe interaction pattern.

Requires:
- `plugins/dx-core/skills/dx-req/scripts/resume-check.sh` (new — adapts dx-simple's resume-check.sh)
- `plugins/dx-core/skills/dx-req/scripts/save-state.sh` (new or symlink to dx-simple's)
- `.ai/specs/<id>-<slug>/resume-state.json` gains `phase: req-interview`, `blocked-at: G-dor`, `comment-cursor` fields

Cross-ref: #154 (universal trigger — dx-agent-all is the top candidate once this passes), #141 (dx-simple recovery — template for this pattern), #150 (dx-bug-all recovery — same model).
