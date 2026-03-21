# Per-Breakpoint CSS Override Tables

## When to generate

Only generate breakpoint tables when **multi-viewport** extraction is active (2+ viewports extracted). For single-viewport extractions, skip this section — there's nothing to diff.

## Mobile-first approach

Tables follow a mobile-first structure:
1. **Mobile baseline** — all CSS properties at the narrowest viewport (no media query)
2. **Tablet overrides** — only properties that CHANGE from mobile
3. **Desktop overrides** — only properties that CHANGE from tablet

## How to build the tables

For each viewport's design context (from Step 6a), extract concrete CSS property values for every visible element. Then diff:

1. Parse the mobile reference code → record all element + property + value triples
2. Parse the tablet reference code → record same triples
3. Parse the desktop reference code → record same triples
4. Mobile table = all mobile triples (this is the baseline)
5. Tablet table = only triples where tablet value differs from mobile
6. Desktop table = only triples where desktop value differs from tablet

## Table format

```markdown
## Breakpoint CSS Overrides

> Mobile-first: mobile values are the base (no media query). Tablet and desktop
> show only properties that change from the previous breakpoint.
> Values marked **≈** are content-dependent (see Dynamic Content Elements).

### Mobile — Baseline (<768px)

| Element | Property | Value |
|---|---|---|
| Container | `padding` | `≈32px 12px` |
| Title | `font-size` | `32px` |
| Cards wrapper | `flex-direction` | `column` |
| Card | `width` | `100%` |

### Tablet — Overrides (≥768px)

| Element | Property | Mobile value | Tablet value |
|---|---|---|---|
| Container | `padding` | `≈32px 12px` | `≈96px 32px` |
| Title | `font-size` | `32px` | `40px` |
| Card | `width` | `100%` | `300px` |

### Desktop — Overrides (≥1024px)

| Element | Property | Tablet value | Desktop value |
|---|---|---|---|
| Container | `padding` | `≈96px 32px` | `≈96px 120px` |
| Title | `font-size` | `40px` | `56px` |
| Cards wrapper | `flex-direction` | `column` | `row` |
| Card | `width` | `300px` | `372px` |
```

## Breakpoint width detection

Use the viewport widths from the extracted frames:
- If two viewports: smaller = mobile, larger = desktop. Use project breakpoints from research.md or config if available, otherwise use frame widths as breakpoint boundaries.
- If three viewports: smallest = mobile, middle = tablet, largest = desktop.
- Standard fallbacks: mobile <768px, tablet ≥768px, desktop ≥1024px.
