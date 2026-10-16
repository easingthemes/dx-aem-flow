---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?aem-verify"'
---

Passes when Claude invoked `aem-verify` (bare or plugin-namespaced). The closing quote in the pattern stops `dx-pr-review` from matching `dx-pr-review-all`.
