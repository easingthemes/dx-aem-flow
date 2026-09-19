# TODO: Coordinator Agent Formalization

## Coordinator Agent Formalization

**Added:** 2026-03-28
**Problem:** Delegation between coordinators, skills, and agents is implicit — buried in skill body text as `Skill()` and `Agent()` calls. There's no machine-readable way to discover "what calls what", generate dependency graphs, or validate that referenced skills/agents exist. Inspired by Paperclip/companies.sh hierarchical agent model.
**Scope:** 12 skill files (coordinators + inline-agent dispatchers), 12 agent files, 3 validation scripts, 1 new graph generator, 2 doc files.
**Done-when:** `grep -r "delegates-to-skills" plugins/dx-core/skills/dx-agent-all/SKILL.md` returns a match AND `bash scripts/generate-coordination-graph.sh` produces valid DOT output AND `bash scripts/validate-structure.sh` passes with new cross-reference checks.

### New Frontmatter Fields

Flat, bash-friendly format (no nested YAML):

```yaml
# On coordinator skills:
delegates-to-skills: [dx-step, dx-step-fix]
delegates-to-agents: [dx-code-reviewer]

# On worker agents:
reports-to-skills: [dx-step-verify]
```

Design decisions:
- Flat fields match existing bash `grep "^field:"` validators
- `agent:` frontmatter stays as the runtime fork mechanism — new fields are metadata-only
- All fields optional — fully backward compatible
- Graph generator treats `agent:` as implicit `delegates-to-agents` entry

### Delegation Map

```
dx-agent-all (top orchestrator)
├── dx-req → dx-ticket-analyze → [dx-doc-searcher, aem-file-resolver, aem-page-finder]
├── dx-figma-all → dx-figma-extract, dx-figma-prototype → [dx-figma-styles, dx-figma-markup]
├── dx-plan
├── dx-step-all → dx-step, dx-step-fix
├── dx-step-build
├── dx-step-verify → [dx-code-reviewer]
├── dx-pr-commit
└── aem-doc-gen → (agent: aem-editorial-guide-capture)

dx-bug-all (bug orchestrator)
├── dx-bug-triage
├── dx-bug-verify → [aem-bug-executor]
└── dx-bug-fix → dx-step, dx-step-build, dx-pr-commit

dx-hub-dispatch (multi-repo orchestrator)
└── dx-agent-all (dispatched to VS Code terminals)
```

### Phase 1: Add frontmatter metadata (24 files)

#### Skills — `delegates-to-skills` (7 files)

| File | `delegates-to-skills` |
|------|----------------------|
| `plugins/dx-core/skills/dx-agent-all/SKILL.md` | `[dx-req, dx-ticket-analyze, dx-figma-all, dx-plan, dx-plan-validate, dx-plan-resolve, dx-step-all, dx-step-build, dx-step-verify, dx-step-fix, dx-pr-commit, dx-doc-gen, aem-doc-gen]` |
| `plugins/dx-core/skills/dx-step-all/SKILL.md` | `[dx-step, dx-step-fix]` |
| `plugins/dx-core/skills/dx-bug-all/SKILL.md` | `[dx-bug-triage, dx-bug-verify, dx-bug-fix]` |
| `plugins/dx-core/skills/dx-figma-all/SKILL.md` | `[dx-figma-extract, dx-figma-prototype, dx-figma-verify]` |
| `plugins/dx-core/skills/dx-pr-answer/SKILL.md` | `[dx-pr-commit]` |
| `plugins/dx-core/skills/dx-bug-fix/SKILL.md` | `[dx-step, dx-step-build, dx-pr-commit]` |
| `plugins/dx-hub/skills/dx-hub-dispatch/SKILL.md` | `[dx-agent-all]` |

#### Skills — `delegates-to-agents` (5 files)

| File | `delegates-to-agents` |
|------|----------------------|
| `plugins/dx-core/skills/dx-ticket-analyze/SKILL.md` | `[dx-doc-searcher, aem-file-resolver, aem-page-finder]` |
| `plugins/dx-core/skills/dx-figma-prototype/SKILL.md` | `[dx-figma-styles, dx-figma-markup]` |
| `plugins/dx-core/skills/dx-step-verify/SKILL.md` | `[dx-code-reviewer]` |
| `plugins/dx-aem/skills/aem-component/SKILL.md` | `[aem-file-resolver, aem-page-finder]` |
| `plugins/dx-core/skills/dx-bug-verify/SKILL.md` | `[aem-bug-executor]` |

Note: 6 skills already have `agent:` frontmatter (aem-snapshot, aem-verify, aem-qa-handoff, aem-doc-gen, aem-editorial-guide, aem-fe-verify) — no changes needed, graph generator treats `agent:` as implicit delegation.

#### Agents — `reports-to-skills` (12 files)

| File | `reports-to-skills` |
|------|---------------------|
| `plugins/dx-core/agents/dx-code-reviewer.md` | `[dx-step-verify]` |
| `plugins/dx-core/agents/dx-doc-searcher.md` | `[dx-ticket-analyze, dx-help]` |
| `plugins/dx-core/agents/dx-file-resolver.md` | `[dx-ticket-analyze]` |
| `plugins/dx-core/agents/dx-figma-styles.md` | `[dx-figma-prototype]` |
| `plugins/dx-core/agents/dx-figma-markup.md` | `[dx-figma-prototype]` |
| `plugins/dx-core/agents/dx-pr-reviewer.md` | `[dx-pr-review, dx-pr-review-all]` |
| `plugins/dx-aem/agents/aem-bug-executor.md` | `[dx-bug-verify]` |
| `plugins/dx-aem/agents/aem-inspector.md` | `[aem-snapshot, aem-verify, aem-qa-handoff]` |
| `plugins/dx-aem/agents/aem-fe-verifier.md` | `[aem-fe-verify]` |
| `plugins/dx-aem/agents/aem-editorial-guide-capture.md` | `[aem-editorial-guide, aem-doc-gen]` |
| `plugins/dx-aem/agents/aem-file-resolver.md` | `[dx-ticket-analyze, aem-component]` |
| `plugins/dx-aem/agents/aem-page-finder.md` | `[aem-component, aem-page-search]` |

### Phase 2: Validation (3 files)

Extend `scripts/validate-structure.sh` with:
1. **`delegates-to-skills` resolution** — verify every referenced skill exists under `plugins/*/skills/`
2. **`delegates-to-agents` resolution** — verify every referenced agent `name:` exists under `plugins/*/agents/`
3. **`reports-to-skills` cross-check** — if agent A says `reports-to-skills: [S]`, then skill S should have either `agent: A` or `delegates-to-agents: [... A ...]`
4. **Cycle detection** — walk `delegates-to-skills` graph, ensure no cycles

Minor updates to `scripts/validate-skills.sh` and `scripts/validate-agents.sh` to accept new fields without erroring.

### Phase 3: Graph generation (1 new file)

Create `scripts/generate-coordination-graph.sh`:
1. Scan all `plugins/*/skills/*/SKILL.md` for `delegates-to-*` and `agent:` fields
2. Scan all `plugins/*/agents/*.md` for `reports-to-skills`
3. Output DOT format graph (pipe to `dot -Tpng` for visualization)
4. Node shapes: coordinators (diamond), skills (box), agents (ellipse)
5. Edge labels: "Skill()" for skill-to-skill, "agent:" for fork, "Task" for inline dispatch

### Phase 4: Documentation (2 files)

1. Update `docs/reference/agent-catalog.md` — add `reports-to-skills` in each agent's properties
2. Update `docs/reference/skill-catalog.md` — reference `scripts/generate-coordination-graph.sh` as authoritative graph source

### Risks & Mitigations

- **Metadata drift**: Someone adds a `Skill()` call but forgets `delegates-to-skills`. Mitigation: validation script greps for `Skill(/` patterns in body and warns if skill not declared.
- **YAML parsing in bash**: Flat format (`delegates-to-skills:` not nested) avoids this entirely.

---

## Spec-artifact contract + conformance validator

**Added:** 2026-09-19
**Problem:** The spec-directory convention ("skills find each other's output by
convention — no data passing needed", CLAUDE.md § Spec Directory Convention) is an
*implicit* interface with no schema and no validator. It holds because a human notices
when `research.md` is empty or `explain.md` belongs to another ticket. Unattended, nothing
does. The sharpest case: `plugins/dx-core/data/lib/plan-metadata.sh` parses step state out
of `implement.md` with text matching, so **the Markdown heading format of `implement.md`
is a load-bearing interface between `dx-plan` and every coordinator** — and it is
unversioned, unvalidated and untested against a malformed input. A skill that changes its
heading style makes `plan-metadata.sh` report `Steps: 0 total, 0 pending`, which a
coordinator reads as "nothing left to do" and reports as success. A silent wrong-success is
strictly worse than a crash, and none of the five `validate-*.sh` can see it: they check
frontmatter, manifests and counts, never artifact shape.
**Scope:** `docs/reference/spec-artifacts.md` (new — the per-file contract: required
headings, required front sections, ticket-id stamp); `plugins/dx-core/data/lib/` (new
`validate-spec-artifact.sh` + a `*.test.sh` suite with malformed fixtures, per the
hermetic rules in CLAUDE.md § Testing Changes); consumers that must call it before reading
an upstream artifact — `plan-metadata.sh`, `dx-step-all`, `dx-agent-all`, `dx-bug-all`,
and the `ado-cli-*.yml` pipelines that chain phases. `docs/reference/skill-catalog.md`
already lists each skill's Output column — that column becomes the contract's index.
**Done-when:** `bash plugins/dx-core/data/lib/validate-spec-artifact.sh <spec-dir> implement.md`
exits non-zero on (a) a missing file, (b) a file whose ticket-id stamp does not match the
directory, and (c) an `implement.md` with zero parseable steps; the accompanying
`*.test.sh` covers all three with fixtures and is picked up by CI discovery; and
`plan-metadata.sh` returns non-zero instead of `Steps: 0 total` when the parse finds
nothing.
**Approach:** Do not introduce YAML front-matter into the spec artifacts — that breaks
every existing `.ai/specs/` directory. Add a single stamped first line (ticket id +
artifact kind + format version) and validate that plus the structural minimum each
consumer actually depends on. Start with `implement.md`, because it is the only artifact
currently parsed by a script rather than read by a model; extend to `explain.md` and
`research.md` only if a real consumer parses them.
