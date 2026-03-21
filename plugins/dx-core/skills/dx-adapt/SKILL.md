---
name: dx-adapt
description: Auto-detect project type, structure, build commands, and AEM values. Saves .ai/project.yaml and substitutes real values into installed .claude/rules/. Run after /dx-init and /aem-init. Re-run anytime to refresh detected values.
argument-hint: "[aem-fullstack|aem-frontend|frontend] (optional — auto-detects if omitted)"
disable-model-invocation: true
allowed-tools: ["read", "edit", "search", "write", "agent"]
---

You detect the project's technical profile from source files and save it to `.ai/project.yaml`. Then you substitute the detected values into `.claude/rules/` files (replacing generic placeholders with real project values).

Use ultrathink — project detection requires reading multiple source files and making accurate inferences.

## 0. Check Prerequisites

Read `.ai/config.yaml`. If it doesn't exist: "Run `/dx-init` first." STOP.

Check if `.ai/project.yaml` already exists:
- **If not exists:** Go directly to Phase 1. (This is normal on first run or when called from `dx-init`.)
- **If exists:** Display the current values and ask: **(A) Keep as-is**, **(B) Re-detect** (re-reads source files), **(C) Edit** (re-confirm with current values pre-loaded). If A: skip to Phase 4 (rule substitution only).

## Phase 1: Detect Project Type

### 1a. Auto-detect (or use argument)

If the user provided an argument (`aem-fullstack`, `aem-frontend`, `frontend`), use it. Otherwise detect:

| Check | Type |
|---|---|
| `pom.xml` exists AND contains `com.adobe.cq` or AEM `uber-jar` dependency | `aem-fullstack` |
| `pom.xml` exists AND contains `content-package-maven-plugin` AND no Java source in `src/main/java/` | `aem-frontend` |
| `package.json` exists AND contains `aem-clientlib-generator` or `clientlib.config.js` exists | `aem-frontend` |
| `package.json` exists AND no AEM indicators | `frontend` |
| Only `pom.xml` (no AEM) | `java` |

### 1b. Extract details per project type

**For `aem-fullstack`:**

```bash
# Find Java package root
find . -path "*/src/main/java/*.java" | head -1
# → extract package from first line of that file

# Find component namespace from filter.xml or .content.xml
grep -r "componentGroup" --include="*.xml" -l | head -5

# Find base branch
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'

# Find Maven modules
find . -maxdepth 3 -name "pom.xml" | grep -v "^./pom.xml"
```

Read 2-3 `.content.xml` files with `componentGroup` to extract:
- `componentGroup` — the group name string (e.g., `"MyProject General"`)
- `componentPath` — derive from the file path (e.g., `/apps/myproject/components`)
- `componentSelector` — from `@Exporter` annotation in any Java `@Model` class
- `serviceVendor` — from `@Component(property = "service.vendor=...")` in any Java class
- `dialogPropertyPrefix` — check if dialog XML uses `./data/` nesting or `./` directly
- `rteInheritancePath` — search for `sling:resourceSuperType` containing `rteConfigs`
- `authorPort` — from `pom.xml` properties (default 4502)

Extract build commands from `pom.xml` and `package.json` (if frontend submodule exists):
- `build.full` — `mvn clean install -PautoInstallPackage` (with correct `-pl` if multi-module)
- `build.deploy` — `mvn clean install -PautoInstallPackage -DskipTests` (quick deploy, no tests)
- `build.compile` — frontend compile if `package.json` submodule exists
- `build.test` — `mvn test -pl <core-module>`
- `build.testSingle` — `mvn test -pl <core-module> -Dtest={className}`
- `build.lint` — from `package.json` scripts if frontend submodule exists

Extract modules list from child `pom.xml` files:
```bash
find . -maxdepth 3 -name "pom.xml" ! -path "./pom.xml" \
  -exec grep -l "packaging" {} \; | sort
```
For each, read packaging type: `bundle`, `content-package`, `jar`.

Extract `sourceRoots`, `testRoots`, `componentPaths` from the module paths found.

**For `aem-frontend`:**

Read `package.json` scripts to extract build, lint, test commands.
Read webpack/clientlib config to find component output paths.
No Java extraction needed — omit `aem.javaPackage`, `aem.componentSelector`, etc.

**For `frontend`:**

Read `package.json` for framework, scripts (build, test, lint, dev).
Read `tsconfig.json` if present for TypeScript confirmation.
Read directory structure (`src/`, `app/`, `pages/`, `components/`) for source roots.

### 1c. Git and SCM details

```bash
# Base branch
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'

# Branch prefix from recent branches
git branch -r | grep -E "feature/|bugfix/" | head -5
```

Read `scm.base-branch` from `.ai/config.yaml` as fallback.

## Phase 2: Confirm with User

Print all detected values as a table. Ask: **"Correct? Type 'yes' or correct any values."**

```markdown
## Detected: <project type>

| Property | Value |
|---|---|
| Project Type | <type> |
| Name | <name from config.yaml> |
| Build (full) | `<command>` |
| Build (compile) | `<command or "—">` |
| Test | `<command>` |
| Test (single) | `<pattern>` |
| Lint | `<command or "none">` |
| Base Branch | <branch> |
| Source Roots | <list> |
| Test Roots | <list> |
| Component Paths | <list> |
<AEM-only rows:>
| Java Package | <package> |
| Component Path | <path> |
| Component Group | <group> |
| Selector | <selector or "—"> |
| Service Vendor | <vendor or "—"> |
| Dialog Property Prefix | <prefix> |
| AEM Author Port | <port> |
```

## Phase 3: Save .ai/project.yaml

Write `.ai/project.yaml` with confirmed values:

```yaml
# Auto-detected by /dx-adapt — re-run to regenerate, or edit manually.
# Read-only for most skills. Skills read build commands from here, not config.yaml.

project:
  name: "{{name}}"           # from config.yaml
  type: "{{type}}"           # aem-fullstack | aem-frontend | frontend | java

structure:
  modules:                   # Maven modules (aem-fullstack / aem-frontend only)
    - { name: "core", path: "{{path}}", type: "bundle" }
    - { name: "apps", path: "{{path}}", type: "content-package" }
  sourceRoots:
    - "{{path}}"
  testRoots:
    - "{{path}}"
  componentPaths:
    - "{{path}}"

build:
  full: "{{command}}"
  compile: "{{command}}"     # omit if same as full
  test: "{{command}}"
  testSingle: "{{pattern}}"  # e.g. "mvn test -pl core -Dtest={className}"
  lint: "{{command}}"        # omit if none
  deploy: "{{command}}"      # omit if same as full

conventions:
  baseBranch: "{{branch}}"
  branchPrefix: "{{prefix}}" # feature | feat | fix

# Only present for aem-fullstack and aem-frontend
aem:
  javaPackage: "{{package}}"
  componentPath: "{{path}}"
  componentGroup: "{{group}}"
  componentSelector: "{{selector}}"
  serviceVendor: "{{vendor}}"
  dialogPropertyPrefix: "{{prefix}}"
  rteInheritancePath: "{{path}}"
  authorPort: {{port}}
```

Print: `Saved .ai/project.yaml`

## Phase 4: Update Template-Seeded Files

Re-generate files seeded from plugin templates. These are the plugin's responsibility (not user-customized), so they always reflect the latest template.

### 4a. Regenerate agent.index.md

Read `templates/INDEX.md.template` from the plugin directory. Replace `{{PROJECT_NAME}}` with `project.name` from `.ai/project.yaml` (or `dx.project-name` from `.ai/config.yaml`). Write to `agent.index.md` (project root). Always overwrite.

### 4b. Regenerate .ai/README.md

Read `templates/README.md.template` from the plugin directory. Replace `{{PROJECT_NAME}}` with the project name. Write to `.ai/README.md`. Always overwrite.

### 4c. Re-run scaffold for new static files

Run scaffold.sh to pick up any new rule templates or utilities added since last init:

```bash
bash skills/dx-init/scripts/scaffold.sh
```

Each file is skipped if it already exists — only newly added templates are installed.

## Phase 5: Filter and Verify .claude/rules/

### 5a. Filter rules by project type

| Project Type | Action |
|---|---|
| `aem-fullstack` | Keep all rules. No deletions. |
| `aem-frontend` | Delete all `be-*.md` rules in `.claude/rules/`. Keep `fe-*.md`, `accessibility.md`, `naming.md`. |
| `frontend` | Delete all `be-*.md` and `fe-clientlibs.md` rules. Keep `accessibility.md`, `naming.md`. |
| `java` | Delete all `fe-*.md` rules. Keep `be-*.md`, `accessibility.md`, `naming.md`. |

Use Glob to list matching files, then delete those that don't apply. If no files match the deletion criteria, report "no rules to filter".

### 5b. Verify project values in rules

Read each `.claude/rules/*.md` file that was installed from an aem-init template. Verify that project-specific values from `.ai/project.yaml` are present — not generic placeholders. Check for:

- Java package name (should match `aem.javaPackage` from project.yaml)
- Component path (should match `aem.componentPath`)
- Component group (should match `aem.componentGroup`)

If any file still contains generic examples instead of real project values, substitute them with values from `.ai/project.yaml`. If a file already has correct project-specific values, skip it silently.

## Phase 6: Report

```markdown
## Project Adapted: <name>

**Type:** <type>
**Config:** `.ai/project.yaml` saved

### Rules Updated
<list of .claude/rules/ files modified with substitutions made>
<list of files skipped (already customized)>

### Next Steps
- Review `.ai/project.yaml` — edit and re-run `/dx-adapt` if any values need correction
- `/dx-init` — re-run if base config.yaml needs changes
- `/aem-init` — re-run if AEM rule templates need reinstalling
```

## Examples

1. `/dx-adapt` — First run after `/dx-init`. Scans the codebase to detect 3 brands, 45 components, Node 10 with Gulp build. Writes `project.yaml` with extracted values, then substitutes placeholders in `.claude/rules/` files (e.g., `{{BRANDS}}` becomes the actual brand list, `{{BUILD_COMMAND}}` becomes `npm run build:new`).

2. `/dx-adapt` (re-run after adding a new brand) — Detects existing `project.yaml`, asks whether to re-detect or keep existing values. User chooses re-detect. Finds the new brand directory, updates `project.yaml`, and re-runs Phase 4 substitution to update rules files with the expanded brand list.

3. `/dx-adapt` (AEM project) — Detects AEM project structure during Phase 1. After Phase 3 (project.yaml saved), automatically chains to `/aem-init` to install AEM-specific rules before Phase 4 runs substitution on all rule files including AEM ones.

## Troubleshooting

- **"project.yaml already exists — re-detect or keep?"**
  **Cause:** `/dx-adapt` was run before and detection results are saved.
  **Fix:** Choose "re-detect" if the project structure changed (new components, new brands). Choose "keep" if you only want to re-run the substitution phase (Phase 4) with existing values.

- **Placeholders left in rule files after adaptation**
  **Cause:** The value could not be extracted from the codebase (e.g., no brands found, build tool not recognized).
  **Fix:** Check `project.yaml` for missing values. Fill them in manually and re-run `/dx-adapt` — Phase 4 will substitute using the updated values.

- **Rule file skipped during substitution**
  **Cause:** The rule file has no remaining placeholders (already customized) or was manually edited.
  **Fix:** This is expected behavior — `/dx-adapt` never overwrites user customizations. If you want to re-apply the template, delete the rule file and run `/dx-adapt` again (it will reinstall from the plugin template first).

## Rules

- **Read real source files** — extract values from actual code, not defaults
- **Never overwrite user customizations** — if a rule file has no matching placeholder, skip it
- **Idempotent** — safe to re-run; Phase 0 check skips detection if project.yaml exists (unless user chooses re-detect)
- **Phase 4 is always run** — even if project.yaml already exists, substitution runs on re-run (user may have reinstalled rules)
- **Graceful on missing data** — if a value can't be extracted, leave the placeholder and note it in the report
