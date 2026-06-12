# Cross-Repo Discovery

Reference document for coordinator skills that need to detect and document
cross-repo work items.

## When This Applies

Code-writing agents (BugFix, DevAgent, DoD-Fix) and `/dx-simple` may touch more
than one repo. They do **not** delegate to each other peer-to-peer anymore — the
central KAI-HUB router decides which repos a work item touches and fans the agent
out, one run per repo (see "Hub pipeline mode" below).

The job of triage/research is therefore just to **detect and document** the
cross-repo scope. The hub's `dx-discover-repos` skill consumes that documentation.

## How Cross-Repo Scope Is Detected

The triage/research skills detect cross-repo scope and document it in a markdown
table that `dx-discover-repos` (tier 2) reads:

- **BugFix:** `triage.md` → `## Cross-Repo Scope` section
- **DevAgent:** `research.md` → `## Cross-Repo Scope` section
- **DoD-Fix:** `research.md` → `## Cross-Repo Scope` section (if present in spec dir)

The section contains a table — the first column holds repo aliases:

```markdown
## Cross-Repo Scope

**Current repo:** <current-repo> (this fix covers only this repo)

| Repo | What's needed | Key files |
|------|--------------|-----------|
| <other-repo> | Backend exporter update | src/main/java/... |
```

Keep emitting this table — it is the contract between the skills and the hub.
Repo names in the first column should be **registry aliases** (keys in
`repos.json`); `dx-discover-repos` skips rows it cannot match to the registry.

## Hub pipeline mode (replaces peer-to-peer delegation)

**When `DX_PIPELINE_MODE=true`** (ADO pipeline environments):

Cross-repo fan-out is handled centrally by the KAI-HUB router pipeline
(`dx-automation/data/pipelines/cli/ado-cli-hub.yml`), not by each worker queuing
the next. The flow is:

1. A `@kai-<agent>` comment fires the **hub** (one Service Hook → one Incoming
   WebHook connection).
2. The hub runs `dx-discover-repos` (in `dx-hub`) to resolve the touched repos
   from the registries + the `## Cross-Repo Scope` table.
3. The hub queues the agent's single worker pipeline once per resolved repo,
   passing `targetRepo`. Each worker clones that repo dynamically and fixes only it.

Workers are **dual-mode**: a single-repo project skips the hub entirely and fires
its worker directly via the worker's own `resources.webhooks`. See
`dx-hub/shared/registry-format.md` for the registry shapes and
`dx-hub/skills/dx-discover-repos/SKILL.md` for the discovery cascade.

There is no `delegate.json`, no `CROSS_REPO_PIPELINE_MAP`, and no
`SOURCE_REPO_NAME` comparison anymore — those were the peer-to-peer mechanism the
hub replaces.

## Local Mode: Manual Handoff (unchanged)

**When `DX_PIPELINE_MODE` is NOT set** (local developer usage):

1. Cross-repo scope appears in the final summary (current behavior)
2. The agent prints: `Run /dx-bug-all <id> in <other-repo>`
3. The developer manually switches to the other repo and runs the command

No pipeline is queued. The developer controls the workflow.

## Hub Mode: Multi-Repo Dispatch (local, interactive)

**When `hub.enabled: true` AND cwd is a `.hub/` directory** (local hub
orchestration — distinct from the automation KAI-HUB pipeline):

Hub mode replaces the manual handoff with a dedicated dispatch skill that opens
independent Claude sessions in VS Code terminals — one per repo. Read
`dx-hub/shared/hub-dispatch.md` for that protocol.

### Priority Order

```
1. Pipeline mode (DX_PIPELINE_MODE=true) — central KAI-HUB router fans out
2. Local hub mode (hub.enabled + .hub/ cwd) — /dx-hub-dispatch terminal sessions
3. Local mode (default) — manual handoff message
```

## Environment Variables

| Variable | Set by | Purpose |
|----------|--------|---------|
| `DX_PIPELINE_MODE` | Pipeline YAML | Marks an ADO pipeline run (workers run in pipeline mode) |
| `HUB_ENABLED` | `.ai/config.yaml` | Local hub mode flag (derived from `hub.enabled`) |
| `HUB_STATE_DIR` | `.ai/config.yaml` | Local hub state directory (derived from `hub.state-dir`) |
