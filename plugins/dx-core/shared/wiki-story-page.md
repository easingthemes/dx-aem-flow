# Wiki Story Page — Find or Create

Shared procedure for skills that write under a story's wiki page (`/dx-doc-gen` 6a/6b, `/dx-prep`). Story pages are often created by hand, so their names vary — `<id>-<slug>`, `<id> <title>`, `<id>: <title>`, several ids (`<id1> <id2> [TAG] <title>`, `<id1>, <id2>: …`), brackets and parentheses in titles. Always reuse the page the team already has; create `<id>-<slug>` only when nothing matches anywhere.

The matching is done by a deterministic helper, not by eye:

```bash
printf '%s\n' "${PATHS[@]}" | bash .ai/lib/dx-common.sh wiki-story-page \
  --id <id> --prefer "<id>-<slug>" --root "$WIKI_ROOT" --sprint "$SPRINT"
```

- Input: one page path per line. Output: `MATCH=<path>`, `SCOPE=current|other-sprint|any`, and `OTHER=<path>` for every further match. Exit `1` = no match.
- A name matches when `<id>` is one of its **leading** ids, followed by a space, `,`, `:`, `-` or the end of the name. A longer number (`<id>1…`, `9<id>`) never matches.
- Ranking: a match in the current sprint folder beats other sprints; then an exact `<id>-<slug>` name; then the shortest path.
- With `--root`, only `<root>/<sprint>/<story>` paths count — child pages of a story (e.g. its plan page) are ignored.

## ADO Wiki

Inputs: `WIKI_ROOT` (`scm.wiki-doc-root`), `SPRINT` (from `.sprint`, or `Unsorted` when unknown), `<id>`, `<slug>` (spec dir name without the id).

1. **Current sprint folder.** List its children:
   ```
   mcp__ado__wiki
     action: "get_page"
     wikiIdentifier: <scm.wiki-id>
     project: <scm.wiki-project>
     path: "${WIKI_ROOT}/${SPRINT}"
     recursionLevel: "OneLevel"
   ```
   If the tool rejects `recursionLevel`, use `action: "list_pages"` with the same `path`. A 404 means the sprint folder does not exist yet — treat it as no children.
   Run the helper over the child paths. `MATCH` → use it.
2. **Other sprint folders** (stories are carried over between sprints). Only when step 1 found nothing: get `WIKI_ROOT` with `recursionLevel: "Full"` (or, if rejected, `OneLevel` on the root and then `OneLevel` on each sprint folder), and run the helper over all paths with `--root "$WIKI_ROOT" --sprint "$SPRINT"`. `MATCH` with `SCOPE=other-sprint` → reuse that page where it is; do **not** move it or create a copy in the current sprint. Say so in the skill's summary: `Story page found in <other sprint> (carried over) — reused`.
3. **Nothing matched anywhere** → `STORY_PATH="${WIKI_ROOT}/${SPRINT}/<id>-<slug>"`. Create the sprint folder first if step 1 returned 404 (`mcp__ado__wiki_upsert_page` with `# ${SPRINT}`).
4. **`OTHER=` lines** → print `⚠ Several wiki pages match #<id>: <chosen> (used), <others>` so a human can merge them. Never write to the others.

Result: `STORY_PATH` (full path of the story page) and whether it already existed.

## Confluence

Inputs: `DOC_ROOT_ID` (page id of `confluence.doc-root`), `SPRINT_PAGE_ID` (sprint page, from `/dx-doc-gen` 6b step 4).

1. Find candidate pages by title under the doc root:
   ```
   mcp__atlassian__confluence_search
     cql: "ancestor = '<DOC_ROOT_ID>' AND space = '<confluence.space-key>' AND title ~ '<id>'"
   ```
2. Turn each result into a path line `ROOT/<parent page title>/<page title>` — the parent being the sprint page — and run the helper with `--root ROOT --sprint "<SPRINT>" --prefer "<id>-<slug>"`. Same rules as ADO: current sprint first, then other sprints (carried over), then create `<id>-<slug>` under `SPRINT_PAGE_ID`.
3. Keep the page id of the match; `OTHER=` lines → same warning as ADO.

`title ~` is a text search and can return pages where the id appears later in the title — the helper drops those.
