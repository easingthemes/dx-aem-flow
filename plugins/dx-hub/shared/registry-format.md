# KAI-Hub Registries

Reference for the two registries the KAI-Hub automation model is built on. They
are the single source of truth for **which repos exist** and **which agents have
a worker pipeline**. Both live in the central AI/automation repo at:

```
.ai/automation/registries/repos.json
.ai/automation/registries/agents.json
```

Schemas + anonymized examples ship in this plugin at
`plugins/dx-hub/data/registries/` (`*.schema.json`, `*.example.json`).

> **Not the same "hub" as `hub-dispatch.md`.** That document describes the
> *local* VS Code-terminal hub for interactive multi-repo dev. These registries
> drive the *automation* KAI-HUB router pipeline (`ado-cli-hub.yml`) that fans
> work out to dynamic-checkout worker pipelines. Different mechanism, shared word.

---

## repos.json — keyed by repo alias

```json
{
  "brand-one": {
    "repoId": "<ado-repo-guid>",
    "adoProject": "Example Project",
    "cloneUrl": "https://dev.azure.com/example-org/Example%20Project/_git/brand-one-frontend",
    "defaultBranch": "development",
    "stack": "node",
    "platform": "global",
    "brand": "brand-one",
    "role": "frontend"
  }
}
```

| Field | Required | Consumed by | Notes |
|-------|----------|-------------|-------|
| `repoId` | yes | (Part B / tooling) | ADO repository GUID |
| `adoProject` | yes | hub queue step | put in the per-repo queue URL so cross-project fan-out works |
| `cloneUrl` | yes | worker clone step | PAT injected at clone time |
| `defaultBranch` | yes | worker clone step | branch to clone + base work on |
| `stack` | no | pre-warm | hint only; pre-warm auto-detects |
| `platform` | no | route-targets.sh | omit on single-platform projects |
| `brand` | no | route-targets.sh | omit on backend/config repos |
| `role` | yes | route-targets.sh | `frontend` \| `backend` \| `fullstack` \| `config` |

`platform`, `brand`, `role` mirror the `repos:` block that `route-targets.sh`
reads via `repos_table`. Because `route-targets.sh` parses a `config.yaml`-shaped
`repos:` block (not JSON), the `dx-discover-repos` tier-1 step **synthesizes a
temporary `repos:` YAML block from `repos.json`** and passes it as `CONFIG_FILE`.
`repos.json` stays the single source of truth; route-targets is unchanged.

## agents.json — keyed by agent tag

```json
{
  "simple": { "workerPipelineId": "<id>", "event": "workitem.commented", "writes": true },
  "dor":    { "workerPipelineId": "<id>", "event": "workitem.commented", "writes": false }
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `workerPipelineId` | yes | ADO pipeline id of this agent's dynamic-checkout worker. **One per agent**, not one per repo — the hub fans the same pipeline out per resolved repo alias. |
| `event` | yes | service-hook event the hub listens for (`workitem.commented`) |
| `writes` | yes | `true` = pushes code / authors content (needs a writable target clone); `false` = read-only (analyzes + comments only) |

The agent tag is the `@kai-<tag>` trigger token (e.g. `@kai-simple`,
`@kai-bugfix`). The hub parses the tag from the comment, looks up
`workerPipelineId` + `writes`, then queues that one worker once per repo alias
returned by `dx-discover-repos`.

---

## Single-repo projects

These registries are **only read in hub mode**. A single-repo project keeps
firing its worker directly via the worker's own `resources.webhooks` (the worker
is dual-mode), so it never needs `repos.json` or `agents.json`. See the worker
pipelines' "Resolve mode" step: with no `targetRepo` param, `TARGET_DIR`
defaults to `$(Build.SourcesDirectory)` and the registries are never touched.
