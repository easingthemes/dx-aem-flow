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
| 26 | Open Plugins: vendor-neutral `.plugin/` manifest | Low | Open | 2026-03-26 | [todo-open-plugins.md#vendor-neutral-manifest](todo-open-plugins.md#vendor-neutral-manifest) — Copilot CLI v1.0.14 supports `.plugin/`; `vercel-labs/open-plugin` repo now accessible |
| 27 | Open Plugins: rules `.mdc` extension | Low | Watch | 2026-03-26 | [todo-open-plugins.md#rules-file-extension](todo-open-plugins.md#rules-file-extension-md--mdc) |
| 28 | Open Plugins: `commands/` dir separation | Low | Watch | 2026-03-26 | [todo-open-plugins.md#commands-directory](todo-open-plugins.md#commands-directory-separation) |
| 29 | Open Plugins: `${PLUGIN_ROOT}` variable naming | Low | Watch | 2026-03-26 | [todo-open-plugins.md#plugin-root](todo-open-plugins.md#plugin_root-variable-naming) |
| 30 | Open Plugins: output styles support | Low | Watch | 2026-03-26 | [todo-open-plugins.md#output-styles](todo-open-plugins.md#output-styles-support) |
| 31 | Open Plugins: monitor spec finalization | Medium | Watch | 2026-03-26 | [todo-open-plugins.md#monitor-spec](todo-open-plugins.md#monitor-spec-finalization) — repo accessible as of 2026-04-03; spec stabilizing |

| 32 | Open Plugins: plugin logo (`logo` field) | Medium | Watch | 2026-03-26 | [todo-open-plugins.md#plugin-logo](todo-open-plugins.md#plugin-logo--icon) — `assets/logo.png` + `"logo"` field added to all 4 plugins; waiting on [vscode#304758](https://github.com/microsoft/vscode/issues/304758) |

| 33 | Hook `if` field — conditional execution | High | Open | 2026-03-27 | [todo-review-plugin-improvements.md#hook-if-field](todo-review-plugin-improvements.md#hook-if-field--conditional-execution) |
| 34 | Branch-guard exit code bug (exit 1 → exit 2) | High | Open | 2026-03-27 | [todo-review-plugin-improvements.md#branch-guard-exit-code](todo-review-plugin-improvements.md#branch-guard-exit-code-bug) |
| 35 | Hook statusMessage for UX | Medium | Open | 2026-03-27 | [todo-review-plugin-improvements.md#hook-statusmessage](todo-review-plugin-improvements.md#hook-statusmessage-for-ux) |
| 36 | Async screenshot hooks | Medium | Open | 2026-03-27 | [todo-review-plugin-improvements.md#async-screenshot](todo-review-plugin-improvements.md#async-screenshot-hooks) |
| 37 | Skill `effort` field for model-tiered skills | Medium | Open | 2026-03-27 | [todo-review-plugin-improvements.md#skill-effort](todo-review-plugin-improvements.md#skill-effort-field) |
| 38 | AEM skills `paths` field for scoped activation | Medium | Open | 2026-03-27 | [todo-review-plugin-improvements.md#aem-paths](todo-review-plugin-improvements.md#aem-skills-paths-field) |
| 39 | Docs: new hook/skill features | Low | Open | 2026-03-27 | [todo-review-plugin-improvements.md#docs](todo-review-plugin-improvements.md#documentation-updates) |
| 40 | Copilot CLI hook compatibility matrix | Low | Open | 2026-03-27 | [todo-review-plugin-improvements.md#copilot-cli](todo-review-plugin-improvements.md#copilot-cli-hook-compatibility) |
| 41 | OpenSkills / Agent Skills cross-platform notes | Low | Watch | 2026-03-27 | [todo-review-plugin-improvements.md#openskills](todo-review-plugin-improvements.md#openskills--agent-skills-standard-compatibility) |
| 42 | Hub V2: rich status tracking (phase, steps, PRs) | Medium | Open | 2026-03-27 | [todo-hub.md#v2-rich-status-tracking](todo-hub.md#v2-rich-status-tracking) |
| 43 | Hub: cross-platform terminal automation | Medium | Open | 2026-03-27 | [todo-hub.md#cross-platform-terminal-automation](todo-hub.md#cross-platform-terminal-automation) |
| 44 | Publish vscode-automator as standalone npm package | Medium | Open | 2026-03-27 | [todo-hub.md#publish-vscode-automator-as-standalone-npm-package](todo-hub.md#publish-vscode-automator-as-standalone-npm-package) |

| 45 | Subagent: parallel dispatch for independent AEM phases | Medium | Open | 2026-03-27 | [todo-subagent-improvements.md#parallel-dispatch](todo-subagent-improvements.md#parallel-dispatch-for-independent-aem-phases) — AEM Verify + FE Verify can run concurrently in dx-agent-all |
| 46 | Subagent: error classification in Result envelope | Medium | Open | 2026-03-27 | [todo-subagent-improvements.md#error-classification](todo-subagent-improvements.md#error-classification-in-result-envelope) — transient/permanent/config enables coordinator retry logic |
| 47 | Subagent: context budget worked examples | Medium | Open | 2026-03-27 | [todo-subagent-improvements.md#context-budget](todo-subagent-improvements.md#subagent-context-budget--worked-examples) — concrete examples for >5KB summarization in fork skills |
| 48 | Subagent: MCP tool discovery resilience | Low | Open | 2026-03-27 | [todo-subagent-improvements.md#mcp-discovery](todo-subagent-improvements.md#mcp-tool-discovery-resilience--shared-reference) — standardize ToolSearch fallback in all MCP agents |
| 49 | Subagent: coordinator output discipline — Tasks over text | Medium | Open | 2026-03-27 | [todo-subagent-improvements.md#output-discipline](todo-subagent-improvements.md#coordinator-output-discipline--tasks-over-text) — use Task updates as progress channel, not conversation text |

| 50 | Budget / token tracking for automation agents | Low | Open | 2026-03-28 | [todo-automation.md#budget-tracking](todo-automation.md#budget-tracking) |
| 51 | Coordinator agent formalization (delegates-to / reports-to) | Medium | Open | 2026-03-28 | [todo-coordinator-formalization.md](todo-coordinator-formalization.md) |

| 52 | Continuous learning / instinct system for automation agents | Medium | Open | 2026-03-31 | [todo-ecc-ideas.md#continuous-learning](todo-ecc-ideas.md#continuous-learning--instinct-system) |
| 53 | De-sloppify pattern (dx-step-clean skill) | Low | Open | 2026-03-31 | [todo-ecc-ideas.md#de-sloppify](todo-ecc-ideas.md#de-sloppify-pattern-post-implementation-cleanup) |
| 54 | Autonomous loop state persistence for automation agents | Medium | Open | 2026-03-31 | [todo-ecc-ideas.md#state-persistence](todo-ecc-ideas.md#autonomous-loop-state-persistence) |

| 55 | GitHub Issues/Projects as tracker platform | Medium | Open | 2026-04-02 | [todo-provider-support.md](todo-provider-support.md#github-as-trackerscm-platform) |
| 56 | dx-init: skip ADO-specific files for non-ADO providers | High | Open | 2026-04-02 | [todo-provider-support.md#dx-init-skip](todo-provider-support.md#dx-init-skip-ado-specific-files-when-scmprovider--ado) |
| 57 | dx-init: provider-aware scaffolding (full flow, skip ADO ceremony) | High | Open | 2026-04-02 | [todo-provider-support.md#dx-init-provider](todo-provider-support.md#dx-init-provider-aware-scaffolding) |
| 58 | dx-req from markdown file instead of ticket | Medium | Open | 2026-04-02 | [todo-provider-support.md#dx-req-markdown](todo-provider-support.md#dx-req-from-markdown-file-instead-of-ticket) |

| 59 | Azure Skills: conditional handoff integration points | Low | Watch | 2026-04-03 | [todo-azure-skills.md#conditional-domain-handoff](todo-azure-skills.md#recommended-integration-model-conditional-domain-handoff) |
| 60 | Azure Skills: adopt `references/` pattern for per-skill docs | Medium | Open | 2026-04-03 | [todo-azure-skills.md#references-pattern](todo-azure-skills.md#1-references-pattern--bundled-domain-knowledge) |
| 61 | Azure Skills: evaluate Context7 MCP for live doc lookup | Low | Open | 2026-04-03 | [todo-azure-skills.md#context7](todo-azure-skills.md#2-context7-mcp--live-documentation-lookup) |
| 62 | Azure Skills: publish dx-core to microsoft/skills catalog | Low | Open | 2026-04-03 | [todo-azure-skills.md#publish](todo-azure-skills.md#4-publish-to-microsoftskills-catalog) |

| 63 | Harness design: structured progress handoff artifact | High | Open | 2026-04-04 | [todo-harness-design.md#progress-file](todo-harness-design.md#3-structured-progress-file-for-cross-session-handoff) — single `progress.md` per spec-dir for cross-session context |
| 64 | Harness design: automation agent startup protocol | High | Open | 2026-04-04 | [todo-harness-design.md#context-resets](todo-harness-design.md#4-context-resets-over-compaction) — standardize artifact-reading preamble for Lambda agents |
| 65 | Harness design: iterative verify→fix→re-verify loop | Medium | Open | 2026-04-04 | [todo-harness-design.md#generator-evaluator](todo-harness-design.md#1-generatorevaluator-separation-gan-style-loop) — structured feedback file + capped retry cycle |
| 66 | Harness design: JSON step status tracking | Medium | Open | 2026-04-04 | [todo-harness-design.md#feature-list-json](todo-harness-design.md#5-feature-list-as-json-not-markdown) — `implement-status.json` alongside `implement.md` |
| 67 | Harness design: externalized grading rubrics | Medium | Open | 2026-04-04 | [todo-harness-design.md#grading-criteria](todo-harness-design.md#6-grading-criteria-for-subjective-quality) — `.ai/rules/code-quality-rubric.md` for project-specific thresholds |
| 68 | Harness design: sprint contract / plan testability review | Medium | Open | 2026-04-04 | [todo-harness-design.md#sprint-contracts](todo-harness-design.md#2-sprint-contracts-pre-agreed-definition-of-done) — evaluator reviews plan done-criteria before execution |

| 69 | Plugin architecture review — full research findings | — | **Done** | 2026-04-06 | [todo-plugin-architecture-review.md](todo-plugin-architecture-review.md) — ecosystem research, complexity hotspots, tiered catalog recommendations |
| 70 | Complexity hotspot: provenance gating invisible error | High | **Done** | 2026-04-06 | [todo-plugin-architecture-review.md#hidden-state-complexity](todo-plugin-architecture-review.md#hidden-state-complexity) — dx-pr now shows diagnostic with current state and next step |
| 71 | Complexity hotspot: heal mechanism implicit plan mutation | High | **Done** | 2026-04-06 | [todo-plugin-architecture-review.md#hidden-state-complexity](todo-plugin-architecture-review.md#hidden-state-complexity) — dx-step-all now prints plan-mutation notice with new step count |
| 72 | Complexity hotspot: spec directory slug fragility | Medium | **Done** | 2026-04-06 | [todo-plugin-architecture-review.md#hidden-state-complexity](todo-plugin-architecture-review.md#hidden-state-complexity) — dx-req now detects and reports title changes (informational) |
| 73 | Complexity hotspot: hub mode stop-and-redirect | Medium | **Done** | 2026-04-06 | [todo-plugin-architecture-review.md#hidden-state-complexity](todo-plugin-architecture-review.md#hidden-state-complexity) — hub-dispatch.md now shows diagnostic with why/next-step/after-dispatch |
| 74 | Tiered skill catalog — 7 primary skills surface | High | **Done** | 2026-04-06 | [todo-plugin-architecture-review.md#a-tier-the-catalog](todo-plugin-architecture-review.md#a-tier-the-catalog--7-primary-skills) — added to website skills page, local workflow page, and reference catalog |
| 75 | Smart router skill (/dx) | Medium | Open | 2026-04-06 | [todo-plugin-architecture-review.md#b-add-a-smart-router](todo-plugin-architecture-review.md#b-add-a-smart-router--entry-point) — single entry point that routes by intent |
| 76 | Consolidate utility skills under dx-doctor | Low | Open | 2026-04-06 | [todo-plugin-architecture-review.md#e-consolidate-utility-skills](todo-plugin-architecture-review.md#e-consolidate-utility-skills) — merge 7 utility skills into umbrella |
| 77 | Absorb micro-skills into parent skills | Medium | Open | 2026-04-06 | [todo-plugin-architecture-review.md#f-absorb-micro-skills](todo-plugin-architecture-review.md#f-absorb-micro-skills) — dx-pr-commit into dx-pr, dx-plan-validate into dx-plan, etc. |

| 69 | Cross-platform: Cursor hooks-cursor.json | Medium | Open | 2026-04-04 | [todo-cross-platform.md#cursor-hooks](todo-cross-platform.md#cursor-hookscursorjson-for-dx-core-and-dx-aem) |
| 70 | Cross-platform: tool name reference docs | Low | Open | 2026-04-04 | [todo-cross-platform.md#tool-names](todo-cross-platform.md#tool-name-reference-docs-for-non-claude-platforms) |
| 71 | Cross-platform: Cursor marketplace registration | Low | Open | 2026-04-04 | [todo-cross-platform.md#cursor-marketplace](todo-cross-platform.md#cursor-plugin-marketplace-registration) |
| 72 | Cross-platform: OpenCode plugin support | Low | Open | 2026-04-04 | [todo-cross-platform.md#opencode](todo-cross-platform.md#opencode-plugin-support) |
| 73 | Cross-platform: shared hook platform detection | Medium | Open | 2026-04-04 | [todo-cross-platform.md#hook-detection](todo-cross-platform.md#sessionstart-hook-platform-detection-shared-script) |
| 74 | Cross-platform: AGENTS.md ↔ CLAUDE.md sync | Low | Ongoing | 2026-04-04 | [todo-cross-platform.md#agents-sync](todo-cross-platform.md#agentsmd-maintenance--keep-in-sync-with-claudemd) |

| 75 | Context graphs: provenance metadata on spec files | Medium | Done | 2026-04-05 | [todo-context-graphs.md#phase-1](todo-context-graphs.md#phase-1--provenance-metadata-low-effort-high-value) — add agent/model/confidence frontmatter to spec outputs |
| 76 | Context graphs: key decisions in implement.md | Medium | Done | 2026-04-05 | [todo-context-graphs.md#phase-2](todo-context-graphs.md#phase-2--key-decisions-in-implementmd-low-effort-high-value) — dx-plan captures alternatives + rationale |
| 77 | Context graphs: provenance consumers | Medium | Done | 2026-04-05 | [todo-context-graphs.md#phase-1b](todo-context-graphs.md#phase-1b--provenance-consumers-low-effort-high-value) — dx-plan warns on low confidence, dx-pr gates on verified, dx-step-verify flags upstream quality |
| 78 | Context graphs: cross-ticket pattern promotion | Medium | Done | 2026-04-05 | [todo-context-graphs.md#phase-3](todo-context-graphs.md#phase-3--cross-ticket-pattern-promotion-medium-effort-very-high-value) — dx-pattern-extract skill + dx-plan consumes patterns |
| 79 | Context graphs: decision nodes as structured YAML | Medium | Done | 2026-04-05 | [todo-context-graphs.md#phase-4](todo-context-graphs.md#phase-4--decision-nodes-as-structured-yaml-medium-effort-high-value) — decision-schema.md + dx-plan writes YAML + dx-pattern-extract reads YAML |
| 80 | Context graphs: full graph with edges | Low | Done | 2026-04-05 | [todo-context-graphs.md#phase-5](todo-context-graphs.md#phase-5--full-graph-with-edges-higher-effort-transformative) — edge-schema.md + dx-plan writes edges + dx-step-verify writes verified-by + dx-agent-all reads graph context |

| 81 | dx-rfp: cost / inference budget controls | Medium | Open | 2026-04-16 | [todo-dx-rfp.md#cost--inference-budget-controls](todo-dx-rfp.md#cost--inference-budget-controls) — `--light` mode, batched perspectives, pre-run cost estimate, `--budget` ceiling |
| 82 | dx-rfp: scoped lock invalidation (task-local vs cross-cutting) | Medium | Open | 2026-04-16 | [todo-dx-rfp.md#lock-invalidation--scoped-propagation](todo-dx-rfp.md#lock-invalidation--scoped-propagation) — diff-preview cascade narrows blast radius |
| 83 | dx-rfp: token-efficient reviewer context bundles | Low | Open | 2026-04-16 | [todo-dx-rfp.md#token-efficient-context-bundles](todo-dx-rfp.md#token-efficient-context-bundles) — chunked reviewer dispatch for large step shards |

**Counts:** 83 total — 15 done, 52 open, 5 blocked, 9 watch, 1 deferred, 1 decision needed, 1 pending, 1 ongoing
