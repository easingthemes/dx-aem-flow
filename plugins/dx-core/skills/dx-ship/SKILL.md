---
name: dx-ship
description: Pre-launch checklist and deployment readiness — code quality, security, performance, accessibility, infrastructure, documentation. Use before production deployments or major releases.
argument-hint: "[target environment (optional — default: production)]"
model: sonnet
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You verify deployment readiness across 6 domains and produce a go/no-go report with evidence for each check.

## 1. Load Context

Read `.ai/config.yaml` for:
- `project.type` — determines which checks apply
- `build.command` — full build with tests
- `scm.base-branch` — target branch
- `aem.author-url` / `aem.publish-url` — for AEM projects

If a spec directory is active, read `implement.md` to verify all steps are `done`.

## 2. Pre-Launch Checklist

Run all 6 domains. Each check produces PASS, FAIL, or SKIP (with reason).

### Domain 1: Code Quality

| Check | How | Pass Criteria |
|-------|-----|---------------|
| Build passes | Run `build.command` | Exit code 0 |
| Tests pass | Run `build.test` | Zero failures |
| Lint clean | Run `build.lint` | Zero errors (warnings OK) |
| No debugging artifacts | `Grep: console\.\(log\|debug\|warn\)\|debugger\|TODO\|FIXME\|HACK` in changed files | No matches in production code (test files OK) |
| No commented-out code | `Grep: \/\/.*\(function\|return\|const\|let\|var\|import\)` | No dead code blocks |
| Code review done | Check for `dx-step-verify` output or PR review | Verification exists |

### Domain 2: Security

| Check | How | Pass Criteria |
|-------|-----|---------------|
| No secrets in code | `Grep: password\|secret\|api_key\|token.*=.*['"]` | No hardcoded secrets |
| Dependencies clean | `npm audit` / `mvn dependency-check` | No critical/high CVEs |
| Input validation | Manual check on endpoints | All entry points validated |
| Auth on protected routes | `Grep: @PreAuthorize\|isAuthenticated\|requireAuth` | Protected endpoints have auth |
| Security headers | Check server config | CSP, HSTS, X-Frame-Options present |

### Domain 3: Performance

| Check | How | Pass Criteria |
|-------|-----|---------------|
| Core Web Vitals | Lighthouse or field data | LCP ≤ 2.5s, INP ≤ 200ms, CLS ≤ 0.1 |
| Bundle size | Check dist/ sizes | Within budget or < 250KB gzipped |
| No N+1 queries | `Grep: for.*query\|for.*find\|for.*select` | No queries in loops |
| Images optimized | Check for width/height, lazy loading, srcset | All images have dimensions |
| Caching configured | Check cache headers / CDN config | Static assets have cache headers |

### Domain 4: Accessibility

| Check | How | Pass Criteria |
|-------|-----|---------------|
| Keyboard navigation | Manual test or axe audit | All interactive elements focusable |
| Screen reader support | Check aria-labels, semantic HTML | Headings hierarchy, alt text present |
| Color contrast | WCAG 2.1 AA check | Ratio ≥ 4.5:1 for text |
| Focus management | Check focus traps, focus restore | Modal/dialog focus handled |

If `mcp__plugin_dx-core_axe-mcp-server__` is available, run an automated accessibility audit.

### Domain 5: Infrastructure

| Check | How | Pass Criteria |
|-------|-----|---------------|
| Environment variables set | Check `.env.example` vs deployment config | All required vars documented |
| Database migrations ready | Check migration files | All migrations applied in staging |
| Health check endpoint | `Grep: /health\|/status\|healthCheck` | Endpoint exists and returns 200 |
| Error monitoring | Check for error tracking (Sentry, etc.) | Error reporting configured |
| Rollback plan documented | Check deployment docs | Rollback steps exist |

### Domain 6: Documentation

| Check | How | Pass Criteria |
|-------|-----|---------------|
| README updated | Check for recent changes | Current with feature changes |
| API docs current | Check OpenAPI/Swagger if applicable | Endpoints documented |
| Changelog updated | Check CHANGELOG.md | Entry for this release |
| ADR exists (if architectural change) | Check `.ai/specs/` or `docs/adr/` | Decision documented |

## 3. Feature Flag Lifecycle

If the deployment uses feature flags:

```
Deploy (flag OFF) → Enable for team → Canary 5% → Gradual increase → 100% → Cleanup
```

**Governance requirements:**
- Every flag has an **owner** and **expiration date**
- Cleanup within **2 weeks** of full rollout
- Dead flags (past expiration) are merge-blocking

Check for stale flags:
```bash
Grep: featureFlag|feature_flag|FEATURE_|isEnabled|isFeatureEnabled — count and list
```

## 4. Staged Rollout Thresholds

| Condition | Action |
|-----------|--------|
| Error rate within 10% of baseline | Advance to next stage |
| Error rate 10-100% above baseline | Hold and investigate |
| Error rate > 2x baseline | **Immediate rollback** |
| P95 latency > 50% above baseline | **Immediate rollback** |

## 5. Report

```markdown
## Deployment Readiness: <environment>

**Overall:** ✅ GO / ❌ NO-GO / ⚠️ GO WITH CAVEATS
**Date:** <ISO date>

### Checklist Results

| Domain | Status | Pass | Fail | Skip |
|--------|--------|------|------|------|
| Code Quality | ✅/❌ | N | N | N |
| Security | ✅/❌ | N | N | N |
| Performance | ✅/❌ | N | N | N |
| Accessibility | ✅/❌ | N | N | N |
| Infrastructure | ✅/❌ | N | N | N |
| Documentation | ✅/❌ | N | N | N |

### Blocking Issues
<list of FAIL items that must be resolved>

### Accepted Risks
<list of SKIP or FAIL items with justification>

### Rollback Plan
1. <steps to roll back if issues are detected>

### Post-Deploy Verification (First Hour)
- [ ] Health endpoint returns 200
- [ ] Error monitoring active
- [ ] Key user flows verified manually
- [ ] Latency within baseline
- [ ] No new error patterns in logs
```

## Anti-Rationalization

| False Logic | Reality Check |
|---|---|
| "We tested in staging, production will be fine" | Staging is not production. Different data, traffic, config, and integrations. |
| "It's a small change, no checklist needed" | Small changes cause big outages. The checklist takes 10 minutes; an incident takes hours. |
| "We can hotfix if something breaks" | Hotfixes under pressure introduce more bugs. Ship right the first time. |
| "The rollback plan is obvious" | Under incident stress, nothing is obvious. Write it down now when you're calm. |
| "Feature flags add complexity" | Feature flags decouple deployment from release. The complexity they add is less than the risk they remove. |
| "Friday deploys are fine" | Friday deploys have no buffer for follow-up. Deploy Monday-Wednesday. |

## Success Criteria

- [ ] All 6 domains checked with evidence
- [ ] Zero blocking issues (or explicitly accepted with justification)
- [ ] Rollback plan documented
- [ ] Post-deploy verification checklist ready
- [ ] Feature flags have owners and expiration dates (if applicable)
- [ ] Build passes with full test suite

## Examples

### Pre-production readiness check
```
/dx-ship
```
Runs all 6 domain checks, produces go/no-go report.

### Staging verification
```
/dx-ship staging
```
Same checks but against staging environment configuration.

## Troubleshooting

### Multiple domains failing
**Cause:** Feature isn't ready for deployment.
**Fix:** Address blocking issues first (security > code quality > others). Re-run after fixes.

### "Health endpoint not found"
**Cause:** No health check endpoint in the application.
**Fix:** Create a minimal `/health` endpoint that returns 200 with app version.

## Rules

- **Evidence required** — every PASS needs proof (command output, file reference)
- **No silent skips** — every SKIP needs a reason
- **Security blocks everything** — a security FAIL is always a NO-GO
- **Rollback plan is mandatory** — no deployment without a documented rollback
- **Feature flags expire** — dead flags are technical debt
- **Post-deploy is part of the deployment** — the job isn't done until the first hour passes clean
