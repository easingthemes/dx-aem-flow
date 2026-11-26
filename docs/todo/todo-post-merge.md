# Post-merge flow

Design: [2026-11-26-post-merge-flow-design.md](../superpowers/specs/2026-11-26-post-merge-flow-design.md)

## Restructure the post-merge skills

**Added:** 2026-11-26
**Problem:** After a PR merges, five overlapping skills (`aem-editorial-guide`, `aem-doc-gen`, `aem-qa-handoff`, `dx-doc-gen`, `dx-doc-retro`) plus `aem-verify --qa` cover the demo page, docs and QA handoff. Callers chain them in different orders (`dx-req-dod` and the DOCAgent pipeline run docs before the demo capture), `dx-agent-all` runs them before merge, a local `authoring-guide.md` makes `aem-doc-gen` skip the QA capture, `dx-doc-gen` reads `qa-handoff.md` which is written after it, wiki screenshots use repo paths the wiki can't resolve, and nothing calls `aem-qa-handoff`. Pre-PR, the local demo page and screenshots are split over `aem-verify`, `aem-fe-verify` and `aem-editorial-guide`; `dx-agent-all` takes the `/aem-snapshot` baseline after deploying the change, and new components get no page because `aem-verify` depends on the snapshot. Users can't tell which skill to run.
**Scope:** `plugins/dx-aem/skills/{aem-doc-gen,aem-editorial-guide,aem-qa-handoff,aem-verify,aem-fe-verify}/`, `plugins/dx-aem/agents/aem-editorial-guide-capture.md`, `plugins/dx-core/skills/{dx-doc-gen,dx-doc-retro,dx-agent-all,dx-req-dod,dx-upgrade}/`, new `dx-core/skills/{dx-post-merge,dx-qa-handoff}/` and `dx-aem/skills/aem-demo-page/`, `plugins/dx-core/data/templates/{wiki,ado-comments}/`, `plugins/dx-automation/data/pipelines/cli/ado-cli-doc-agent.yml`, `docs/reference/{skill-catalog,agent-catalog,ado-mcp-tools}.md`, `plugins/dx-core/shared/{format-registry,provider-config}.md`, READMEs, website.
**Done-when:**
- `ls plugins/dx-aem/skills/aem-demo-page plugins/dx-core/skills/dx-post-merge plugins/dx-core/skills/dx-qa-handoff` succeeds, and `ls plugins/dx-aem/skills/{aem-doc-gen,aem-editorial-guide,aem-qa-handoff,aem-verify} plugins/dx-core/skills/dx-doc-retro` fails for all five.
- `grep -rn "aem-doc-gen\|aem-editorial-guide\|aem-qa-handoff\|aem-verify\b\|dx-doc-retro\|aem-after.md" plugins cli website/src docs/reference` finds only `dx-upgrade` migration notes.
- In `plugins/dx-core/skills/dx-agent-all/SKILL.md` the `/aem-snapshot` phase comes before Phase 3, and `/aem-demo-page --local` runs after the build with no dependency on the snapshot.
- `grep -n "qa-handoff.md" plugins/dx-core/skills/dx-doc-gen/SKILL.md` finds nothing.
- `grep -n "Phase 6.5\|Phase 7" plugins/dx-core/skills/dx-agent-all/SKILL.md` finds nothing.
- The attachment upload helper has a hermetic `*.test.sh` that passes in CI.
- All `scripts/validate-*.sh` pass.
**Approach:** See the design spec — `aem-demo-page` (QA by default, deploy gate, dialog shot only when `_cq_dialog/` changed, author-preview shot, `demo/demo-page.md`), `dx-doc-gen` (reads `demo-page.md`, adds How to test + Demo script, absorbs retro mode), `dx-qa-handoff` (dx-core, no AEM), `dx-post-merge` coordinator with `--skip`. Screenshots uploaded as work-item attachments by a script (not base64 through the MCP tool).

## `@kai-demo` comment trigger for `/dx-post-merge`

**Added:** 2026-11-26
**Problem:** `/dx-post-merge` is started by hand. Teams using the comment-triggered agents (`@kai-simple`, `@kai-bugfix`, `@kai-dor`) have no equivalent for the post-merge demo/docs/handoff, so it gets forgotten after the QA deploy.
**Scope:** new `plugins/dx-automation/data/pipelines/cli/ado-cli-post-merge.yml` (or a rewrite of `ado-cli-doc-agent.yml`), `plugins/dx-automation/skills/{auto-pipelines,auto-webhooks,auto-init}/`, `plugins/dx-automation/data/infra.template.json`, config key `dx-post-merge.trigger-token` (default `@kai-demo`), docs.
**Done-when:** a pipeline YAML under `plugins/dx-automation/data/pipelines/cli/` has a `resources.webhooks` listener whose filter matches the `dx-post-merge.trigger-token` value and runs `/dx-post-merge <id>`; `/auto-webhooks` creates the matching Service Hook; the webhook-payload hermetic test covers it (`grep -l post-merge plugins/dx-automation/data/pipelines/cli/__tests__/*.test.sh` returns a file).
**Approach:** Mirror `ado-cli-dor.yml` (Azure-native Service Hook → Incoming WebHook → `resources.webhooks`; payload fields through `env:`, never `${{ }}` in script bodies). The `aem-demo-page` deploy gate makes an early comment safe — it stops with "not deployed to QA yet". Later option: fire from the QA deploy pipeline's completion instead of a comment.
