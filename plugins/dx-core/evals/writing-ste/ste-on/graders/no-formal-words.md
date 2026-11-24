---
type: regex
target: { source: file, path: .ai/specs/demo/summary.md }
pattern: '\b(utili[sz](e|es|ed|ing|ation)|initiat(e|es|ed|ing)|prior to|leverag(e|es|ed|ing)|facilitat(e|es|ed|ing)|in order to|subsequently|in the event that|by means of|commenc(e|es|ed|ing))\b'
flags: i
match: not_contains
---

Exact oracle for the STE plain-words rule. The fixture is written in a formal
register and uses most of these phrases, so a summary that copies the source
wording fails here.
