# Design-vs-Story Relevance Check

**This step is mandatory.** After extraction, compare the Figma design content against the story context gathered in Step 4.

## Signals to Check

1. **Node name** — does the Figma frame/component name overlap with story component names?
2. **UI elements** — does the design contain the UI patterns described in requirements? (e.g., story says "dropdown" but design shows a "stats table")
3. **Content type** — does the design's purpose match the story's purpose? (e.g., story is "product selection flow" but design is "rider profile card")

## Scoring

Count keyword matches between (story title + explain.md component names + UI element names) and (Figma node name + design context element names). Case-insensitive.

## If relevance is LOW (< 2 keyword matches)

```
⚠️ Design-story mismatch detected

   Figma design: "<node name>" — <brief description of what the design shows>
   Story #<id>:  "<story title>" — <brief description of what the story requires>

   The Figma design does not appear to match this story's requirements.
   Possible causes:
   - Wrong Figma link in the ADO story
   - User provided a test/unrelated URL
   - Design covers a different aspect of the story

   Extraction saved but flagged. Review before using in downstream steps.
```

Write the mismatch warning to `$SPEC_DIR/figma-extract.md` in a `## Relevance Warning` section (between the header and Screenshot section).

Also write `$SPEC_DIR/figma-mismatch.md` with full details:

```markdown
# Figma Design Mismatch Report

**Story:** #<id> — <title>
**Figma:** <node name> (node <nodeId>)
**Relevance score:** <N> keyword matches out of <total keywords checked>
**Date:** <ISO date>

## Story Keywords
<list of component names, UI elements, and key terms from explain.md>

## Figma Keywords
<list of element names, component types, and content from the design>

## Matches Found
<list of matching keywords, or "None">

## Recommendation
<"Verify the Figma link in the ADO story" or "This may be a different section of the story — check with design">
```

## If relevance is OK (>= 2 keyword matches)

Continue silently, no warning needed.
