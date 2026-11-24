---
type: regex
target: { source: file, path: .ai/specs/demo/summary.md }
pattern: 'reduced[- ]motion'
flags: i
match: contains
---

Content guard. Plain language must not cost facts. The reduced-motion
requirement (R2, risk 3) is in both fixture files, so a correct summary names it.
