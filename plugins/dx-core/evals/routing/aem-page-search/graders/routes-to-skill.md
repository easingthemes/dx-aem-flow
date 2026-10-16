---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?aem-page-search"'
---

Passes when Claude invoked `aem-page-search` (bare or plugin-namespaced). The closing quote in the pattern stops `dx-pr-review` from matching `dx-pr-review-all`.
