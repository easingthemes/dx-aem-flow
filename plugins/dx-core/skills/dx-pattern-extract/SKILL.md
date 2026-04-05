---
name: dx-pattern-extract
description: Scan completed tickets for recurring patterns and promote to cross-ticket knowledge. Run periodically or after completing several tickets. Creates .ai/graph/nodes/patterns/ entries.
argument-hint: "[--dry-run (preview without writing)]"
model: haiku
effort: low
allowed-tools: ["read", "search", "write"]
---

You scan all completed spec directories for recurring decisions and approaches, then promote patterns that appear in 3+ tickets to `.ai/graph/nodes/patterns/` for cross-ticket knowledge reuse.

## 1. Scan Spec Directories

Find all spec directories with completed work:

```bash
find .ai/specs/ -name "implement.md" -type f 2>/dev/null
```

For each `implement.md` found, read:
- The `## Key Decisions` section (if present) — these are explicit design choices with alternatives
- The `## Approach` section — the overall strategy
- The `## Steps` section — scan step titles and file references for recurring patterns

Also read `research.md` from the same directory (if present):
- The `## Existing Implementation Check` section — which existing code was reused
- The `## Key Findings` section — important discoveries

Skip spec directories that have no `implement.md` or where all steps are still `pending` (ticket not yet worked on).

## 2. Identify Recurring Patterns

Group the extracted decisions and approaches by similarity. Two decisions are "the same pattern" when they share:

- **Same architectural choice** — e.g., "extend existing component" appears in multiple tickets
- **Same file/class pattern** — e.g., multiple tickets modify the same utility or follow the same model class pattern
- **Same technology approach** — e.g., multiple tickets use the same library, config pattern, or API pattern

**Matching heuristics:**
- Decisions that reference the same files or directories
- Decisions with the same "Chosen" approach (even if wording differs)
- Steps that follow the same sequence (e.g., "modify model → update dialog → update template")
- Reused utilities or services that appear in 3+ tickets' Key Findings

**Minimum threshold:** A pattern must appear in **3 or more tickets** to be promoted. Fewer occurrences may be coincidence.

## 3. Check Existing Patterns

Read all existing pattern files:

```bash
find .ai/graph/nodes/patterns/ -name "*.yaml" -type f 2>/dev/null
```

For each existing pattern:
- Check if new tickets should be added to its `tickets:` list
- Update `updated:` timestamp if new evidence found
- Do NOT create duplicates — merge into existing patterns

## 4. Write Pattern Nodes

Read `shared/pattern-schema.md` for the YAML schema.

Create the directory if it doesn't exist:

```bash
mkdir -p .ai/graph/nodes/patterns
```

For each newly identified pattern (3+ tickets, not already captured):

1. Generate a kebab-case topic slug from the pattern title
2. Write `.ai/graph/nodes/patterns/<topic>.yaml` following the schema exactly
3. Set `confidence: medium`, `trust_tier: long-term`
4. Include all tickets that contributed to the pattern

For existing patterns with new ticket evidence:
1. Read the existing YAML
2. Add new ticket entries to `tickets:`
3. Update `updated:` timestamp
4. If tickets count reaches 5+, consider upgrading `confidence` to `high`

### Dry Run Mode

If `--dry-run` is passed as argument:
- Print what patterns would be created/updated
- Do NOT write any files
- Useful for previewing before committing to the graph

## 5. Present Summary

```markdown
## Pattern Extraction Complete

**Specs scanned:** <count>
**Patterns found:** <count new> new, <count updated> updated

### New Patterns
| Pattern | Tickets | Tags |
|---------|---------|------|
| <title> | <count> | <tags> |

### Updated Patterns
| Pattern | New Tickets Added | Total |
|---------|------------------|-------|
| <title> | +<count> | <total> |

### Below Threshold (2 tickets — watching)
| Candidate | Tickets | Notes |
|-----------|---------|-------|
| <description> | <count> | Needs 1 more occurrence |

### Next steps:
- Patterns are now available for `/dx-plan` to reference
- Run `/dx-plan <id>` — it will check patterns automatically
- Review patterns in `.ai/graph/nodes/patterns/` for accuracy
```

## Examples

### First extraction (bootstrapping)
```
/dx-pattern-extract
```
Scans 12 completed specs, finds 3 patterns with 3+ ticket occurrences each. Creates `.ai/graph/nodes/patterns/` with 3 YAML files. Reports 2 candidates below threshold.

### Dry run preview
```
/dx-pattern-extract --dry-run
```
Same analysis but only prints what would be created. No files written.

### Incremental update
```
/dx-pattern-extract
```
After completing 5 more tickets, re-run. Finds 1 new pattern, updates 2 existing patterns with new ticket evidence. Reports updated totals.

## Rules

- **3-ticket minimum** — never promote a pattern with fewer than 3 occurrences
- **No speculation** — only extract patterns from actual completed work, not hypothetical approaches
- **Merge, don't duplicate** — if a pattern already exists, add ticket evidence to it
- **Concrete, not abstract** — patterns must reference specific files, classes, or config keys. "Use existing utilities" is too vague; "Extend `validateField()` in `src/core/scripts/libs/forms.js`" is concrete.
- **Tags for matching** — include enough tags that dx-plan can find relevant patterns by keyword matching against research.md
- **Preserve provenance** — each ticket entry records HOW that ticket used the pattern, not just that it did
- **Idempotent** — running twice produces the same result (no duplicate patterns or ticket entries)
