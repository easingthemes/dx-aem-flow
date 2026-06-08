# Bitbucket Config Lookup

Skills that interact with Bitbucket pull requests read provider details from `.ai/config.yaml`.

## When This Applies

When `scm.provider` is `bitbucket-cloud` or `bitbucket-dc`.

## Config Fields

### Bitbucket Cloud

```yaml
scm:
  provider: bitbucket-cloud
  org: "myworkspace"              # Bitbucket workspace slug
  bitbucket-token: ""             # App password or OAuth token (or use BITBUCKET_TOKEN env var)
```

### Bitbucket Data Center (Server)

```yaml
scm:
  provider: bitbucket-dc
  org: "MYPROJECT"                # Bitbucket project key (e.g., "PROJ")
  bitbucket-host: "https://bitbucket.example.com"  # DC host URL (no trailing slash)
  bitbucket-token: ""             # Personal access token (or use BITBUCKET_TOKEN env var)
```

## Token Resolution

Read token in this order:
1. `BITBUCKET_TOKEN` environment variable
2. `scm.bitbucket-token` from `.ai/config.yaml`

```bash
TOKEN="${BITBUCKET_TOKEN:-$(grep 'bitbucket-token:' .ai/config.yaml 2>/dev/null | awk '{print $2}' | tr -d '"')}"
[ -z "$TOKEN" ] && echo "ERROR: Bitbucket token not found. Set BITBUCKET_TOKEN env var or scm.bitbucket-token in config." && exit 2
```

## URL Patterns

### Bitbucket Cloud

Pull requests:
```
https://bitbucket.org/{workspace}/{repo-slug}/pull-requests/{id}
```

### Bitbucket DC

Pull requests:
```
https://{host}/projects/{project}/repos/{repo}/pull-requests/{id}
```

## REST API Reference

All requests require the auth header. Set a shell variable before making calls:

```bash
BB_AUTH="-H \"Authorization: Bearer $TOKEN\""
BB_JSON="-H \"Content-Type: application/json\""
```

### Bitbucket Cloud (api.bitbucket.org/2.0)

| Operation | Method | Endpoint |
|---|---|---|
| Get PR | GET | `/2.0/repositories/{workspace}/{repo}/pullrequests/{id}` |
| List PR comments | GET | `/2.0/repositories/{workspace}/{repo}/pullrequests/{id}/comments?pagelen=100` |
| Post PR comment (general) | POST | `/2.0/repositories/{workspace}/{repo}/pullrequests/{id}/comments` |
| Post inline comment | POST | Same — add `inline` block (see below) |
| Reply to comment | POST | Same — add `parent.id` field |
| Approve PR | POST | `/2.0/repositories/{workspace}/{repo}/pullrequests/{id}/approve` |
| Request changes | POST | `/2.0/repositories/{workspace}/{repo}/pullrequests/{id}/request-changes` |
| Remove approval | DELETE | `/2.0/repositories/{workspace}/{repo}/pullrequests/{id}/approve` |
| Get current user | GET | `/2.0/user` |

#### Comment body — general (Cloud)

```json
{"content": {"raw": "<comment text>"}}
```

#### Comment body — inline (Cloud)

```json
{
  "content": {"raw": "<comment text>"},
  "inline": {
    "path": "path/to/file.js",
    "to": 42
  }
}
```

Use `"to"` for the end line. Use `"from"` optionally for the range start (multi-line comment).

#### Reply to existing comment (Cloud)

```json
{
  "content": {"raw": "<reply text>"},
  "parent": {"id": 123}
}
```

#### Key PR fields (Cloud response)

| Field | Path in JSON |
|---|---|
| PR ID | `.id` |
| Title | `.title` |
| Description | `.description` |
| Source branch | `.source.branch.name` |
| Target branch | `.destination.branch.name` |
| State | `.state` (OPEN \| MERGED \| DECLINED) |
| Author display name | `.author.display_name` |
| Author username / slug | `.author.nickname` |
| Author account ID | `.author.account_id` |
| SSH clone URL | `.source.repository.links.clone[] \| select(.name=="ssh") \| .href` |
| HTTPS clone URL | `.source.repository.links.clone[] \| select(.name=="https") \| .href` |

#### Key comment fields (Cloud response `.values[]`)

| Field | Path |
|---|---|
| Comment ID | `.id` |
| Author nickname | `.author.nickname` |
| Comment text | `.content.raw` |
| Inline file | `.inline.path` |
| Inline line | `.inline.to` |
| Parent ID | `.parent.id` (if a reply) |
| Created | `.created_on` |

### Bitbucket DC / Server (REST API 1.0)

Base URL: `{scm.bitbucket-host}/rest/api/1.0`

Store as shell variable: `BASE="{scm.bitbucket-host}/rest/api/1.0"`

| Operation | Method | Endpoint |
|---|---|---|
| Get PR | GET | `/projects/{project}/repos/{repo}/pull-requests/{id}` |
| List PR activities | GET | `/projects/{project}/repos/{repo}/pull-requests/{id}/activities?limit=100` |
| List PR comments | GET | `/projects/{project}/repos/{repo}/pull-requests/{id}/comments?limit=100` |
| Post PR comment (general) | POST | `/projects/{project}/repos/{repo}/pull-requests/{id}/comments` |
| Post inline comment | POST | Same — add `anchor` block (see below) |
| Reply to comment | POST | `/projects/{project}/repos/{repo}/pull-requests/{id}/comments` with `parent.id` |
| Approve PR | POST | `/projects/{project}/repos/{repo}/pull-requests/{id}/approve` |
| Request changes (Needs Work) | PUT | `/projects/{project}/repos/{repo}/pull-requests/{id}/participants/{userSlug}` |
| Get current user info | GET | `/users/{userSlug}` or parse from git config |

#### Comment body — general (DC)

```json
{"text": "<comment text>"}
```

#### Comment body — inline (DC)

```json
{
  "text": "<comment text>",
  "anchor": {
    "line": 42,
    "lineType": "ADDED",
    "fileType": "TO",
    "path": "path/to/file.js"
  }
}
```

`lineType`: `ADDED` (green/new line), `REMOVED` (red/old line), `CONTEXT` (unchanged). Use `ADDED` for inline review comments on new code.
`fileType`: `TO` (new version of the file). Always use `TO` for review comments.

#### Reply to existing comment (DC)

```json
{
  "text": "<reply text>",
  "parent": {"id": 123}
}
```

#### Approval and vote (DC)

Approve:
```bash
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  "$BASE/projects/{project}/repos/{repo}/pull-requests/{id}/approve"
```

Request changes ("Needs Work") — requires the reviewer's user slug (readable from `git config user.name` or a dedicated lookup):
```bash
# Resolve slug from email
USER_SLUG=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "$BASE/users?filter={email}" | jq -r '.values[0].slug')

# Set status to NEEDS_WORK
curl -s -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"user\": {\"name\": \"$USER_SLUG\"}, \"approved\": false, \"status\": \"NEEDS_WORK\"}" \
  "$BASE/projects/{project}/repos/{repo}/pull-requests/{id}/participants/$USER_SLUG"
```

Remove approval:
```bash
curl -s -X DELETE -H "Authorization: Bearer $TOKEN" \
  "$BASE/projects/{project}/repos/{repo}/pull-requests/{id}/approve"
```

#### Key PR fields (DC response)

| Field | Path in JSON |
|---|---|
| PR ID | `.id` |
| Title | `.title` |
| Description | `.description` |
| Source branch | `.fromRef.displayId` |
| Target branch | `.toRef.displayId` |
| State | `.state` (OPEN \| MERGED \| DECLINED \| SUPERSEDED) |
| Author display name | `.author.user.displayName` |
| Author username / slug | `.author.user.name` |
| Author email | `.author.user.emailAddress` |
| SSH clone URL | `.fromRef.repository.links.clone[] \| select(.name=="ssh") \| .href` |

#### Key comment fields (DC response `.values[]`)

| Field | Path |
|---|---|
| Comment ID | `.id` |
| Author slug | `.author.name` |
| Author email | `.author.emailAddress` |
| Comment text | `.text` |
| Inline file | `.anchor.path` |
| Inline line | `.anchor.line` |
| Parent ID | `.parent.id` (if a reply) |
| Created | `.createdDate` (epoch ms) |

## Vote Mapping

| ADO concept | Bitbucket Cloud | Bitbucket DC |
|---|---|---|
| Approved (+10) | POST `/approve` | POST `/approve` |
| ApprovedWithSuggestions (+5) | POST `/approve` | POST `/approve` |
| WaitingForAuthor / changes-requested | POST `/request-changes` | PUT `/participants/{slug}` with `status: NEEDS_WORK` |
| NoVote (0) | DELETE `/approve` (if previously set) | PUT `/participants/{slug}` with `status: UNAPPROVED` |
| Skip voting | (no-op) | (no-op) |

## Idempotency — Duplicate Detection

Before posting, check existing PR comments for the `**[AI Review]` marker:
- **Cloud:** check `.values[].content.raw` for `**[AI Review]`
- **DC:** check `.values[].text` for `**[AI Review]`

For inline dedup, build a set of `(filePath, line)` from existing inline comments:
- **Cloud:** `(.inline.path, .inline.to)` from existing `.values[]`
- **DC:** `(.anchor.path, .anchor.line)` from existing `.values[]`

## Cross-Repo Awareness

When `.ai/config.yaml` has a `repos:` section, individual repos can override workspace/project:

```yaml
repos:
  - name: my-backend
    path: ../my-backend
    role: backend
    bitbucket-workspace: "other-workspace"   # Cloud override
    bitbucket-project: "OTHERPROJ"           # DC project key override
```
