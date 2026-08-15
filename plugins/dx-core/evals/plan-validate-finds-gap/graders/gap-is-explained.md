---
type: llm
focus: { source: file, path: .ai/specs/demo/validation-report.md }
weight: 1
---

The report reviews an implementation plan against three requirements:

- R1 — debounce(fn, ms) delays calls
- R2 — the wrapper exposes .cancel()
- R3 — debounce throws a TypeError when fn is not a function

Only R3 is genuinely uncovered by the plan. R1 and R2 are each covered by a step.

PASS if the report identifies R3 (input validation / the TypeError requirement)
as the uncovered requirement, AND does not claim that R1 or R2 is uncovered.

FAIL if it reports full coverage, if it names R1 or R2 as uncovered, or if it
is so vague that a reader could not tell which requirement is missing.

Judge only the requirement-coverage finding. Ignore scope-creep, dependency,
test-coverage, and reuse remarks — they are out of scope for this rubric.
