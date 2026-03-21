# Implementation Plan Format

## File: implement.md

Plans are saved to `<spec-dir>/implement.md` and track step-by-step execution status.

## Header

```markdown
# Implementation Plan: <title>

**Work Item:** #<ADO-ID>
**Branch:** feature/<id>-<slug>
**Status:** In Progress | Complete

## Requirements Summary
<2-3 sentence summary of what we're building>
```

## Step Format

Each step has a status badge, title, files involved, and description.

```markdown
## Step 1: <Title> [pending]

**Files:**
- Modify: `path/to/file.java`
- Create: `path/to/new-file.java`
- Test: `path/to/test/FileTest.java`

**What:**
<Clear description of what this step does. Specific enough that a developer
with no context can execute it.>

**Verification:**
<How to verify this step worked — test command, expected output, manual check>
```

## Status Badges

- `[pending]` — not started
- `[in-progress]` — currently executing
- `[done]` — completed and verified
- `[blocked]` — failed, needs fix (see error below)
- `[skipped]` — intentionally skipped (with reason)

## Rules

1. **One concern per step** — each step changes one thing (one component, one service, one test file)
2. **Files are explicit** — every step lists the exact files it touches (Modify/Create/Test)
3. **Order matters** — steps execute top to bottom, dependencies flow downward
4. **Tests adjacent to code** — test step immediately follows the code step it verifies
5. **No gold plating** — only steps that implement the requirements, nothing extra
6. **Verification is mandatory** — every step has a way to verify it worked
7. **Build step at the end** — final step is always "build and verify full compilation"

## Status Updates

Skills update step status in-place:
- `/dx-step` changes `[pending]` → `[in-progress]` → `[done]` or `[blocked]`
- `/dx-step-fix` changes `[blocked]` → `[pending]` (with fix applied)
- `/dx-step-heal` adds corrective steps after `[blocked]` steps

## Example

```markdown
## Step 1: Add subtitle field to Hero model [done]

**Files:**
- Modify: `core/src/main/java/com/example/models/HeroImpl.java`
- Test: `core/src/test/java/com/example/models/HeroImplTest.java`

**What:**
Add `@ValueMapValue` field `subtitle` to HeroImpl. Add getter to Hero interface.
Default to empty string when not authored.

**Verification:**
`mvn test -pl core -Dtest=HeroImplTest` — all tests pass
```
