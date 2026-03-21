# PR Review Checklist

Reference checklist for the dx-pr-reviewer agent. Loaded on demand during review — not always in context.

## JavaScript / Frontend

| Check | Severity | Example |
|-------|----------|---------|
| XSS via innerHTML/outerHTML with user input | Critical | `el.innerHTML = userInput` → use `textContent` or sanitize |
| Missing null/undefined guards on data paths | Critical | `this.data.items.length` without `this.data?.items` |
| Event listeners not cleaned up in `unload()` | Important | addEventListener in afterLoad without removeEventListener in unload |
| Hardcoded strings that should be i18n keys | Important | `"Add to cart"` → `this.data.labels.addToCart` |
| Console.log left in production code | Suggestion | Remove or gate behind debug flag |
| jQuery mixed with vanilla DOM in same method | Suggestion | Pick one approach per method |

## CSS / SCSS

| Check | Severity | Example |
|-------|----------|---------|
| !important overriding component scoping | Important | Use more specific selector instead |
| Magic numbers without comment | Suggestion | `margin-top: 37px` → explain or use variable |
| Missing responsive breakpoint coverage | Important | Desktop styles without tablet/mobile |
| Vendor prefixes that autoprefixer handles | Suggestion | Remove manual `-webkit-` if in autoprefixer config |

## Security

| Check | Severity | Example |
|-------|----------|---------|
| Unsanitized user input in DOM manipulation | Critical | `innerHTML = response.data` |
| Hardcoded credentials or API keys | Critical | `const API_KEY = "sk-..."` |
| eval() or Function() with dynamic input | Critical | `eval(userCode)` |
| HTTP URLs in HTTPS context | Important | Mixed content warnings |
| Missing CSRF protection on state-changing endpoints | Important | POST without token validation |

## Performance

| Check | Severity | Example |
|-------|----------|---------|
| DOM queries inside loops | Important | `document.querySelector` in forEach → cache outside |
| Missing debounce on scroll/resize handlers | Important | Raw addEventListener('scroll') |
| Large synchronous operations blocking render | Important | JSON.parse of large payload on main thread |
| Unused imports or dead code in changed files | Suggestion | Import removed but dependency still in file |

## AEM-Specific (if applicable)

| Check | Severity | Example |
|-------|----------|---------|
| Sling model missing null checks on injected fields | Critical | `@Inject` without `@Optional` or `@Default` |
| HTL expression without context | Important | `${properties.text}` → `${properties.text @ context='html'}` |
| Component dialog field without fieldLabel | Suggestion | Missing accessibility for authors |
| Hardcoded content paths | Important | `/content/brand-a/...` → use resource resolver |

## Severity Reference

| Level | Confidence Range | Meaning | PR Action |
|-------|-----------------|---------|-----------|
| **Critical** (must fix) | 90-100 | Broken functionality, security vuln, data loss | Blocks approval |
| **Important** (should fix) | 80-89 | Logic error, performance issue, convention violation | Fix before merge |
| **Suggestion** (consider) | 70-79 | Clarity, naming, minor optimization | Author's discretion |
| Below threshold | < 70 | Not reported | Dropped silently |
