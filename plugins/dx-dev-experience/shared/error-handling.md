# Error Handling Taxonomy

Skills and agents MUST classify errors before choosing a recovery strategy. Do not retry blindly.

## Error Categories

### TRANSIENT (retryable)

Temporary failures that may resolve on their own. Retry up to 2× with exponential backoff (wait 2s, then 4s). After 2 retries, escalate to user.

| Sub-type | Detection Pattern | Example |
|----------|------------------|---------|
| TIMEOUT | MCP call hangs >30s, `ETIMEDOUT`, `ECONNREFUSED` | AEM MCP unresponsive during restart |
| RATE_LIMITED | HTTP 429, `rate limit exceeded` in output | ADO API throttled |
| RESOURCE | `OutOfMemoryError`, `ENOSPC`, `heap out of memory` | Maven build OOM |

### VALIDATION (fixable)

Code-level issues that an auto-fix attempt can resolve. Attempt ONE fix, then mark step blocked with diagnosis if fix fails.

| Sub-type | Detection Pattern | Example |
|----------|------------------|---------|
| SYNTAX | `SyntaxError`, `ParseError`, compiler exit code ≠ 0 | Missing semicolon, unclosed bracket |
| LINT | `warning`/`error` from eslint/sasslint | Unused variable, wrong indentation |
| TEST | `FAIL` in test output, non-zero exit from test runner | Assertion failure in unit test |

### PERMANENT (escalate immediately)

Fundamental issues that no retry or auto-fix can resolve. Stop immediately with structured error report.

| Sub-type | Detection Pattern | Example |
|----------|------------------|---------|
| MISSING_DEPENDENCY | `command not found`, `MODULE_NOT_FOUND`, tool not in ToolSearch | Node.js not installed, MCP server missing |
| PERMISSION | HTTP 401/403, `Permission denied`, `EACCES` | Wrong credentials, no repo access |
| LOGIC | Step output contradicts plan intent, wrong files modified | Plan says "extend hero" but code creates new component |

## Usage in Skills

When a skill encounters an error:

1. **Classify** — Match error output against detection patterns above
2. **Act** — Follow the category's recovery strategy
3. **Report** — If escalating, include:
   - Error category and sub-type
   - Exact error message (first 3 lines)
   - What was attempted
   - Suggested next action for user

## Example Classification

```
Error output: "java.lang.OutOfMemoryError: Java heap space"
→ Category: TRANSIENT / RESOURCE
→ Action: Retry with `MAVEN_OPTS="-Xmx2048m"`, then escalate

Error output: "error TS2304: Cannot find name 'foo'"
→ Category: VALIDATION / SYNTAX
→ Action: Auto-fix (add import or declaration), then mark blocked

Error output: "bash: mvn: command not found"
→ Category: PERMANENT / MISSING_DEPENDENCY
→ Action: STOP. Report: "Maven not installed. Install: brew install maven"
```
