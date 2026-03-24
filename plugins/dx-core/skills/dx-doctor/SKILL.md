---
name: dx-doctor
description: Check health of all dx workflow files — config, rules, scripts, seed data, MCP, settings. Detects installed plugins and checks each. Use after upgrading plugins or when something seems broken.
argument-hint: "[dx|aem|auto|all]"
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You are a diagnostic tool for the dx workflow setup in a consumer project. You check all init-generated files across all installed plugins, then print a status report with actionable remediation.

**This skill is read-only. Never modify, fix, or create anything.**

## Tool Usage Rules

- **File existence:** Use `Glob` with exact path patterns — never `[ -f ]`, `test -f`, or `ls` in Bash
- **File content:** Use `Read` to read files — never `cat`, `head`, or `diff` in Bash
- **Content comparison:** Read both files with `Read`, compare in-context — never shell `diff`
- **Bash is ONLY for:** `git branch -a` (step 6a) — nothing else in this skill needs Bash
- **Parallel checks:** Call multiple `Glob`/`Read` tools in a single response for efficiency — do not serialize into one Bash command with `&&`/`||`

## 0. Read Configuration & Detect Plugins

Read `.ai/config.yaml`. If it does not exist:
```
✗ FATAL: .ai/config.yaml not found. Run /dx-init first.
```
STOP.

Detect which plugins are configured:
- **dx** — always (config.yaml exists)
- **aem** — `aem:` section present in config.yaml
- **seed-data** — `.ai/project/` directory exists with seed data files
- **auto** — `.ai/automation/infra.json` exists

Parse the argument:
- `dx` — check dx core only
- `aem` — check AEM plugin only
- `seed-data` or `data` — check seed data only
- `auto` — check automation plugin only
- `all` or no argument — check everything

If the user requests a specific plugin that is not configured, report: `⚠ <plugin> plugin not configured. Skipping.`

## 1. dx Core Files

Check existence and validity of every file dx-init generates.

### 1a. Config Structure

Read `.ai/config.yaml` and verify these required keys exist and are non-empty:
- `project.name`
- `project.prefix`
- `scm.provider`
- `scm.org`
- `scm.base-branch`
- `build.command`

Report each: `✓ present` or `✗ MISSING`.

### 1a-ii. Config Version

Read `dx.version` from `.ai/config.yaml`:
- **Missing** → `⚠ dx.version not set — run /dx-upgrade to add version tracking`
- **Older than current plugin version** → `⚠ Config version <version> behind plugin <plugin-version> — run /dx-upgrade`
- **Current** → `✓ dx.version: <version>`

To determine the current plugin version, read `version` from the dx-core plugin.json.

### 1b. Stale project.yaml check

Check for the deprecated adapt-generated profile file `.ai/project.yaml` (NOT `.ai/project/project.yaml` — that's seed data and is checked in section 8):

- Exists → `⚠ DEPRECATED: .ai/project.yaml found. Run /dx-upgrade to migrate fields to config.yaml.`
- Missing → `✓ not present (expected — fields are in config.yaml)`

### 1c. Template-Generated Files

Check existence of:
- `.ai/README.md` → `✓ present` or `✗ MISSING`
- `agent.index.md` (project root) → `✓ present` or `✗ MISSING`
- `.ai/me.md` → `✓ present` or `⚠ missing (optional — created by /dx-init)`

### 1d. Utility Scripts

Find the dx plugin directory by searching for this skill's own location:
```
Glob: "**/skills/dx-doctor/SKILL.md"
```
Navigate up 3 levels from the skill directory to get the dx plugin root.

Compare installed files against plugin source:

| Installed | Plugin Source |
|-----------|-------------|
| `.ai/lib/audit.sh` | `<dx-plugin>/data/lib/audit.sh` |
| `.ai/lib/dx-common.sh` | `<dx-plugin>/data/lib/dx-common.sh` |
| `.ai/lib/pre-review-checks.sh` | `<dx-plugin>/data/lib/pre-review-checks.sh` |
| `.ai/lib/plan-metadata.sh` | `<dx-plugin>/data/lib/plan-metadata.sh` |
| `.ai/lib/gather-context.sh` | `<dx-plugin>/data/lib/gather-context.sh` |
| `.ai/lib/ensure-feature-branch.sh` | `<dx-plugin>/data/lib/ensure-feature-branch.sh` |
| `.ai/lib/queue-pipeline.sh` | `<dx-plugin>/data/lib/queue-pipeline.sh` |
| `.claude/hooks/stop-guard.sh` | `<dx-plugin>/data/hooks/stop-guard.sh` |

For each:
1. If installed file is missing → `✗ MISSING`
2. If installed file exists, Read both files and compare content:
   - Identical → `✓ up to date`
   - Different only in **comment lines** (lines starting with `#`) where the change is a genericized example name (e.g., plugin uses `myai-dedupe` but project uses `kai-dedupe`) → `✓ up to date (project-specific examples)`. Plugin templates use generic placeholder names in code comments; consumer projects replace these with real infrastructure names. This is NOT staleness.
   - Different in **functional code** (non-comment lines) → `⚠ STALE (plugin version updated — run /dx-upgrade)`

### 1e. (Removed — .ai/docs/ no longer managed by plugins)

Plugin documentation is public at https://easingthemes.github.io/dx-aem-flow/

If `.ai/docs/` exists in the project, note: `ℹ .ai/docs/ found — these are no longer synced from plugins. Safe to remove if not project-specific.`

### 1f. Output Templates

Check `.ai/templates/` directory structure and staleness against `<dx-plugin>/data/templates/`:

For each subdirectory (`spec/`, `wiki/`, `ado-comments/`):
1. Check if `.ai/templates/<subdir>/` exists → if not, `✗ MISSING`
2. For each `*.template` file in the plugin source:
   - Check if `.ai/templates/<subdir>/<name>` exists
     - Missing → `✗ MISSING`
   - If exists, Read both and compare:
     - Identical → `✓ up to date`
     - Different → `⚠ stale (plugin template updated — run /dx-upgrade)`

Report count: `Output templates (<N> present, <M> stale, <K> missing out of <T> templates)`

## 2. dx Rule Files

Compare installed rules against plugin templates. The dx plugin templates live at `<dx-plugin>/templates/rules/`.

### 2a. Shared Rules (`.ai/rules/`)

| Installed | Template |
|-----------|----------|
| `.ai/rules/pr-review.md` | `pr-review.md.template` |
| `.ai/rules/pr-answer.md` | `pr-answer.md.template` |
| `.ai/rules/pragmatism.md` | `pragmatism.md.template` |
| `.ai/rules/plan-format.md` | `plan-format.md.template` |

**Note:** If AEM plugin is configured, `pr-review.md` and `pr-answer.md` will have AEM sections appended — this is expected. When comparing, check whether the dx template portion (before the AEM section) matches the template. If only the AEM section differs, report as up to date for dx purposes.

### 2b. Universal Rules (`.claude/rules/`)

| Installed | Template |
|-----------|----------|
| `.claude/rules/reuse-first.md` | `universal-reuse-first.md.template` |

For each rule:
1. Missing → `✗ MISSING`
2. Read both files and compare:
   - Identical (or template portion matches) → `✓ up to date`
   - Different → `⚠ stale (plugin template updated — run /dx-upgrade)`

## 3. MCP Configuration

Read `scm.provider` from config.yaml.

**If `ado`:**
1. Check `.mcp.json` exists → `✓` or `✗ MISSING`
2. If exists, read it and check:
   - Has `mcpServers.ado` entry → `✓` or `✗ MISSING`
   - The `args` array contains the org from `scm.org` → `✓ matches` or `⚠ org mismatch (config: <config-org>, .mcp.json: <mcp-org>)`

**If not `ado`:** Report `— Not ADO, MCP check skipped`

**Security: Never print credentials, tokens, or full args arrays. Only report structure and org name.**

## 4. Settings

Check `.claude/settings.json`:
1. Exists → check for `attribution` key with `commit` and `pr` subkeys
   - Present → `✓ attribution configured`
   - Missing attribution → `⚠ attribution settings missing (run /dx-upgrade)`
2. File missing → `⚠ .claude/settings.json missing`

## 5. .gitignore Coverage

Read `.gitignore` (if it exists). Check for these entries (exact or parent-covering pattern):
- `.ai/specs/` → `✓` or `⚠ NOT in .gitignore`
- `.ai/run-context/` → `✓` or `⚠ NOT in .gitignore`
- `.ai/research/` → `✓` or `⚠ NOT in .gitignore`

If `.gitignore` does not exist → `⚠ no .gitignore found`

## 6. References

Cross-check config values against the filesystem:

### 6a. Base Branch
Run:
```bash
git branch -a 2>/dev/null
```
Check if `scm.base-branch` value appears in the output:
- Found → `✓ branch exists`
- Not found → `⚠ branch '<name>' not found in local or remote branches`

### 6b. Build Tool
Check that the build tool referenced in `build.command` has its config file:
- Contains `mvn` → check `pom.xml` exists
- Contains `npm` or `npx` → check `package.json` exists
- Contains `gradle` → check `build.gradle` or `build.gradle.kts` exists
- Contains `cargo` → check `Cargo.toml` exists
- Contains `go ` → check `go.mod` exists
- Found → `✓ build config found`
- Not found → `⚠ build command uses <tool> but <config-file> not found`

## 6.5. Copilot Files (conditional)

Skip if `.github/agents/` doesn't exist — Copilot was never enabled.

If it exists, check:

### 6.5a. Copilot Agents

Compare installed agents in `.github/agents/` against plugin templates in `<dx-plugin>/templates/agents/`:

For each `*.agent.md.template` in the plugin:
1. Check if `.github/agents/<name>.agent.md` exists
   - Missing → `✗ MISSING`
2. If exists, Read both files and compare content:
   - Identical → `✓ up to date`
   - Different → `⚠ stale (plugin template updated — run /dx-upgrade)`

Report count: `Copilot agents (<N> present, <M> stale, <K> missing out of <T> templates)`

## 7. AEM Plugin (conditional)

Skip if aem plugin not configured or not in scope.

Find the aem plugin directory:
```
Glob: "**/skills/aem-init/SKILL.md"
```
Navigate up 3 levels to get the aem plugin root.

### 7a. Config Keys

Check these keys exist in the `aem:` section:
- `aem.component-path` → `✓` or `✗ MISSING`
- `aem.author-url` → `✓` or `✗ MISSING`

### 7b. AEM Rule Files

Check existence and staleness of AEM rules in `.claude/rules/`. Compare each against `<aem-plugin>/templates/rules/*.template`:

| Installed | Template |
|-----------|----------|
| `.claude/rules/be-components.md` | `be-components.md.template` |
| `.claude/rules/be-sling-models.md` | `be-sling-models.md.template` |
| `.claude/rules/be-testing.md` | `be-testing.md.template` |
| `.claude/rules/fe-clientlibs.md` | `fe-clientlibs.md.template` |
| `.claude/rules/fe-javascript.md` | `fe-javascript.md.template` |
| `.claude/rules/fe-styles.md` | `fe-styles.md.template` |
| `.claude/rules/naming.md` | `naming.md.template` |
| `.claude/rules/accessibility.md` | `accessibility.md.template` |

For each: missing → `✗ MISSING`, content matches → `✓ up to date`, differs → `⚠ stale`.

**Note:** Some rules may have been intentionally deleted by dx-init step 8a (project type filtering). If `.ai/config.yaml` has `project.type: aem-frontend`, expect `be-*.md` files to be absent — report as `— filtered (aem-frontend)` not as missing.

### 7c. AEM Sections in Shared Rules

Read `.ai/rules/pr-review.md` and `.ai/rules/pr-answer.md`. Check each contains an AEM-related section (grep for `## AEM` or `## Sling`):
- Found → `✓ AEM sections present`
- Not found → `⚠ AEM sections missing from <file> (run /dx-upgrade)`

### 7d. Delegation

Print: `→ For component, OSGi, dispatcher, and instance checks, run /aem-doctor`

### 7e. Config Migration Status

Check for legacy config patterns that need migration:

- `aem.repos` section exists in config → `⚠ MIGRATE: aem.repos should be merged into top-level repos:. Run /dx-upgrade or /dx-sync`
- `aem.current-repo` field exists → `⚠ MIGRATE: aem.current-repo is deprecated. Run /dx-upgrade or /dx-sync`
- Top-level `repos:` entries exist but any entry lacks a `path` field → `⚠ repos entries missing path field. Run /dx-upgrade`

## 8. Project Seed Data (conditional)

Skip if `.ai/project/` directory does not exist or not in scope.

### 8a. Seed Data Inventory

Check which seed data files exist in `.ai/project/` and report line counts:

| File | Purpose | Expected |
|------|---------|----------|
| `project.yaml` | Repos, brands, markets, platforms | yes |
| `file-patterns.yaml` | Source file path patterns | yes |
| `content-paths.yaml` | AEM content tree, language defaults | optional |
| `component-index-project.md` | Enriched component catalog | yes |
| `architecture.md` | Rendering pipelines, patterns | yes |
| `features.md` | Domain feature documentation | yes |
| `component-index.md` | Local repo component scan | generated by /aem-init |

For each: exists → `✓ present (<N> lines)`, missing (expected) → `✗ MISSING`, missing (optional) → `⚠ not present (optional)`

### 8b. YAML Validation

For each `.yaml` file in `.ai/project/`:
1. Read the file
2. Check for valid YAML syntax (balanced indentation, no duplicate keys visible, no bare tabs)
3. For `project.yaml`: verify `platforms[].id` values are referenced by at least one entry in `repos[]` or `brands[].markets[]`
4. Report: `✓ valid` or `⚠ syntax issues: <details>`

### 8c. AEM Rule Files (from aem plugin templates)

Check existence and staleness in `.claude/rules/`. Compare against `<aem-plugin>/templates/rules/`:

| Installed | Template |
|-----------|----------|
| `.claude/rules/audit.md` | `audit.md.template` |
| `.claude/rules/qa-basic-auth.md` | `qa-basic-auth.md.template` |

## 9. Automation Plugin (conditional)

Skip if automation plugin not configured or not in scope.

### 9a. Infrastructure Config

- `.ai/automation/infra.json` exists → `✓` or `✗ MISSING`
- If exists, read it and check:
  - `automationProfile` value → report: `Profile: <full-hub|consumer>` (if field absent, report `Profile: full-hub (legacy — no profile field)`). Treat legacy `pr-only` and `pr-delegation` values as `consumer`.
  - `{{` placeholder remnants — **profile-aware check:**
    1. Find all `{{...}}` placeholders in the file
    2. Determine which pipeline entries are **expected** for this profile:
       - `full-hub`: all pipelines + Lambda + storage + monitoring + apiGateway + webhooks
       - `consumer`: `pr-review`, `pr-answer`, `eval`, `devagent`, `bugfix`, `dod-fix` pipeline entries + `webhooks.pr-answer` (consumers need their own repo-scoped PR Answer hook)
    3. Classify each placeholder:
       - **Relevant to profile** (pipeline ID or config for an expected agent, or `webhooks.pr-answer` for consumers) → `⚠ unresolved`
       - **Hub-only** (pipeline ID or config for agents NOT expected in this profile, or Lambda/storage/monitoring/apiGateway sections, or WI webhook entries for consumers) → `— hub-only (not applicable for consumer)`
    4. Report:
       - If no relevant placeholders remain → `✓ no unresolved placeholders`
       - If relevant placeholders found → `⚠ <N> unresolved placeholders` + list only the relevant ones
       - If hub-only placeholders found → `ℹ <N> hub-only placeholders ignored (not applicable for consumer — these entries belong to the hub project)`
    5. **Legacy detection:** If profile is `consumer` but infra.json contains `lambdas`, `storage`, `monitoring`, or `apiGateway` sections → `⚠ infra.json contains hub-only sections (likely initialized with old plugin). Run /auto-init to re-scaffold with correct profile.` Note: `webhooks.pr-answer` IS expected for consumers (repo-scoped hook) — only WI webhook entries are hub-only.

### 9b. Supporting Files

- `.ai/automation/repos.json` exists and is valid JSON → `✓` or `✗`
- `.ai/automation/policy/pipeline-policy.yaml` exists → `✓` or `✗`

### 9c. Profile-Aware File Checks

Read `automationProfile` from infra.json. Check only files expected for the profile:

- **full-hub:** Expect Lambda handlers, agent steps, and all pipeline YAMLs. Report missing files as `✗`.
- **consumer** (or legacy `pr-only`/`pr-delegation`): Only expect pipeline YAMLs for consumer agents and config files. Do NOT report missing Lambda handlers (`lambda/`), agent step directories (`agents/dor/`, `agents/pr-review/`, `agents/pr-answer/`), or shared libs as errors — these are hub-only files.

### 9d. Delegation

Print: `→ For pipeline, Lambda, and env var checks, run /auto-doctor`

## 10. Print Results

Use this exact format with status indicators:

- `✓` — check passed
- `⚠` — warning (works but attention needed)
- `✗` — error (broken or missing)
- `—` — skipped (not applicable)

```
=== dx Project Doctor ===

Plugins detected: dx, aem, seed-data

dx Core Files                                      Status
─────────────────────────────────────────────────────────
.ai/config.yaml                                    ✓ valid (6 required keys)
  project.name                                     ✓ present
  scm.provider                                     ✓ present
  ...
.ai/project.yaml (deprecated)                      ✓ not present
.ai/README.md                                      ✓ present
agent.index.md                                     ✓ present
.ai/me.md                                          ⚠ missing (optional)
.ai/lib/audit.sh                                   ✓ up to date
.ai/lib/dx-common.sh                               ✓ up to date
.ai/lib/pre-review-checks.sh                       ✓ up to date
.ai/lib/plan-metadata.sh                           ✓ up to date
.ai/lib/gather-context.sh                          ✓ up to date
.ai/lib/ensure-feature-branch.sh                   ✓ up to date
.ai/lib/queue-pipeline.sh                          ✓ up to date
.claude/hooks/stop-guard.sh                        ⚠ STALE
  Plugin version updated — run /dx-upgrade
Docs (8 templates)                                 ✓ 8 present, 0 stale
Output templates (11 templates)                    ✓ 11 present, 0 stale

dx Rule Files                                      Status
─────────────────────────────────────────────────────────
.ai/rules/pr-review.md                             ✓ up to date
.ai/rules/pr-answer.md                             ⚠ stale
  Template updated — run /dx-upgrade
.ai/rules/pragmatism.md                            ✓ up to date
.ai/rules/plan-format.md                           ✓ up to date
.claude/rules/reuse-first.md                       ✓ up to date

MCP Configuration                                  Status
─────────────────────────────────────────────────────────
.mcp.json                                          ✓ ADO MCP configured

Settings                                           Status
─────────────────────────────────────────────────────────
.claude/settings.json                              ✓ attribution configured

.gitignore Coverage                                Status
─────────────────────────────────────────────────────────
.ai/specs/                                         ✓ in .gitignore
.ai/run-context/                                   ⚠ NOT in .gitignore
.ai/research/                                      ✓ in .gitignore

References                                         Status
─────────────────────────────────────────────────────────
Base branch (develop)                              ✓ exists
Build tool (mvn)                                   ✓ pom.xml found

Copilot Files                                      Status
─────────────────────────────────────────────────────────
Copilot agents (14 templates)                      ✓ 14 present, 0 stale
Copilot skills (31 templates)                      ✓ 31 present, 0 stale
Shared files (7 files)                             ✓ 7 present, 0 stale

AEM Plugin                                         Status
─────────────────────────────────────────────────────────
aem: config section                                ✓ valid
  aem.component-path                               ✓ present
  aem.author-url                                   ✓ present
AEM rules (8 files)                                ✓ all present
  be-components.md                                 ⚠ stale
AEM sections in shared rules                       ✓ present
→ For component/OSGi/dispatcher/instance checks, run /aem-doctor

Project Seed Data                                  Status
─────────────────────────────────────────────────────────
.ai/project/                                       ✓ 6 files present
  project.yaml                                     ✓ present (277 lines), valid
  file-patterns.yaml                               ✓ present (119 lines), valid
  content-paths.yaml                               ✓ present (58 lines), valid
  component-index-project.md                       ✓ present (478 lines)
  architecture.md                                  ✓ present (100 lines)
  features.md                                      ✓ present (112 lines)
AEM rules                                          ✓ all present

Automation Plugin                                  Status
─────────────────────────────────────────────────────────
.ai/automation/infra.json                          ✓ valid
  Profile                                          consumer
  Relevant placeholders                            ⚠ 3 unresolved
    {{PR_REVIEW_PIPELINE_ID}}
    {{PR_ANSWER_PIPELINE_ID}}
    {{EVAL_PIPELINE_ID}}
  Hub-only placeholders                            ℹ 8 ignored (hub-only)
.ai/automation/repos.json                          ✓ valid JSON
.ai/automation/policy/pipeline-policy.yaml          ✓ present
→ For pipeline/Lambda/env checks, run /auto-doctor

Summary: 25 passed, 4 warnings, 0 errors
→ Run /dx-upgrade to fix 4 stale/missing items
```

For each warning/error, include a one-line remediation below the status.

## Examples

### Check everything
```
/dx-doctor
```
Detects installed plugins (dx, aem, seed-data, auto), runs all checks, prints status report with pass/warn/error counts.

### Check specific plugin
```
/dx-doctor aem
```
Only checks AEM plugin files — config keys, rule files, AEM sections in shared rules.

### After upgrade
```
/dx-doctor
```
Compares installed files against plugin templates. Reports stale files that need updating via `/dx-upgrade`.

## Troubleshooting

### "FATAL: .ai/config.yaml not found"
**Cause:** Project hasn't been initialized.
**Fix:** Run `/dx-init` to set up the project.

### Many "STALE" warnings after plugin upgrade
**Cause:** Plugin templates have been updated but consumer project files haven't been refreshed.
**Fix:** Run `/dx-upgrade` to update stale files automatically.

### Plugin directory not found
**Cause:** Plugin isn't installed or was installed to a different path.
**Fix:** Check that plugins are installed via `/plugin install`. The skill locates plugins by searching for their skill files.

## Error Handling

- If a plugin directory cannot be found (Glob returns nothing), skip file comparison for that plugin: `⚠ <plugin> plugin directory not found. Cannot compare file versions. Checking existence only.`
- Never fail silently — always report what was skipped and why
- If `.gitignore` doesn't exist, report it but don't treat it as fatal

## Rules

- **Read-only** — never modify, fix, or create anything
- **Config-driven** — read all paths from `.ai/config.yaml`, never hardcode
- **Graceful degradation** — skip checks when plugin is not configured or plugin dir not found
- **Actionable output** — every warning/error suggests a specific fix command
- **Efficient** — check file existence first, then content comparisons; no external service calls
- **Delegate deep checks** — do not duplicate aem-doctor or auto-doctor logic; point to them
- **Compare by content** — Read both files and compare; report "up to date" or "stale"
- **Never expose secrets** — never print credentials, tokens, or full MCP args
