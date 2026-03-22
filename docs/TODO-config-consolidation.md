# TODO: Consolidate config.yaml and project.yaml

## Problem

`config.yaml` and `project.yaml` have duplicated data (build commands, component prefix, DAM path, frontend dir). Both are read by different skills, creating confusion about which is the source of truth.

## Current State

### config.yaml (user-edited, read by every skill)
- `dx.version`, `tracker`, `scm.*`, `repos:`, `preferences`, `overrides`
- `build.command`, `build.deploy`, `build.test`, `build.lint`, `build.frontend`
- `aem.*` (URLs, brands, markets, QA auth, wiki paths, component-path, component-prefix, dam-path)

### project.yaml (auto-detected by /dx-adapt, read by ~10 skills)
- `type: aem-frontend` — project type classification
- `modules:` — module names, roles, paths
- `build.*` — MORE granular: full, frontend, serve, lint, lint-js, lint-scss, lint-fix
- `toolchain:` — node version, build tool, css compiler, js transpiler, template engine
- `source:` — detailed path map (core, brand, components, themes, scripts)
- `output:` — dist path, dam-path (duplicated)
- `component:` — prefix (duplicated), base-class, registration pattern

### Duplicated fields
| Field | config.yaml | project.yaml |
|-------|------------|-------------|
| Build commands | `build.command/deploy/test/lint/frontend` | `build.full/frontend/serve/lint/lint-js/lint-scss/lint-fix` |
| Component prefix | `aem.component-prefix` | `component.prefix` |
| DAM path | `aem.dam-path` | `output.dam-path` |
| Frontend dir | `aem.frontend-dir` | `source.*` paths |

## Proposal

Merge `project.yaml` INTO `config.yaml` as a `project:` section. One file, one source of truth.

### Migration path
1. Add `project:` section to config.yaml schema (type, modules, toolchain, source, output, component)
2. Move granular build commands from project.yaml into config.yaml `build:` (add lint-js, lint-scss, serve, lint-fix)
3. Remove duplicated fields (keep in config.yaml, remove from project.yaml)
4. Update /dx-adapt to write to config.yaml instead of project.yaml
5. Update all skills that read project.yaml to read from config.yaml `project:` section
6. Deprecate project.yaml with migration in /dx-upgrade

### Affected skills (~20+)
- dx-core: dx-adapt, dx-init, dx-agent-all, dx-ticket-analyze, dx-help, dx-doctor, dx-upgrade
- dx-aem: aem-init, aem-component, aem-file-resolver agent, aem-page-finder agent
- dx-core agents: dx-doc-searcher

### Risk
- Touches config reading in many skills — needs careful testing
- Consumer repos need migration (move project.yaml content into config.yaml)
- Sync script may need updates

## Priority

Medium — works fine as-is, just confusing. Tackle when doing a config schema revision.
