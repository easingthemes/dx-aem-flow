# PR Review Rules

## Confidence-Based Filtering

Only report issues with confidence >= 80. Each finding must include:
- **Confidence score** (0-100)
- **Severity** (Critical / Important / Suggestion)
- **File and line reference**
- **What's wrong and why**
- **Suggested fix** (code snippet when possible)

## Focus Areas

### Critical (must fix)
- Security vulnerabilities (XSS, injection, SSRF, insecure deserialization, secrets in code)
- Data loss risks
- Broken functionality (null pointer, missing null checks on critical paths)
- Race conditions, missing synchronization, deadlocks
- Resource leaks (unclosed streams, missing cleanup, memory leaks)

### Important (should fix)
- Logic errors and off-by-one mistakes
- API misuse (wrong method signatures, deprecated APIs, incorrect framework usage)
- Missing error handling on external calls
- Performance issues (N+1 queries, unnecessary re-renders, large allocations in loops)
- Convention violations that affect maintainability
- Missing or incorrect test coverage for changed logic

### Suggestion (nice to have)
- Code clarity improvements
- Better naming
- Simplification opportunities
- Documentation for non-obvious logic

## Comment Format

Each comment should be:
1. **Specific** — reference the exact line and code
2. **Actionable** — explain what to change, not just what's wrong
3. **Proportionate** — don't nitpick formatting or style preferences
4. **Constructive** — no snark, no "why did you do this?"

## What NOT to Flag

- Style, formatting, naming conventions — linters handle these
- TODOs that are tracked in work items
- Refactoring opportunities unrelated to the PR's purpose
- Missing tests for code that wasn't changed
- Missing comments or documentation
- Minor refactoring opportunities that don't affect correctness
- Nitpicks that are subjective preferences

## Quality Controls

- Maximum 10 findings — prioritize highest severity first
- Each comment MUST be actionable with a specific fix suggestion
- If the code is correct and well-structured, return empty findings and approve
- Prefer "suggestion" over "must-fix" unless the issue would cause a bug in production
- Consider the context: is this a hotfix, feature, refactor? Adjust scrutiny accordingly

## PR Summary

Start with a brief summary:
- What the PR does (1-2 sentences)
- Overall assessment (Approve / Approve with suggestions / Request changes)
- Critical/Important issue count

## Persona

If `.ai/me.md` exists, it shapes the voice of review comments. Structural constraints (confidence filtering, severity levels, comment format, max 10 findings) still apply. Create `.ai/me.md` with `/dx-init` or write it manually.
