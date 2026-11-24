---
type: regex
target: { source: file, path: .ai/specs/demo/summary.md }
pattern: '(?:[^\s.!?:;|]+[ \t]+){25}[^\s.!?:;|]+'
match: not_contains
---

Exact oracle for the STE sentence limit (25 words in a description). The
pattern matches 26 words in a row on one line with no `.`, `!`, `?`, `:` or `;`
between them. A newline, a table cell border (`|`) or a dot inside a file name
also ends the run, so the grader can only undercount a sentence. A hit is
always a real long sentence.
