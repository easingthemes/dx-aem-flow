---
type: llm
focus: { source: file, path: .ai/specs/demo/summary.md }
weight: 1
---

The reader of this summary is a developer who reads English as a second
language, at level B1. Judge only how easy the text is to read for that person.

PASS if all of these hold:

- Most sentences carry one idea and are short.
- Most verbs are in active voice, with a named actor.
- The text uses common words. Formal phrases such as "in order to",
  "facilitate", "utilize" or "prior to" are absent or rare.

FAIL if the text has two or more long sentences with several clauses, or if
it reads like formal business prose.

Do not judge accuracy, completeness or formatting. Technical names, file paths
and identifiers count as plain words.
