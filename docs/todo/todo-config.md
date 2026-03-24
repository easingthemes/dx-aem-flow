# TODO: Consolidate config.yaml and project.yaml

## Merge project.yaml into config.yaml

**Added:** 2026-03-22
**Problem:** `config.yaml` (user-edited, read by every skill) and `project.yaml` (auto-detected by `/dx-adapt`, read by ~10 skills) duplicate data: build commands, component prefix, DAM path, frontend dir. Two files for overlapping config creates confusion about source of truth.
**Scope:**
- `project.yaml` creation: `plugins/dx-core/skills/dx-adapt/SKILL.md`
- `config.yaml` creation: `plugins/dx-core/skills/dx-init/SKILL.md`
- Skills that read `project.yaml` (9 files):
  - `plugins/dx-core/skills/dx-ticket-analyze/SKILL.md`
  - `plugins/dx-core/skills/dx-init/SKILL.md`
  - `plugins/dx-core/skills/dx-doctor/SKILL.md`
  - `plugins/dx-core/skills/dx-help/SKILL.md`
  - `plugins/dx-core/skills/dx-agent-all/SKILL.md`
  - `plugins/dx-core/skills/dx-adapt/SKILL.md`
  - `plugins/dx-aem/skills/aem-init/SKILL.md`
  - `plugins/dx-aem/skills/aem-component/SKILL.md`
  - `plugins/dx-aem/skills/aem-refresh/SKILL.md`

**Done-when:** `grep -rl "project\.yaml" plugins/*/skills/*/SKILL.md` returns no matches AND `config.yaml` has a `project:` section (check: `grep "^project:" plugins/dx-core/templates/config.yaml.template`).

**Duplicated fields:**

| Field | config.yaml | project.yaml |
|-------|------------|-------------|
| Build commands | `build.command/deploy/test/lint/frontend` | `build.full/frontend/serve/lint/lint-js/lint-scss/lint-fix` |
| Component prefix | `aem.component-prefix` | `component.prefix` |
| DAM path | `aem.dam-path` | `output.dam-path` |
| Frontend dir | `aem.frontend-dir` | `source.*` paths |

**Approach:**
1. Add `project:` section to config.yaml schema (type, modules, toolchain, source, output, component)
2. Move granular build commands into `build:` (add lint-js, lint-scss, serve, lint-fix)
3. Remove duplicated fields (keep in config.yaml)
4. Update `/dx-adapt` to write to config.yaml instead of project.yaml
5. Update all 9 skills that read project.yaml
6. Deprecate project.yaml with migration in `/dx-upgrade`

**Risk:** Touches config reading in many skills — needs careful testing. Consumer repos need migration (move project.yaml content into config.yaml).

**Resolved:** 2026-03-24 — project.yaml fields merged into config.yaml (project.type, project.role, toolchain section). Migration via dx-upgrade Step 1b. 9 skills updated to read from config.yaml.

## DoD Checkbox Format

**Added:** 2026-03-23
**Problem:** DoR now uses checkbox format (`- [ ] **Name** \`tag\` — hint`) which is simpler to parse and interactive in ADO. DoD still uses the old 3-column table format (`Criterion | Who checks | What to verify`). Having two formats creates documentation overhead and makes the wiki-format page more complex. Unifying to checkbox format would simplify parsing logic and enable `dx-req-dod` to use the same dynamic wiki parsing as `dx-dor`.
**Scope:**
- `plugins/dx-core/skills/dx-req-dod/SKILL.md` — needs wiki-driven parsing (currently has some hardcoded checks)
- `website/src/pages/contributing/wiki-format.mdx` — currently documents both formats
- `website/src/pages/usage/dor-dod.mdx` — mentions DoD table format
- Consumer wiki pages — DoD pages need migration to checkbox format
**Done-when:** `grep -n "Who checks" plugins/dx-core/skills/dx-req-dod/SKILL.md` returns zero matches AND `grep "checkbox" website/src/pages/contributing/wiki-format.mdx` shows a single unified format for both DoR and DoD.
**Approach:** Follow the dx-dor pattern — extract DoD wiki parsing into a shared reference, migrate DoD wiki pages to checkbox format, update dx-req-dod to parse dynamically.
