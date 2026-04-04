# Launch Checklist

Reference file used by `/dx-pr` and `/dx-step-verify`. Skills reference this — do not delete.

## Pre-Launch Domains

### 1. Code Quality
- [ ] Build passes (`build.command` exits 0)
- [ ] Tests pass (`build.test` — zero failures)
- [ ] Lint clean (`build.lint` — zero errors)
- [ ] No debugging artifacts (`console.log`, `debugger`, `TODO`, `FIXME` in production code)
- [ ] No commented-out code blocks
- [ ] Code review completed

### 2. Security
- [ ] No secrets in code or git history
- [ ] Dependencies clean (`npm audit` / `mvn dependency-check` — no critical/high CVEs)
- [ ] Input validated at all entry points
- [ ] Auth + authz on protected endpoints
- [ ] Security headers present (CSP, HSTS, X-Frame-Options)
- [ ] Error messages don't expose internals

### 3. Performance
- [ ] Core Web Vitals acceptable (LCP ≤ 2.5s, INP ≤ 200ms, CLS ≤ 0.1)
- [ ] Bundle size within budget
- [ ] No N+1 query patterns
- [ ] Images optimized (dimensions, lazy loading, srcset)
- [ ] Caching configured for static assets

### 4. Accessibility
- [ ] Keyboard navigation works
- [ ] Screen reader support (headings, alt text, labels)
- [ ] Color contrast ≥ 4.5:1 (WCAG AA)
- [ ] Focus management in modals/overlays

### 5. Infrastructure
- [ ] Environment variables documented
- [ ] Database migrations applied in staging
- [ ] Health check endpoint exists
- [ ] Error monitoring configured
- [ ] Rollback plan documented

### 6. Documentation
- [ ] README updated
- [ ] API docs current (if applicable)
- [ ] Changelog updated
- [ ] ADR exists for architectural changes

## Feature Flag Lifecycle

```
Deploy (flag OFF) → Enable for team → Canary 5% → Gradual increase → 100% → Cleanup (within 2 weeks)
```

Every flag needs an **owner** and **expiration date**. Dead flags are technical debt.

## Staged Rollout Thresholds

| Condition | Action |
|-----------|--------|
| Error rate within 10% of baseline | Advance to next stage |
| Error rate 10-100% above baseline | Hold and investigate |
| Error rate > 2x baseline | **Immediate rollback** |
| P95 latency > 50% above baseline | **Immediate rollback** |

## Post-Deploy Verification (First Hour)

- [ ] Health endpoint returns 200
- [ ] Error monitoring active — no new error patterns
- [ ] Key user flows verified manually
- [ ] Latency within baseline
- [ ] Logs flowing correctly
- [ ] Rollback tested and ready
