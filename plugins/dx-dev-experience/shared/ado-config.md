> **Note:** This file covers ADO-specific configuration only. For multi-provider support (ADO + Jira/Confluence), see `shared/provider-config.md` which includes both backends. New skills should reference `provider-config.md` instead.

# ADO Config Lookup

All skills that call ADO MCP tools must read the project name from config — never hardcode it.

## How to Get ADO Project

1. Read `.ai/config.yaml`
2. Get `scm.org` for the organization URL
3. Get `scm.project` for the ADO project name
4. Get `scm.repo-id` for the repository ID (if set), otherwise discover via MCP

## ADO Constants

- **Organization:** read from `.ai/config.yaml` `scm.org` — NEVER hardcode
- **Project:** read from `.ai/config.yaml` `scm.project` — NEVER hardcode

## URL Patterns

Work items:
```
{scm.org}/{scm.project}/_workitems/edit/{id}
```

Pull requests:
```
{scm.org}/{scm.project}/_git/{REPO}/pullrequest/{id}
```

Source files:
```
{scm.org}/{scm.project}/_git/{REPO}?path=/{FILE_PATH}
```

Replace `{scm.org}` and `{scm.project}` with values from `.ai/config.yaml` (URL-encode project name if it contains spaces).

## MCP Calls

When calling any `mcp__ado__wit_*` or `mcp__ado__repo_*` tool that requires a `project` parameter:

1. **If the user provided a URL** that contains a project (e.g., `https://myorg.visualstudio.com/My%20Project/_git/...`), **always use the project from the URL** — URL-decode it. The URL is the source of truth.
2. **Otherwise**, use the ADO project from `.ai/config.yaml`:
```
project: "<scm.project value>"
```

**Never override a URL-provided project with the config value.** The same repo can exist in multiple ADO projects.

## Work Item Comments — Always Use Markdown Format

When posting comments to work items via `mcp__ado__wit_add_work_item_comment`, **always pass `format: "markdown"`**:

```
mcp__ado__wit_add_work_item_comment
  project: "<project>"
  workItemId: <id>
  text: "<your markdown content>"
  format: "markdown"
```

Without the `format` parameter, ADO renders the comment as plain text — markdown syntax like `**bold**` and `- lists` appears literally instead of being formatted.

PR thread comments (`mcp__ado__repo_create_pull_request_thread`, `mcp__ado__repo_reply_to_comment`) render markdown natively — no `format` parameter needed.

## Wiki Configuration

For skills that post to ADO wiki (e.g., `dx-pr-review-report`, `dx-pr-reviews-report`, `dx-doc-gen`):

- **Wiki ID:** read from `.ai/config.yaml` `scm.wiki-id` — wiki identifier (GUID)
- **Wiki Project:** read from `.ai/config.yaml` `scm.wiki-project` — ADO project that owns the wiki
- **Wiki PR Review Root:** read from `.ai/config.yaml` `scm.wiki-pr-review-root` — parent wiki page path for PR review reports
- **Wiki Doc Root:** read from `.ai/config.yaml` `scm.wiki-doc-root` — parent wiki page path for technical documentation

If any wiki config field is missing, the skill saves the report locally only and stops wiki posting.

## User Identity

For skills that identify the current user (e.g., `dx-pr-reviews-report` mine mode, `dx-pr-review` skip-own-PR check):

```bash
git config user.email
```

This is compared case-insensitively against PR `createdBy.uniqueName` to filter or skip own PRs.

## Cross-Repo Awareness

If `.ai/config.yaml` has a `repos:` section, use it to look up the correct ADO project for other repos:

```yaml
repos:
  - name: My-Backend-Repo
    path: ../My-Backend-Repo
    role: backend
    platform: Legacy
    ado-project: "My Backend Project"  # optional — defaults to scm.project
  - name: My-Frontend-Repo
    path: ../My-Frontend-Repo
    role: frontend
```
