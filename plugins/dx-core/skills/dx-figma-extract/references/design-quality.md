# Design Quality — Screenshot Layer Analysis

Figma designs vary in quality. Designers sometimes paste website screenshots as context and overlay new/changed elements on top. This step detects those patterns and produces a cleaned reference code where screenshot layers are stripped and real elements are preserved.

## Three-Phase Analysis

Run phases in order. Phase 1 catches obvious cases structurally. Phase 2 uses visual comparison to catch what Phase 1 missed and to describe screenshot regions. Phase 3 produces the cleaned output.

---

## Phase 1 — Structural Detection

Scan the `get_metadata` XML and `get_design_context` reference code for known patterns. Classify each top-level child of the root frame.

### Pattern Catalog

Each pattern has a **name**, **detection rule**, and **classification**. New patterns can be added to this catalog as they're discovered.

#### P1: URL-Named Screenshot

- **Detection:** Node name contains a URL-like string — domain patterns (`www.`, `.com`, `http`), path segments (`/en/us/`, `/shop/`), or filenames with URL fragments
- **Node types:** `rounded-rectangle`, `rectangle`, or any leaf node with no children
- **Classification:** `screenshot-context`
- **Example:** `name="www.example.com_en_shop_product-detail (4)"`

#### P2: Full-Bleed Background Image

- **Detection:** In the reference code, a node's first child is an absolutely positioned image wrapper: `absolute inset-0 overflow-hidden pointer-events-none` containing an `<img>` tag. The node also has other real children (frames, text, instances).
- **Classification:** `hybrid` — the `absolute inset-0` img is a screenshot background; the remaining children are real designed elements
- **Action:** Strip the screenshot `<img>` wrapper, keep all other children

#### P3: Leaf Image Node

- **Detection:** A node has zero children in the XML metadata AND spans the full width of its parent (within 5% tolerance). In the reference code it renders as only an `<img>` tag with no other content.
- **Classification:** `screenshot-context`
- **Note:** Distinguish from legitimate images (product photos, icons) by checking: does the image span full parent width? Is the node name generic ("Rectangle 1") or URL-like?

#### P4: Device Frame Decoration

- **Detection:** Node name matches device UI patterns: `ios-status-bar`, `android-status-bar`, `browser-chrome`, `status-bar`, `device-frame`, `safari-toolbar`
- **Classification:** `decoration` — strip entirely from output
- **Note:** These are Figma presentation frames, not part of the actual component

#### P5: Cropped Screenshot Slice

- **Detection:** In the reference code, an image has extreme CSS positioning: `top: -477%`, `height: 1052%`, etc. — the image is much larger than its container, indicating a full-page screenshot cropped to show just one section.
- **Classification:** `screenshot-context` (if leaf node) or the background portion of a `hybrid` (if parent has other children)
- **Example:** `<img className="absolute h-[1052.63%] left-0 max-w-none top-[-477.89%] w-full" />`

#### P6: Named Screenshot with Index

- **Detection:** Node name ends with a parenthetical index: `(1)`, `(2)`, `(4)`, `(8)` — suggesting the designer pasted the same screenshot multiple times and cropped different regions
- **Classification:** `screenshot-context`
- **Example:** `name="www.example.com_en_shop_product-detail (5)"`

<!-- ═══════════════════════════════════════════════════════════
     ADD NEW PATTERNS HERE

     Format:
     #### P<N>: <Short Name>
     - **Detection:** <how to identify this pattern>
     - **Node types:** <which Figma node types exhibit this>
     - **Classification:** <screenshot-context | hybrid | decoration | designed>
     - **Example:** <concrete example from a real extraction>

     Then update the "Signal Summary" table below.
     ═══════════════════════════════════════════════════════════ -->

### Signal Summary

Quick-reference for all structural signals:

| Signal | Patterns | Classification |
|--------|----------|----------------|
| URL-like node name | P1, P6 | `screenshot-context` |
| `absolute inset-0` img + real siblings | P2 | `hybrid` |
| Leaf node, full parent width, img-only | P3 | `screenshot-context` |
| Device UI name (`ios-status-bar`, etc.) | P4 | `decoration` |
| Extreme CSS crop (`top: -477%`, `height: 1052%`) | P5 | `screenshot-context` or `hybrid` bg |
| Indexed name suffix `(N)` | P6 | `screenshot-context` |

---

## Phase 2 — Visual Reconstruction

Read the Figma screenshot image (`figma-reference.png`) and cross-reference against Phase 1 classifications. **The goal is not just to label screenshot regions, but to reconstruct the actual UI elements visible in them** so the prototype can render real HTML — not gray placeholders.

### For `screenshot-context` nodes:

These regions contain **real UI that needs to be built** — the designer just delivered it as a screenshot instead of proper Figma elements. Visually examine the screenshot region and reconstruct:

1. **Element inventory** — list every distinct UI element visible in the region
2. **Text content** — read actual text verbatim from the screenshot
3. **Layout** — how elements relate spatially (stacked, side-by-side, grid, overlapping, etc.)
4. **Visual style** — colors, weight, sizing, backgrounds, borders — whatever is discernible
5. **Semantic mapping** — what HTML element each would be (the LLM decides based on what it sees)

There is no fixed template — the output depends entirely on what's in the screenshot. It could be a form, a carousel, a single button, a product grid, a footer, animated content, or anything else. Describe what you see, not what you expect.

### For `hybrid` nodes:

Confirm the real children (text, frames, instances) match what's visible in the screenshot at that position. Flag any discrepancies. Also check if the screenshot background contains additional UI elements NOT covered by the real children — if so, extract those elements using the same inventory format above.

### For `designed` nodes:

Quick visual check — does the structured reference code plausibly match this region of the screenshot? If a node was classified `designed` but visually appears to be a flat screenshot, reclassify it.

### Catch missed gaps:

Look for regions in the screenshot that have visible UI elements but were NOT captured as `designed` or `hybrid` — they may be screenshot areas that Phase 1 didn't flag (no URL name, no obvious structural signal). Reclassify as needed and extract their element inventory.

---

## Phase 3 — Cleaned Output

Produce two outputs:

### 1. Layer Classification Table

| Node ID | Name | Type | Classification | Action |
|---------|------|------|----------------|--------|

One row per top-level child of the root frame. Classification values:
- `designed` — proper Figma element, use as-is
- `hybrid` — has screenshot bg + real children, strip bg
- `screenshot-context` — pure screenshot, replace with semantic description
- `decoration` — device frame / presentation chrome, remove entirely

### 2. Cleaned Reference Code

Take the raw `get_design_context` reference code and transform:

- **`designed`** nodes → keep unchanged
- **`hybrid`** nodes → remove the `<div className="absolute inset-0 ..."><img .../></div>` wrapper. Keep all other children. Add comment: `{/* bg-screenshot stripped */}`
- **`screenshot-context`** nodes → replace with **reconstructed semantic HTML** based on the Phase 2 element inventory. Convert what's visible in the screenshot into reference JSX. Wrap in a `<section>` with `data-source-node` and a comment so downstream skills know the origin:
  ```jsx
  {/* reconstructed from screenshot: <node-name> */}
  <section className="screenshot-reconstructed" data-source-node="<node-id>">
    <!-- actual elements based on Phase 2 inventory -->
  </section>
  ```
  The inner HTML depends entirely on what's in the screenshot — there is no fixed structure. The goal is **real renderable HTML** that the prototype can display, not a placeholder.
- **`decoration`** nodes → remove entirely

The cleaned code becomes the `## Reference Code` section in figma-extract.md. The raw code is NOT saved — only the cleaned version.

### 3. Screenshot Regions Table

For `screenshot-context` and `hybrid` bg layers, provide the reconstructed element inventory:

| Node ID | Region | Elements reconstructed from screenshot |
|---------|--------|----------------------------------------|

---

## Classification: `designed`

When NONE of the patterns match — node has real children (text, frames, instances, vectors), proper Figma structure, and no screenshot background layer. This is the default classification.

## Edge Cases

- **Ambiguous leaf images:** Small images (icons, product thumbnails) that are legitimate design elements, not screenshots. Heuristic: if the image is < 50% of parent width and has a descriptive name (not URL-like), classify as `designed`.
- **Multiple screenshot slices from same source:** Often the same website screenshot is pasted multiple times with different crops. The indexed names (`(4)`, `(5)`, `(8)`) are a tell. Group them in the description.
- **Mixed-quality frames:** A frame might have some children that are screenshots and others that are real. Classify the frame as `hybrid` and annotate each child individually in the classification table.
