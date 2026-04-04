# Performance Checklist

Reference checklist used by `/dx-perf` and `/dx-ship`. Skills reference this — do not delete.

## Core Web Vitals Targets

| Metric | Good | Needs Work | Poor |
|--------|------|------------|------|
| LCP (Largest Contentful Paint) | ≤ 2.5s | 2.5-4.0s | > 4.0s |
| INP (Interaction to Next Paint) | ≤ 200ms | 200-500ms | > 500ms |
| CLS (Cumulative Layout Shift) | ≤ 0.1 | 0.1-0.25 | > 0.25 |

## Frontend Optimization

### Images
- [ ] All images have `width` and `height` attributes (prevents CLS)
- [ ] Below-fold images have `loading="lazy"`
- [ ] Responsive images use `srcset` and `sizes`
- [ ] Images served in modern formats (WebP, AVIF)
- [ ] No images > 200KB without justification

### Scripts & Styles
- [ ] No render-blocking `<script>` without `defer` or `async`
- [ ] Critical CSS inlined, rest loaded async
- [ ] No unused CSS in critical path
- [ ] Tree-shakable imports (ESM, not CommonJS)
- [ ] Code splitting for route-based chunks

### Bundle Size
- [ ] Bundle size within budget (typically < 250KB gzipped for initial load)
- [ ] No full library imports (lodash, moment.js) — use tree-shakable alternatives
- [ ] Dynamic imports for heavy, rarely-used features
- [ ] Source maps analyzed for unexpected large dependencies

### Rendering
- [ ] No layout thrashing (reads then writes, not interleaved)
- [ ] Virtual scrolling for lists > 100 items
- [ ] React: `React.memo` / `useMemo` for expensive computations only
- [ ] No forced synchronous layouts (reading offsetHeight in a loop)

## Backend Optimization

### Database
- [ ] No N+1 queries (queries inside loops → use JOIN or batch)
- [ ] Unbounded queries have LIMIT / pagination
- [ ] Indexes on frequently queried columns
- [ ] Connection pool configured (not opening new connections per request)
- [ ] Slow query logging enabled

### API
- [ ] Response times < 200ms for p95
- [ ] Large responses paginated
- [ ] Caching headers set for cacheable resources (ETags, Cache-Control)
- [ ] No synchronous blocking in async handlers
- [ ] Gzip/Brotli compression enabled

### Memory
- [ ] No memory leaks (event listeners, timers, closures holding references)
- [ ] Large objects released after use
- [ ] Streams used for large file processing (not loading entire file into memory)

## Measurement Commands

```bash
# Bundle analysis
npx webpack-bundle-analyzer dist/stats.json --mode static --no-open
npx source-map-explorer dist/**/*.js --json

# File sizes
find dist/ build/ -name '*.js' -exec ls -lh {} \; | sort -k5 -h -r | head -20

# Test timing (Maven)
grep -r "Time elapsed" target/surefire-reports/ | sort -t: -k2 -n -r | head -10

# npm dependencies size
npx cost-of-modules 2>/dev/null | head -20
```
