# Comment Format — ADO/Jira Posting

## ADO/Jira Comment Posting

**This step is NOT optional.** Always post the DoR results as a comment on the work item.

### Fetch existing comments

```
mcp__ado__wit_list_work_item_comments
  project: "<ADO project>"
  workItemId: <id>
```

#### If provider = jira

Comments are included in the `jira_get_issue` response. Fetch the issue and search `fields.comment.comments[].body` for the signature:
```
mcp__atlassian__jira_get_issue
  issue_key: "<issue key>"
```

Scan all comments for text containing `[DoRAgent] Definition of Ready Check`.

### Read checkbox state from existing comment

If a `[DoRAgent]` comment exists, parse its checkbox lines to detect BA actions:

- `- [x] **Section**` — BA confirmed this item is addressed (or agent pre-checked it as passing)
- `- [ ] **Section**` — still unchecked — BA has NOT addressed this yet

**Compare against the original post:**
- If a checkbox was `- [ ]` in the original post and is now `- [x]` — BA addressed it
- Track which sections were newly checked as `ba_addressed_sections`

If `ba_addressed_sections` is non-empty:
1. Print: `BA checked <N> items: <list>. Re-fetching story to validate...`
2. Re-fetch the work item via MCP (`mcp__ado__wit_get_work_item`) to get updated content
   - **If provider = jira:** Re-fetch via `mcp__atlassian__jira_get_issue` with the issue key instead.
3. Re-run the scorecard evaluation against the fresh story data
4. Update `dor-report.md` with the new scores
5. Continue to posting (Mode B — update comment)

If no checkboxes changed and report was not regenerated — Mode C (skip).

### Post — three modes

**Mode A — First post (no existing `[DoRAgent]` comment):**

Post the full DoR checklist. Read `.ai/templates/ado-comments/dor-check.md.template` and follow that structure exactly. Use checkboxes (`- [x]` for passing, `- [ ]` for failing/warning) instead of tables. The checklist dynamically reflects whatever wiki-parsed sections are defined — there is no fixed number.

```
mcp__ado__wit_add_work_item_comment
  project: "<ADO project>"
  workItemId: <id>
  comment: "<comment following dor-check.md.template with checkboxes>"
  format: "markdown"
```

#### If provider = jira

```
mcp__atlassian__jira_add_comment
  issue_key: "<issue key>"
  comment: "<comment following dor-check.md.template with checkboxes>"
```

**Mode B — Update (BA checked items OR report regenerated):**

Post a SHORT update comment — do NOT re-post the full checklist. Format:

```markdown
### [DoRAgent] DoR Update

**Score:** <old score> → <new score> (<percentage>%)
**Trigger:** <what changed — e.g., "BA addressed 2 items: Component Details, QA page URL">

#### Resolved
- [x] **Component Details** — now passes (was warning)
- [x] **Content & Testing** — QA URL added

#### Still Missing
- [ ] **Design & Visual** — Figma link still missing node-id

#### Updated Questions
<!-- Only if questions changed -->
- <new or updated question>

---
_[DoRAgent] Update | <ISO date> · <N> items resolved, <M> remaining_
```

**Mode C — No changes (no checkbox changes AND report not regenerated):**

Print `DoR comment already posted to ADO #<id> — no changes detected — skipping` and do NOT post.

### Format rules

- Use `format: "markdown"` — NEVER use `format: "html"`. ADO renders markdown natively.
- **Always use checkboxes** (`- [x]` / `- [ ]`) for DoR items — NEVER use tables. Checkboxes are interactive in ADO and enable the BA collaboration loop.
- The checklist reflects wiki-parsed sections dynamically — do not assume a fixed count. Use `### [DoRAgent]` header for full post, `### [DoRAgent] DoR Update` for updates.
- End with the signature line including action hint: `_[DoRAgent] Run | <date> · Check items above after updating the story, then re-run DoR._`

### On failure

If the ADO/Jira comment fails to post (network error, auth issue), print a warning but do NOT fail the skill:
```
Could not post DoR comment to ADO #<id> — post manually from dor-report.md
```
