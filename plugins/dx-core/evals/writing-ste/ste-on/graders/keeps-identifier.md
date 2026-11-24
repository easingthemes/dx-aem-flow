---
type: regex
target: { source: file, path: .ai/specs/demo/summary.md }
pattern: 'videoPath'
match: contains
---

Content guard for the "keep identifiers exact" rule. The dialog field name is
`videoPath`. A summary that rewords it ("video path field") fails here.
