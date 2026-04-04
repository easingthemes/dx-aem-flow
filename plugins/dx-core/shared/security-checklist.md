# Security Checklist

Reference checklist used by `/dx-security` and `/dx-step-verify`. Skills reference this — do not delete.

## Pre-Commit Checks

- [ ] No secrets in staged files (`git diff --cached | grep -i "password\|secret\|api_key\|token"`)
- [ ] No `.env` files staged (`git diff --cached --name-only | grep '\.env'`)
- [ ] No private keys staged (`git diff --cached --name-only | grep '\.pem\|\.key\|\.p12'`)

## Input Validation

- [ ] All API endpoints validate input with schema (Zod, Joi, Bean Validation)
- [ ] File uploads restricted by MIME type and size
- [ ] No string concatenation in SQL queries — parameterized only
- [ ] URL parameters decoded and validated before use
- [ ] JSON payloads size-limited

## Authentication & Authorization

- [ ] Protected endpoints check auth AND authz (not just auth)
- [ ] Passwords hashed with bcrypt (12+ rounds) / scrypt / argon2
- [ ] Sessions: httpOnly, secure, sameSite, 24h max expiration
- [ ] Auth tokens NOT in localStorage (use httpOnly cookies)
- [ ] Rate limiting on auth endpoints (10 attempts / 15 min)
- [ ] Failed login attempts logged with IP (not password)

## Output & Headers

- [ ] Content-Security-Policy header set
- [ ] Strict-Transport-Security header set (HSTS)
- [ ] X-Frame-Options: DENY or SAMEORIGIN
- [ ] X-Content-Type-Options: nosniff
- [ ] CORS restricted to known origins (not `*`)
- [ ] Error responses don't include stack traces or internal details
- [ ] Sensitive fields excluded from API responses

## Dependencies

- [ ] `npm audit` / `mvn dependency-check` — no critical/high CVEs
- [ ] Lockfile committed and up to date
- [ ] No dependencies from untrusted registries

## OWASP Top 10 Quick Reference

| # | Category | Check |
|---|----------|-------|
| A01 | Broken Access Control | Auth on every protected endpoint |
| A02 | Crypto Failures | No MD5/SHA1, HTTPS everywhere |
| A03 | Injection | Parameterized queries, no eval() |
| A04 | Insecure Design | CSRF tokens, rate limiting |
| A05 | Misconfiguration | No debug mode, strict CORS |
| A06 | Vulnerable Components | Clean dependency audit |
| A07 | Auth Failures | bcrypt+, session config |
| A08 | Integrity | SRI on CDN scripts, signed artifacts |
| A09 | Logging | Security events logged, no secrets in logs |
| A10 | SSRF | User input never flows directly to URLs |
