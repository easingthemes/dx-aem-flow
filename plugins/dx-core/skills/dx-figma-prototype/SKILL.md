---
name: dx-figma-prototype
description: Research project conventions and generate a high-fidelity standalone HTML/CSS prototype from Figma extraction data. Produces figma-conventions.md and prototype files. Use after /dx-figma-extract. Trigger on "figma prototype", "generate prototype", "create prototype from figma". Do NOT use without figma-extract.md or for non-design tasks.
argument-hint: "<ADO Work Item ID (optional — uses most recent if omitted)>"
compatibility: "Requires figma-extract.md from /dx-figma-extract. No external dependencies — generates standalone HTML/CSS."
metadata:
  version: 2.28.0
  mcp-server: figma
  category: design-to-code
allowed-tools: ["read", "edit", "search", "write", "agent", "figma/*", "chrome-devtools-mcp/*"]
---

You research the consumer project's frontend conventions, then generate a standalone high-fidelity HTML/CSS prototype that replaces Figma as the visual reference for all downstream implementation steps.

Use ultrathink for prototype generation — mapping design tokens to project conventions and producing pixel-accurate output requires deep reasoning.

## 1. Locate the Spec Directory

```bash
SPEC_DIR=$(bash .ai/lib/dx-common.sh find-spec-dir $ARGUMENTS)
```

If the script exits with error, ask the user for the work item ID.

## 2. Check Prerequisites

- `$SPEC_DIR/figma-extract.md` MUST exist. If not: print `figma-extract.md not found — run /dx-figma-extract first` and STOP.
- Read `figma-extract.md` to confirm it has content.

## 3. Check Existing Output

1. If `$SPEC_DIR/figma-conventions.md` AND `$SPEC_DIR/prototype/index.html` both exist:
2. Check if `figma-extract.md` changed since prototype was generated
3. If unchanged → print `prototype already up to date — skipping` and STOP
4. If stale → continue (regenerate)

## 4. Phase A — Conventions Research

Launch three subagents in parallel using the Agent tool:

**Subagent 1 — Styles (dx-figma-styles):**
```
Agent tool:
  subagent_type: dx-core:dx-figma-styles
  prompt: |
    Discover CSS/SCSS conventions for this project.
    spec_dir: <$SPEC_DIR>

    Figma design tokens to map against (from figma-extract.md):
    <paste the Design Tokens section from figma-extract.md>

    Return the full Styles Conventions report.
```

**Subagent 2 — Markup (dx-figma-markup):**
```
Agent tool:
  subagent_type: dx-core:dx-figma-markup
  prompt: |
    Discover HTML and accessibility conventions for this project.
    spec_dir: <$SPEC_DIR>
    component_name: <component name from figma-extract.md>

    Return the full Markup Conventions report.
```

**Subagent 3 — Component Reuse (dx-figma-components):**
```
Agent tool:
  subagent_type: dx-core:dx-figma-components
  prompt: |
    Analyze the Figma design and find existing codebase components to reuse.
    spec_dir: <$SPEC_DIR>

    Figma design reference (from figma-extract.md):
    <paste the Reference Code section and component name from figma-extract.md>

    Identify every UI building block in the design (buttons, images, cards, inputs, etc.)
    and search the codebase for existing components that match. Return the Component Reuse Map.
```

**Wait for all three to complete.** Combine results into `$SPEC_DIR/figma-conventions.md`:

```markdown
# Project Conventions (auto-discovered)

**Generated:** <ISO date>
**Project:** <from .ai/config.yaml project.name>

<Styles Conventions section from dx-figma-styles agent>

<Markup Conventions section from dx-figma-markup agent>

<Component Reuse Map section from dx-figma-components agent>
```

## 5. Phase B — Scaffold & Generate Prototype

### 5a. Scaffold from Template

Determine the layout mode from `figma-extract.md`:
- Read the `**Viewports:**` field — extract the design width (e.g., `360px` for mobile, `1440px` for desktop)
- **≤600px** → `row` layout (prototype + Figma reference side by side — both fit)
- **>600px** → `col` layout (stacked — too wide for side by side)

Run the scaffold script:
```bash
bash skills/dx-figma-prototype/scripts/scaffold-prototype.sh "$SPEC_DIR" <row|col>
```

This creates `prototype/index.html` (from template), empty `styles.css`, and empty `script.js`. The HTML contains two placeholders: `{{PROTOTYPE_CONTENT}}` and `{{FIGMA_REFERENCES}}`.

### 5b. Read Inputs

- `$SPEC_DIR/figma-extract.md` — design data, reference code, tokens, screenshots
- `$SPEC_DIR/figma-conventions.md` — project conventions (just created in Phase A)
- `$SPEC_DIR/explain.md` — requirements (what the component should do)

### 5c. Fill the Template

**Replace `{{PROTOTYPE_CONTENT}}`** in `prototype/index.html` with the component HTML:
- Use the project's component naming conventions (prefix, BEM pattern from conventions)
- Use semantic HTML elements matching project patterns
- Include ARIA attributes following project accessibility patterns
- Include all states/variations described in explain.md (use separate `<section class="prototype-section">` blocks with `<h2 class="prototype-section-label">` headers for each state)
- **Screenshot-reconstructed regions:** The reference code may contain `<section className="screenshot-reconstructed">` elements from the design quality step. These are **real UI reconstructed from screenshot regions** in the Figma design — the designer pasted screenshots instead of creating proper elements. Render them as full HTML with proper styling matching the project conventions. They should look like normal page sections, not placeholders. The `data-source-node` attribute and comment indicate the origin, but the HTML content is real and should be styled to match.

**Replace `{{FIGMA_REFERENCES}}`** with Figma reference image tag(s):
- **Single viewport:** `<img class="prototype-figma-ref" src="figma-reference.png" alt="Figma reference screenshot" />`
- **Multi-viewport:** One `<img>` per viewport with a label:
  ```html
  <p class="prototype-figma-ref-label">Desktop (1440px)</p>
  <img class="prototype-figma-ref" src="figma-reference-desktop.png" alt="Figma reference — desktop" />
  <p class="prototype-figma-ref-label">Mobile (375px)</p>
  <img class="prototype-figma-ref" src="figma-reference-mobile.png" alt="Figma reference — mobile" />
  ```

**IMPORTANT:** Do NOT modify the scaffold structure (`.prototype-wrapper`, `.prototype-compare`, `.prototype-compare-col` elements or the inline `<style>` block). Only replace the two `{{...}}` placeholders with content. The comparison layout is provided by the template — do not reinvent it.

### 5d. Component Reuse Rule

**Before generating any HTML/CSS, consult the Component Reuse Map in `figma-conventions.md`.**

The Figma design is composed of multiple UI building blocks — buttons, images, cards, form inputs, etc. Most of these already exist in the codebase. The prototype must reflect the reuse strategy:

- **Reuse as-is:** Use the existing component's class names, HTML structure, and variant configuration exactly as documented in the reuse map. Do NOT reinvent button styles, image wrappers, or other atomic components.
- **Extend:** Use the existing component's structure and add the identified missing variant or modification. Add a CSS comment marking the extension: `/* EXTEND: <component> — added <what> */`
- **Compose:** Assemble the Figma element from the listed existing components. The prototype HTML should reflect the composition hierarchy (e.g., Card wrapping Image + Button).
- **Create new:** Only for elements explicitly marked "Create New" in the reuse map. Follow the nearest existing component's patterns.

This ensures the prototype is grounded in the actual component library and implementation can reuse existing code rather than rebuilding from scratch.

### 5e. Generation Rules

**CSS (`prototype/styles.css`):**
- Flat CSS (not SCSS) — no build system needed
- Do NOT include prototype scaffold styles (`.prototype-wrapper`, `.prototype-compare-*`, `.prototype-section-*`, `.sr-only`) — these are already in the template's inline `<style>`
- Use the project's actual color values (mapped from Figma tokens → project tokens via figma-conventions.md)
- Use the project's breakpoints as `@media` query values
- Use the project's typography scale (font sizes, weights, families)
- Use the project's spacing values
- Follow the project's class naming pattern
- Include responsive styles for all breakpoints the component needs

**JS (`prototype/script.js`):**
- Vanilla JS, no dependencies
- Only for interactive behavior (tabs, accordions, dropdowns, toggles)
- Minimal — just enough to demonstrate the interaction
- If the component is purely visual (no interaction), leave the file empty

### Token Mapping

Map Figma design tokens to the closest project equivalent:
1. Check if the Figma token value exactly matches a project variable value → use project variable name in a comment
2. Check if a close match exists (within 10% for numeric, similar hue for colors) → use project value, note the mapping
3. No match → use the Figma value directly, flag as "no project equivalent"

Include a token mapping table as an HTML comment at the top of `styles.css`:
```css
/*
 * Token Mapping: Figma → Project
 * ─────────────────────────────────
 * Figma #3a7bd5 → $color-primary (exact match)
 * Figma 16px    → $font-size-md (exact match)
 * Figma 24px    → $spacing-lg (close: project has 20px)
 * Figma #f5f5f5 → NO MATCH (using Figma value)
 */
```

## 6. Write Files

Files are already scaffolded by Step 5a. Write content to:

1. `index.html` — already exists from template; replace `{{PROTOTYPE_CONTENT}}` and `{{FIGMA_REFERENCES}}` placeholders using the Edit tool
2. `styles.css` — write component styles (no scaffold styles — those are inline in the template)
3. `script.js` — write interaction JS, or leave empty if purely visual

Ensure `figma-reference.png` (from dx-figma-extract) is already in the directory.

## 7. Structural Sanity Check

Consult `references/quality-check.md` for details. Quick one-pass check:

1. Verify all visible elements from `figma-extract.md` reference code are present in the generated HTML
2. Check correct nesting and parent-child relationships
3. Verify all states/variations from `explain.md` are represented
4. Add any clearly missing elements

This is a structural check only — real visual verification happens in `/dx-figma-verify`.
Skip if: design is very simple (< 3 visual elements).

## 8. Present Summary

```markdown
## Prototype generated

**Component:** <name>
- `prototype/index.html` — <line count> lines
- `prototype/styles.css` — <line count> lines, <N> token mappings (<M> exact, <K> close, <J> no match)
- `prototype/script.js` — <line count> lines (or "not needed")
- `figma-conventions.md` — <section count> convention categories discovered

**Token coverage:** <percentage>% of Figma tokens mapped to project equivalents

### To preview: open `<full path>/prototype/index.html` in a browser

### Next: `/dx-figma-verify` to visually verify prototype against Figma, then `/dx-plan`
```

## Error Handling

- **Subagent failure:** If one convention research agent fails, proceed with whatever the others returned. Note the gap in figma-conventions.md. If the component reuse agent fails, proceed without the reuse map — the prototype will still work but implementation may miss reuse opportunities.
- **No conventions found:** If neither agent finds anything (bare project with no rules/components), generate the prototype using Figma reference code directly with a warning.
- **Token mapping impossible:** If project has no discoverable design tokens, use Figma values directly and flag all as "no project equivalent."

## Rules

- **High fidelity** — the prototype must be visually comparable to the Figma screenshot
- **Project conventions first** — always prefer project tokens/patterns over Figma's raw output
- **Standalone** — no build system, no dependencies, no imports. Just open in browser.
- **Document mappings** — every design decision (token mapping, naming choice) must be traceable
- **Idempotent** — check existing output before regenerating
- **Conventions file is reusable** — write it as a standalone artifact that dx-plan and dx-step can reference
