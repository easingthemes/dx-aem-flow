# TODO — Master Tracker

> Single source of truth. Each item links to a detail file with Problem, Scope, Done-when.

| # | Item | Priority | Status | Added | Details |
|---|------|----------|--------|-------|---------|
| 1 | ~~Skill triggering evals (Layer 2)~~ | Medium | **Done** | 2026-03-21 | [todo-testing.md#layer-2](todo-testing.md#layer-2-skill-triggering-evals) — `tests/run-evals.sh` with --quick/--full/--explicit modes, 10 prompt files, CI workflow |
| 2 | Workflow integration tests (Layer 3) | Medium | Open | 2026-03-21 | [todo-testing.md#layer-3](todo-testing.md#layer-3-workflow-integration) |
| 3 | Automation CLI pipeline eval framework | Low | Open | 2026-03-22 | [todo-testing.md#automation-eval](todo-testing.md#automation-eval) |
| 4 | Agent file format divergence (dual files) | Medium | Blocked | 2026-03-03 | [todo-copilot-cli.md#agent-format](todo-copilot-cli.md#agent-format-divergence) |
| 5 | Normalize MCP tool names to bare format (213 refs) | Low | Open | 2026-03-22 | [todo-copilot-cli.md#mcp-prefixes](todo-copilot-cli.md#mcp-tool-prefix-stripping) — LLM resolves prefixed names on all platforms; cosmetic cleanup only |
| 6 | Copilot CLI experimental features (watch) | Low | Watch | 2026-03-03 | [todo-copilot-cli.md#experimental](todo-copilot-cli.md#experimental-features) |
| 7 | ~~Clean up old automation in plugin~~ | High | **Done** | 2026-03-22 | [todo-automation.md](todo-automation.md) — `1800b25` |
| 8 | ~~Consolidate config.yaml + project.yaml~~ | Medium | **Done** | 2026-03-22 | [todo-config.md](todo-config.md) — project.yaml fields merged into config.yaml; migration via dx-upgrade; 9 skills updated |
| 9 | ~~Extract website stats constants~~ | Low | **Done** | 2026-03-22 | [todo-website.md](todo-website.md) — `stats.ts` created; 11 `.mdx` pages use imports; 7 `.md` tips have hardcoded counts (can't import TS) |
| 10 | Rename `.ai/me.md` → `.me` at project root | Low | Decision needed | 2026-03-03 | [todo-naming-ux.md#rename-me](todo-naming-ux.md#rename-aimemd) |
| 11 | ~~Rename `/aem-demo` → `/aem-editorial-guide`~~ | Low | **Done** | 2026-03-03 | [todo-naming-ux.md#rename-aem-demo](todo-naming-ux.md#rename-aem-demo) — skill, agent, template, 19 file refs, website all updated |
| 12 | Revert to namespace-only skill naming | Low | Blocked | 2026-03-03 | [todo-naming-ux.md#namespace](todo-naming-ux.md#revert-namespace-naming) |
| 13 | ~~Visual separation in coordinator logs~~ | Low | **Done** | 2026-03-03 | [todo-naming-ux.md#visual](todo-naming-ux.md#visual-separation-in-logs) — solved via TaskCreate `b6325a4` |
| 14 | Remote Figma support for CI/CD pipelines | Medium | Open | 2026-03-03 | [todo-pipeline.md#figma](todo-pipeline.md#remote-figma-for-cicd) |
| 15 | Pipeline pause-and-resume (human-in-the-loop) | Medium | Open | 2026-03-03 | [todo-pipeline.md#pause](todo-pipeline.md#pause-and-resume) |
| 16 | Plugin install ignores marketplace qualifier | Medium | Blocked (upstream) | 2026-03-03 | [todo-bugs.md#marketplace](todo-bugs.md#plugin-install-marketplace-qualifier) |
| 17 | `updatedMCPToolOutput` not replacing inline image | Low | Open | 2026-03-03 | [todo-bugs.md#mcp-output](todo-bugs.md#updatedmcptooloutput-image-replacement) |
| 18 | ~~DoR comment deduplication bug~~ | Medium | **Done** | 2026-03-22 | [todo-bugs.md#dor-dedup](todo-bugs.md#dor-comment-deduplication) — explicit `[DoRAgent]` check added to SKILL.md Phase 2 |
| 19 | SubagentStart/SubagentStop logging hooks | Low | Deferred | 2026-03-03 | [todo-bugs.md#hooks](todo-bugs.md#subagent-hooks) — TaskCreate progress covers most use cases; revisit if pipeline debugging becomes painful |
| 20 | Copilot CLI shared/ path resolution bug | Medium | Open | 2026-03-22 | [todo-copilot-cli.md#shared-paths](todo-copilot-cli.md#shared-path-resolution) |
| 21 | ~~Copilot CLI attachment download bug~~ | Low | **Done** | 2026-03-22 | [todo-copilot-cli.md#attachments](todo-copilot-cli.md#attachment-download) — explicit "Do NOT download" added to SKILL.md Phase 1 |
| 22 | ~~Port hooks to Copilot CLI~~ | Medium | **Done** | 2026-03-22 | [todo-copilot-cli.md#hooks-porting](todo-copilot-cli.md#hooks-porting) — 3 ported (SessionStart×2, PostToolUse Edit); Figma blocked by #17, Stop blocked by Copilot CLI |
| 23 | Copilot CLI project MCP not loaded | Medium | Blocked (upstream) | 2026-03-22 | [todo-copilot-cli.md#project-mcp](todo-copilot-cli.md#project-mcp-discovery) |

| 24 | Migrate DoD wiki to checkbox format | Low | Open | 2026-03-23 | [todo-config.md#dod-checkbox](todo-config.md#dod-checkbox-format) |
| 25 | Cross-repo component-discovery.md consumption | Medium | Pending | 2026-03-24 | [todo-aem-discovery.md](todo-aem-discovery.md#cross-repo-discovery-consumption) |
| 26 | Open Plugins: vendor-neutral `.plugin/` manifest | Low | Watch | 2026-03-26 | [todo-open-plugins.md#vendor-neutral-manifest](todo-open-plugins.md#vendor-neutral-manifest) |
| 27 | Open Plugins: rules `.mdc` extension | Low | Watch | 2026-03-26 | [todo-open-plugins.md#rules-file-extension](todo-open-plugins.md#rules-file-extension-md--mdc) |
| 28 | Open Plugins: `commands/` dir separation | Low | Watch | 2026-03-26 | [todo-open-plugins.md#commands-directory](todo-open-plugins.md#commands-directory-separation) |
| 29 | Open Plugins: `${PLUGIN_ROOT}` variable naming | Low | Watch | 2026-03-26 | [todo-open-plugins.md#plugin-root](todo-open-plugins.md#plugin_root-variable-naming) |
| 30 | Open Plugins: output styles support | Low | Watch | 2026-03-26 | [todo-open-plugins.md#output-styles](todo-open-plugins.md#output-styles-support) |
| 31 | Open Plugins: monitor spec finalization | Medium | Watch | 2026-03-26 | [todo-open-plugins.md#monitor-spec](todo-open-plugins.md#monitor-spec-finalization) |

| 32 | Open Plugins: plugin logo (`logo` field) | Medium | Watch | 2026-03-26 | [todo-open-plugins.md#plugin-logo](todo-open-plugins.md#plugin-logo--icon) — `assets/logo.png` + `"logo"` field added to all 4 plugins; waiting on [vscode#304758](https://github.com/microsoft/vscode/issues/304758) |

**Counts:** 32 total — 9 done, 7 open, 5 blocked, 8 watch, 1 deferred, 1 decision needed, 1 pending
