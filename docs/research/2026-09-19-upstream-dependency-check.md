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
| [#179](https://github.com/easingthemes/dx-aem-flow/issues/179) — ADO MCP attachment truncation | **UNBLOCKED — fix is ours** | Upstream source read (v2.10.0): no size cap in the tool, and `savePath` skips base64 entirely |

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

**Other Copilot skill-system issues found while checking, not tracked by any of our issues** — worth knowing before we blame our own plugin for a report from a Copilot user:
- [#4209](https://github.com/github/copilot-cli/issues/4209) **Closed** (2026-07-21, closed with no visible resolution comment or linked PR) — asked for `skill` as a tool alias in custom-agent `tools:` so agents can invoke skills instead of copying their bodies. Nothing in the v1.0.68–v1.0.87 release notes implements it, so treat it as closed-without-fix rather than shipped.
- [#4545](https://github.com/github/copilot-cli/issues/4545) Open — personal skills in `~/.copilot/skills/` are never discovered despite being documented.
- [#4886](https://github.com/github/copilot-cli/issues/4886) Open — skills loaded via `--plugin-dir` are missing from `/skills` and `/env`.
- [#3699](https://github.com/github/copilot-cli/issues/3699) Open — `allowed-tools` frontmatter ignored in non-interactive mode, which is the mode `dx-automation` pipelines run in.
- [#4438](https://github.com/github/copilot-cli/issues/4438) Open — `disable-model-invocation` makes a skill unreachable rather than manual-only.

Release notes Jul–Sep are all skill *plumbing* (`copilot skill add/enable/disable`, discovery via `--add-dir`, plugin/skill persistence on resume) — nothing about routing or subagent access.

## ADO MCP (GH #179) — source read, and we can route around it

A search of `microsoft/azure-devops-mcp` still returns **no issue** describing the `wit_get_work_item_attachment` >75 KB base64 truncation, so the ready-to-file report in #179 is still ours to file. But reading the upstream source at **v2.10.0** (`src/tools/work-items.ts`, tool since renamed `wit_get_work_item_attachment` → `wit_work_item_attachment`) changes what we should do about it:

**1. The tool has no size cap.** It streams the attachment, `Buffer.concat`s every chunk and base64-encodes the whole thing before returning a `resource` content block. Nothing in the tool trims it. That corroborates the original diagnosis — the loss is at the JSON-RPC/transport boundary, not in ADO's API or the tool's logic — and it means an upstream fix would be a protocol/transport change, not a one-line patch. Don't wait for it.

**2. The tool now takes `savePath`, which skips base64 entirely.** With a relative directory, the tool does:

```js
fs.writeFileSync(path.join(savePath, resolvedFileName), buffer);
return { content: [{ type: "text", text: `Attachment saved to: ${localFilePath}` }] };
```

No blob crosses the wire, so there is nothing to truncate. Constraints: `savePath` must be relative (absolute paths, drive letters and `..` are rejected), it resolves against the **MCP server's** cwd, and it throws if the file already exists.

**3. We don't use it.** `plugins/dx-core/data/lib/fetch-raw-story.js` calls `wit_work_item_attachment` with `{project, attachmentId, fileName}` only — the base64 path, i.e. the buggy one, on every image in every ticket.

So #179 flips from *blocked on upstream* to *actionable here*: pass `savePath` (the spec dir's `images/`) and drop the base64 decode on that path, keeping `validate-image.sh` as the guard for older server versions. TODO #103 relabelled **Actionable**; the issue keeps the upstream report for filing.

## Recommended next actions

1. **Use `savePath` in `fetch-raw-story.js`** (TODO #103) — the one code change this sweep produced. It removes the truncation class of failure instead of quarantining it.
2. **Decide TODO #12** — now unblocked. Either rename 78 skill dirs to drop the prefix, or write the prefix down as a deliberate convention and close the TODO. Doing neither leaves a stale "Blocked" row.
3. **File the two upstream issues we keep re-noting as untracked:** `microsoft/azure-devops-mcp` attachment truncation (#179) and `github/copilot-cli` skill `agent:` routing (#22).
4. **Next sweep:** the four Copilot items only move when Copilot CLI ships; re-check on the next quarterly pass rather than per-release.
