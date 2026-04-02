# Provider Support — Provider-Agnostic Flow

## GitHub as tracker/SCM platform

**Added:** 2026-04-02
**Problem:** dx-core currently supports ADO and Jira as work-item trackers. GitHub Issues/Projects is a widely-used alternative but is not supported — users on GitHub-only workflows cannot use dx skills for ticket analysis, PR linking, or work-item queries.
**Scope:** `plugins/dx-core/` — dx-init (tracker selection), dx-req/dx-ticket-analyze (issue reading), dx-pr (PR linking), config.yaml schema (`tracker:` section), MCP server config, templates.
**Done-when:** `grep -r 'github' plugins/dx-core/skills/dx-init/SKILL.md` shows a GitHub option in the tracker selection step; `.ai/config.yaml` schema supports `tracker.type: github`; at least dx-ticket-analyze can read a GitHub issue.
**Approach:** (TBD) — likely needs: GitHub MCP server in .mcp.json, new `tracker.type: github` config option, skill conditionals for GitHub API shapes (issues vs work items, PR model differences). Consider whether GitHub CLI (`gh`) is sufficient or a dedicated MCP server is needed.

## dx-init: skip ADO-specific files when scm.provider != ado

**Added:** 2026-04-02
**Problem:** dx-init unconditionally copies ADO-specific data files to the consumer project regardless of `scm.provider`. GitHub-only users end up with unusable files: `ado-comments/` templates (6 files), `wiki/` templates (2 files referencing "ADO #"), and `audit.sh` (ADO pipeline + AWS Lambda infra). Additionally, spec templates (`explain.md.template`, `research.md.template`, `dod.md.template`) hardcode "ADO #\<id\>" instead of a provider-neutral format.
**Scope:**
- `plugins/dx-core/skills/dx-init/SKILL.md` — Step 4 (directory + file copy) at lines ~158-162
- `plugins/dx-core/data/templates/ado-comments/` — 6 files, skip entirely when provider != ado
- `plugins/dx-core/data/templates/wiki/` — 2 files, skip entirely when provider != ado
- `plugins/dx-core/data/lib/audit.sh` — skip when provider != ado (it wraps `az pipelines` and `aws lambda`)
- `plugins/dx-core/data/templates/spec/explain.md.template` — replace "ADO #\<id\>" with "#\<id\>"
- `plugins/dx-core/data/templates/spec/research.md.template` — replace "ADO #\<id\>" with "#\<id\>"
- `plugins/dx-core/data/templates/spec/dod.md.template` — replace "ADO #\<id\>" with "#\<id\>"
**Done-when:** Running dx-init with `scm.provider: github` in config produces no files under `.ai/templates/ado-comments/` or `.ai/templates/wiki/`, no `.ai/lib/audit.sh`, and spec templates use "#\<id\>" not "ADO #\<id\>". Verify: `grep -r 'ADO #' .ai/templates/spec/` returns no matches.
**Approach:** Add a provider check early in Step 4 of SKILL.md. Gate the copy of `ado-comments/`, `wiki/`, and `audit.sh` behind `if scm.provider == ado`. For spec templates, replace hardcoded "ADO #\<id\>" with a neutral format that works for any provider.

## dx-init: provider-aware scaffolding

**Added:** 2026-04-02
**Problem:** dx-init scaffolds ADO-specific ceremony files unconditionally. Non-ADO users get unusable `ado-comments/`, `wiki/`, `audit.sh`, and `pragmatism.md`. But the core dev flow (req → plan → step → pr) is provider-agnostic — ADO is just one input adapter. dx-init should install the full flow for everyone, but skip ADO-specific ceremony for non-ADO providers.
**Scope:**
- `plugins/dx-core/skills/dx-init/SKILL.md` — Steps 4 (file copy) and 5 (config generation)
- **Always install** (full flow works for all providers):
  - `data/templates/spec/` (7 files) — spec output templates (after making provider-neutral, see #56)
  - `data/lib/dx-common.sh` — find_spec_dir, slugify (used by file-based and ticket-based flows)
  - `data/lib/plan-metadata.sh` — implement.md step parser (used by dx-step coordinator)
  - `data/lib/gather-context.sh`, `data/lib/pre-review-checks.sh` — git/build helpers
  - `rules/` — plan-format, pr-review, pr-answer, pragmatism (pragmatism applies to any requirements source, not just tickets)
- **ADO-only** (skip when `scm.provider != ado`):
  - `data/templates/ado-comments/` (6 files) — ADO work-item comment formats
  - `data/templates/wiki/` (2 files) — ADO wiki page formats
  - `data/lib/audit.sh` — ADO pipeline + AWS Lambda infra audit
**Done-when:** Running dx-init with `scm.provider: github` installs all spec templates, lib scripts, and rules — but no `ado-comments/`, `wiki/`, or `audit.sh`. The full dx-req → dx-pr flow is available.
**Approach:** Combine with #56 (provider-neutral templates). The gate is simple: only copy files under `data/templates/ado-comments/`, `data/templates/wiki/`, and `data/lib/audit.sh` when `scm.provider == ado`.

## dx-req from markdown file instead of ticket

**Added:** 2026-04-02
**Problem:** dx-req currently requires an ADO or Jira ticket ID as input. But ADO/Jira are just the *fetch* step — once requirements are in `explain.md`, the entire downstream flow (dx-plan → dx-step → dx-pr) is already source-agnostic. A markdown file with requirements should be a first-class alternative input, enabling the full dev workflow for any project regardless of tracker.
**Scope:**
- `plugins/dx-core/skills/dx-req/SKILL.md` — currently reads from ADO/Jira MCP tools
- `plugins/dx-core/skills/dx-req-all/SKILL.md` — coordinator that chains dx-req → dx-plan
- `plugins/dx-core/data/lib/dx-common.sh` — `find_spec_dir` uses ticket ID for directory naming
- `plugins/dx-core/data/templates/spec/` — templates reference `<id>` from ticket
**Done-when:** Running `/dx-req path/to/requirements.md` reads the markdown file, creates a spec directory (`.ai/specs/<slug>/`), and produces `explain.md`. Then `/dx-plan`, `/dx-step 1`, `/dx-pr` all work without modification. Full flow, no tracker needed.
**Approach:** Key design decisions:
1. **Input detection:** dx-req already takes an argument. If the argument is a file path (exists on disk, ends in `.md`), treat as file source. If it's a number or ticket ID, use tracker MCP as today.
2. **Spec directory naming:** Use a slug from the filename or first heading. E.g., `add-dark-mode.md` → `.ai/specs/add-dark-mode/`.
3. **Template adaptation:** Replace "Issue #\<id\>" with "Source: \<filename\>" or use a generic "\<title\>" placeholder that works for any source.
4. **Downstream unchanged:** dx-plan, dx-step, dx-pr read from the spec directory by convention — they don't know or care about the original source. Only dx-req needs the new input adapter.
5. **Full flow works including DoR:** dx-dor checks requirements completeness against the DoD/DoR criteria — this is source-agnostic. The only provider-specific part is *where to post* the result. Each skill needs a "post" adapter:
   - ADO: comment on work item via MCP (today)
   - GitHub: comment on issue (future, TODO #55)
   - File: write to spec dir only, no remote post (user reads locally)
6. **Three input adapters** (current + planned):
   - `/dx-req 12345` → fetch from ADO/Jira (today)
   - `/dx-req requirements.md` → read from file (this TODO)
   - `/dx-req #42` → fetch from GitHub Issues (TODO #55, future)
7. **Generalized pattern — fetch vs post:** Every skill that touches a tracker has two provider-specific operations: *fetch* (read ticket/issue) and *post* (write comment/update status). This fetch/post separation is the mental model for making all skills provider-agnostic across four provider families:

   | Provider | Fetch | Post | MCP/Tool |
   |----------|-------|------|----------|
   | **ADO** | Work items | WI comments, ADO wiki | `@azure-devops/mcp` |
   | **Atlassian** | Jira issues | Jira comments, Confluence pages | `atlassian-mcp` |
   | **GitHub** | Issues, PRs | Issue comments | `gh` CLI or MCP (TBD) |
   | **File** | Read `.md` | Write to spec dir only | None |

   The file adapter is the simplest — no MCP, no auth, no API. Makes it a good first implementation that proves the pattern. ADO and Atlassian already work. GitHub is TODO #55.
