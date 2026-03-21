# Prototype Structural Sanity Check

A quick structural check after generating the prototype — verifies the HTML has all expected elements before the real visual verification in `/dx-figma-verify`.

## What to Check

Read the Figma reference code from `figma-extract.md` and verify the generated HTML contains:

1. **All visible elements** — every text block, image, button, icon, and container from the design
2. **Correct nesting** — parent-child relationships match the design hierarchy
3. **All states/variations** — if explain.md describes multiple states, each should be present
4. **Linked assets** — CSS file linked, JS file linked (if needed), images referenced

## Fix Obvious Gaps

If an element from the design is clearly missing from the HTML:
1. Add it
2. Add basic styling in the CSS

This is a one-pass check — no iteration. Save visual accuracy verification for `/dx-figma-verify`.

## When to Skip

- If the design is very simple (< 3 visual elements), this check adds no value
- If `figma-extract.md` has no reference code section

## Next Step

For real visual verification (Chrome screenshot comparison against Figma reference), run `/dx-figma-verify`.
