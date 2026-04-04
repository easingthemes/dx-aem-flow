# Accessibility Checklist

Reference checklist used by `/dx-axe` and `/dx-step-verify`. Skills reference this — do not delete.

## WCAG 2.1 AA Requirements

### Keyboard Navigation
- [ ] All interactive elements reachable via Tab key
- [ ] Focus order matches visual order
- [ ] No keyboard traps (can Tab in AND out of every component)
- [ ] Custom controls have Enter/Space activation
- [ ] Escape closes modals/overlays and returns focus to trigger
- [ ] Skip-to-content link present on pages with repeated navigation

### Screen Reader Support
- [ ] Heading hierarchy: one `<h1>`, logical nesting (`<h2>` → `<h3>`, never skip)
- [ ] All images have `alt` text (decorative images: `alt=""`)
- [ ] Form inputs have associated `<label>` elements
- [ ] ARIA landmarks: `<main>`, `<nav>`, `<aside>`, `<footer>`
- [ ] Dynamic content updates announced with `aria-live` regions
- [ ] Tables have `<caption>` and `<th scope>` attributes

### Visual Design
- [ ] Color contrast ≥ 4.5:1 for normal text (WCAG AA)
- [ ] Color contrast ≥ 3:1 for large text (18px+ or 14px+ bold)
- [ ] Information not conveyed by color alone (add icons, patterns, text)
- [ ] Focus indicators visible (not just `outline: none`)
- [ ] Text resizable to 200% without loss of content or functionality
- [ ] No content that flashes more than 3 times per second

### ARIA Usage
- [ ] ARIA used only when native HTML can't provide semantics
- [ ] `role` attributes match element behavior
- [ ] `aria-label` / `aria-labelledby` on custom controls
- [ ] `aria-expanded` on disclosure widgets (accordions, dropdowns)
- [ ] `aria-selected` on selectable items (tabs, list items)
- [ ] `aria-hidden="true"` on decorative elements only

### Forms
- [ ] Required fields marked with `aria-required="true"` AND visual indicator
- [ ] Error messages linked to inputs via `aria-describedby`
- [ ] Error messages describe what went wrong AND how to fix it
- [ ] Auto-complete attributes on address/payment fields

### Media
- [ ] Video has captions
- [ ] Audio has transcript
- [ ] No auto-playing media with sound

## Testing Tools

```bash
# Axe CLI
npx @axe-core/cli <url> --tags wcag2a,wcag2aa

# Pa11y
npx pa11y <url> --standard WCAG2AA

# Lighthouse accessibility audit
# Available via Chrome DevTools MCP
```

## Common AEM Accessibility Issues

- Missing `alt` text on DAM images — check `alt` property in component dialog
- Empty links from optional `linkUrl` fields — guard with conditional rendering
- Missing heading hierarchy in authored content — enforce via dialog field validation
- Overlay/modal focus traps — use `shared/aem-dom-rules.md` focus management patterns
