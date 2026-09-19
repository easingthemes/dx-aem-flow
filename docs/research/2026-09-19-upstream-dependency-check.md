# Upstream dependency check — 2026-09-19

Periodic sweep of every open GitHub issue that is **blocked on / waiting for** an upstream tool (Claude Code, Copilot CLI, ADO MCP). Previous sweep: [2026-07-01](2026-07-01-upstream-dependency-check.md).

**Method:** upstream issue threads + changelogs read directly, **plus two live probes on the installed Claude Code v2.1.277** (see below). A changelog entry is not a verification — the two Claude Code items were closed only after running them.

**Latest upstream versions observed:** Claude Code v2.1.277 (installed locally) · Copilot CLI v1.0.86 stable / v1.0.87-0 pre-release (2026-09-17/18) · ADO MCP `@azure-devops/mcp` v2.10.0.

## Headline: 2 of 6 upstream-blocked issues are now fixed — both on Claude Code

| Issue | Verdict | Evidence |
|-------|---------|----------|
| [#24](https://github.com/easingthemes/dx-aem-flow/issues/24) — `plugin:skill` namespace resolution | **FIXED — closed** | Live probe, v2.1.277 |
| [#16](https://github.com/easingthemes/dx-aem-flow/issues/16) — `updatedMCPToolOutput` doesn't replace inline image | **FIXED — closed** | Live probe, v2.1.277 |
| [#123](https://github.com/easingthemes/dx-aem-flow/issues/123) — auto-commit/auto-PR fire without config | **FIXED (ours) — closed** | Code read |
| [#22](https://github.com/easingthemes/dx-aem-flow/issues/22) — Copilot `agent:` frontmatter | STILL BLOCKED | No tracker, no fix |
| [#21](https://github.com/easingthemes/dx-aem-flow/issues/21) — Copilot `context: fork` | STILL BLOCKED | [copilot-cli#1169](https://github.com/github/copilot-cli/issues/1169) Open |
| [#20](https://github.com/easingthemes/dx-aem-flow/issues/20) — Copilot subagents can't invoke skills | STILL BLOCKED (**regressed**) | New tracker [copilot-cli#4708](https://github.com/github/copilot-cli/issues/4708) |
| [#19](https://github.com/easingthemes/dx-aem-flow/issues/19) — Copilot `handoffs:` execution | STILL BLOCKED | [copilot-cli#561](https://github.com/github/copilot-cli/issues/561) Open since Nov 2025 |
| [#179](https://github.com/easingthemes/dx-aem-flow/issues/179) — ADO MCP attachment truncation | STILL UNTRACKED UPSTREAM | No matching issue in `microsoft/azure-devops-mcp` |

---

## Probe 1 — plugin skill namespacing (GH #24)

Two probe skills in a throwaway plugin `testns@nstest`, one **with** `name:` frontmatter, one **without**, installed next to `dx-core`. Asked a headless `claude -p` run to echo the skill names it was offered:

```
testns:hello      # has  name: hello      in frontmatter
testns:world      # has no name: field
dx-core:dx-init   # our own plugin
```

**Result:** plugin skills are namespaced `plugin:skill` on v2.1.277, **including** when `name:` is set — which was the exact defect behind our prefix workaround ([#22063](https://github.com/anthropics/claude-code/issues/22063), closed as not planned; the fix landed via the v2.1.216 changelog entry "plugin skills with a `name` frontmatter field no longer lose their plugin prefix"). The feature request we were tracking, [#50486](https://github.com/anthropics/claude-code/issues/50486), is **closed as not planned** — stale-closed *after* the behavior it asked for already shipped.

**Consequence:** our `dx-` / `aem-` directory prefixes now stutter (`dx-core:dx-init`). The bug is fixed; the **rename is a separate, now-unblocked choice** — TODO #12, moved Blocked → Ready. Not done here: 78 skills, all cross-references, the catalogs, the website and every consumer project's muscle memory. `/dx-init` is also still the shape users have typed for six months, so the rename needs its own decision, not a drive-by.

## Probe 2 — `updatedMCPToolOutput` image replacement (GH #16)

A 40-line stdio MCP server returning an **image content block** (1×1 PNG) plus a text marker, and a `PostToolUse` hook replacing the result with a marker string. Headless run, asked what arrived:

| Hook output field | Image reached the model? | Text the model saw |
|---|---|---|
| `updatedToolOutput` + `updatedMCPToolOutput` | **No** | replacement marker only |
| `updatedMCPToolOutput` **alone** | **No** | replacement marker only |

**Result:** image content blocks *are* replaced on v2.1.277, and the `updatedMCPToolOutput` field name we already use is the one that works. The original text block of the tool result is dropped too. The ~500 KB-per-screenshot waste this issue described is gone.

Note the matcher this issue was written against (`mcp__figma__get_screenshot`) no longer exists — the v3.0.0 migration moved screenshots to Playwright / chrome-devtools MCP. Any new screenshot hook can now rely on replacement working.

## Copilot CLI — still blocked, one regression

Latest: v1.0.86 (2026-09-17), v1.0.87-0 pre-release (2026-09-18). Nothing in the Jul–Sep releases addresses skill frontmatter routing or skill-in-subagent invocation.

- **#20 (subagent orchestration) regressed.** [copilot-cli#4708](https://github.com/github/copilot-cli/issues/4708) — "Subagents cannot access installed skills that are available to the main agent" (opened 2026-09-03, `Bug`, `area:agents` + `area:plugins`, no maintainer response) reports subagents losing access to skills from `.copilot/installed-plugins` that the main agent can see, described as a regression from ~late August. This is now the sharpest upstream tracker for #20 — better than the four older ones in the issue body ([#1374](https://github.com/github/copilot-cli/issues/1374) is closed; [#1180](https://github.com/github/copilot-cli/issues/1180), [#2150](https://github.com/github/copilot-cli/issues/2150), [#1506](https://github.com/github/copilot-cli/issues/1506) remain open but are adjacent feature requests).
- **#22 (`agent:` routing)** — still no upstream tracker. Adjacent and open: [#2758](https://github.com/github/copilot-cli/issues/2758) (sub-agents silently downgraded to the cheap session model, opt-out requested) and [#3180](https://github.com/github/copilot-cli/issues/3180). v1.0.85 shipped "subagent launches honor explicit model and reasoning preferences from custom instructions" — *custom instructions*, not skill frontmatter, so it does not close this. [#3532](https://github.com/github/copilot-cli/issues/3532) (`skills:` preload in agent profiles) closed 2026-05-26 without covering `agent:`. **Still recommended: file it.**
- **#21 (`context: fork`)** — [#1169](https://github.com/github/copilot-cli/issues/1169) Open, unassigned, no PR. v1.0.87-0 added `worktreePathTemplate` (worktree *layout*, not skill-declared isolation).
- **#19 (`handoffs:`)** — [#561](https://github.com/github/copilot-cli/issues/561) Open since 2025-11-14, still no labels, assignee or PR; [#1180](https://github.com/github/copilot-cli/issues/1180) Open.

## ADO MCP (GH #179)

A search of `microsoft/azure-devops-mcp` still returns **no issue** describing the `wit_get_work_item_attachment` >75 KB base64 truncation. The ready-to-file report in #179 is still ours to file; `plugins/dx-core/data/lib/validate-image.sh` remains the mitigation. (Unverified here — reproducing it needs a live ADO work item, which this environment has no access to.)

## Recommended next actions

1. **Decide TODO #12** — now unblocked. Either rename 78 skill dirs to drop the prefix, or write the prefix down as a deliberate convention and close the TODO. Doing neither leaves a stale "Blocked" row.
2. **File the two upstream issues we keep re-noting as untracked:** `microsoft/azure-devops-mcp` attachment truncation (#179) and `github/copilot-cli` skill `agent:` routing (#22).
3. **Next sweep:** the four Copilot items only move when Copilot CLI ships; re-check on the next quarterly pass rather than per-release.
