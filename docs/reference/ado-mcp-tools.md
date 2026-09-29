# ADO MCP tool names (`@azure-devops/mcp` v2.10.0)

v2.9.0 (2026-07-29) consolidated most single-purpose tools into **action-dispatched** tools.
The old names no longer exist — a call to them fails with "tool not found". This table is the
source of truth for skills, agents, templates and pipeline `ALLOWED_TOOLS`.

Extracted from the v2.10.0 package itself (tool schemas registered by `dist/tools/*.js`), not
from docs. Full prefix in skills: `mcp__ado__<tool>` (project-level server, no plugin prefix).

## Old → new

| Old tool (≤ v2.8) | New tool | `action` | Key params (v2.10.0) |
|---|---|---|---|
| `wit_get_work_item` | `wit_work_item` | `get` | `id`, `project`, `fields?`, `expand?` |
| `wit_get_work_items_batch_by_ids` | `wit_work_item` | `get_batch` | `ids`, `project`, `fields?` |
| `wit_list_work_item_comments` | `wit_work_item` | `list_comments` | `workItemId`, `project`, `top?` |
| `wit_add_work_item_comment` | `wit_work_item_comment_write` | `add` | `workItemId`, `project`, `text`, `format?` (`Markdown`\|`Html`) |
| `wit_update_work_item_comment` | `wit_work_item_comment_write` | `update` | `workItemId`, `commentId`, `text`, `format?` |
| `wit_create_work_item` | `wit_work_item_write` | `create` | `project`, `workItemType`, `fields` |
| `wit_update_work_item` | `wit_work_item_write` | `update` | `id`, `updates` |
| `wit_update_work_items_batch` | `wit_work_item_write` | `update_batch` | `batchUpdates` |
| `wit_add_child_work_items` | `wit_work_item_write` | `add_child` | `parentId`, `workItemType`, `items` |
| `wit_link_work_item_to_pull_request` | `wit_work_item_link_write` | `link_to_pull_request` | `workItemId`, `projectId`, `repositoryId`, `pullRequestId` |
| `wit_get_work_item_attachment` | `wit_work_item_attachment` | *(none)* | `attachmentId`, `project?`, `fileName?`, `savePath?` |
| `repo_get_repo_by_name_or_id` | `repo_repository` | `get` | `project`, `repositoryNameOrId` |
| `repo_get_pull_request_by_id` | `repo_pull_request` | `get` | `repositoryId`, `pullRequestId`, `project?`, `includeWorkItemRefs?` |
| `repo_list_pull_requests_by_repo_or_project` | `repo_pull_request` | `list` | `repositoryId?`, `project?`, `status?`, `sourceRefName?`, `targetRefName?`, `top?` |
| `repo_list_pull_requests_by_commits` | `repo_pull_request` | `list_by_commits` | `repository`, `commits`, `project?` |
| `repo_list_pull_request_threads` | `repo_pull_request_thread` | `list` | `repositoryId`, `pullRequestId`, `project?`, `status?` |
| `repo_list_pull_request_thread_comments` | `repo_pull_request_thread` | `list_comments` | `repositoryId`, `pullRequestId`, `threadId` |
| `repo_create_pull_request` | `repo_pull_request_write` | `create` | `repositoryId`, `sourceRefName`, `targetRefName`, `title`, `description?`, `isDraft?`, `workItems?`, `labels?` |
| `repo_update_pull_request` | `repo_pull_request_write` | `update` | `repositoryId`, `pullRequestId`, `title?`, `description?`, `status?`, `autoComplete?` |
| `repo_vote_pull_request` | `repo_pull_request_write` | `vote` | `repositoryId`, `pullRequestId`, `vote` (`Approved`\|`ApprovedWithSuggestions`\|`NoVote`\|`WaitingForAuthor`\|`Rejected`) |
| `repo_create_pull_request_thread` | `repo_pull_request_thread_write` | `create` | `repositoryId`, `pullRequestId`, `content`, `filePath?`, `rightFileStartLine?`, `rightFileEndLine?`, `status?` |
| `repo_reply_to_comment` | `repo_pull_request_thread_write` | `reply` | `repositoryId`, `pullRequestId`, `threadId`, `content` |
| *(thread status change)* | `repo_pull_request_thread_write` | `update_status` | `repositoryId`, `pullRequestId`, `threadId`, `status` |
| `wiki_list_pages` | `wiki` | `list_pages` | `wikiIdentifier`, `project`, `path?` |
| `wiki_get_page` | `wiki` | `get_page` | `wikiIdentifier`, `project`, `path` |
| `wiki_get_page_content` | `wiki` | `get_page_content` | `wikiIdentifier`, `project`, `path` (or `url`) |
| `wiki_create_or_update_page` | `wiki_upsert_page` | *(none)* | `wikiIdentifier`, `path`, `content`, `project?`, `etag?` |
| `wiki_search` | `search_wiki` | *(none)* | `searchText`, `project?` |

## Enum casing

Enums are built from TypeScript enum **keys**, so values are capitalized. The old lowercase
values fail validation before the handler runs:

- `wit_work_item` `expand`: `None|Relations|Fields|Links|All` (not `"all"`/`"relations"`)
- `repo_pull_request` `status`: `NotSet|Active|Abandoned|Completed|All`
- `repo_pull_request_thread[_write]` `status`: `Unknown|Active|Fixed|WontFix|Closed|ByDesign|Pending`

## Output

v2.10.0 wraps every tool result in nonce-delimited `[UNTRUSTED ... CONTENT]` markers. Scripts
that `JSON.parse` tool text must strip them first — see `parseToolText` in
`plugins/dx-core/data/lib/fetch-raw-story.js`.

## Unchanged names

`wit_query` (actions `get|get_results|wiql`), `wit_backlog`, `repo_branch`, `repo_create_branch`,
`repo_file`, `repo_search_commits`, `core_*`, `search_code|search_wiki|search_workitem`,
`pipelines_*`, `testplan_*`, `advsec_*`, `work_*`.
