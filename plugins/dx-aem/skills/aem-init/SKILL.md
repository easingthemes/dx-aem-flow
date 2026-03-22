---
name: aem-init
description: Configure AEM-specific settings for the dx workflow. Detects AEM project structure, component paths, and brands. Appends aem section to .ai/config.yaml. Run after /dx-init.
argument-hint: "(no arguments — interactive)"
allowed-tools: ["read", "edit", "search", "write", "agent", "AEM/*", "chrome-devtools-mcp/*"]
---

You configure AEM-specific settings by detecting the project structure and appending an `aem:` section to `.ai/config.yaml`.

## Re-run Validation Protocol

**CRITICAL: When aem-init is re-run, EVERY step MUST execute. NEVER stop early.** If the user chooses "Keep as-is" for config, skip to step 6 and continue through ALL remaining steps (6→7→8→9). Each step validates:

| File Category | Re-run Behavior |
|---|---|
| **Config** (aem: section in config.yaml) | Ask: keep / modify / regenerate |
| **Component index** (.ai/project/component-index.md) | Offer to re-scan if stale |
| **Shared rule extensions** (pr-review.md, pr-answer.md AEM sections) | Validate sections exist, re-append if missing |
| **Rule templates** (.claude/rules/be-*.md, fe-*.md) | Compare against plugin template → if template changed and user hasn't customized: update. If user customized: show diff, ask |
| **Copilot instructions** | Read from `.claude/rules/` via `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` — no copies needed |
| **Copilot agents** (.github/agents/AEM*.md) | Compare against plugin template → update silently if changed |

> **Inline execution from dx-init:** When this skill is run inline from `/dx-init` step 7 (AEM auto-chain), skip Copilot-related steps: **8a** (Copilot question), **8e** (AEM Copilot agent templates), and **8f** (copilot-instructions.md update). Also skip **step 9** (Confirm). These are handled by dx-init steps 9 and 10 instead. Set `COPILOT_ENABLED=false` as default — dx-init handles Copilot output separately.

## 1. Check Prerequisites

Check if `.ai/config.yaml` exists. If not: "Run `/dx-init` first to set up the base project config."

Check if `.ai/config.yaml` already has an `aem:` section:
- **If it exists:** Display current AEM config and ask: "AEM config already exists. **(A) Keep as-is**, **(B) Modify**, or **(C) Regenerate**?"
  - If **A**: Say "Config kept. Validating all AEM files..." — then **CONTINUE to step 6** to validate component index, rules, and templates. **DO NOT stop or exit.**
  - If **B/C**: Continue to step 2
- **If it doesn't exist:** Continue to step 2.

## 2. Detect AEM Structure

### 2a. Find Component Path

Search for AEM component definitions using Glob (no Bash needed):

```
Glob: "**/jcr_root/apps/*/components/*/.content.xml"
```

From the results, extract:
- **Component namespace** — e.g., `/apps/myproject/components/content/`
- **Component prefix** — e.g., `myproject` from path patterns
- **Component group** — from `componentGroup` in `.content.xml` files

### 2b. Detect Module Structure

Look for AEM Maven modules:

| Check | Module Type |
|-------|------------|
| `*-core/pom.xml` with `bundle` packaging | Java/OSGi bundle |
| `*-apps/pom.xml` with `content-package` | HTL + dialogs |
| `*-clientlibs*/pom.xml` or `frontend/` | Frontend build |
| `*-config*/pom.xml` | Configuration |
| `*-all*/pom.xml` | Deployable container |

### 2c. Detect Frontend Structure

Look for frontend source locations using Glob (no Bash needed):

```
Glob: "*/frontend/"
Glob: "**/ui.frontend/"
Glob: "**/clientlib.config.js"
Glob: "**/clientlibs/**/.content.xml"
```

### 2d. Detect Brands (multi-brand)

Look for brand directories using Glob (no Bash needed):

```
Glob: "**/brands/clientlibs/*/"
```

## 3. Ask AEM URLs

Ask all four URLs. Author = content editing and dialog testing. Publisher = user-facing website rendering. These are always different instances.

```
**AEM Author URL (local dev)?** Content editing, dialog testing, component configuration. (default: http://localhost:4502)
**AEM Publisher URL (local dev)?** User-facing website rendering. (default: http://localhost:4503)
**Remote Author URL (QA/stage)?** For clickable author links in research output. (leave blank to use dev URL)
**Remote Publisher URL (QA/stage)?** For user-facing verification on QA environment. (leave blank to use dev URL)
```

## 4. Confirm

Present detected values:

```markdown
## Detected AEM Configuration

| Property | Value |
|----------|-------|
| Component Path | `/apps/<prefix>/components/content/` |
| Component Prefix | `<prefix>` |
| Component Group | `<group>` |
| Resource Type Pattern | `<prefix>/components/content/<name>` |
| Java Package | `<package>` (if detected) |
| Frontend Dir | `<path>` |
| Brands | <list or "single-brand"> |
| AEM Author (Dev) | `http://localhost:4502` |
| AEM Publisher (Dev) | `http://localhost:4503` |
| AEM Author (QA) | `<url or "same as dev">` |
| AEM Publisher (QA) | `<url or "same as dev">` |

**Correct?** Type "yes" or tell me what to change.
```

## 5. Append to Config

Append `aem:` section to `.ai/config.yaml`:

```yaml
aem:
  component-path: "/apps/<prefix>/components/content"
  component-prefix: "<prefix>"
  component-group: "<group>"
  resource-type-pattern: "<prefix>/components/content/<name>"
  java-package: "<package>"              # if detected
  frontend-dir: "<path>"                 # if detected
  brands: [<list>]                       # if multi-brand
  author-url: "http://localhost:4502"    # Author — dialog/component editing
  author-url-qa: "<url>"                 # Remote author — clickable links in research output
  publish-url: "http://localhost:4503"   # Publisher — user-facing website
  publish-url-qa: "<url>"               # Remote publisher — user-facing verification on QA
  demo-parent-path: "<path>"             # Parent for AI-created demo pages (e.g., /content/mysite/en/demo)
  # selector: "<exporter-selector>"      # Uncomment if project uses custom selector
```

## 6. Generate Component Index (optional)

Ask: "Scan for existing components and generate `.ai/project/component-index.md`? This helps `/aem-component` and `/dx-ticket-analyze` find files faster."

If yes:
1. Glob for all component `.content.xml` files under the component path
2. Extract: name, title, group, resource type, resourceSuperType
3. Write `.ai/project/component-index.md` as a lookup table (create `.ai/project/` if needed)

## 7. Extend Shared Rules with AEM Patterns

Append AEM-specific focus areas to the shared rules in `.ai/rules/` (installed by dx-init). This ensures both local dx skills and automation agents apply AEM review criteria.

**Idempotent:** check if the section already exists before appending.

### 7a. Extend pr-review.md

If `.ai/rules/pr-review.md` exists:

1. Read the file and check if it contains `## AEM/Sling Patterns` (use Grep tool, not Bash)
2. If NOT found, append:

```markdown

## AEM/Sling Patterns
- Verify Sling Model annotations: correct adaptables, resource types, injection strategies
- Check @Self @Via(ResourceSuperType) delegation patterns
- Validate OSGi service references use proper injection
- Ensure ResourceResolver lifecycle is respected (no leaked resolvers)

## Frontend Patterns
- Check component-loader registration matches class name
- Verify config files externalize DOM selectors and CSS classes
- Check PubSub event usage matches constants from commons/constants/events.js
- Validate SCSS uses @use/@forward (not @import)
```

### 7b. Extend pr-answer.md

If `.ai/rules/pr-answer.md` exists:

1. Read the file and check if it contains `## AEM/Sling Patterns` (use Grep tool, not Bash)
2. If NOT found, append:

```markdown

## AEM/Sling Patterns
- Understand @Self @Via(ResourceSuperType) delegation
- Understand Sling Model injection strategies
- Know when OSGi service patterns are intentional

## Frontend Patterns
- Understand component-loader registration
- Know config externalization patterns
- Understand PubSub event communication
- SCSS uses @use/@forward (not @import)
```

If `.ai/rules/pr-review.md` or `.ai/rules/pr-answer.md` does not exist, skip and note: "Shared rules not found — run `/dx-init` first."

## 8. Copy Convention Templates

Unified convention templates (`templates/rules/`) contain dual frontmatter (`paths:` for Claude Code, `applyTo:` for Copilot CLI). Each template is copied to `.claude/rules/`. Copilot CLI reads rules from this same location via `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` env var (set by `/dx-init` step 9a-bis) — no `.github/instructions/` copies needed.

### 8a. Ask about Copilot support

```
**Support GitHub Copilot CLI?** (default: yes)
If yes:
- AEM Copilot agent definitions are generated in `.github/agents/`
If no:
- No Copilot agents generated
```

Set `COPILOT_ENABLED=true` or `COPILOT_ENABLED=false` based on the answer.

### 8b. Create target directories

Ensure `.claude/rules/` exists. The Write tool creates parent directories automatically, so no explicit mkdir is needed.

### 8c. Copy rule templates to `.claude/rules/`

Use Glob to find template files (no Bash needed):
```
Glob: "<plugin-path>/templates/rules/*.md.template"
```

For each result:

Derive target filename by stripping the `.template` suffix (e.g., `be-sling-models.md.template` → `be-sling-models.md`).

**If `.claude/rules/<target>` already exists:**
Read both the existing file and the plugin template. Compare content:
- **Identical:** Report "validated (up to date)", skip.
- **Template changed, file matches old template:** Update silently — the user hasn't customized it.
- **User has customized (content differs from template):** Show the diff summary and ask: **(A) Keep existing**, **(B) Replace with updated template**, **(C) Write updated as `.template`** (user can diff manually).

**Check for topic overlap (new files only):**
Scan existing `.claude/rules/*.md` — read their frontmatter (`description` and `paths` fields). Compare against the template's `paths` glob and topic (filename prefix: `fe-` or `be-`). If a file with overlapping paths and similar topic exists:

- Show both filenames and their descriptions side-by-side
- Ask: **(A) Skip** (keep existing), **(B) Replace** (overwrite with template), **(C) Write as `.template`** (user can diff manually)

**No conflict:**
1. Copy the file to `.claude/rules/<target>`, stripping the `.template` extension.

> **Note:** `.github/instructions/` copies are no longer generated. Copilot CLI reads rules directly from `.claude/rules/` via `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` env var. Rules with dual frontmatter (`paths:` + `applyTo:`) work in both tools from a single source.

### 8d. (Removed — instruction templates merged into rule templates)

Instruction templates no longer exist as separate files. The unified rule templates in `templates/rules/` contain both `paths:` (Claude Code) and `applyTo:` (Copilot CLI) frontmatter. Step 8c handles both outputs.

### 8e. Copy AEM Copilot agent templates (if Copilot enabled)

Only if the user answered "yes" to Copilot support in step 7a.

Use Glob to find agent template files (no Bash needed):
```
Glob: "<plugin-path>/templates/agents/*.agent.md.template"
```

For each result:

1. Read the template
2. Strip the `.template` suffix from the filename
3. Write to `.github/agents/<AgentName>.agent.md`

**On re-run:** If `.github/agents/<target>` already exists, compare against the plugin template. Update silently if the template has changed (Copilot agents are not user-customized). Report "validated" or "updated".

### 8f. Update copilot-instructions.md (if Copilot enabled and file exists)

If `.github/copilot-instructions.md` exists (generated by `/dx-init`), append an AEM agents section:

```markdown

## AEM Agents

| Agent | Purpose | Invoke |
|-------|---------|--------|
| AEMBefore | Pre-development baseline snapshot | `@AEMBefore <component>` |
| AEMAfter | Post-deployment verification | `@AEMAfter <component>` |
| AEMSnapshot | Component inspection | `@AEMSnapshot <component>` |
| AEMDemo | Dialog screenshot + authoring guide | `@AEMDemo <component>` |
| AEMComponent | Find pages using a component | `@AEMComponent <component>` |
| AEMVerify | Bug verification on AEM | `@AEMVerify <component>` |
```

If the file doesn't exist, skip this step (it means `/dx-init` didn't generate Copilot files).

### 8g. Report results

```markdown
### Convention Files

**Rules** (`.claude/rules/`): <N> written, <N> skipped
<If Copilot enabled:>
**Copilot instructions**: read from `.claude/rules/` via `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` (no copies needed)
**Copilot Agents** (`.github/agents/`): <N> written, <N> skipped
```

## 9. Confirm

```markdown
## AEM Initialized

**Component Path:** `<path>`
**Brands:** <list>
**Config:** `.ai/config.yaml` (aem section appended)

### Next Steps
- `/aem-component <name>` — look up a component's files and pages
- `/aem-snapshot <name>` — capture baseline before development
- `/aem-verify <name>` — verify after deployment
```

## 10. Project Setup (if seed data exists)

Check if `.ai/project/project.yaml` exists. If not, print: "No project.yaml found. To add project knowledge, create `.ai/project/project.yaml`. See docs/authoring/seed-data-guide.md for format." Then skip to step 11.

If project.yaml exists:

### 10a. Brand/Market Selection

1. Read `project.yaml` → `brands[]` list
2. For each brand:
   - If `single-market: true`: auto-confirm this brand and its single market. Report "Auto-confirmed: <brand> (<market>)"
   - Otherwise: Ask via AskUserQuestion: "Which markets are active for **<brand>**? Options: <market codes>. Enter comma-separated codes or 'all'."
3. Store selected brands and market codes

### 10b. Repo Local Paths

1. Read existing `repos:` from `.ai/config.yaml` (written by `/dx-init`)
2. Read `repos[]` from `.ai/project/project.yaml` for platform and ado-project data
3. For each repo in project.yaml NOT already in config `repos:`, add it with `name` and `path` (ask: "Local path for **<repo>**? (default: `../<name>`)")
4. For each repo in config `repos:`, enrich with fields from project.yaml: `platform`, `ado-project`
5. If `path` is missing on any entry, ask: "Local path for **<repo>**? (default: `../<name>`)"
6. Ask for `base-branch` if not set (default: same as `scm.base-branch`)

### 10c. Preferences

Ask via AskUserQuestion (one at a time):
1. "Auto-commit after each plan step? (y/n, default: n)"
2. "Auto-create PR when all steps complete? (y/n, default: n)"
3. "Docs repo URL for seed data refresh? (ADO URL or blank)"

### 10d. Read Defaults

From `project.yaml` → `defaults`:
- `qa-author-url` → write to `aem.author-url-qa`
- `qa-publish-url` → write to `aem.publish-url-qa` (if present)

### 10e. Write Project Config

**Update top-level `repos:` section** (NOT under `aem:`):

For each repo, ensure these fields are present:
```yaml
repos:
  - name: <repo>
    path: <relative-path>
    role: <role>                      # preserved from dx-init
    platform: <platform>              # NEW — from project.yaml
    ado-project: <project>            # NEW — from project.yaml (if different from scm.project)
    base-branch: <branch>             # NEW — user input or scm.base-branch default
```

**Remove `aem.repos` if present** (migrated to top-level `repos:`).
**Remove `aem.current-repo`** (redundant — current repo is implicit).
**Keep `aem.platform`** (quick self-identification for the current repo).

Append/update these fields in the `aem:` section of `.ai/config.yaml`:

```yaml
aem:
  # ... existing aem-init fields (component-path, etc.) ...
  platform: <derived from project.yaml>
  active-brands: [<brands>]
  active-markets: [<market codes>]
  author-url-qa: <url from defaults>
  publish-url-qa: <url from defaults>
  docs-repo: <url>
  auto-commit: <bool>
  auto-pr: <bool>
```

### 10f. Re-run Behavior

If `aem:` section already has project config (`active-brands`, `active-markets`):
- Ask: "Project config already exists. **(A) Keep existing**, **(B) Update**?"
- If **A**: Skip 10a-10e, continue to step 11
- If **B**: Run 10a-10e (overwrites project config, preserves other aem: fields)

**Migration from `aem.repos`:** On re-run, if `.ai/config.yaml` has `aem.repos:` but top-level `repos:` is missing or incomplete, migrate: copy entries from `aem.repos` to top-level `repos:`, mapping `local-path` → `path`. Then remove the `aem.repos` section. Report what was migrated.

## 11. AEM Rule Template Installation

Copy rule templates from the plugin `templates/rules/` directory to `.claude/rules/`:

- `audit.md.template` → `.claude/rules/audit.md` (remote change audit rules)
- `qa-basic-auth.md.template` → `.claude/rules/qa-basic-auth.md` (QA/stage auth credentials)

For `qa-basic-auth`: the rule now reads credentials from env vars first (`QA_BASIC_AUTH_USER` etc.), with `.ai/config.yaml` as legacy fallback. If `project.yaml` defines `defaults.qa-basic-auth`, still substitute into the rule template for backward compatibility.

**On re-run:** Compare existing file against template. If identical: skip. If template changed and user hasn't customized: update silently. If user customized: show diff, ask.

### 11a. Check AEM Environment Variable

Check if `AEM_INSTANCES` is already set in the shell environment:

```bash
echo "$AEM_INSTANCES"
```

1. **If set:** Report: "AEM_INSTANCES detected in shell environment — AEM MCP will use it." Skip to step 12.

2. **If not set:** Print setup instructions:

   ```
   AEM MCP requires the AEM_INSTANCES environment variable.
   Add to your shell profile (~/.bashrc or ~/.zshrc):

     export AEM_INSTANCES="local:http://localhost:4502:admin:admin"

   Format: name:url:user:pass (comma-separated for multiple instances).
   Then restart your terminal or run: source ~/.zshrc

   Alternative: add to .claude/settings.local.json under "env" (Claude Code only, not Copilot CLI).
   ```

3. **Also update `.claude/settings.local.json`** if it exists — add the `AEM_INSTANCES` key as a placeholder so users have a reference of the expected format. Do NOT overwrite existing values:

   ```json
   {
     "env": {
       "AEM_INSTANCES": "local:http://localhost:4502:admin:admin"
     }
   }
   ```

   Report: "Added AEM_INSTANCES placeholder to `.claude/settings.local.json`. Preferred: set in shell profile for both Claude Code and Copilot CLI."

## 12. Summary

```markdown
## AEM Initialized

**Component Path:** `<path>`
**Brands:** <list>
**Active Markets:** <codes>
**Repos:** <count> configured (<count> with local paths)
**Config:** `.ai/config.yaml` (aem section updated)

### Seed Data Status
| File | Status |
|------|--------|
| component-index.md | <generated / exists / skipped> |
| project.yaml | <found / not found> |
| file-patterns.yaml | <found / not found> |
| content-paths.yaml | <found / not found> |
| architecture.md | <found / not found> |
| features.md | <found / not found> |
| component-index-project.md | <found / not found> |

### Next Steps
- `/aem-component <name>` — look up a component's files and pages
- `/aem-refresh` — refresh seed data from docs repo
- `/aem-snapshot <name>` — capture baseline before development
- `/aem-verify <name>` — verify after deployment
```

## Examples

1. `/aem-init` — First run after `/dx-init`. Detects `ui.frontend/src/core/components/` and `ui.frontend/src/brand/components/` directories, identifies brands from the project's component directories, and appends `aem:` section to `.ai/config.yaml` with author URL, publisher URL, component paths, and active markets.

2. `/aem-init` (re-run to update markets) — Detects existing `aem:` section in config. Asks whether to re-detect or update specific values. User updates `active-markets` from `[gb, de]` to `[gb, de, fr]`. Refreshes seed data files in `.ai/project/`.

3. `/aem-init` (with component index scan) — After detecting project structure, asks "Scan AEM for component index?" User confirms. Queries AEM author instance for all components under `/apps/`, builds `component-index-project.md` with component names, resource types, and dialog field counts.

## Troubleshooting

- **"`.ai/config.yaml` not found — run `/dx-init` first"**
  **Cause:** `/aem-init` requires the base config created by `/dx-init`.
  **Fix:** Run `/dx-init` first to create `.ai/config.yaml`, then run `/aem-init` to add the AEM section.

- **Component index scan fails or returns empty**
  **Cause:** AEM author instance is not running or not reachable at the configured URL.
  **Fix:** Start AEM locally or verify `aem.author-url` in `.ai/config.yaml`. The component index is optional — skip it and run `/aem-init` again later when AEM is available.

- **Seed data files missing after init**
  **Cause:** The plugin's `data/` directory doesn't contain seed files for this project, or the copy step was skipped.
  **Fix:** Run `/aem-refresh` to pull seed data from the docs repo or a local path. Check that `.ai/project/` contains `project.yaml`, `file-patterns.yaml`, `content-paths.yaml`, and `architecture.md`.

## Rules

- **Interactive — use AskUserQuestion** — Every question, confirmation, or choice in this skill MUST use the `AskUserQuestion` tool to pause and wait for the user's response. Never proceed past a question without receiving the user's answer first. Present numbered options in the question text, then STOP and wait. Do not batch multiple questions into one message — ask one, wait for the answer, then continue.
- **dx-init required first** — `.ai/config.yaml` must exist before adding AEM config
- **Detect first, ask second** — auto-detect everything possible
- **Append, don't overwrite** — add `aem:` section to existing config
- **Validate on re-run** — every step executes on re-run; validate existing files against plugin templates, smart-update what's outdated, ask when in doubt
- **Component index is optional** — ask before scanning (can be slow for large projects)
- **No hardcoded paths** — detect from the actual project structure
