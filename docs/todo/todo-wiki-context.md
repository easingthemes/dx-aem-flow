# Wiki context TODO

## Scoped wiki context in dx-req research

**Added:** 2026-11-05
**Problem:** On a large client, several teams (markets) share one codebase and one ADO wiki, but each team only sees its own work. A ticket often touches something another market already built, documented or broke, and nobody on the team knows. `dx-req` Phase 4 reads code and `.ai/project/` seed data, never the wiki; only `dx-dor` and `dx-req-dod` read it, and only one known page. The wiki is no help as-is:

- It belongs to the whole client, not the project. A project with 4 repos sees a wiki covering many more repos, other markets and other tech stacks (commerce, CRM), so a plain search returns mostly noise.
- It is badly structured. The top level mixes market wikis, platform wikis and one-off pages. Market pages also sit at the root next to their market's parent, and market-specific pages live inside platform subtrees. A path prefix cannot say what belongs to whom.
- `mcp__ado__search_wiki` is keyword-only. It misses wording gaps ("UAT" vs "staging") and language gaps (EN tickets, DE pages).

**Scope:**
- New: a wiki map + index step, a search helper in `plugins/dx-core/data/lib/`, a `wiki:` section in `plugins/dx-core/templates/config.yaml.template`.
- Changed: `plugins/dx-core/skills/dx-req/SKILL.md` Phase 4 and `references/research-patterns.md` (budget).
- Possibly: `plugins/dx-hub/` (where the shared map/index lives for multi-repo projects).
- Fixture (done): `plugins/dx-core/data/lib/fixtures/wiki-sample/` + `wiki-sample-fixture.test.js`.

**Done-when:**
1. Config without `wiki.enabled: true` → `git diff` of a `dx-req` run's `research.md` against main shows no wiki section and no wiki MCP calls (behaviour unchanged).
2. The map step on `fixtures/wiki-sample/wiki/` with `fixtures/wiki-sample/config.json` reproduces `expected-map.json` for at least 30 of 33 pages, including all three `override: true` pages. Checked by a hermetic `*.test.js`.
3. A hermetic `*.test.js` reports recall@5 per retrieval mode (at least keyword and keyword + query expansion; vector only if implemented) over `questions.json`, broken down by `kind`. The numbers are written to the item, whatever they are.
4. No `must_not` page appears in the top 5 for its question when platform scoping is on.
5. On the fixture, `research.md` has wiki hits split into our market / platform / other markets, at most 3 hits each, each with a link and one line on why it is relevant.

**Approach:**

*Two-axis map, not path prefixes.* Every page gets two tags:
- `platform`: `ours` / `other-stack` / `general`. `ours` is derived (dx-aem installed → AEM; otherwise from the config stack), `other-stack` comes from config paths/keywords.
- `market`: `mine` / `other:<name>` / `global`. Derived from the existing `markets:` config plus optional paths/keywords.

Classification order: inherit from the parent page → override by a keyword in the title or first paragraph → LLM classifies what is still ambiguous (title + first ~100 words only). Output is a human-readable `wiki-map` file the team reviews once and edits; new pages are added incrementally. **The map replaces the structure the wiki lacks.** Untagged pages default to `general`/`global` and are never dropped.

*Search is scoped, then bucketed.* Pages tagged `other-stack` are skipped. The rest is searched and the hits are split into three buckets:
- `mine`: our market
- `global`: platform-wide pages, often the most useful
- `other:*`: other markets. This is the point of the feature: "another market already did X on this component".

*Cheap retrieval first.* v1 = BM25 over `##`-chunks + LLM query expansion (synonyms, DE/EN), since the model already writes the query. Local embeddings (`@huggingface/transformers`, multilingual MiniLM) only as a third mode, and only kept if the fixture shows it beats keyword + expansion. A ~100 MB model download is a big step for a plugin that is otherwise Markdown + small scripts.

*One map/index per project, not per repo.* A 4-repo project shares one wiki; indexing it 4 times wastes time. Keep the map/index in a shared location (hub dir or a user cache keyed by org/wiki); each repo only reads it.

*Source.* Shallow clone of the `<project>.wiki` git repo when possible (pages are `<Page>.md` + `.order`, the fixture's layout). Fall back to `wiki list_pages` + `get_page_content` via MCP.

**Open questions:**
- Automation pipelines start without the index. Pipeline cache, or local-only in v1?
- Index freshness: rebuild on demand, or check the wiki repo HEAD before each `dx-req` run?
- Jira/Confluence parity: same map model should work on Confluence spaces; not required in v1.
- A fresher signal than the wiki for "what do other markets do": recent PRs and commits by other teams on the same files/components. Possibly a separate item.

**Out of scope for v1:** vector DB, rerankers, indexing work items or past specs, changes to code search.
