---
type: regex
target: { source: file, path: .ai/specs/demo/validation-report.md }
pattern: '[01]\s*/\s*3'
match: not_contains
---

Exact oracle — PRECISION. R1 and R2 are correctly covered and exist as
distractors. A run that invents extra gaps reports 1/3 or 0/3 and fails here.

This is the grader that catches a "validator" which simply flags everything.
Without it, a report claiming all three requirements are uncovered would still
look plausible to a reader.
