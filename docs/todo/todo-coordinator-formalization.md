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
