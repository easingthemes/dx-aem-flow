---
name: dx-req-research
description: Search the codebase for code related to a fetched ADO story. Creates research.md with findings from models, services, templates, tests, and configuration. Use after /dx-req-explain or when the user wants to understand what existing code is relevant to a story.
argument-hint: "[ADO Work Item ID (optional — uses most recent if omitted)]"
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You read the fetched ADO story documents, analyze the requirements, then actively search the codebase to find all related code. Results are saved to `research.md`.

This skill uses `context: fork` conceptually — it spawns parallel Explore subagents for heavy codebase searching to avoid polluting the main conversation context.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir <work-item-id-if-provided>)
```

If the script exits with error, ask the user for the work item ID.

Read both `raw-story.md` and `explain.md` from `$SPEC_DIR`. If `explain.md` doesn't exist, read only `raw-story.md` and work from that.

### Pre-Dispatch Reads (parallel)

Read these files simultaneously before spawning research agents:
- `$SPEC_DIR/dor-report.md` (if exists)
- `$SPEC_DIR/ticket-research.md` (if exists)
- `.ai/config.yaml` (for repo/scope context)

These reads are independent — execute all in one message with parallel Read calls.

## 1b. Check for Pre-Existing Research

Two sources of pre-discovered data accelerate subagent work. Check both.

### Source A: ticket-research.md (from `/dx-ticket-analyze`)

If `$SPEC_DIR/ticket-research.md` exists, read it and extract:

| Data | Where in ticket-research.md | Use |
|------|---------------------------|-----|
| Component names + platform | Heading patterns | Skip name-guessing in step 2 |
| Backend file paths | Backend tables | Agent 1 reads these directly instead of searching |
| Frontend file paths | Frontend tables | Agent 1 reads these directly |
| Exporter paths | Row containing "Exporter" in backend table | Agent 2 reads directly + Agent 3 starts here |
| Pages / URLs | Pages tables | Skip page searches, include in research.md |
| Market scope | Narrowing search line | Pass to agents for path filtering |
| Figma links | Design Assets section | Include in research.md Key Findings |
| Acceptance criteria | Acceptance Criteria section | Inform search targets in step 2 |

**Strip URL wrappers to get local paths:** ticket-research.md may use clickable source links. Extract the file path from the URL to get the local file path.

### Source B: DoR Report (from `/dx-req-dor`)

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

## 2. Identify Search Targets

From the requirements (and `$CONTEXT` if available), extract a search plan:

- **Component/feature names** — names mentioned in the story. If index lookup found them, include confirmed paths.
- **Class patterns** — model names, service names, exporter names to search for
- **Property names** — config properties, field names, parameter names
- **Resource types** — framework resource types, route patterns, component identifiers
- **Endpoint paths** — API endpoints, servlet paths mentioned
- **Keywords** — domain-specific terms that would appear in code

## 3. Check Existing Output

1. Check if `research.md` exists in the spec directory
2. If it exists, read its content
3. Check staleness indicators:
   - Does the title/ID in `research.md` match the current work item?
   - Do the files listed in the Files Inventory section still exist in the codebase?
   - Has `explain.md` changed since research was generated? (Compare requirement count, key terms, and section headings)
4. If `research.md` is current and comprehensive → print `research.md already up to date — skipping` and STOP
5. If inputs changed or research looks stale → print `research.md exists but is outdated — regenerating` and continue
6. If not found → continue normally (first run)

## 4. Dispatch Parallel Subagents

Spawn **4 Explore subagents** via the Agent tool, all running in parallel. Each agent receives the search targets, the explain.md content, and `$CONTEXT` (if available) for context.

**When `$CONTEXT` has file paths:** Agents 1 and 2 switch from **discovery mode** (grep/glob the codebase) to **analysis mode** (read known files, analyze their contents in depth). This is faster and produces richer findings.

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

### Agent Error Handling

If any subagent fails (response length limit, timeout, stale/non-responsive):

1. **Response too long** — retry once with a narrower prompt: "Return only the top 5-10 most relevant files with one-line descriptions. No code snippets." If still fails, fall back to direct Glob/Grep inline.
2. **Stale or non-responsive** — do not wait indefinitely. Move on and note the gap in research.md: "Search for [category] incomplete — manual review recommended."
3. **Partial results** — use what was returned. Supplement gaps with targeted Glob/Grep queries.
4. **2+ agents fail** — abandon subagent approach. Research inline using direct Glob and Grep with focused queries. Reduced coverage is better than no research.md.

**Always produce research.md** even with partial results — mark incomplete sections clearly rather than producing nothing.

## 5. Synthesize Findings into research.md

Combine all 4 agents' findings into `research.md`. If `$CONTEXT` provided data from ticket-research.md, merge it:

- **Pages/URLs** from ticket data → include in the "Existing Components" section
- **Figma links** from ticket data → include in "Key Findings" as a reference
- **Acceptance criteria** from ticket data → cross-reference against findings to flag coverage gaps
- **Source links** from ticket data → include alongside local paths in Files Inventory for easy navigation

Do NOT duplicate ticket data verbatim — research.md should be deeper (code analysis, not just file discovery).

Read `.ai/templates/spec/research.md.template` and follow that structure exactly. The template defines all sections: Existing Components, Component Config, Backing Code (Models, Services, Exporters, API Endpoints), Frontend, Test Coverage, Related Components, Existing Implementation Check (MANDATORY), Key Findings, Files Inventory table, and Cross-Repo Scope.

## 6. Intent Workspace Sync (optional)

If running inside an Intent workspace, mirror the research findings to a dedicated Research note. Read `shared/intent-sync-contract.md` for full conventions.

**Guard:** Is the tool `mcp__workspace-mcp__add_to_note` available? If NO → set `INTENT_STATUS = "skipped"` and go to Step 7.

**If available:**

1. **Find or create Research note** — call `list_notes` and search for a note titled `Research: #<id>`. If found, use its `noteId`. If not, call `create_note(title="Research: #<id>", content="Research findings for ADO #<id>")` and use the returned `noteId`.

2. **Add summary** — call `add_to_note(noteId=<research-note-id>)` with the Key Findings section content from `research.md` (reuse verbatim — do not regenerate).

3. **Add reference blocks** — for each file in the Files Inventory table of `research.md`, call:
   ```
   add_reference_primitive(
     noteId = <research-note-id>,
     semanticId = "<file-path>",
     description = "<one-line description from table>"
   )
   ```
   Use the file path as `semanticId`. If the table includes a class/component name, append `#class:<Name>` to the semanticId.

4. **Add cross-repo scope** — if `research.md` contains a Cross-Repo Scope section, call `add_to_note(noteId=<research-note-id>, heading="## Cross-Repo Scope")` with that section's content.

5. **Add architecture diagram (conditional)** — if ≥3 distinct components or services were discovered in research.md, call `add_to_note(noteId=<research-note-id>)` with a diagram block:
   ```
   ~~~architecture layout=layered LR
   [Component1] --> [Service1]
   [Component2] --> [Service1]
   [Service1] --> [Model1]
   ~~~
   ```
   Map the actual component/service/model names from findings. Skip if <3 nodes.

6. **Link from Spec note** — call `add_to_note(noteId="spec", content="### Research\nSee [Research: #<id>](intent://local/note/<research-note-id>)")`.

7. Set `INTENT_STATUS = "synced (N references, 1 note)"` where N is the number of `add_reference_primitive` calls made.

**Error handling:** If any MCP call fails, log `Intent sync: <tool_name> failed — skipping remaining sync`, set `INTENT_STATUS = "failed (<reason>)"`, and continue to Step 7. Do NOT retry or block.

## 7. Present Summary

After saving:

```markdown
## research.md created

**<Title>** (ADO #<id>)
- Files found: <count> directly related
- Key findings: <count> items
- Files to modify: <count> (estimated)
- Test coverage: <existing test count> tests found
- Cross-repo: <"all files in this repo" OR "also needs work in <repo1>, <repo2>">

**Intent:** <INTENT_STATUS>

### Next steps:
- `/dx-plan` — create implementation plan based on findings
- `/dx-req-dor` — re-run DoR check to add codebase-informed questions
```

## Examples

### Standard research
```
/dx-req-research 2435084
```
Reads `explain.md`, spawns 4 parallel Explore agents (UI, Models, Services, Tests), synthesizes findings into `research.md` with Files Inventory, Existing Implementation Check, and Key Findings.

### With pre-existing ticket analysis
```
/dx-req-research 2435084
```
If `ticket-research.md` exists from `/dx-ticket-analyze`, agents switch to analysis mode — reading known files directly instead of searching. Produces deeper findings faster.

### Cross-repo detection
```
/dx-req-research 2435084
```
If files are found in other repos (e.g., frontend in a separate repo), adds a Cross-Repo Scope section listing which repos need changes.

## Troubleshooting

### Research produces thin results
**Cause:** Component name doesn't match codebase naming conventions, or search targets are too generic.
**Fix:** Run `/dx-ticket-analyze <id>` first to pre-discover files. Or check that `.ai/config.yaml` has correct paths and component naming.

### Agent fails with "response too long"
**Cause:** Explore agent found too many matches and exceeded response limits.
**Fix:** The skill auto-retries with a narrower prompt. If still failing, it falls back to inline Glob/Grep. Research.md is always produced, even with partial results.

### "Existing Implementation Check" shows feature already exists
**Cause:** The codebase already has the requested feature (or similar).
**Fix:** This is valuable — review the findings. The plan step will use this to extend existing code rather than creating new code.

## Decision Examples

### Codebase-Only Search Sufficient
**Requirement:** "Change hero background color to brand primary"
**Assessment:** CSS-only change. SCSS variables and hero styles in this repo.
**Action:** Grep for hero SCSS, find color variable. No AEM MCP needed.

### AEM MCP Required
**Requirement:** "Add new toggle field to hero dialog"
**Assessment:** Dialog fields defined in AEM content. Need to inspect current dialog structure.
**Action:** Use AEM MCP `scanPageComponents` for current dialog, then codebase for HTL/JS that reads values.

## Success Criteria

- [ ] `research.md` exists in spec directory
- [ ] ≥1 section has findings (not all "No results found")
- [ ] File paths in findings are valid (exist in codebase)
- [ ] Cross-repo scope documented if detected

## Rules

- **Search, don't guess** — every claim in research.md must be backed by an actual file found in the codebase. No "there is probably a service that..." statements.
- **Include file paths with line numbers** — for specific findings, reference `path/to/File.ext:45` so the developer can jump straight there.
- **Include short code snippets** — when a finding is about a specific pattern or structure, show the relevant 5-10 lines. Don't dump entire files.
- **Mark "not found" clearly** — if searching for a component's test and none exists, say "No existing tests found" not silence.
- **Parallel is key** — launch all 4 subagents simultaneously for speed. Don't run them sequentially.
- **Never fail silently** — if an agent errors (response length limit, timeout, stale), retry once narrower, then fall back to inline Glob/Grep. Always produce research.md.
- **Stay focused** — only report findings relevant to the story requirements. Don't catalogue the entire codebase.
- **Findings ≠ risks** — Key Findings should be factual discoveries ("component uses show/hide config", "no exporter exists"). Don't speculate about blockers or risks — that's for plan and plan-validate.
- **Reuse-first is mandatory** — the "Existing Implementation Check" section is NOT optional. Every research.md MUST assess whether the feature already exists and what can be reused. Search for existing utilities, helpers, mixins, services, and patterns before concluding something needs to be created new.
- **Config vs UI changes** — configuration/dialog-only changes do not require design assets. Only flag missing design links as a risk if the story involves UI rendering changes. Always check the story for design links before claiming they're missing.
