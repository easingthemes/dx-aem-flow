---
type: regex
target: { source: file, path: .ai/specs/demo/summary.md }
pattern: 'dispatcher'
flags: i
match: contains
---

Content guard. The dispatcher filter that blocks `.mp4` on publish is the
highest risk in `research.md`. A summary that drops it lost the main finding.
