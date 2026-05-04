# TODO: Bugs & Fixes

## Plugin Install Marketplace Qualifier

**Added:** 2026-03-03
**Problem:** `/plugin install dx-aem@dx-aem-flow` resolves `dx-aem` from a *different* marketplace if cached. Claude Code extracts just the plugin name, searches for any `dx-aem@*` match, and returns the first hit — the `@marketplace` qualifier is effectively ignored.
**Scope:** Claude Code CLI internals — not fixable in this repo.
**Done-when:** [anthropics/claude-code#20593](https://github.com/anthropics/claude-code/issues/20593) is closed, AND `/plugin install dx-aem@dx-aem-flow` installs from the correct marketplace when multiple marketplaces exist.
**Approach:** Blocked on upstream fix. Workaround: ensure only one marketplace per plugin name, or delete stale cache (`rm -rf ~/.claude/plugins/cache/<wrong-marketplace>`). Cache location: `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`.

## updatedMCPToolOutput Image Replacement

**Added:** 2026-03-03
**Problem:** The `PostToolUse` hook for `mcp__figma__get_screenshot` correctly returns `updatedMCPToolOutput` (a text string with the saved file path), but Claude Code still sends the original base64 image inline to the LLM. The `additionalContext` field works fine — only image replacement doesn't.
**Scope:** Hook definition in `plugins/dx-core/hooks/hooks.json` (PostToolUse matcher for figma screenshot). May be a Claude Code CLI bug.
**Done-when:** After a Figma screenshot call, the LLM context contains only the file path text (from `updatedMCPToolOutput`), NOT the base64 image. Verify by checking token count — screenshot calls should use ~1K tokens, not ~500K.
**Approach:** Possible causes:
- Claude Code sends MCP image content before processing hook output
- `updatedMCPToolOutput` may only work for text, not image content types
- Hook output format may need different structure for image replacement

**Impact:** Low — screenshot saves to disk, `additionalContext` tells the skill where the file is. Only downside is ~500K wasted tokens per screenshot.

## DoR Comment Deduplication

**Added:** 2026-03-22
**Problem:** Two cross-platform issues cause duplicate DoR comments on ADO work items:
1. **Signature mismatch:** Claude Code posts DoR comments with `<!-- ai:role:dor-agent -->` HTML comment instead of the `[DoRAgent]` text signature specified in `dx-dor/references/comment-format.md`. Copilot CLI can't detect Claude's comment → posts a duplicate.
2. **Copilot CLI bypasses reference file logic:** Generated `dor-report.md` via Python script instead of following `dx-dor/references/comment-format.md`'s comment-checking flow. Never fetched existing comments to check for duplicates.
**Scope:**
- Reference file: `plugins/dx-core/skills/dx-dor/references/comment-format.md` (has correct `[DoRAgent]` signature)
- Skill: `plugins/dx-core/skills/dx-dor/SKILL.md` (standalone DoR check, also called by dx-req Phase 2)
**Done-when:** `grep -n "DoRAgent\|BEFORE posting\|fetch.*comment.*search" plugins/dx-core/skills/dx-dor/SKILL.md plugins/dx-core/skills/dx-dor/references/comment-format.md` shows explicit instructions to (a) use `[DoRAgent]` signature and (b) fetch existing comments before posting.
**Approach:** Standardize on `[DoRAgent]` signature in dx-dor skill and comment-format.md reference. The signature detection and comment-checking flow are now in the standalone `/dx-dor` skill.

## ADO MCP `wit_get_work_item_attachment` truncates large attachments

**Added:** 2026-05-04
**Problem:** `mcp__ado__wit_get_work_item_attachment` silently truncates the base64 payload for some attachments above ~75 KB. The returned bytes decode to a file whose IHDR/dimensions/MIME look correct (so `file --mime-type`, `file -b`, and `PIL.Image.open()` all pass) but whose IDAT stream is incomplete (no IEND chunk). When that file is loaded via the Read tool, Anthropic's vision API does a full decode and returns `API Error: 400 — Could not process image`, aborting the whole turn. Reproducible: WI 2490722 attachment `47ead4d5-723c-413c-8aa2-afe8414ecf1d` returns 74967 bytes; clean MCP fetch and agent-improvised decode produce the same SHA256, so truncation is upstream of any client code. Likely cause: a JSON-RPC message-size cap inside `@azure-devops/mcp` truncating Resource blobs before base64-encoding.
**Scope:** `@azure-devops/mcp` (microsoft/azure-devops-mcp). Local mitigation lives in `plugins/dx-core/data/lib/validate-image.sh` (PNG/JPEG/GIF/WebP structural decode that catches truncation before Read).
**Done-when:** A 100 KB+ ADO attachment fetched via `mcp__ado__wit_get_work_item_attachment` returns the full byte stream — `bash plugins/dx-core/data/lib/validate-image.sh <saved-file>` exits 0 with `ok:` rather than `skip: truncated: ...`. Until then, the validator quarantines truncated files into INDEX.md's `## Skipped` section so dx-req can complete.
**Approach:** File issue against `microsoft/azure-devops-mcp`. Until upstream fix lands, defense-in-depth in the validator is sufficient — affected attachments get skipped rather than 400-ing the turn. Optional follow-up: add a REST-API fallback in `fetch-raw-story.js` that re-fetches with curl + ADO PAT when MCP returns truncated bytes.

## Subagent Hooks — RESOLVED 2026-04-25

**Added:** 2026-03-03
**Resolved:** 2026-04-25
**Status:** Both Claude Code (`SubagentStart`/`SubagentStop` first-class events since v2.1.x) and Copilot CLI (`agentStop`/`subagentStop` shipped, [#1157](https://github.com/github/copilot-cli/issues/1157)/[#2253](https://github.com/github/copilot-cli/issues/2253) closed 2026-04-07) support these hooks natively. TaskCreate progress already covers most observability needs.
**Implementation guidance (if needed):** Add hooks to `.claude/settings.json` and `.github/hooks/hooks.json` that log agent name, start time, end time, and exit status to `.ai/logs/agents.log`. Useful for pipeline performance optimization in `dx-automation`.
**Evidence:** [2026-04-25-platform-state-update.md](../research/2026-04-25-platform-state-update.md#now-closed--actionable)
