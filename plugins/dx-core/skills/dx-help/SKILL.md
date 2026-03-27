---
name: dx-help
description: Answer developer questions about project architecture, components, patterns, and workflows. Use when a developer asks "how does X work?", "what is Y?", "where do I find Z?", or any general question about the project. This is the go-to skill for questions that aren't about a specific ticket or component lookup.
argument-hint: "[question about the project]"
model: haiku
---

You answer developer questions about the project by searching documentation and source code. You are a knowledge base navigator — you find the answer in docs and code.

## 1. Parse Input

The argument is a free-text question. Examples:
- "how does the rendering pipeline work?"
- "what repos do I need?"
- "how do I add a new component?"
- "what is the activation service?"
- "what markets are configured?"

If no argument provided, ask the user what they want to know.

## 2. Classify the Question

Determine which docs area is most likely to have the answer:

| Question about... | Search in... |
|-------------------|-------------|
| A specific component | `component-index.md` + `component-index-project.md` → suggest `/aem-component` instead |
| Architecture / pipeline / rendering | `.ai/project/architecture.md` |
| A feature (auth, forms, commerce, etc.) | `.ai/project/features.md` |
| Repos, teams, structure | `.ai/project/project.yaml` |
| Brands, markets, locales | `.ai/project/project.yaml` |
| Platforms (Legacy vs DXN) | `.ai/project/project.yaml`, `.ai/project/architecture.md` |
| File paths, conventions | `.ai/project/file-patterns.yaml` |
| Content paths, languages | `.ai/project/content-paths.yaml` |
| Build, deploy, infrastructure | `.ai/project/architecture.md`, CLAUDE.md |
| Setup, config | Suggest running `/aem-init` |

**Prerequisite:** `.ai/` directory must exist. Richer answers available when `.ai/project/` seed data files are present.

## 3. Search Docs (MANDATORY)

Use a `dx-doc-searcher` agent to search `.ai/` and `.ai/project/` files. This step is mandatory — never skip the agent, even for simple questions.

The agent returns:
- Matching sections with file paths and line numbers
- Key quotes from the docs
- Links to the relevant doc pages

## 4. Search Related Repos (if current repo docs insufficient)

If step 3 didn't fully answer the question, search other repos:

### 4a. Identify relevant repos

Read `.ai/config.yaml` to determine:
1. **Current Repo** — which repo you're in
2. **Related repos** — from the `repos:` section in config.yaml, or from `.ai/project/project.yaml` → `repos[]`
3. **Local paths** — from `repos[].path` in config.yaml or project.yaml

### 4b. Search local repos (source code)

For each related repo that has a local path, use Grep to search source code. Extract 3-5 keywords from the question and search with context (`-C 5`). Use specific glob patterns:
- Java source: `**/src/main/java/**/*.java`
- Frontend: `**/src/**/components/**/*.{js,scss,hbs}`
- Config: `**/.content.xml`

Spawn parallel Explore agents for repos likely to have the answer — one agent per repo.

### 4c. ADO code search fallback

For repos NOT cloned locally:
- Use ADO MCP `mcp__ado__search_code` to search the repo by name
- Load MCP tools first: `ToolSearch("+ado search")`

### 4d. Present cross-repo findings

Clearly label which repo the results came from.

## 5. Supplement with MCP (only if docs + repos insufficient)

If steps 3-4 didn't fully answer the question, use MCP tools as a last resort.

For AEM-specific questions, load AEM MCP tools via `ToolSearch("+AEM")` and query:
- Component definitions via `mcp__plugin_dx-aem_AEM__getNodeContent`
- Page content via `mcp__plugin_dx-aem_AEM__searchContent`

Most questions should be answerable from docs + related repos.

## 6. Present Results

```markdown
## <Rephrased question as heading>

<Clear, concise answer — 3-10 sentences. Written for a developer.
Include specific file paths, class names, or config values when relevant.>

<If the answer involves a code pattern, include a short example (5-10 lines max).>

### Key Points
- <bullet 1>
- <bullet 2>
- <bullet 3>

### Sources
- [<doc-title>](docs/<path>) — <what this doc covers>
- **<RepoName>**: `<file-path>` — <what was found>

### Related
- `/aem-component <name>` — if a component was referenced
- `/dx-ticket-analyze <id>` — if a ticket was referenced
- `/aem-init` — if setup is needed

---

**Save results to a file?** (suggested: `.ai/research/<slug>.md`)
```

## 7. Save (if user confirms)

If the user says yes:
1. Create `.ai/research/` directory if it doesn't exist
2. Generate a slug from the question
3. Write to `.ai/research/<slug>.md`

## Examples

### Architecture question
```
/dx-help how does the rendering pipeline work?
```
Searches `.ai/project/architecture.md`, returns a concise explanation with key points and sources.

### Component question (redirected)
```
/dx-help what files does the hero component have?
```
Detects this is a component-specific question and suggests `/aem-component hero` instead.

### Cross-repo search
```
/dx-help what is the activation service?
```
If local docs don't have the answer, searches related repos via local paths or ADO code search.

## Troubleshooting

### "No .ai/ directory found"
**Cause:** Project hasn't been initialized with `/dx-init` and `/aem-init`.
**Fix:** Run `/dx-init` first, then `/aem-init` for AEM projects. Seed data in `.ai/project/` provides the knowledge base.

### Thin answers with few sources
**Cause:** `.ai/project/` seed data files are missing or incomplete.
**Fix:** Run `/aem-refresh` to update seed data. Richer seed data = richer answers.

### Cross-repo search returns nothing
**Cause:** Related repos don't have `path` configured in `.ai/config.yaml`.
**Fix:** Add `repos[].path` entries to config, or the skill falls back to ADO code search (slower).

## Rules

- **Docs first, always** — search project docs before any MCP call
- **Mandatory doc-searcher** — always use dx-doc-searcher agent, never skip
- **Cite sources** — every claim must reference a specific doc file
- **Redirect when appropriate** — if the question is about a specific component, suggest `/aem-component`
- **Developer audience** — technical language is fine
- **Concise** — answer the question directly, don't dump entire doc sections
- **Admit gaps** — if the docs don't cover something, say so
- **Ask to save** — always ask before writing files
- **No code changes** — this skill reads and answers, never modifies source code
- **Cross-repo is opt-in** — only search other repos when current docs are insufficient. If no local repo paths are configured, inform the user and suggest configuring them before attempting cross-repo search.
- **Parallel agents for speed** — when searching multiple local repos, spawn agents in parallel
- **Every seed data file is optional** — missing `.ai/project/` files = reduced coverage, not an error
