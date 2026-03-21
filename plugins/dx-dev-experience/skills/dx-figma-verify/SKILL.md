---
name: dx-figma-verify
description: Visually verify a generated prototype against the Figma reference screenshot. Opens prototype in Chrome, takes a screenshot, compares with Figma reference using multimodal vision, fixes gaps, and produces a verification report. Use after /dx-figma-prototype. Trigger on "verify prototype", "compare prototype", "figma verify", "check prototype against figma". Do NOT use without a generated prototype or when no Figma reference screenshot exists.
argument-hint: "<ADO Work Item ID (optional — uses most recent if omitted)>"
compatibility: "Requires Chrome DevTools MCP (chrome-devtools-mcp) and a generated prototype from /dx-figma-prototype with figma-reference.png from /dx-figma-extract."
metadata:
  version: 2.28.0
  mcp-server: chrome-devtools-mcp
  category: design-to-code
allowed-tools: ["read", "edit", "search", "write", "agent", "figma/*", "chrome-devtools-mcp/*"]
---

You visually verify a generated HTML/CSS prototype against the original Figma design screenshot. You open the prototype in Chrome, take a screenshot, compare both images side by side using multimodal vision, and fix any visual gaps — up to 2 iterations.

Use ultrathink for visual comparison — identifying layout, spacing, and color differences between two screenshots requires careful analysis.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir $ARGUMENTS)
```

If the script exits with error, ask the user for the work item ID.

## 2. Check Prerequisites

Verify required files exist:

- `$SPEC_DIR/prototype/index.html` — if missing: print `prototype/index.html not found — run /dx-figma-prototype first` and STOP.
- Read `$SPEC_DIR/figma-extract.md` — extract the node name, Figma URL, and **Viewports** field for the report header.

**Detect viewport mode:**
- Check the `**Viewports:**` field in `figma-extract.md`
- If `single` or field absent → single-viewport mode. Require `prototype/figma-reference.png`.
- If multi-viewport (e.g., `2 — desktop (1440px), mobile (375px)`) → multi-viewport mode. Require `prototype/figma-reference-desktop.png` (and any other listed viewport files). Also accept `figma-reference.png` as fallback for desktop.

Set `verify_viewports` list:
- Single: `[{ name: "default", reference: "figma-reference.png" }]`
- Multi: `[{ name: "desktop", reference: "figma-reference-desktop.png", width: 1440 }, { name: "mobile", reference: "figma-reference-mobile.png", width: 375 }]` (parsed from figma-extract.md)

**Run Steps 3–7 once per viewport.** For multi-viewport, iterate through each viewport sequentially — resize Chrome, screenshot, compare, fix. Aggregate all gaps into a single `figma-gaps.md`.

## 3. Match Viewport to Figma Reference Size

The prototype screenshot MUST match the Figma reference width exactly — otherwise the visual comparison is meaningless (e.g., 390px mobile design vs 1000px desktop screenshot).

**Step 3a.** Get the Figma reference image dimensions. Use one of these methods:

1. **From figma-extract.md** — check for explicit width in the `**Viewports:**` field (e.g., `mobile (375px)`, `desktop (1440px)`). This is the most reliable source.

2. **Via bash** — read image dimensions directly:
   ```bash
   file <absolute-path-to-figma-reference.png>
   ```
   This outputs dimensions like `PNG image data, 390 x 844`. Parse the width.

3. **Via evaluate_script** — load the image in a blank page (before navigating to prototype):
   ```
   mcp__plugin_dx-aem_chrome-devtools-mcp__navigate_page
     url: "about:blank"
   ```
   ```
   mcp__plugin_dx-aem_chrome-devtools-mcp__evaluate_script
     expression: |
       (() => {
         return new Promise((resolve) => {
           const img = new Image();
           img.onload = () => resolve({ width: img.naturalWidth, height: img.naturalHeight });
           img.onerror = () => resolve({ error: 'failed to load image' });
           img.src = 'file://<absolute-path-to-figma-reference.png>';
         });
       })()
   ```

If none of these methods return a width, fall back to **1440x900**.

**Step 3b.** Resize Chrome to match the Figma reference width:
```
mcp__plugin_dx-aem_chrome-devtools-mcp__resize_page
  width: <figma-reference-width>
  height: <figma-reference-height or 900>
```

**Step 3c.** Verify the resize took effect:
```
mcp__plugin_dx-aem_chrome-devtools-mcp__evaluate_script
  expression: "(() => ({ width: window.innerWidth, height: window.innerHeight }))()"
```

If `window.innerWidth` does not match the target width, retry the resize once. If still wrong, log a warning: `⚠️ Chrome viewport is <actual>px, expected <target>px. Screenshot may not match Figma reference dimensions.`

**CRITICAL:** This resize MUST happen BEFORE navigating to the prototype (Step 4). The prototype screenshot must be taken at the same width as the Figma reference. A 390px Figma mobile design compared against a 1000px screenshot will produce false gaps everywhere.

## 4. Open Prototype in Chrome

Navigate to the prototype HTML file:
```
mcp__plugin_dx-aem_chrome-devtools-mcp__navigate_page
  url: "file://<absolute-path-to-SPEC_DIR>/prototype/index.html"
```

Wait for the page to load:
```
mcp__plugin_dx-aem_chrome-devtools-mcp__wait_for
  text: "</html>"
  timeout: 10000
```

If the prototype has a side-by-side comparison container (Figma reference panel), hide it so only the component renders:
```
mcp__plugin_dx-aem_chrome-devtools-mcp__evaluate_script
  expression: |
    (() => {
      // Hide any Figma reference comparison panel
      const panels = document.querySelectorAll('[class*="reference"], [class*="comparison"], [class*="figma-ref"], [class*="side-by-side"]');
      panels.forEach(el => el.style.display = 'none');
      // Also hide any img pointing to figma-reference
      document.querySelectorAll('img[src*="figma-reference"]').forEach(el => el.style.display = 'none');
      return { hiddenPanels: panels.length };
    })()
```

## 5. Take Prototype Screenshot

```
mcp__plugin_dx-aem_chrome-devtools-mcp__take_screenshot
```

Save the screenshot with viewport-aware naming:
- **Single viewport:** `$SPEC_DIR/prototype/prototype-screenshot.png`
- **Multi-viewport:** `$SPEC_DIR/prototype/prototype-screenshot-<viewport.name>.png` (e.g., `prototype-screenshot-desktop.png`, `prototype-screenshot-mobile.png`)

If Chrome DevTools returns the screenshot as a displayed image rather than a file path, note the output for visual comparison in the next step.

## 6. Visual Comparison

Read both images and compare them:

1. Read the Figma reference for this viewport (`figma-reference.png` or `figma-reference-<viewport.name>.png`)
2. Read the prototype screenshot for this viewport (`prototype-screenshot.png` or `prototype-screenshot-<viewport.name>.png`)

**Compare across these categories:**

| Category | What to check |
|----------|--------------|
| **Layout** | Flex/grid direction, alignment, element ordering, overall structure |
| **Typography** | Font sizes, weights, line heights, text alignment, letter spacing |
| **Colors** | Background colors, text colors, border colors, accent colors |
| **Spacing** | Margins, paddings, gaps between elements |
| **Missing elements** | Buttons, icons, dividers, labels, images present in Figma but absent in prototype |
| **Extra elements** | Anything in prototype not in the Figma design |

**≈ Tolerance:** If `figma-extract.md` contains a `## Dynamic Content Elements` table, read it before comparing. Properties marked **≈** in the extract are content-dependent — allow reasonable deviation for these (e.g., ≈32px padding could be 28-36px without being flagged). Only flag ≈ values as gaps if the deviation is clearly wrong (>30% off or visually broken).

**For each gap found, record:**
- Category (from table above)
- Description of the difference
- Severity: `major` (structural/layout wrong, missing element) or `minor` (spacing off, color slightly different)
- Whether the property is ≈ (content-dependent) — if so, note the tolerance

**If no gaps found:** Skip to Step 8.

## 7. Fix Loop (max 2 iterations)

For each iteration:

### 7a. Apply Fixes

Edit the prototype files directly based on the gaps found:

- **CSS fixes** (colors, spacing, typography, sizing): Edit `prototype/styles.css`
- **HTML fixes** (missing elements, wrong structure, extra elements): Edit `prototype/index.html`
- **JS fixes** (interactive behavior): Edit `prototype/script.js` if it exists

Make targeted, surgical edits — do not regenerate the entire file. Fix one gap at a time.

### 7b. Re-screenshot

Reload the page in Chrome:
```
mcp__plugin_dx-aem_chrome-devtools-mcp__navigate_page
  url: "file://<absolute-path-to-SPEC_DIR>/prototype/index.html"
```

Hide the comparison panel again (Step 4 script), then take a new screenshot. Overwrite `prototype-screenshot.png`.

### 7c. Re-compare

Read the new screenshot and compare again against the Figma reference for this viewport. Update the gap list:
- Mark fixed gaps as `fixed`
- Note any remaining gaps
- Note any new gaps introduced by fixes

### 7d. Loop Control

- If all gaps are fixed or only minor gaps remain → break
- If iteration count reaches 2 → break (diminishing returns)
- Otherwise → continue to next iteration

## 8. Write figma-gaps.md

After all viewports have been verified, write a single `$SPEC_DIR/figma-gaps.md`.

Read `.ai/templates/spec/figma-gaps.md.template` and follow that structure exactly. The template uses HTML comments as authoring instructions — follow them but do not include them in the output. Key rules:

- **Overall result** is the worst result across all viewports (e.g., desktop PASS + mobile NEEDS ATTENTION → overall NEEDS ATTENTION)
- Include one **per-viewport section** for each verified viewport (or one "Default" section for single-viewport)
- **Visual Acceptance Checklist** is mandatory — generate binary pass/fail assertions per viewport with concrete values (hex colors, pixel sizes). See `references/acceptance-checklist.md` for assertion format rules.
- Mark `[x]` for assertions verified during comparison, `[ ]` for unverified or manual-check items
- Use **≈** prefix for assertions about content-dependent properties (from figma-extract.md's Dynamic Content Elements table)

## 9. Present Summary

```markdown
## Prototype verification complete

**Result:** <PASS | PASS WITH MINOR GAPS | NEEDS ATTENTION>
**Viewports:** <list with per-viewport results, e.g. "desktop: PASS, mobile: PASS WITH MINOR GAPS">
- Gaps found: <total count>
- Fixed: <count> in <N> iterations
- Remaining: <count> (<severity breakdown>)
- Acceptance checklist: <count> assertions (<count> verified, <count> to check manually)
- Report: figma-gaps.md

<if PASS>
### Prototype matches Figma reference. Ready for `/dx-plan`.
</if>
<if PASS WITH MINOR GAPS>
### Minor differences remain — acceptable for implementation. Ready for `/dx-plan`.
</if>
<if NEEDS ATTENTION>
### Major gaps remain after 2 fix rounds. Review figma-gaps.md and consider re-running `/dx-figma-prototype`.
</if>
```

## Result Classification

| Result | Criteria |
|--------|----------|
| **PASS** | 0 remaining gaps |
| **PASS WITH MINOR GAPS** | Only minor remaining gaps (no major) |
| **NEEDS ATTENTION** | 1+ major remaining gaps after max iterations |

## Error Handling

- **Chrome DevTools MCP not available:** Print `⚠️ Chrome DevTools MCP not available — cannot verify prototype visually. Ensure Chrome is running with DevTools Protocol enabled.` and STOP.
- **File URL blocked by Chrome:** Some Chrome configs block `file://` URLs. Print instructions: `Try: open -a "Google Chrome" --args --allow-file-access-from-files` and retry.
- **Screenshot fails:** Continue with whatever was captured. If no screenshot at all, fall back to structural HTML comparison (read the HTML source and compare element structure against figma-extract.md).
- **Resize fails:** Proceed with default viewport. Note the mismatch in the report.

## Rules

- **Real screenshots only** — always use Chrome DevTools, never "mentally compare"
- **Match viewport** — resize Chrome to Figma reference dimensions before screenshotting
- **Surgical fixes** — edit specific CSS properties/HTML elements, don't regenerate files
- **2 iterations max** — stop after 2 fix rounds regardless of remaining gaps
- **Separate images** — compare prototype screenshot vs Figma reference as two independent images
- **Classify severity** — major (structural) vs minor (cosmetic) determines the result
- **Idempotent** — re-running overwrites prototype-screenshot.png and figma-gaps.md
