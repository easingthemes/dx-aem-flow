# Context Graphs for Multi-Agent Workflows

Research into shared, structured context graphs that agents can reason over together — moving beyond bigger memory toward compounding, verifiable knowledge.

**Added:** 2026-04-05

---

## Executive Summary

The emerging consensus across AI research (Karpathy), venture capital (Foundation Capital), and decentralized infrastructure (OriginTrail) is that **agents need shared, structured context they can reason over together** — not just bigger context windows or better RAG. The dx-aem-flow plugins already have a proto-context-graph in the `.ai/specs/` convention and `config.yaml`. This research maps the gap between our current file-based knowledge sharing and a true context graph with decision lineage, trust layers, and cross-session compounding.

**Why this matters for dx-aem-flow:** Our automation agents (Lambda-triggered pipelines) run stateless. Our interactive agents share context through spec files by convention. Neither approach captures *why* decisions were made, *which agent's findings to trust more*, or *how knowledge from ticket A informs ticket B*. A context graph would solve all three.

---

## External Research

### 1. Karpathy — Personal Knowledge Bases That Compound

Andrej Karpathy's "LLM OS" framing (2023-2025) describes LLMs as an operating system kernel where surrounding infrastructure (retrieval, tools, memory) forms the peripherals. The key insight for our domain:

- **Knowledge should be structured and retrievable**, not just embedded in model weights or dumped as text chunks
- **Personal/project context is a moat** — the more an LLM knows about your specific codebase, conventions, and history, the more useful it becomes
- **Naive RAG is insufficient** for true knowledge compounding — you need something closer to a knowledge graph where relationships between concepts are preserved
- **The gap** between "what the model knows" and "what it needs to know about my project" is the core problem to solve

**dx-aem-flow mapping:** Our `config.yaml` + `rules/` + `specs/` convention is an early form of this compounding pattern. The `.ai/learning/` directory (fixes.jsonl, bugs.jsonl, promoted patterns in `.claude/rules/learned-fix-*.md`) is the beginning of knowledge that compounds across sessions. But it's flat — no relationships, no provenance, no cross-ticket learning.

### 2. Foundation Capital — Context Graphs as Decision Lineage

Foundation Capital's thesis: whoever builds the canonical context graph for enterprises captures a position analogous to what Salesforce did for customer relationships or GitHub did for code. The context graph becomes the system of record for **organizational knowledge and decision provenance**.

**Core architectural ideas:**
- **Decision lineage:** Every decision node links to its inputs (data, prior decisions, stakeholder opinions), its rationale, and its outcomes
- **Compounding value:** Unlike documents, a context graph gets more valuable as connections densify
- **Agent-native:** AI agents need structured context to operate autonomously — a context graph is the "memory layer" that makes agents reliable rather than hallucination-prone
- **Cross-system integration:** The graph sits above individual tools (Jira, Slack, Figma, code repos), connecting context across them

**dx-aem-flow mapping:** Our spec directory chain (`raw-story.md` → `explain.md` → `research.md` → `implement.md`) is a linear decision chain. A context graph would capture branching decisions (why approach A over B), cross-ticket relationships (ticket 1234's auth pattern reused in ticket 5678), and reviewer feedback loops.

### 3. OriginTrail DKG — Verifiable Knowledge Sub-Graphs

OriginTrail's Decentralized Knowledge Graph demonstrates how multiple autonomous agents can share a knowledge layer with built-in verification:

**Technical primitives:**
- **Knowledge Assets (KAs):** Structured semantic data (RDF/JSON-LD), identified by a unique UAL, anchored on-chain with a cryptographic hash, owned by a wallet address, versioned
- **Sub-graphs:** Logical groupings of related knowledge — agents publish to and query specific sub-graphs for their domain
- **Publishing:** Agent creates structured knowledge → publishes to DKG → network replicates → blockchain anchors the hash
- **Querying:** SPARQL queries with provenance metadata (who published, when, verification status)
- **Verification:** On-chain hash anchoring (tamper detection), provenance chains, token-staking incentives for honest behavior

**dx-aem-flow mapping:** We don't need blockchain or tokens, but the primitives map cleanly:
- **Knowledge Asset** → agent output file (spec, review, plan) with structured metadata
- **Sub-graph** → per-ticket spec directory or per-project knowledge namespace
- **Verification** → agent attestation ("dx-step-verify passed with score 4/5")
- **Ownership** → agent identity ("produced by dx-code-reviewer on Opus")

### 4. Trust Layers — Filtering by Provenance

Tiered memory with trust/provenance filtering is the key architectural pattern:

| Tier | Scope | Lifetime | Trust Level | dx-aem-flow Equivalent |
|------|-------|----------|-------------|----------------------|
| **Working** | Single agent, single task | Session | Unverified | Agent's conversation context |
| **Shared** | Multi-agent, single workflow | Workflow | Peer-attested | `.ai/specs/<id>/` files |
| **Long-term** | Organization-wide | Persistent | Review-gated | `.ai/learning/`, `.ai/patterns/` |
| **Verified** | Cross-project | Permanent | Cryptographically verified | `.claude/rules/learned-fix-*.md` (promoted) |

**Provenance metadata per memory entry:**
- **Who** created it (agent identity + model tier)
- **When** (timestamp)
- **How** (what tools/methods were used)
- **Confidence** (self-reported by creating agent)
- **Verification status** (has another agent confirmed this?)
- **Lineage** (what prior knowledge informed this?)

**dx-aem-flow mapping:** Our model tier strategy (Opus for deep reasoning, Haiku for lookups) already implies different trust levels. A finding from `dx-code-reviewer` (Opus, `memory: project`) should be weighted differently than a `dx-file-resolver` (Haiku) lookup. Making this explicit would enable smarter retrieval.

### 5. Context Graphs vs RAG — Why Structure Matters

| Dimension | RAG (our current approach) | Context Graph (target) |
|-----------|--------------------------|----------------------|
| **Knowledge structure** | Flat files in `specs/` | Typed nodes + edges |
| **Retrieval** | Grep by convention | Graph traversal + optional similarity |
| **Relationships** | Implicit (file naming) | Explicit (edges with types) |
| **Provenance** | None | First-class (who, when, why, confidence) |
| **Multi-agent sharing** | Shared filesystem | Shared graph with per-agent views |
| **Conflict resolution** | Last-write-wins | Explicit: edges represent disagreement |
| **Temporal reasoning** | File timestamps only | Native (edges carry time + causality) |
| **Decision lineage** | Not captured | Core feature |
| **Cross-ticket learning** | Manual | Graph traversal finds similar patterns |

**The practical difference:** A reviewer agent queries for "authentication patterns." With RAG, it gets 5 text chunks. With a context graph, it sees: the planner considered approaches A, B, and C; approach A was chosen for performance; the security policy was updated after the decision; the QA agent already verified the implementation. Full context for a meaningful review.

---

## Current State in dx-aem-flow

### What We Already Have (Proto-Context-Graph)

Our plugins already implement early forms of structured context sharing:

1. **Spec directory convention** — `.ai/specs/<id>-<slug>/` with predictable filenames is a proto-context-graph stored as files. Skills discover each other's output by convention.

2. **Config-driven runtime** — `config.yaml` is a shared knowledge node that all skills read, avoiding hardcoded values.

3. **Three-layer override system** — `.ai/rules/ > config.yaml overrides > plugin defaults` is a precedence graph for configuration knowledge.

4. **Subagent return envelope** — `shared/subagent-contract.md` defines a structured protocol for agents to report Status, Summary, Files, Next, Error — a lightweight provenance format.

5. **Learning directory** — `.ai/learning/raw/runs.jsonl`, `fixes.jsonl`, `bugs.jsonl` accumulate knowledge across sessions. Promoted patterns become `.claude/rules/learned-fix-*.md`.

6. **Coordinator pattern** — `disable-model-invocation: true` coordinators dispatch subagents that communicate through spec files, not shared context. File I/O between steps = edges in a context graph.

7. **Memory frontmatter** — `dx-code-reviewer` and `dx-pr-reviewer` declare `memory: project`, enabling cross-session knowledge accumulation.

### What's Missing (Gaps)

1. **No decision lineage** — We capture *what* was decided (implement.md) but not *why* or *what alternatives were rejected*. When a reviewer questions a design choice, the rationale is lost.

2. **No provenance metadata** — Spec files don't record which agent produced them, at what model tier, or with what confidence. A Haiku-generated analysis looks identical to an Opus-generated one.

3. **No cross-ticket knowledge** — Each ticket's spec directory is isolated. Knowledge from ticket A (e.g., "this API requires auth header X") doesn't inform ticket B's planning.

4. **No trust filtering** — All agent outputs are treated equally. A `dx-step-verify` PASS (Opus, 6-phase gate) and a `dx-file-resolver` file listing (Haiku) have the same weight in downstream decisions.

5. **No temporal reasoning** — File timestamps are the only ordering. There's no way to ask "what changed since the last review?" or "was this decision made before or after the security policy update?"

6. **No conflict representation** — When agents disagree (reviewer says "use pattern A," implementer used pattern B), there's no structured way to capture the disagreement for resolution.

### Related In-Flight Work

Several existing TODOs converge on context graph primitives:

| TODO | Relevance to Context Graphs |
|------|---------------------------|
| **#52** Continuous learning / instinct system | Long-term memory tier with confidence scores |
| **#54** Autonomous loop state persistence | Working memory → shared memory promotion |
| **#63** Structured progress file for cross-session handoff | Handoff artifact = context snapshot |
| **#64** Automation agent startup protocol | Context graph query at session start |
| **#51** Coordinator agent formalization | Graph edges between coordinators and delegates |
| Ruflo: Cross-session pattern memory | `.ai/patterns/` = long-term knowledge tier |
| Ruflo: Concurrent agent work-ownership | Lock files = ownership edges in a graph |
| Harness: verify-feedback.md | Feedback loop = bidirectional graph edge |

---

## Proposed Architecture: `.ai/graph/`

A lightweight, file-based context graph that builds on existing conventions rather than introducing a database or external service.

### Design Principles

1. **Files, not databases** — Agents already read/write files. The graph is stored as structured files that can be grepped, diffed, and committed to git.
2. **Incremental adoption** — Existing skills continue working unchanged. Graph features are additive.
3. **Provenance by default** — Every graph node carries metadata about who created it, when, and with what confidence.
4. **Trust tiers are explicit** — Agent outputs are tagged with trust level based on agent identity and verification status.

### Proposed Directory Structure

```
.ai/graph/
├── nodes/                          # Knowledge nodes (one file per node)
│   ├── decisions/                  # Planning decisions with rationale
│   │   └── <ticket>-<slug>.yaml   # Why approach X was chosen
│   ├── patterns/                   # Reusable patterns discovered
│   │   └── <topic>.yaml           # Pattern with provenance
│   ├── findings/                   # Agent findings (reviews, inspections)
│   │   └── <ticket>-<agent>.yaml  # Finding with trust metadata
│   └── attestations/              # Verification records
│       └── <ticket>-<phase>.yaml  # Pass/fail with evidence
├── edges/                          # Relationships between nodes
│   └── <ticket>.yaml              # All edges for a ticket
└── index.yaml                     # Graph-wide index for fast lookup
```

### Node Schema (YAML)

```yaml
# .ai/graph/nodes/decisions/1234-auth-pattern.yaml
id: decision-1234-auth-pattern
type: decision
ticket: "1234"
title: "Use JWT middleware over session cookies"
created: "2026-04-05T14:30:00Z"
agent: dx-plan
model: opus
confidence: 0.9
trust_tier: shared          # working | shared | long-term | verified
status: active              # active | superseded | rejected
content: |
  Chose JWT middleware over session cookies for the auth layer.
  Reasons: stateless scaling, microservice compatibility, existing
  JWT library in project dependencies.
alternatives:
  - name: "Session cookies"
    reason_rejected: "Requires sticky sessions, incompatible with CDN caching"
  - name: "OAuth2 + PKCE"
    reason_rejected: "Over-engineered for internal service; no external IdP needed"
lineage:
  - "requirement-1234-raw"     # Link to raw story
  - "research-1234-auth"       # Link to research output
verified_by: []                # Populated when dx-step-verify confirms
```

### Edge Schema (YAML)

```yaml
# .ai/graph/edges/1234.yaml
ticket: "1234"
edges:
  - from: requirement-1234-raw
    to: decision-1234-auth-pattern
    type: informed              # informed | blocked-by | supersedes | verified-by | reuses
    created: "2026-04-05T14:30:00Z"

  - from: decision-1234-auth-pattern
    to: implementation-1234-step3
    type: implemented-as

  - from: review-1234-pr-security
    to: decision-1234-auth-pattern
    type: verified-by
    confidence: 0.95
    agent: dx-code-reviewer
    model: opus
```

### Trust Tier Promotion Rules

```
working (ephemeral, single session)
  ↓ when persisted to spec file
shared (multi-agent, single ticket)
  ↓ when verified by dx-step-verify or dx-code-reviewer
long-term (cross-ticket, within project)
  ↓ when pattern appears in 3+ tickets OR manually promoted
verified (cross-project, permanent)
  → written to .claude/rules/learned-*.md
```

### Query Patterns (Shell-Based)

No database needed — grep and yq are sufficient at project scale:

```bash
# Find all decisions for a ticket
grep -rl "ticket: \"1234\"" .ai/graph/nodes/decisions/

# Find all verified findings
grep -rl "trust_tier: verified" .ai/graph/nodes/

# Find patterns used across tickets
grep -rl "type: reuses" .ai/graph/edges/

# Find all nodes created by a specific agent
grep -rl "agent: dx-code-reviewer" .ai/graph/nodes/

# Decision lineage for a ticket
yq '.edges[] | select(.type == "informed")' .ai/graph/edges/1234.yaml
```

### Integration with Existing Skills

The context graph augments — not replaces — existing spec directory convention:

| Skill | Current Behavior | + Context Graph |
|-------|-----------------|-----------------|
| `dx-plan` | Writes `implement.md` | Also writes decision nodes with alternatives |
| `dx-step-verify` | Writes pass/fail to implement.md status | Also writes attestation node + verified-by edges |
| `dx-pr-review` | Posts review comments | Also writes finding nodes with trust metadata |
| `dx-req` | Writes `explain.md`, `research.md` | Also writes requirement nodes with lineage |
| `dx-step-fix` | Reads verify feedback, applies fix | Also reads finding nodes for context |
| `dx-agent-all` | Orchestrates full flow | Reads graph index for cross-ticket patterns |

### Cross-Ticket Knowledge Flow

The highest-value capability a context graph enables:

```
Ticket 1234 (done):
  decision-1234-auth → pattern-jwt-middleware (promoted to long-term)

Ticket 5678 (new, similar):
  dx-plan reads .ai/graph/nodes/patterns/jwt-middleware.yaml
  → "This project has an established JWT auth pattern (from #1234, verified by reviewer)"
  → Plan references the existing pattern instead of re-inventing
```

This is the "compounding knowledge" that Karpathy describes — each ticket's learnings make the next ticket faster.

---

## Implementation Approach

### Phase 1 — Provenance Metadata (Low Effort, High Value) ✅ DONE

Add provenance headers to existing spec files. No new directory structure needed.

**Completed:** Provenance schema (`shared/provenance-schema.md`), 7 producer skills emit provenance frontmatter, `dx-step-verify` sets `verified: true` on PASS, `dx-step` preserves provenance on status updates.

### Phase 1b — Provenance Consumers (Low Effort, High Value) ✅ DONE

Close the feedback loop — skills that READ provenance metadata and act on it.

**Completed:**
- **dx-plan** reads `research.md`/`explain.md` provenance → warns on low confidence, notes Haiku-tier research, propagates lowest input confidence as ceiling for `implement.md`
- **dx-pr** reads `implement.md` provenance → hard gate on `verified: false` (blocks PR creation), soft warning on low confidence, enriches PR description with provenance section
- **dx-step-verify** reads upstream provenance → flags low-confidence inputs in pre-review output, passes confidence context to code review subagent for extra scrutiny
- `shared/provenance-schema.md` updated with full consumer documentation (Writers vs Readers sections)

### Phase 2 — Key Decisions in implement.md (Low Effort, High Value) ✅ DONE

`dx-plan` captures non-obvious design decisions with alternatives and rationale in a `## Key Decisions` section of `implement.md`.

### Phase 3 — Cross-Ticket Patterns (Medium Effort, Very High Value)

Extend `dx-plan` to record decision rationale in `.ai/graph/nodes/decisions/`.

**Scope:** New step in `dx-plan` that extracts key decisions and alternatives from the planning process into structured YAML.
**Done-when:** `ls .ai/graph/nodes/decisions/` shows decision files after running `/dx-plan`.

### Phase 3 — Cross-Ticket Patterns (Medium Effort, Very High Value)

Build the pattern promotion pipeline: findings that appear across 3+ tickets get promoted to `.ai/graph/nodes/patterns/` and referenced by `dx-plan`.

**Scope:** New skill `dx-pattern-extract` (Haiku tier) that scans recent spec directories for recurring decisions/patterns.
**Done-when:** `dx-plan` queries `.ai/graph/nodes/patterns/` and references relevant patterns in its output.

### Phase 4 — Decision Nodes as Structured YAML (Medium Effort, High Value)

Extract key decisions from `implement.md` into `.ai/graph/nodes/decisions/` as structured YAML with lineage edges. Currently decisions live inline in implement.md — this phase externalizes them for graph queries.

**Scope:** New step in `dx-plan` that writes decision YAML files alongside `implement.md`.
**Done-when:** `ls .ai/graph/nodes/decisions/` shows decision files after running `/dx-plan`.

### Phase 5 — Full Graph With Edges (Higher Effort, Transformative)

Complete edge schema, index, and graph-aware query patterns in coordinator skills.

**Scope:** `.ai/graph/edges/` directory, `index.yaml`, graph-traversal helpers in a shared script.
**Done-when:** `dx-agent-all` reads decision lineage from the graph when planning work on a ticket.

---

## Relationship to Existing TODOs

This research informs but does not replace existing TODO items:

- **#52 (Instinct system)** becomes the "long-term memory tier" in the context graph
- **#54 (Loop state persistence)** becomes "working → shared memory promotion"
- **#63 (Progress file)** becomes the "context snapshot" node type
- **Ruflo cross-session patterns** becomes the "patterns/" node directory
- **Harness verify-feedback.md** becomes a "finding" node with "verified-by" edges

The context graph is the unifying architecture that connects these separate improvements into a coherent system.

---

## Open Questions

1. **Git-committed or .gitignored?** Decision nodes are project knowledge (commit). Working memory is developer-specific (ignore). Where's the line?
2. **YAML vs JSON for nodes?** YAML is more readable; JSON is harder for models to corrupt (per harness design research). Recommendation: YAML for human-edited, JSON for machine-written.
3. **Index maintenance** — Should `index.yaml` be rebuilt on demand or maintained incrementally by skills?
4. **Multi-repo graphs (dx-hub)** — How do context graphs span repos in a dx-hub multi-repo setup? Shared graph in a hub repo?
5. **Graph pruning** — How do we prevent unbounded growth? Archival rules for completed tickets?

---

## Sources

- Karpathy, A. — "LLM OS" concept, talks and slides (2023-2025); "vibe coding" and personal tooling (2025)
- Foundation Capital — Context graphs as enterprise decision lineage thesis (2024-2025)
- OriginTrail — Decentralized Knowledge Graph (DKG) protocol documentation; Knowledge Assets, sub-graphs, verification architecture
- Anthropic — [Harness design for long-running apps](https://www.anthropic.com/engineering/harness-design-long-running-apps) (2026); [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- dx-aem-flow existing: `docs/todo/todo-ecc-ideas.md` (instinct system), `docs/todo/todo-ruflo-ideas.md` (cross-session patterns), `docs/todo/todo-harness-design.md` (progress files, feedback loops)
