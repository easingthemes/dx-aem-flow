---
name: dx-simplify
description: Code simplification — reduce complexity while maintaining exact behavioral equivalence. Applies Chesterton's Fence (understand before changing) and Rule of 500 (replace when simpler). Use when code works but is harder to maintain than necessary.
argument-hint: "[file path or directory (optional — defaults to changed files)]"
model: opus
effort: high
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You reduce code complexity while maintaining exact behavioral equivalence. Every simplification must be proven safe by existing tests.

**Core principle:** Simplification is not refactoring. Refactoring changes structure for future benefit. Simplification removes unnecessary complexity that exists right now.

## 1. Determine Scope

- If a file/directory argument is provided, analyze those files
- Otherwise, analyze files changed since base branch:

```bash
BASE=$(git merge-base $(git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null || echo origin/main) HEAD)
git diff --name-only $BASE..HEAD
```

## 2. Chesterton's Fence

Before changing ANY code, answer: **Why does this complexity exist?**

For each complex section:
1. Read the git log for that section: `git log --oneline -10 -- <file>`
2. Read surrounding comments and commit messages
3. Check if there's a test that specifically tests the complex behavior
4. Check if there's an ADR or design doc explaining the choice

**If you can't explain why it's complex, don't simplify it.** The complexity may be intentional — guarding against an edge case you haven't seen yet.

## 3. Complexity Identification

### Code Smells to Target

| Smell | Indicator | Simplification |
|-------|-----------|----------------|
| Dead code | Unreachable branches, unused functions, commented-out blocks | Remove entirely |
| Unnecessary abstraction | Interface with 1 implementation, wrapper that just delegates | Inline the abstraction |
| Premature generalization | Config for values that never change, factory for 1 type | Replace with direct code |
| Over-engineering | Strategy pattern for 2 options, builder for 3 fields | Replace with simple conditional or constructor |
| Nested complexity | 4+ levels of nesting, chained ternaries | Extract to early returns or named functions |
| Flag arguments | Boolean params that change function behavior | Split into 2 clear functions |
| Zombie code | No commits in 12+ months, no clear owner, failing tests | Deprecate or remove |

### Complexity Metrics

Check for high-complexity areas:

```bash
# Find deeply nested code
Grep: \{.*\{.*\{.*\{ — 4+ levels of nesting

# Find long functions (>50 lines between function declaration and closing brace)
# Check manually by reading suspicious files

# Find god objects (files with >500 lines)
find . -name '*.js' -o -name '*.ts' -o -name '*.java' | xargs wc -l 2>/dev/null | sort -n -r | head -20
```

## 4. Rule of 500

When evaluating whether to simplify:

- **If the simpler version is < 500 characters** of the complex version: simplify
- **If the simpler version requires > 500 characters** of explanation: the complexity may be warranted
- **If 3+ people have asked "why is this complex?"**: simplify regardless

This is a heuristic, not a law. Use judgment.

## 5. Apply Simplifications

For each simplification:

1. **Record the current behavior** — run existing tests, note what passes
2. **Apply the simplification** — minimal structural change
3. **Verify behavioral equivalence** — same tests pass, same outputs
4. **If any test fails, revert** — the simplification broke something

### Safe Simplification Patterns

| Pattern | Before | After |
|---------|--------|-------|
| Early return | Deep nesting with else branches | Guard clauses at top |
| Inline trivial wrapper | `function getX() { return this.x; }` then `obj.getX()` | `obj.x` directly |
| Remove dead code | Commented-out blocks, unused imports | Delete entirely |
| Flatten conditionals | `if (a) { if (b) { if (c) { ... }}}` | `if (a && b && c) { ... }` |
| Replace flag with functions | `process(data, true, false)` | `processWithValidation(data)` |
| Simplify boolean | `if (condition) { return true; } else { return false; }` | `return condition;` |

## 6. Report

```markdown
## Simplification Report

**Files analyzed:** <N>
**Simplifications applied:** <N>
**Lines removed:** <N>
**Tests:** all passing (behavioral equivalence verified)

### Changes Applied

| # | File | What | Lines Removed | Risk |
|---|------|------|---------------|------|
| 1 | `file.js:42` | Removed dead code block (unreachable after L30 guard) | 15 | Low |
| 2 | `utils.js:10` | Inlined trivial wrapper (only 1 call site) | 8 | Low |

### Skipped (Chesterton's Fence)

| # | File | Complexity | Why Kept |
|---|------|------------|----------|
| 1 | `auth.js:55` | Nested try-catch with retry | Commit msg explains: "handles flaky SSO provider" |

### Opportunities for Later
- <items that need broader discussion before simplifying>
```

## Anti-Rationalization

| False Logic | Reality Check |
|---|---|
| "But we might need this flexibility later" | YAGNI. You Aren't Gonna Need It. Remove it now; add it when you actually need it. |
| "The abstraction makes it testable" | If the test requires the abstraction, the abstraction is justified. If not, it's overhead. |
| "It's not hurting anything" | Dead code misleads readers, increases cognitive load, and slows grep/search results. |
| "Removing code is risky" | Keeping unnecessary code is riskier — it gets maintained, tested, and documented forever. |
| "The original author had a reason" | That's Chesterton's Fence — so investigate the reason. If the reason no longer applies, remove. |
| "Three lines is fine, no need for a function" | Correct. Three similar lines is better than a premature abstraction. Don't extract. |

## Success Criteria

- [ ] All existing tests pass after simplification (behavioral equivalence)
- [ ] Build passes
- [ ] Every change has a Chesterton's Fence check documented
- [ ] Net lines removed > 0 (simplification reduces code, never adds)
- [ ] No new abstractions introduced (simplification removes abstractions)
- [ ] Dead code fully removed (not just commented out)

## Examples

### Simplify changed files
```
/dx-simplify
```
Analyzes files changed since base branch, identifies complexity, applies safe simplifications.

### Simplify specific file
```
/dx-simplify src/components/Hero.js
```
Deep analysis of one file for simplification opportunities.

### Simplify directory
```
/dx-simplify src/utils/
```
Scan all files in a directory for dead code, unnecessary abstractions, over-engineering.

## Troubleshooting

### "Tests fail after simplification"
**Cause:** The simplification changed behavior, not just structure.
**Fix:** Revert the change. The complexity was protecting a behavior you didn't see.

### "Can't determine if code is dead"
**Cause:** Dynamic dispatch, reflection, or string-based references.
**Fix:** Skip it — flag as "possibly dead, needs runtime analysis" in the report.

## Rules

- **Understand before changing** — Chesterton's Fence is mandatory, not optional
- **Behavioral equivalence** — tests must pass identically before and after
- **Remove, don't comment out** — dead code is deleted, not commented
- **No new abstractions** — simplification reduces abstractions, never adds them
- **One change at a time** — simplify, test, commit. Then next simplification.
- **Three lines is fine** — don't extract a function for three similar lines. That's premature abstraction.
- **Net negative lines** — a simplification that adds more code than it removes isn't simplification
- **Revert on failure** — if tests fail, the original code was right. Revert immediately.
