# Output Format Registry

Contributor reference for the files skills write and read by convention (no skill loads this file). Spec files live in `.ai/specs/<id>-<slug>/` unless a path is given. Versions are informational — nothing checks them.

All Markdown spec files include provenance frontmatter — see `shared/provenance-schema.md`.

| File | Version | Producer | Required Sections | Validation |
|------|---------|----------|-------------------|------------|
| raw-story.md | 2.1 | dx-req (Phase 1) | Provenance, Title, ADO/Jira Link, Type, State, Description | Title non-empty, link valid URL |
| explain.md | 1.1 | dx-req (Phase 3) | Provenance, Requirements, Acceptance Criteria, Out of Scope | ≥1 requirement, no TBD |
| research.md | 1.1 | dx-req (Phase 4) | Provenance, ≥1 of: Models, Services, Templates, Tests | ≥1 finding, valid paths |
| dor-report.md | 1.0 | dx-req (Phase 2) | Checklist with pass/fail/unclear, Open Questions | ≥1 assessed |
| implement.md | 2.3 | dx-plan | Provenance, Key Decisions (optional), Steps with Status/Files/What/Verification | Valid status values, no dupes |
| share-plan.md | 1.1 | dx-req (Phase 5) | Provenance, Summary, Approach, Scope | Non-technical language |
| triage.md | 1.0 | dx-bug-triage | Component, Scope, Root Cause Hypothesis | Component identified |
| figma-extract.md | 1.0 | dx-figma-extract | Design Tokens, Component Mapping | ≥1 screenshot, tokens present |
| qa.json | 1.1 | aem-qa | `$SPEC_DIR/qa.json` object: storyId, verificationPlan, pagesVerified, screenshots (relative to spec dir), findings[], bugsCreated, verdict, timestamp | No duplicate findings (component + description) |
| aem-before.md | 1.1 | aem-snapshot | Provenance, Dialog Fields, Pages Using Component | ≥1 field documented |
| aem-after.md | 1.1 | aem-verify | Provenance, Dialog Fields, Pages, Comparison, Regressions | ≥1 field documented |
| `.ai/pr-reviews/pr-<id>-findings.md` | 1.0 | dx-pr-review | Provenance, Metadata, Issues, Summary | ≥1 issue or clean verdict |
