# Visual Comparison Categories

When comparing AEM rendered output against a Figma reference or requirements, evaluate each category below.

## Categories

| Category | What to check | Major if... | Minor if... |
|----------|--------------|-------------|-------------|
| **Layout** | Flex/grid direction, alignment, element ordering, overall structure | Wrong direction, missing sections, broken grid | Slightly off alignment |
| **Typography** | Font sizes, weights, line heights, text alignment, letter spacing | Wrong font family, drastically wrong size | Weight 400 vs 500, 1-2px size diff |
| **Colors** | Background, text, borders, accent colors | Completely wrong color, missing background | Slightly off shade (#333 vs #2d2d2d) |
| **Spacing** | Margins, paddings, gaps between elements | Missing padding, elements overlapping | 4-8px deviation |
| **Missing elements** | Buttons, icons, dividers, labels, images in reference but absent | Any missing interactive element | Missing decorative element |
| **Extra elements** | Elements in AEM render not in reference | Functional elements that shouldn't exist | Debug/test artifacts |
| **Responsive** | Component fills container width correctly, no horizontal scroll | Broken at viewport width, overflow | Minor width mismatch |

## Content Tolerance

Figma designs show mockup/placeholder content. AEM pages show real or demo-authored content. These differences are **expected and acceptable**:

- Different text strings (lorem ipsum vs real copy)
- Different images (placeholder vs DAM assets)
- Different number of list/card items (mockup count vs authored count)
- Slightly different text wrapping due to different content length

**Only flag content differences if they break layout** (e.g., text overflow, missing truncation, container doesn't grow).

## ≈ Dynamic Content Values

If `figma-extract.md` contains a `## Dynamic Content Elements` table, properties marked with **≈** are content-dependent. Allow ~30% deviation for these without flagging. Only flag ≈ values if:

- Deviation exceeds 30%
- The result is visually broken (text overflow, overlapping elements)
- Layout structure changes (e.g., 2 columns become 1)

## Gap Recording Format

For each gap found:

```markdown
| # | Category | Severity | Description | Source |
|---|----------|----------|-------------|--------|
| 1 | Layout | major | Flex direction is row, should be column on mobile | figma-reference-mobile.png |
| 2 | Spacing | minor | Gap between cards is 16px, reference shows ~24px | figma-reference-desktop.png |
| 3 | Missing | major | CTA button not rendered | explain.md AC-3 |
```

## Multi-Viewport Comparison

For multi-viewport Figma references:
1. Resize Chrome to match each viewport's width
2. Run comparison per viewport
3. Use viewport-specific reference screenshots
4. Aggregate gaps with viewport labels
5. Overall result = worst result across all viewports
