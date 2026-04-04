---
name: dx-perf
description: Performance audit — measure baseline, identify bottlenecks, fix, verify improvement. Covers Core Web Vitals, bundle analysis, N+1 queries, and profiling. Use when performance requirements exist or regressions are suspected.
argument-hint: "[target: 'frontend' | 'backend' | 'bundle' | 'all' (default: all)]"
model: sonnet
effort: high
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You perform a measurement-first performance audit: establish baseline, identify bottlenecks, fix them, and verify improvement with evidence.

**Core principle:** Performance work without measurement is guessing. Never optimize without a baseline.

## 1. Discover Project Context

Read `.ai/config.yaml` for:
- `project.type` — determines which checks apply (frontend, backend, fullstack)
- `build.command` — for bundle analysis
- `build.perf-budget` — custom performance budgets (if configured)
- `aem.author-url` / `aem.publish-url` — for AEM frontend checks

Read `shared/perf-checklist.md` for the full checklist reference.

## 2. Determine Scope

Based on the argument (or `all` by default):

| Target | Checks |
|--------|--------|
| `frontend` | Core Web Vitals, bundle size, rendering, images, lazy loading |
| `backend` | N+1 queries, response times, memory, connection pools |
| `bundle` | Bundle analysis only — tree-shaking, code splitting, heavy deps |
| `all` | All of the above |

## 3. Establish Baseline

### Frontend Baseline

If Chrome DevTools MCP is available (`mcp__plugin_dx-aem_chrome-devtools-mcp__`):
1. Navigate to the target page
2. Run Lighthouse performance audit
3. Capture Core Web Vitals: LCP, INP, CLS

If not available, check for existing metrics in CI output or package.json scripts.

**Core Web Vitals targets:**

| Metric | Good | Needs Work | Poor |
|--------|------|------------|------|
| LCP (Largest Contentful Paint) | ≤ 2.5s | 2.5-4.0s | > 4.0s |
| INP (Interaction to Next Paint) | ≤ 200ms | 200-500ms | > 500ms |
| CLS (Cumulative Layout Shift) | ≤ 0.1 | 0.1-0.25 | > 0.25 |

### Bundle Baseline

```bash
# npm projects
npx webpack-bundle-analyzer dist/stats.json --mode static --no-open 2>/dev/null
# or source-map-explorer
npx source-map-explorer dist/**/*.js --json 2>/dev/null
```

If neither tool is available, check bundle sizes directly:
```bash
find dist/ build/ -name '*.js' -exec ls -lh {} \; 2>/dev/null | sort -k5 -h -r | head -20
```

### Backend Baseline

Check for slow queries, response times in logs, or test execution times:
```bash
# Maven test timing
grep -r "Time elapsed" target/surefire-reports/ 2>/dev/null | sort -t: -k2 -n -r | head -10
```

Record all baselines — they're needed for the verification step.

## 4. Identify Bottlenecks

### Frontend Bottlenecks

Search for common anti-patterns:

**Images without optimization:**
```
Grep: <img(?![^>]*loading=) — missing lazy loading
Grep: <img(?![^>]*width=) — missing dimensions (causes CLS)
```

**Large synchronous scripts:**
```
Grep: <script(?![^>]*defer|async) — render-blocking scripts
```

**Unnecessary re-renders (React):**
```
Grep: useEffect\(\s*\(\)\s*=> — effects without dependency arrays
Grep: \{\.\.\.props\} — prop spreading (breaks memoization)
```

### Backend Bottlenecks

**N+1 query patterns:**
```
Grep: for.*\{[\s\S]*?(query|find|get|fetch|select) — queries inside loops
```

**Unbounded data fetching:**
```
Grep: findAll\(\)|find\(\{\}\)|SELECT \* — missing pagination or limits
```

**Missing caching:**
```
Grep: @Cacheable|cache\.|Redis|memcached — check if caching exists for hot paths
```

### Bundle Bottlenecks

**Heavy imports:**
```
Grep: import .* from ['"]lodash['"] — full lodash import (should use lodash-es or per-function)
Grep: import .* from ['"]moment['"] — moment.js (should use date-fns or dayjs)
```

**Missing tree-shaking:**
```
Grep: require\( — CommonJS in ESM project prevents tree-shaking
```

**Missing code splitting:**
```
Grep: import\s+\w+\s+from — static imports of heavy, rarely-used modules
```

## 5. Fix Bottlenecks

For each identified bottleneck:

1. **Classify severity:** Critical (measured impact > 20%) | Important (10-20%) | Minor (< 10%)
2. **Apply the minimal fix** — don't refactor, just optimize
3. **Document what changed** — before/after for each fix

### Common Fixes

| Problem | Fix |
|---------|-----|
| Missing image dimensions | Add `width`/`height` attributes |
| Missing lazy loading | Add `loading="lazy"` to below-fold images |
| Render-blocking scripts | Add `defer` or `async` attribute |
| Full lodash import | Switch to `import debounce from 'lodash-es/debounce'` |
| N+1 queries | Use JOIN, batch fetch, or eager loading |
| Unbounded queries | Add LIMIT/pagination |
| Missing code splitting | Use `React.lazy()` or dynamic `import()` for heavy routes |

## 6. Verify Improvement

**Re-measure using the same method as baseline.** Compare:

```markdown
## Performance Results

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| LCP | X.Xs | X.Xs | -X% |
| INP | Xms | Xms | -X% |
| CLS | X.XX | X.XX | -X% |
| Bundle size | X KB | X KB | -X% |
| Test time | Xs | Xs | -X% |

### Fixes Applied
1. <file:line> — <what changed> — <measured impact>
2. ...

### Remaining Opportunities
- <issue not fixed and why>
```

**Evidence is mandatory.** Never claim improvement without before/after numbers.

## Anti-Rationalization

| False Logic | Reality Check |
|---|---|
| "It feels faster" | Feelings aren't metrics. Measure with tools, not intuition. |
| "We'll optimize later" | Performance debt compounds. Users leave before "later" arrives. |
| "It's fast enough on my machine" | Your dev machine has 32GB RAM. Test on target hardware. |
| "Premature optimization is evil" | Measurement-first optimization is engineering. Only blind optimization is premature. |
| "The framework handles performance" | Frameworks provide tools, not guarantees. Misuse causes the same bottlenecks. |
| "Bundle size doesn't matter — users have fast internet" | Mobile users on 3G are your largest growth segment. Bundle size always matters. |

## Success Criteria

- [ ] Baseline measurements recorded before any changes
- [ ] Every fix has before/after measurements with specific numbers
- [ ] Core Web Vitals within acceptable ranges (if frontend)
- [ ] No N+1 query patterns in changed code (if backend)
- [ ] Bundle size within budget (if configured in config.yaml)
- [ ] Build still passes after optimizations
- [ ] No behavioral regressions — existing tests still pass

## Examples

### Full performance audit
```
/dx-perf
```
Runs all checks — frontend, backend, bundle. Establishes baseline, identifies bottlenecks, suggests fixes.

### Frontend-only audit
```
/dx-perf frontend
```
Focuses on Core Web Vitals, image optimization, render-blocking resources.

### Bundle analysis only
```
/dx-perf bundle
```
Analyzes bundle size, tree-shaking, code splitting opportunities.

## Troubleshooting

### "No baseline metrics available"
**Cause:** No Lighthouse, no bundle analyzer, no test timing in CI output.
**Fix:** Install measurement tools first, or use file-size checks as a proxy.

### "Core Web Vitals not available"
**Cause:** Chrome DevTools MCP not configured, or no running local instance.
**Fix:** Use static analysis (image dimensions, script attributes, bundle size) as proxy metrics.

## Rules

- **Measure first** — never optimize without a baseline
- **One fix at a time** — apply, measure, verify, then next
- **Evidence required** — every claim needs before/after numbers
- **No behavioral changes** — optimize, don't refactor or add features
- **Respect budgets** — if `build.perf-budget` is configured, enforce it
- **Profile, don't guess** — use actual profiling data to find bottlenecks
