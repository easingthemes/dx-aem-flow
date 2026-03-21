# Visual Acceptance Checklist

## Purpose

A set of binary pass/fail assertions about the component's visual appearance, generated from the Figma design data. A QA engineer with NO Figma access can verify the implementation against this checklist alone.

## Structure

The checklist is organized per viewport (matching the viewports from figma-extract.md), with categories matching the comparison categories from Step 6.

## How to generate

After the verify comparison (Step 6), convert each observed property into a binary assertion:

1. **From the Figma reference screenshot** — extract visual properties you can measure: colors, font sizes, spacing, layout direction, element count, alignment
2. **From the figma-extract.md** — use design tokens, breakpoint tables, and reference code for exact values
3. **From the Dynamic Content Elements table** — prefix assertions about content-dependent properties with **≈**

## Assertion format

Each assertion is a checkbox with a concrete, measurable claim:

```markdown
- [ ] Heading font-size: 24px / weight: 700
- [ ] ≈ Container height: ≈200px (content-dependent — actual height may vary)
- [ ] List items layout: flex-direction column, gap 8px
- [ ] Background color: #ffffff / border: 1px solid #e0e0e0
```

## Rules

- **One property per assertion** when possible — easier to check/uncheck
- **≈ prefix** for content-dependent values — signals tolerance
- **Structural assertions are never approximate** — `flex-direction: row` is binary, not ≈
- **Include color hex values** — not just "dark" or "brand color"
- **Include pixel values** — not "large spacing" or "small text"
- **Skip embedded component internals** — only assert the container/slot styling
- **Group by category** — Layout, Typography, Colors, Spacing, Interactive States

## Placement in figma-gaps.md

Add as the final section, after Remaining Issues:

```markdown
## Visual Acceptance Checklist

> Binary pass/fail assertions for QA verification without Figma access.
> Assertions marked ≈ have tolerance for dynamic content.
> Generated from Figma design data + prototype verification.

### <Viewport Name> (<width>px)

#### Layout
- [x] <assertion — checked if verified during comparison>
- [ ] <assertion — unchecked if not verified or remaining gap>

#### Typography
- [x] <assertion>

#### Colors
- [x] <assertion>

#### Spacing
- [x] <assertion>

#### Interactive States
- [ ] <assertion — typically unchecked, verify manually>
```
