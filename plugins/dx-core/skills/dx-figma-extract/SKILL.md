---
name: dx-figma-extract
description: Extract design context, tokens, and screenshots from a Figma URL. Saves figma-extract.md and reference screenshots. Use after requirements phase when a Figma URL is in the story. Trigger on "extract figma", "figma design", "get figma". Do NOT use for general Figma browsing, viewing designs without a story, or when no spec directory exists.
argument-hint: "[ADO Work Item ID] [Figma URL] — both optional, any order. Uses most recent story if ID omitted."
compatibility: "Requires Figma desktop app with Dev Mode MCP enabled (port 3845). File must be open in Figma."
metadata:
  version: 2.28.0
  mcp-server: figma
  category: design-to-code
allowed-tools: ["read", "edit", "search", "write", "agent", "figma/*", "chrome-devtools-mcp/*"]
---

You extract everything needed from a Figma design link — reference code, design tokens, screenshots — so that Figma is never consulted again in downstream steps.

Use ultrathink for node selection logic — matching Figma frame names to story context requires careful reasoning.

## 1. Parse Arguments & Locate Spec Directory

**Parse `$ARGUMENTS` into two optional parts:** an ADO work item ID and a Figma URL. They can appear in any order, or only one, or neither.

Detection rules:
- **Figma URL:** any token containing `figma.com/` — set `$FIGMA_URL_ARG`
- **ADO ID:** any token that is purely numeric — set `$ADO_ID_ARG`
- Remaining tokens: ignore (may be noise from slash-command parsing)

**Locate spec directory** using only the ADO ID (never the Figma URL):
```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir $ADO_ID_ARG)
```

If no ADO ID was provided, `find-spec-dir` returns the most recent spec directory. If the script exits with error, ask the user for the work item ID.

## 2. Check Existing Output

1. Check if `figma-extract.md` exists in the spec directory
2. If it exists and `raw-story.md` hasn't changed → print `figma-extract.md already up to date — skipping` and STOP
3. If stale → continue (regenerate)

## 3. Find Figma URL

**Priority order:**
1. `$FIGMA_URL_ARG` (from arguments) — if provided, use it as the Figma URL
2. `$SPEC_DIR/raw-story.md` — search for URLs matching `figma.com/design/<fileKey>/<fileName>?node-id=<nodeId>`
3. `$SPEC_DIR/dor-report.md` (Design section) — fallback if raw-story.md has no Figma URL

**If no Figma URL found anywhere:** Print `No Figma URL found in story or arguments — skipping` and STOP.

**URL Parsing:**
- Extract `nodeId` from `node-id=` parameter, convert hyphens to colons (`1-2` → `1:2`)
- Extract `fileKey` from the path segment after `/design/` (recorded in figma-extract.md for reference)
- If URL format is `figma.com/design/:fileKey/branch/:branchKey/:fileName` → use `branchKey` as fileKey

**User-provided URL override:**
If `$FIGMA_URL_ARG` was provided AND raw-story.md also contains a Figma URL, record both in figma-extract.md and flag the override:
```
⚠️ Using user-provided Figma URL (differs from story URL)
   Story URL: <url from raw-story.md>
   User URL:  <url from user>
```
If raw-story.md has no Figma URL, record the source as `"User-provided URL (no story URL)"`.

## 4. Gather Story Context

Read these files for component identification (used in node selection and relevance check):
- `$SPEC_DIR/explain.md` — distilled requirements with component names
- `$SPEC_DIR/research.md` — codebase findings with component directories

Extract and remember:
- Component names (e.g., "Header", "ProductCard", "hero")
- Variation names (e.g., "brand", "default", "pdp")
- UI element names (e.g., "dropdown", "stepper", "card", "teaser")
- Key terms from the story title and requirements

## 5. Node Selection

Call `get_metadata` to understand the node structure:
```
mcp__plugin_dx-core_figma__get_metadata
  nodeId: <nodeId>
  clientLanguages: "html,css,javascript"
```

Analyze the XML response:

**Case A — Node is a COMPONENT, INSTANCE, or FRAME (single viewport, not a PAGE):**
Use this node directly. Set `viewports: [{ name: "default", nodeId: <nodeId> }]`. Proceed to Step 6.

**Case B — Node is a PAGE or top-level FRAME with many children:**
1. Parse child frame names from the XML
2. **First, check for viewport variants** (Case C below) among the children
3. If no viewport variants found, match against component names from explain.md/research.md:
   - Case-insensitive substring match
   - Strip common prefixes (e.g., "Desktop/", "Mobile/", "Component/")
   - Score by relevance to story context
4. **High-confidence single match** → auto-select, print: `Auto-selected Figma node: "<name>" (ID: <nodeId>)`
5. **Multiple candidates** → ask the user:
   ```
   Figma link points to a page with multiple components:
   1. <name1> (ID: <id1>)
   2. <name2> (ID: <id2>)
   3. <name3> (ID: <id3>)
   Which component(s) should I extract? (numbers, comma-separated)
   ```
6. **No match** → ask the user with the full list of top-level children
7. After selecting a node, check if IT contains viewport variants (Case C). A selected component frame may itself contain Desktop/Mobile children.

**Case C — Viewport variants detected:**

A node (the linked node itself, or a selected child) contains multiple viewport variants as children. Detect using these heuristics:

1. **Name-based:** Child frame names containing (case-insensitive): `desktop`, `mobile`, `tablet`, `responsive`, `phone`, `web`, or common width values (`1440`, `1280`, `1024`, `768`, `375`, `390`, `414`)
2. **Size-based:** Two or more sibling frames where one is wide (>900px) and another is narrow (<500px) — check frame width from the XML `width` attribute
3. **Pattern-based:** Names like `Component / Desktop`, `Hero - Mobile`, `Desktop View`, `Mobile View`, `@desktop`, `@mobile`

**When viewport variants are detected:**
- Print: `Multi-viewport design detected: <list of variant names with dimensions>`
- Set `viewports` list, e.g.: `[{ name: "desktop", nodeId: "123:456", width: 1440 }, { name: "mobile", nodeId: "123:789", width: 375 }]`
- Sort viewports by width descending (desktop first)
- Proceed to Step 6 which will extract each viewport separately

**When NOT viewport variants:** Sibling frames that represent different components (e.g., "Header" and "Footer") are NOT viewport variants — they differ in content, not just width. Use name heuristics first; fall back to size comparison only for ambiguous cases.

## 6. Extract Design Data

**For each viewport** in the `viewports` list (or once if single viewport), make three MCP calls. When multiple viewports exist, loop through each and tag all output with the viewport name.

### 6a. Design Context

```
mcp__plugin_dx-core_figma__get_design_context
  nodeId: <viewport.nodeId>
  clientLanguages: "html,css,javascript"
```

Save: reference code, annotations, design system hints. Tag with viewport name if multi-viewport.

**Important:** The response contains image/SVG asset URLs served locally by the Figma desktop MCP (e.g., `http://localhost:3845/assets/<hash>.png`). The PostToolUse hook automatically downloads these to `$SPEC_DIR/prototype/assets/`. After the hook runs, check `$SPEC_DIR/prototype/.figma-asset-manifest.json` for the downloaded file paths.

### 6b. Screenshot

Before calling `get_screenshot`, write the target path so the PostToolUse hook saves the image there:

**Single viewport:**
```bash
mkdir -p $SPEC_DIR/prototype
echo "$SPEC_DIR/prototype/figma-reference.png" > .ai/.figma-screenshot-target
```

**Multi-viewport:**
```bash
mkdir -p $SPEC_DIR/prototype
echo "$SPEC_DIR/prototype/figma-reference-<viewport.name>.png" > .ai/.figma-screenshot-target
```
Example: `figma-reference-desktop.png`, `figma-reference-mobile.png`

Then call:
```
mcp__plugin_dx-core_figma__get_screenshot
  nodeId: <viewport.nodeId>
```

The hook automatically saves the PNG to the target path and reports the location via `additionalContext`.

**Also create a convenience symlink/copy** for backward compatibility: copy the desktop (widest) screenshot to `figma-reference.png` so downstream skills that expect the default filename still work.

### 6c. Variable Definitions

Only call once (tokens are shared across viewports):
```
mcp__plugin_dx-core_figma__get_variable_defs
  nodeId: <viewport.nodeId>  # use the first/desktop viewport
```

Save: design token definitions (colors, spacing, typography variables).

## 7. Screenshot Layer Analysis (Design Quality)

**This step is mandatory.** Consult `references/design-quality.md` for the full pattern catalog, three-phase analysis process, and output format.

Designers sometimes paste website screenshots as context and overlay new elements on top. This step detects those patterns, classifies each node, and produces a cleaned reference code.

### Summary

1. **Phase 1 — Structural detection:** Scan the `get_metadata` XML and `get_design_context` reference code against the pattern catalog in `references/design-quality.md`. Classify each top-level child as `designed` | `hybrid` | `screenshot-context` | `decoration`.

2. **Phase 2 — Visual confirmation:** Read the Figma screenshot image and cross-reference. For `screenshot-context` nodes, describe what existing UI is visible. Catch any gaps Phase 1 missed.

3. **Phase 3 — Cleaned output:** Produce the Layer Classification table, Screenshot Regions table, and a cleaned reference code (screenshot layers stripped, real elements preserved).

**If ALL nodes are `designed`** (no screenshots detected): print `Design quality: clean — no screenshot layers detected` and skip to Step 8. Do NOT add the `## Design Quality` section to figma-extract.md.

**If any screenshots detected:** The cleaned reference code replaces the raw code in the `## Reference Code` section. Add `## Design Quality` section to figma-extract.md (between `## Screenshot` and `## Reference Code`) with the classification table and screenshot region descriptions.

## 8. Design-vs-Story Relevance Check

**This step is mandatory.** Consult `references/relevance-check.md` for the full scoring algorithm, mismatch report format, and output file conventions. Summary:

1. Count keyword matches between story context (Step 4) and Figma design content
2. **LOW (< 2 matches):** warn user, write `figma-mismatch.md`, add `## Relevance Warning` to figma-extract.md
3. **OK (>= 2 matches):** continue silently

## 9. Analyze Dynamic Content & Build Breakpoint Tables

Consult `references/dynamic-content.md` for detection heuristics and `references/breakpoint-tables.md` for table format.

### 9a. Dynamic Content Detection

Scan the design context reference code from Step 6 and identify elements with placeholder content. For each, record which CSS properties are content-dependent. Tag these values with **≈** in all output sections.

### 9b. Breakpoint CSS Override Tables (multi-viewport only)

When multi-viewport extraction is active, diff the design context across viewports to produce mobile-first CSS override tables:

1. Extract element + property + value triples from each viewport's reference code
2. Mobile baseline = all mobile triples
3. Tablet overrides = only triples where tablet differs from mobile
4. Desktop overrides = only triples where desktop differs from tablet

Mark content-dependent values with **≈**. Use viewport frame widths as breakpoint boundaries (or project breakpoints from research.md if available).

Skip this step for single-viewport extractions.

## 10. Write figma-extract.md

Create `$SPEC_DIR/prototype/` directory if it doesn't exist.

Read `.ai/templates/spec/figma-extract.md.template` and follow that structure exactly. The template uses HTML comments as authoring instructions — follow them but do not include them in the output. Key rules:

- **Single-viewport:** use the single "Reference Code" section, omit per-viewport sections and Breakpoint CSS Overrides
- **Multi-viewport:** use per-viewport sections (Desktop Variant, Mobile Variant, etc.), include Breakpoint CSS Overrides, omit the single "Reference Code" section
- **Dynamic Content Elements** is mandatory in both modes — scan reference code for placeholders, tag content-dependent values with ≈
- **Breakpoint CSS Overrides** is multi-viewport only — diff CSS values across viewports in mobile-first order
- Omit `## Relevance Warning` if no mismatch detected
- Omit `## Annotations & Constraints` (single-viewport) if none found

## 11. Present Summary

```markdown
## figma-extract.md created

**Component:** <node name>
**Node ID:** <selectedNodeId>
<if multi-viewport>**Viewports:** <list, e.g. "desktop (1440px), mobile (375px)"></if>
- Reference code: <lines of code extracted> <if multi-viewport>(per viewport)</if>
- Design tokens: <count> variables
- Dynamic content elements: <count> marked with ≈ tolerance
<if multi-viewport>- Breakpoint tables: <count> breakpoints with CSS override diffs</if>
- Screenshots: <if single>prototype/figma-reference.png<else>prototype/figma-reference-desktop.png, prototype/figma-reference-mobile.png</if>
- Assets: <count> download URLs (<count> downloaded locally)
<if screenshots detected>- Design quality: hybrid — <N> screenshot layers stripped, <M> real elements preserved</if>
<if clean design>- Design quality: clean — no screenshot layers</if>
<if mismatch>- ⚠️ Design-story mismatch detected — see figma-mismatch.md</if>
<if url override>- ⚠️ Using user-provided URL (differs from story)</if>

### Next: `/dx-figma-prototype` to generate HTML/CSS prototype, then `/dx-figma-verify` to verify
```

## MCP Fallback & Error Handling

Consult `references/mcp-fallback.md` for the full fallback strategy and error handling. Key rules:
- **Desktop MCP only** — never fall back to `mcp__claude_ai_Figma__*` (cloud)
- **Graceful degradation** — if one MCP call fails, continue with whatever is available
- **Partial extraction** is better than no extraction

## Success Criteria

- [ ] `figma-extract.md` exists in spec directory
- [ ] ≥1 reference screenshot saved
- [ ] Design tokens extracted (colors, spacing, typography)
- [ ] Component mapping documented

## Rules

- **Extract everything** — be thorough, this is the only Figma interaction
- **Save screenshots as files** — not just descriptions, actual image files via the hook
- **Download assets** — the hook downloads localhost:3845 image URLs from get_design_context
- **Smart node selection** — use story context to auto-drill-down when possible
- **One interruption max** — only ask the user if auto-selection fails
- **Always check relevance** — compare design against story context, warn on mismatch
- **Track URL source** — record whether URL came from story or user override
- **Idempotent** — check existing output before re-extracting
- **Graceful degradation** — partial extraction is better than no extraction
