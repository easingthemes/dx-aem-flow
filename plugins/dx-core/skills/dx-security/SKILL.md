---
name: dx-security
description: Security hardening audit — OWASP Top 10 prevention, secrets scan, dependency audit, input validation, auth review. Use before PR or when handling user input, authentication, or external integrations.
argument-hint: "[scope: 'changes' | 'full' (default: changes)]"
model: opus
effort: high
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You perform a security audit of the codebase, checking for OWASP Top 10 vulnerabilities, secrets exposure, dependency vulnerabilities, and hardening gaps.

## 1. Determine Scope

- **`changes`** (default) — audit only files changed since base branch
- **`full`** — audit the entire codebase

Get the file list:

```bash
# changes mode
BASE=$(git merge-base $(git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null || echo origin/main) HEAD)
git diff --name-only $BASE..HEAD

# full mode
find . -type f \( -name '*.js' -o -name '*.ts' -o -name '*.java' -o -name '*.py' -o -name '*.jsx' -o -name '*.tsx' -o -name '*.xml' -o -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) | grep -v node_modules | grep -v target
```

Read `shared/security-checklist.md` for the full checklist reference.

## 2. Three-Tier Boundary System

### ALWAYS DO (Non-negotiable)

These must be present in every project. Flag if missing:

- [ ] All external input validated at system boundaries (API endpoints, form handlers)
- [ ] Database queries parameterized — no string concatenation with user data
- [ ] Output encoded to prevent XSS (framework auto-escaping enabled)
- [ ] HTTPS for all external communication
- [ ] Passwords hashed with bcrypt/scrypt/argon2 (not MD5/SHA-1)
- [ ] Security headers set: CSP, HSTS, X-Frame-Options, X-Content-Type-Options
- [ ] Session cookies: httpOnly, secure, sameSite
- [ ] Dependency audit clean (`npm audit` / `mvn dependency-check`)

### ASK FIRST (Flag for team review)

These require explicit team decision:

- New authentication flows or authorization logic changes
- Storage of additional sensitive data categories
- New third-party service integrations
- CORS configuration changes
- File upload functionality additions
- Rate limiting or throttling changes
- Permission or role elevation logic

### NEVER DO (Hard blocks)

Flag these as **Critical** — merge-blocking:

- Secrets committed to version control
- Sensitive data in logs (passwords, tokens, card numbers, PII)
- Client-side validation as the only security boundary
- `eval()` or `innerHTML` with untrusted data
- Auth tokens in localStorage (use httpOnly cookies)
- Stack traces exposed to users in production
- Security headers disabled "for convenience"

## 3. OWASP Top 10 Checks

### A01: Broken Access Control
```
Grep: @PreAuthorize|@Secured|authorize|isAuthenticated|hasRole — check auth exists on protected endpoints
```
Flag endpoints without authorization checks. "Always check authorization, not just authentication."

### A02: Cryptographic Failures
```
Grep: MD5|SHA1|sha1|md5|DES|RC4 — weak cryptography
Grep: http:// — unencrypted communication (should be https)
```

### A03: Injection
```
Grep: \+ .*\.(query|execute|sql|raw) — string concatenation in queries
Grep: innerHTML|outerHTML|document\.write|\.html\( — DOM injection
Grep: eval\(|Function\(|setTimeout\(["'] — code injection
```

### A04: Insecure Design
Check for missing rate limiting on auth endpoints, missing CSRF tokens on state-changing operations.

### A05: Security Misconfiguration
```
Grep: Access-Control-Allow-Origin.*\* — overly permissive CORS
Grep: debug.*=.*true|DEBUG.*=.*1 — debug mode in production config
```

### A06: Vulnerable Components
```bash
npm audit --json 2>/dev/null | head -100
mvn dependency-check:check 2>/dev/null | tail -50
```

### A07: Authentication Failures
```
Grep: password.*=.*["']|token.*=.*["']|secret.*=.*["'] — hardcoded credentials
Grep: bcrypt|argon2|scrypt|pbkdf2 — verify proper password hashing exists
```

### A08: Software & Data Integrity
Check for unsigned/unverified downloads, missing SRI attributes on CDN scripts.

### A09: Logging Failures
```
Grep: console\.log.*password|console\.log.*token|log\.(info|debug).*secret — sensitive data in logs
```
Verify security events ARE logged: failed logins, permission denials, input validation failures.

### A10: SSRF
```
Grep: fetch\(|axios\(|http\.get\(|request\( — check if user input flows into URLs
```

## 4. Secrets Scan

Go beyond basic grep — check comprehensively:

```bash
# Check git history for secrets
git log --all --diff-filter=A -- '*.env' '*.pem' '*.key' '*credentials*' '*secret*' 2>/dev/null | head -20

# Check current files
grep -rn 'AKIA[0-9A-Z]\{16\}' . --include='*.{js,ts,java,py,yaml,json,xml}' 2>/dev/null  # AWS keys
grep -rn 'password\s*=\s*["\x27][^"\x27]\{8,\}' . --include='*.{js,ts,java,py,yaml,json,properties}' 2>/dev/null  # Hardcoded passwords
grep -rn 'Bearer [a-zA-Z0-9._-]\{20,\}' . --include='*.{js,ts,java,py}' 2>/dev/null  # Bearer tokens
```

Verify `.env` is in `.gitignore`. Verify `.env.example` has placeholder values only.

## 5. Input Validation Check

For every endpoint or form handler in changed files:
1. Is input validated at the boundary? (schema validation, type checking)
2. Is file upload restricted by MIME type and size?
3. Are SQL/NoSQL queries parameterized?
4. Is HTML output encoded?

## 6. Report

```markdown
## Security Audit: <scope>

**Files scanned:** <N>
**Issues found:** <N critical> / <N important> / <N advisory>

### Critical Issues (merge-blocking)

| # | Category | File | Line | Issue | Fix |
|---|----------|------|------|-------|-----|
| 1 | A03 Injection | `file.js` | L42 | innerHTML with user input | Use textContent or sanitize with DOMPurify |

### Important Issues (should fix before merge)

| # | Category | File | Line | Issue | Fix |
|---|----------|------|------|-------|-----|

### Advisory (team should review)

| # | Category | File | Line | Issue |
|---|----------|------|------|-------|

### Checks Passed
- [ ] No secrets in source or git history
- [ ] Dependencies clean (no critical/high vulnerabilities)
- [ ] Input validated at all entry points
- [ ] Output encoded (XSS prevention)
- [ ] Auth + authz on protected endpoints
- [ ] Security headers present
- [ ] Error messages don't expose internals
```

## Anti-Rationalization

| False Logic | Reality Check |
|---|---|
| "It's an internal tool, security doesn't matter" | Internal systems are primary attack targets — they have the most access and least scrutiny. |
| "We'll add security later" | Retrofitting security costs 10x more than building it in. And "later" means "after the breach." |
| "Nobody would think to try that" | Automated scanners try everything. Your obscure endpoint is in somebody's wordlist. |
| "The framework handles security" | Frameworks provide tools, not guarantees. One `dangerouslySetInnerHTML` undoes all of React's XSS protection. |
| "It's just a prototype" | Prototypes become production. Security debt in prototypes becomes production vulnerabilities. |
| "We have a WAF, it'll catch it" | Defense in depth. The WAF catches known patterns; your custom logic creates unknown ones. |

## Success Criteria

- [ ] All critical issues resolved or explicitly accepted with justification
- [ ] No secrets in source or git history
- [ ] Dependency audit shows no critical/high vulnerabilities
- [ ] User input validated at all entry points in changed files
- [ ] Every protected endpoint enforces auth + authz
- [ ] Security headers present in responses
- [ ] Error messages omit internal details

## Examples

### Audit changed files only
```
/dx-security
```
Scans files changed since base branch for OWASP Top 10 issues, secrets, and dependency vulnerabilities.

### Full codebase audit
```
/dx-security full
```
Comprehensive scan of all source files.

## Troubleshooting

### "npm audit shows 50+ vulnerabilities"
**Cause:** Transitive dependencies with known CVEs.
**Fix:** Run `npm audit fix`. For unfixable ones, check if they're dev-only dependencies (lower risk). Document accepted risks.

### False positive on test fixture
**Cause:** Test files contain dummy passwords/tokens for testing.
**Fix:** Verify the flagged content is not a real secret. If it's a test fixture, add a comment explaining it's intentional.

## Rules

- **Boundary validation** — validate at system boundaries, trust internal code
- **Defense in depth** — never rely on a single layer of security
- **Secrets never in code** — environment variables or secret managers only
- **Parameterize everything** — never concatenate user input into queries or commands
- **Encode output** — prevent XSS at the rendering layer
- **Minimal permissions** — request the least privilege needed
- **Log security events** — failed auth, permission denials, validation failures
- **Don't suppress** — fix the vulnerability, don't add `@SuppressWarnings` or `// nosec`
