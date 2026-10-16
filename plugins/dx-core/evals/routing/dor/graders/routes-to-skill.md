---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?dx-dor"'
---

Passes when Claude invoked `dx-dor` (bare or plugin-namespaced). The closing quote in the pattern stops `dx-pr-review` from matching `dx-pr-review-all`.
