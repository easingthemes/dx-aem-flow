# PR Review Report: [{{TICKET_NUMBER}}] - {{TITLE}}

**PR:** [#{{PR_ID}}]({{PR_URL}}) | **Repo:** {{REPO_NAME}}
**Author:** {{PR_AUTHOR}} | **Reviewed by:** {{REVIEWERS}}
**Date:** {{REVIEW_DATE}} | **Status:** {{PR_STATUS}}
**Verdict:** {{VERDICT}}

---

## Summary

{{SUMMARY}}

**Total comments:** {{TOTAL_COMMENTS}} | **Meaningful findings:** {{MEANINGFUL_FINDINGS}}
**Patches proposed:** {{PATCHES_PROPOSED}} | **Fixed:** {{PATCHES_FIXED}} | **Declined:** {{PATCHES_DECLINED}} | **Open:** {{PATCHES_OPEN}}

## Findings by Category

<!-- For each category that has findings, sorted by count descending: -->

### {{CATEGORY}} ({{CATEGORY_COUNT}})

<!-- For each finding in this category: -->
- **{{FILE}}:{{LINE}}** — {{ISSUE_SUMMARY}} *(reviewer: {{COMMENT_AUTHOR}})*
  - Status: {{STATUS}}
  <!-- If patch was proposed: --> - Patch: {{PATCH_OUTCOME}}
  <!-- If author replied with notable response: --> - Author: "{{AUTHOR_RESPONSE}}"

<!-- Categories with 0 findings are OMITTED entirely. -->

## Patch Resolution

<!-- Only include this section if patches were proposed. -->

| # | File | Issue | Patch | Author Action |
|---|------|-------|-------|---------------|
| {{N}} | `{{FILE}}` | {{SHORT_ISSUE}} | Proposed | {{AUTHOR_ACTION}} |

## Review Outcome

- **Final verdict:** {{VERDICT}}
- **Findings breakdown:** {{FINDINGS_BREAKDOWN}}
- **Resolution rate:** {{RESOLUTION_RATE}}
- **Open items:** {{OPEN_ITEMS}}
