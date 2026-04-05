# Edge Schema for Graph Relationships

Edges capture relationships between graph nodes (decisions, patterns, findings, attestations) and spec artifacts (requirements, research, implementation steps). They live in `.ai/graph/edges/` as per-ticket YAML files.

## Schema

```yaml
# .ai/graph/edges/<ticket>.yaml
ticket: "<ticket-id>"
updated: <ISO-8601>
edges:
  - from: "<source-node-or-artifact-id>"
    to: "<target-node-or-artifact-id>"
    type: <edge-type>
    created: <ISO-8601>
    agent: <producing-agent>
```

## Edge Types

| Type | Meaning | Example |
|------|---------|---------|
| `informed` | Source informed a decision or plan | requirement → decision |
| `implemented-as` | Decision was implemented in a step | decision → step |
| `verified-by` | Node was verified by a review or check | decision → attestation |
| `supersedes` | New node replaces an old one | decision-v2 → decision-v1 |
| `reuses` | Implementation reuses an existing pattern | step → pattern |

## ID Conventions

Nodes and artifacts are referenced by string IDs. Use these conventions:

| Type | ID Format | Example |
|------|-----------|---------|
| Decision node | `decision-<ticket>-<slug>` | `decision-1234-jwt-over-sessions` |
| Pattern node | `pattern-<topic>` | `pattern-jwt-auth-middleware` |
| Requirement | `requirement-<ticket>-raw` | `requirement-1234-raw` |
| Research | `research-<ticket>` | `research-1234` |
| Explanation | `explain-<ticket>` | `explain-1234` |
| Implementation step | `step-<ticket>-<N>` | `step-1234-3` |
| Attestation | `attestation-<ticket>-verify` | `attestation-1234-verify` |

These IDs don't need to correspond to actual files — they're logical references for graph traversal. Decision and pattern IDs match the `id` field in their respective YAML nodes.

## Field Rules

1. **ticket** — The work item ID. One edge file per ticket.
2. **updated** — ISO-8601 timestamp of the last modification to this file.
3. **edges** — Array of edge entries. Each edge has:
   - **from** — Source node/artifact ID
   - **to** — Target node/artifact ID
   - **type** — One of the edge types above
   - **created** — When this edge was established
   - **agent** — Which agent/skill created this edge

## Producer Rules

Multiple skills write to the same edge file (append, don't overwrite):

| Producer | When | Edges Written |
|----------|------|---------------|
| `dx-plan` | After writing decision nodes | `requirement → decision` (informed), `research → decision` (informed), `decision → step` (implemented-as), `step → pattern` (reuses, if pattern referenced) |
| `dx-step-verify` | On PASS verdict | `attestation → decision` (verified-by) for each active decision |

### Writing protocol

1. Read existing `.ai/graph/edges/<ticket>.yaml` if it exists
2. Append new edges — do NOT remove existing edges from other producers
3. Deduplicate: if an edge with the same `from`, `to`, and `type` already exists, skip it
4. Update the `updated` timestamp

```bash
mkdir -p .ai/graph/edges
```

## Consumer Rules

Skills that read edges should:
1. Use `find .ai/graph/edges/ -name "*.yaml"` to discover edge files
2. Filter by ticket ID if working on a specific ticket
3. Traverse edges by following `from`/`to` references to node files in `.ai/graph/nodes/`
4. Handle missing edge files gracefully — edges are optional enrichment, not required for any skill to function

## Query Patterns

No database needed — grep and standard tools are sufficient at project scale:

```bash
# Find all edges for a ticket
cat .ai/graph/edges/1234.yaml

# Find all verified-by edges across tickets
grep -rl "type: verified-by" .ai/graph/edges/

# Find which decisions a requirement informed
grep -A2 "from: requirement-1234" .ai/graph/edges/1234.yaml

# Find all edges from a specific decision
grep -A2 "from: decision-1234-jwt" .ai/graph/edges/1234.yaml
```

## Example

```yaml
ticket: "2416553"
updated: 2026-04-05T15:00:00Z
edges:
  - from: requirement-2416553-raw
    to: decision-2416553-extend-layout-dropdown
    type: informed
    created: 2026-04-05T14:30:00Z
    agent: dx-plan

  - from: research-2416553
    to: decision-2416553-extend-layout-dropdown
    type: informed
    created: 2026-04-05T14:30:00Z
    agent: dx-plan

  - from: decision-2416553-extend-layout-dropdown
    to: step-2416553-1
    type: implemented-as
    created: 2026-04-05T14:30:00Z
    agent: dx-plan

  - from: decision-2416553-extend-layout-dropdown
    to: step-2416553-2
    type: implemented-as
    created: 2026-04-05T14:30:00Z
    agent: dx-plan

  - from: step-2416553-1
    to: pattern-dialog-dropdown-extension
    type: reuses
    created: 2026-04-05T14:30:00Z
    agent: dx-plan

  - from: attestation-2416553-verify
    to: decision-2416553-extend-layout-dropdown
    type: verified-by
    created: 2026-04-05T16:00:00Z
    agent: dx-step-verify
```
