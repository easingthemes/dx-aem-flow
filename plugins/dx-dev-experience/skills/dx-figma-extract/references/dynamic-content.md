# Dynamic Content Detection & ≈ Tolerance Markers

## What is dynamic content?

Elements whose content differs in production from the Figma mockup. The Figma design shows placeholder text/images, but real content varies in length, line count, and dimensions.

## How to detect

Scan the design context reference code for elements that are clearly placeholders:

| Element type | Detection signals |
|---|---|
| **Headings/titles** | Short generic text like "Title", "Heading", "Lorem ipsum" |
| **Body/description** | Multi-line text blocks, paragraph elements |
| **Button/CTA labels** | Text inside buttons, links, CTAs |
| **Images** | Placeholder images, stock photos |
| **Badge/tag text** | Short labels that vary per item |
| **Repeated items** | Cards, list items, grid items — count may vary |

## Content-dependent CSS properties

For each dynamic element, identify which CSS properties will shift when real content replaces the placeholder:

| Property | Why it's content-dependent |
|---|---|
| `width` / `height` / `min-height` | Text length or image aspect ratio changes dimensions |
| `padding` | Visual balance around variable-length text |
| `gap` / `margin` | Spacing between items when count varies |
| `line-height` x line count | Total height changes with text length |
| `aspect-ratio` | Image aspect ratio varies per asset |

## ≈ Marker convention

Values measured from Figma placeholder content that will vary in production are prefixed with **≈** (approximate):

- In the **Breakpoint Override Tables**: `≈32px` means "measured 32px from placeholder, actual will vary"
- In the **Dynamic Content Elements table**: lists which elements and properties are approximate
- In the **Visual Acceptance Checklist** (dx-figma-verify): assertions prefixed with ≈ have tolerance — verify the general range, not pixel-exact values

**Structural properties are NEVER approximate.** `flex-direction: column`, `position: absolute`, `display: grid` — these are either correct or incorrect regardless of content.

## Output format

Add a `## Dynamic Content Elements` section to figma-extract.md:

```markdown
## Dynamic Content Elements

> Elements with placeholder content in Figma. Values measured from these elements
> are marked **≈** throughout this document. Downstream skills should treat ≈ values
> as guidelines, not pixel-exact targets.

| Element | Content type | Content-dependent properties |
|---|---|---|
| Title heading | Text (variable length) | `height`, `margin-bottom` |
| Body paragraph | Text (multi-line, variable) | `height`, `min-height` |
| CTA button label | Text (variable length) | `width`, `padding-inline` |
| Card image | Image (variable aspect ratio) | `height`, `aspect-ratio` |
| Card items | Repeated (variable count) | Container `height`, `gap` accumulation |
```
