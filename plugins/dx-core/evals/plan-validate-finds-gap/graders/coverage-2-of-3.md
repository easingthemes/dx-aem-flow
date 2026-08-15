---
type: regex
target: { source: file, path: .ai/specs/demo/validation-report.md }
pattern: '2\s*/\s*3'
match: contains
---

Exact oracle — RECALL. The fixture has 3 requirements and exactly one (R3) is
uncovered, so the report's coverage count must read 2/3.

A run that misses the planted gap reports 3/3 and fails here.
