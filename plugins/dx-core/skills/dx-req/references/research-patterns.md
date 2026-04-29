# Research Patterns — Detailed Rules

This file contains the detailed codebase research logic used by Phase 4 of `/dx-req`.

## Pre-Dispatch Reads (parallel)

Read these files simultaneously before spawning research agents:
- `$SPEC_DIR/dor-report.md` (if exists)
- `$SPEC_DIR/ticket-research.md` (if exists)
- `.ai/config.yaml` (for repo/scope context)

These reads are independent — execute all in one message with parallel Read calls.

## Check for Pre-Existing Research

Two sources of pre-discovered data accelerate subagent work. Check both.

### Source A: ticket-research.md (from `/dx-ticket-analyze`)

If `$SPEC_DIR/ticket-research.md` exists, read it and extract:

| Data | Where in ticket-research.md | Use |
|------|---------------------------|-----|
| Component names + platform | Heading patterns | Skip name-guessing in search target identification |
| Backend file paths | Backend tables | Agent 1 reads these directly instead of searching |
| Frontend file paths | Frontend tables | Agent 1 reads these directly |
| Exporter paths | Row containing "Exporter" in backend table | Agent 2 reads directly + Agent 3 starts here |
| Pages / URLs | Pages tables | Skip page searches, include in research.md |
| Market scope | Narrowing search line | Pass to agents for path filtering |
| Figma links | Design Assets section | Include in research.md Key Findings |
| Acceptance criteria | Acceptance Criteria section | Inform search targets |

**Strip URL wrappers to get local paths:** ticket-research.md may use clickable source links. Extract the file path from the URL to get the local file path.

### Source B: DoR Report (from Phase 2)

If `$SPEC_DIR/dor-report.md` exists, read the "Extracted BA Data" section and merge into `$CONTEXT`:

| DoR Data | Use |
|----------|-----|
| Component name + type (new/existing) | Skip component name-guessing, focus search |
| AEM Page URL | Skip AEM page search |
| Dialog fields table | Skip dialog inspection — fields already known |
| Figma URL with node-id | Skip Figma discovery |
| Brands / Markets | Scope market-specific searches |

Log each skipped discovery step in research.md: `ℹ Skipped <step> — BA provided via DoR report.`

### Source C: Project index files

If ticket-research.md and dor-report.md did NOT already provide file paths:

1. Extract component/feature names from `explain.md` (or `raw-story.md`)
2. If `.ai/project/component-index.md` (or `.ai/component-index.md`) exists, grep it for each name — get platform, location, source links
3. If `.ai/project/component-index-project.md` exists, grep it for each name — get enriched data: platform, FE column, source links, dialog fields, repo
4. Read `.ai/config.yaml` for relevant content paths or market scoping
5. If `.github/instructions/` (or `.ai/instructions/`) exists, read instruction files relevant to the component types — these provide framework-specific patterns, field references, and search hints

### Build $CONTEXT

Combine findings into `$CONTEXT` to pass to each subagent:

```
Components: [{name, platform, backend_paths[], frontend_paths[], exporter_path}]
Market: {brand, country, paths[]}
Known_Pages: [{path, url}]
Figma: [urls]
```

If no pre-existing data is found, set `$CONTEXT` with project-level info only — subagents use broader codebase search.

## Adaptive Research Scope

Phase 4 used to dispatch 4 broad parallel agents unconditionally. Measured runs showed ~557k tokens of agent output landing back in the parent thread before planning even started (issue #136). To keep Phase 1 fitting in a 200k context window, the orchestrator now picks a profile *before* dispatching:

| Profile | Agents dispatched | When to use |
|---------|------------------|-------------|
| `minimal` | Agent 1 (UI) + Agent 4 (Tests) | Markup-only / copy / config / single-property tweaks. Default for stories tagged `change-type: copy` or scope `Small` in share-plan.md. |
| `frontend` | Agents 1, 2, 4 | FE-only changes (no service or exporter work). Skip Agent 3. |
| `backend` | Agents 2, 3, 4 | API/service-only changes (no UI). Skip Agent 1's frontend slice. |
| `full` | All 4 | Default for `Medium`/`Large` stories or anything touching backend + frontend. |

**How to decide:** read `share-plan.md` (if Phase 5 has been run for a previous re-run) or `explain.md` and pick the smallest profile that covers the requirements. Err on the side of `minimal` for stories with ≤3 numbered requirements and no API or model changes — adding a follow-up narrow agent later is cheaper than re-running the full quartet.

**Override via env var:** `DX_RESEARCH_PROFILE=full|frontend|backend|minimal` forces the profile (used by automation pipelines and the low-context mode in `docs/reference/low-context-mode.md`).

**Override via config:** `.ai/config.yaml` may set `research.profile: minimal|frontend|backend|full|auto` (default `auto`). `auto` follows the table above.

Print the chosen profile before dispatch: `Phase 4: research profile = <profile> (<reason>)`.

## 4 Parallel Explore Subagents

Spawn the Explore subagents picked by the profile above via the Agent tool, all running in parallel. Each agent receives the search targets, the explain.md content, and `$CONTEXT` (if available) for context.

**When `$CONTEXT` has file paths:** Agents 1 and 2 switch from **discovery mode** (grep/glob the codebase) to **analysis mode** (read known files, analyze their contents in depth). This is faster and produces richer findings.

### Per-Agent Output Budget (mandatory)

Every Explore-agent prompt MUST include this contract verbatim — it caps the tokens that flow back into the parent thread:

> **Output budget:** report findings in **≤800 words**. List **at most 10 files** with one-line annotations. Do not paste code blocks longer than 5 lines (link to `path:line` instead). Stop searching as soon as you have located the relevant code — exhaustive enumeration of the codebase is out of scope.

Concretely, append to each agent's prompt:

```
Output rules:
- ≤800 words total.
- ≤10 files in the inventory; one-line annotation each.
- No code snippets >5 lines; cite `path:line` instead.
- Early-exit: once you've found the files that answer the search targets, stop. Don't keep exploring "for completeness".
- If a search target is clearly irrelevant to this story's scope, skip it and say so in one line.
```

If an agent returns >1200 words anyway, the orchestrator must summarize the agent's report into ≤300 words *before* writing it into research.md. The raw report stays in the subagent context only.

### Agent 1: UI Layer (Templates, Views & Config)

**With $CONTEXT paths (analysis mode):**
Read the known files directly — templates, view definitions, config/dialog files, and any frontend templates. Focus on **deep analysis**: field types/options, template bindings, show/hide patterns, data structures. Also search for **related files** near the known paths (sibling files, shared configurations).

**Without $CONTEXT (discovery mode):**
Search the project for:
- Template files matching component/feature names
- View/dialog/config definitions for the component
- Frontend component files (JS/TS, CSS/SCSS)
- Component metadata or registration files

Report: file paths, field/property names and types, template bindings, resource type values.

### Agent 2: Models & Data Layer

**With $CONTEXT paths (analysis mode):**
Read the known model/entity files directly. Focus on **deep analysis**: injected properties, initialization logic, service dependencies, child/nested mappings, serialization patterns.

**Without $CONTEXT (discovery mode):**
Search the project's source directories for:
- Model/entity classes that back the component or feature (match by name or resource type)
- Injected/annotated properties and their types
- Initialization logic
- Service dependencies

Report: class names with full paths, properties, service dependencies, key business logic.

### Agent 3: Services & API Layer

Search the project's source directories for:
- Services related to the component or feature
- Exporter/serializer classes for data output
- API endpoints / controllers / servlets
- Configuration interfaces or schemas
- Helper/utility classes

Report: service interfaces and implementations, API fields, endpoint paths, config properties.

### Agent 4: Tests & Fixtures

Search the project's test directories for:
- Existing test classes for the component or related code
- Test fixtures and mock data
- Test patterns used (setup patterns, mocking patterns)
- Coverage gaps — what's tested vs what isn't

Report: test class paths, fixture file paths, what assertions are made, suggested patterns for new tests.

## Agent Error Handling

If any subagent fails (response length limit, timeout, stale/non-responsive):

1. **Response too long** — retry once with a narrower prompt: "Return only the top 5-10 most relevant files with one-line descriptions. No code snippets." If still fails, fall back to direct Glob/Grep inline.
2. **Stale or non-responsive** — do not wait indefinitely. Move on and note the gap in research.md: "Search for [category] incomplete — manual review recommended."
3. **Partial results** — use what was returned. Supplement gaps with targeted Glob/Grep queries.
4. **2+ agents fail** — abandon subagent approach. Research inline using direct Glob and Grep with focused queries. Reduced coverage is better than no research.md.

**Always produce research.md** even with partial results — mark incomplete sections clearly rather than producing nothing.

## Synthesis Rules

Combine all 4 agents' findings into `research.md`. If `$CONTEXT` provided data from ticket-research.md, merge it:

- **Pages/URLs** from ticket data → include in the "Existing Components" section
- **Figma links** from ticket data → include in "Key Findings" as a reference
- **Acceptance criteria** from ticket data → cross-reference against findings to flag coverage gaps
- **Source links** from ticket data → include alongside local paths in Files Inventory for easy navigation

Do NOT duplicate ticket data verbatim — research.md should be deeper (code analysis, not just file discovery).

Read `.ai/templates/spec/research.md.template` and follow that structure exactly. The template defines all sections: Existing Components, Component Config, Backing Code (Models, Services, Exporters, API Endpoints), Frontend, Test Coverage, Related Components, Existing Implementation Check (MANDATORY), Key Findings, Files Inventory table, and Cross-Repo Scope.

## Rules

- **Search, don't guess** — every claim in research.md must be backed by an actual file found in the codebase. No "there is probably a service that..." statements.
- **Include file paths with line numbers** — for specific findings, reference `path/to/File.ext:45` so the developer can jump straight there.
- **Include short code snippets** — when a finding is about a specific pattern or structure, show the relevant 5-10 lines. Don't dump entire files.
- **Mark "not found" clearly** — if searching for a component's test and none exists, say "No existing tests found" not silence.
- **Parallel is key** — launch the dispatched subagents simultaneously for speed. Don't run them sequentially.
- **Profile-first** — pick the smallest research profile that covers the story (see "Adaptive Research Scope" above). The default of "all 4 agents" is wrong for small stories — it's the dominant Phase 1 context cost (issue #136).
- **Cap every agent's output** — every prompt must carry the ≤800 words / ≤10 files / no large code blocks contract. An uncapped agent can pull >150k tokens into the parent thread by itself.
- **Never fail silently** — if an agent errors (response length limit, timeout, stale), retry once narrower, then fall back to inline Glob/Grep. Always produce research.md.
- **Stay focused** — only report findings relevant to the story requirements. Don't catalogue the entire codebase.
- **Findings ≠ risks** — Key Findings should be factual discoveries ("component uses show/hide config", "no exporter exists"). Don't speculate about blockers or risks — that's for plan and plan-validate.
- **Reuse-first is mandatory** — the "Existing Implementation Check" section is NOT optional. Every research.md MUST assess whether the feature already exists and what can be reused.
- **Config vs UI changes** — configuration/dialog-only changes do not require design assets. Only flag missing design links as a risk if the story involves UI rendering changes.
