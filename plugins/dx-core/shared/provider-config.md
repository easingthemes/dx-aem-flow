# Provider Config Lookup

All skills that call work-item or wiki MCP tools must detect the provider and use the correct tools.

## Provider Detection

1. Read `.ai/config.yaml`
2. Check `tracker.provider` (preferred) or `scm.provider` (legacy fallback):
   - `ado` → Azure DevOps (default, existing behavior)
   - `jira` → Atlassian (Jira for work items, Confluence for wiki)

If neither field is set, default to `ado`.

**Why `tracker.provider`?** Work-item tracking (ADO/Jira) is separate from source-code management (ADO repos/GitHub/Bitbucket). A project can use Jira for tickets but ADO for code repos. `scm.provider` is kept for backward compatibility but `tracker.provider` is the canonical field.

## ADO Configuration

When `tracker.provider = ado`:

- **Organization:** `scm.org`
- **Project:** `scm.project`
- **Repo ID:** `scm.repo-id` (or discover via `mcp__ado__repo_get_repo_by_name_or_id`)
- **Wiki ID:** `scm.wiki-id`
- **Wiki Project:** `scm.wiki-project`

Tool prefix: `mcp__ado__`

See `shared/ado-config.md` for ADO-specific details (URL patterns, comment format rules, cross-repo awareness).

## Jira Configuration

When `tracker.provider = jira`:

- **Jira URL:** `jira.url` (e.g., `https://jira.example.com`)
- **Project Key:** `jira.project-key` (e.g., `PROJ`) — used in JQL queries and issue creation
- **Board ID:** `jira.board-id` (optional — for sprint queries)

Tool prefix: `mcp__atlassian__`

### Jira Tool Reference

| Operation | Tool |
|-----------|------|
| Fetch issue | `mcp__atlassian__jira_get_issue` with `issue_key` |
| Search issues | `mcp__atlassian__jira_search` with JQL query |
| Create issue | `mcp__atlassian__jira_create_issue` |
| Update issue | `mcp__atlassian__jira_update_issue` |
| Add comment | `mcp__atlassian__jira_add_comment` with `issue_key`, `comment` |
| Edit comment | `mcp__atlassian__jira_edit_comment` |
| Get transitions | `mcp__atlassian__jira_get_transitions` |
| Transition issue | `mcp__atlassian__jira_transition_issue` |
| List projects | `mcp__atlassian__jira_get_all_projects` |
| Search fields | `mcp__atlassian__jira_search_fields` |
| Get sprints | `mcp__atlassian__jira_get_sprints_from_board` |
| Link issues | `mcp__atlassian__jira_create_issue_link` |
| Link to epic | `mcp__atlassian__jira_link_to_epic` |
| Get dev info | `mcp__atlassian__jira_get_issue_development_info` |

### Issue Key Format

Jira uses **string keys** like `PROJ-123`, not numeric IDs. Skills must accept both formats:
- Numeric ID → ADO work item (e.g., `2435084`)
- `KEY-123` format → Jira issue (e.g., `PROJ-123`)
- Full URL → parse accordingly:
  - ADO: `https://dev.azure.com/{org}/{project}/_workitems/edit/{id}` → extract numeric ID
  - Jira: `https://{instance}/browse/{KEY-123}` → extract issue key

### Input Detection (for skills that accept both)

```
If argument matches /^[A-Z]+-\d+$/ → Jira issue key
If argument matches /^\d+$/ → could be either; check scm.provider
If argument contains "dev.azure.com" or "visualstudio.com" → ADO
If argument contains "/browse/" → Jira
```

## Confluence Configuration

When `scm.provider = jira` (Confluence is the wiki backend):

- **Confluence URL:** `confluence.url` (e.g., `https://wiki.example.com`)
- **Space Key:** `confluence.space-key` (e.g., `PROJ`)
- **Doc Root:** `confluence.doc-root` (parent page path for generated docs)
- **PR Review Root:** `confluence.pr-review-root` (parent page path for PR reviews)
- **DoR Page Title:** `confluence.dor-page-title` (page title for Definition of Ready checklist)
- **DoD Page Title:** `confluence.dod-page-title` (page title for Definition of Done checklist)

### Confluence Tool Reference

| Operation | Tool |
|-----------|------|
| Search pages | `mcp__atlassian__confluence_search` with CQL query |
| Get page | `mcp__atlassian__confluence_get_page` with `page_id` |
| Get children | `mcp__atlassian__confluence_get_page_children` |
| Create page | `mcp__atlassian__confluence_create_page` with `space_key`, `title`, `body`, `parent_id` |
| Update page | `mcp__atlassian__confluence_update_page` with `page_id`, `title`, `body`, `version_number` |
| Delete page | `mcp__atlassian__confluence_delete_page` |
| Add comment | `mcp__atlassian__confluence_add_comment` |

### Confluence vs ADO Wiki Differences

| Aspect | ADO Wiki | Confluence |
|--------|----------|------------|
| Page ID | Path-based (`/Root/Sprint 42/Page`) | Numeric ID |
| Create | Path creates hierarchy automatically | Must specify `parent_id` |
| Content | Markdown | Confluence Storage Format (XHTML) or wiki markup |
| Versioning | Implicit | Explicit `version_number` on update |
| Space | Wiki ID (GUID) | Space Key (string) |

**Critical:** Confluence `create_page` needs a `parent_id` (numeric). To find it:
1. Search for the parent page: `mcp__atlassian__confluence_search` with CQL `title = "Sprint 42" AND space = "PROJ"`
2. If not found, create the parent page first under the doc root
3. The doc root page ID should be cached in `confluence.doc-root-id` in config, or discovered once per session

## Field Mapping: ADO ↔ Jira

| Concept | ADO Field | Jira Field |
|---------|-----------|------------|
| Title | `fields.System.Title` | `fields.summary` |
| Description | `fields.System.Description` (HTML) | `fields.description` (ADF or wiki markup) |
| Type | `fields.System.WorkItemType` | `fields.issuetype.name` |
| State / Status | `fields.System.State` | `fields.status.name` |
| Assigned To | `fields.System.AssignedTo.displayName` | `fields.assignee.displayName` |
| Priority | `fields.Microsoft.VSTS.Common.Priority` (1-4) | `fields.priority.name` (Highest/High/Medium/Low/Lowest) |
| Tags / Labels | `fields.System.Tags` (semicolon-separated) | `fields.labels[]` (array) |
| Acceptance Criteria | `fields.Microsoft.VSTS.Common.AcceptanceCriteria` (HTML) | Custom field (varies per project — check `jira.acceptance-criteria-field` in config, default: `customfield_10100`) |
| Story Points | `fields.Microsoft.VSTS.Scheduling.StoryPoints` | `fields.story_points` or `fields.customfield_10106` (check `jira.story-points-field`) |
| Sprint | `fields.System.IterationPath` (path string) | `fields.sprint.name` |
| Area / Component | `fields.System.AreaPath` | `fields.components[].name` |
| Parent | `relations[].rel="System.LinkTypes.Hierarchy-Reverse"` → extract ID from URL | `fields.parent.key` |
| Children | `relations[].rel="System.LinkTypes.Hierarchy-Forward"` | `jira_search` with JQL `parent = KEY` |
| Original Estimate | `Microsoft.VSTS.Scheduling.OriginalEstimate` (hours) | `fields.timeoriginalestimate` (seconds) — divide by 3600 |
| Remaining Work | `Microsoft.VSTS.Scheduling.RemainingWork` (hours) | `fields.timeestimate` (seconds) — divide by 3600 |

### Jira Custom Fields

Jira custom field IDs vary per instance. Store mappings in config:

```yaml
jira:
  url: https://jira.example.com
  project-key: PROJ
  custom-fields:
    acceptance-criteria: customfield_10100   # Acceptance Criteria
    story-points: story_points               # or customfield_10106
    business-benefits: customfield_10200     # if applicable
```

Skills should read `jira.custom-fields.<name>` and fall back to defaults if not configured.

### Jira Description Format

Jira Server/Data Center uses **wiki markup** (not ADF). When creating/updating issues:
- Bold: `*text*` (not `**text**`)
- Italic: `_text_`
- Headers: `h1. Title` (not `# Title`)
- Lists: `* item` or `# numbered item`
- Links: `[text|url]`
- Code: `{code}...{code}`

When READING Jira descriptions, the MCP server returns plain text or simplified content — use as-is for raw-story.md.

### Jira Comments

```
mcp__atlassian__jira_add_comment
  issue_key: "PROJ-123"
  comment: "<comment text>"
```

Comments support wiki markup on Server/DC. No `format` parameter needed (unlike ADO which requires `format: "markdown"`).

### Jira Issue Creation

```
mcp__atlassian__jira_create_issue
  project_key: "PROJ"
  issue_type: "Task"          # or "Story", "Bug", "Sub-task"
  summary: "<title>"
  description: "<description>"
  # Additional fields as needed:
  # parent_key: "PROJ-123"   # for Sub-tasks
  # labels: ["frontend"]
  # components: ["hero"]
```

**Sub-task vs child issue:** Jira Server uses "Sub-task" issue type for children. The equivalent of ADO `wit_add_child_work_items` is:
1. Create issues with `issue_type: "Sub-task"` and `parent_key: "<parent issue key>"`
2. Or create regular Tasks and link them: `mcp__atlassian__jira_create_issue_link`

Check `jira.child-issue-type` in config (default: `Sub-task`).

## URL Patterns

### ADO
```
Work items: https://{scm.org}/{scm.project}/_workitems/edit/{id}
PRs: https://{scm.org}/{scm.project}/_git/{REPO}/pullrequest/{id}
```

### Jira
```
Issues: https://{jira.url}/browse/{KEY-123}
Board: https://{jira.url}/secure/RapidBoard.jspa?rapidView={board-id}
```

### Confluence
```
Pages: https://{confluence.url}/display/{SPACE}/{Page+Title}
  or:  https://{confluence.url}/pages/viewpage.action?pageId={id}
```

## Cross-Repo Awareness (Jira)

ADO has per-repo project overrides in `repos:`. Jira projects are typically 1:1 with a project key, but cross-repo stories may reference multiple Jira projects. The `repos:` section can include Jira overrides:

```yaml
repos:
  - name: Backend-Core
    role: backend
    jira-project-key: PLAT     # Override for this repo
```

## Comment Signature Conventions

Both ADO and Jira comments use HTML/markdown signatures to detect duplicates:

| Signature | Used By | ADO Format | Jira Format |
|-----------|---------|------------|-------------|
| `<!-- ai:role:share-plan -->` | dx-req (Phase 5) | HTML comment in markdown | Same (HTML comments work in Jira wiki markup) |
| `[DevPlan] Development Plan` | dx-req (Phase 5) | Visible text | Same |
| `<!-- ai:role:dor-agent -->` | dx-req (Phase 2) | HTML comment | Same |
| `<!-- ai:role:estimation-agent -->` | dx-estimate | HTML comment | Same |
| `<!-- ai:role:triage-agent -->` | dx-bug-triage | HTML comment | Same |
| `<!-- ai:role:verification-agent -->` | dx-bug-verify | HTML comment | Same |

HTML comments are preserved in both ADO markdown and Jira wiki markup — signature detection works identically.
