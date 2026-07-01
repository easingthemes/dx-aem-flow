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

**Upstream check (2026-07-01):** PARTIAL — now actionable. Claude Code v2.1.121 (2026-04-28) generalized `PostToolUse.updatedToolOutput` from MCP-only to **all** tools, but the [hooks docs](https://code.claude.com/docs/en/hooks) do not confirm it replaces an **image content block** (base64) with text — so this specific waste is NOT confirmed fixed. Next step: live re-test against the **current** screenshot hook path (Figma MCP was replaced by Playwright/Chrome-DevTools MCP in the v3.0.0 migration — the old `mcp__figma__get_screenshot` matcher no longer applies). Tracked as GH #16. See [2026-07-01-upstream-dependency-check.md](../research/2026-07-01-upstream-dependency-check.md).

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

**Upstream check (2026-07-01):** STILL UNTRACKED UPSTREAM — no issue exists in `microsoft/azure-devops-mcp` for this truncation bug (closest #392/#1213/#299 are unrelated & closed). Latest ADO MCP is `@azure-devops/mcp` v2.8.0 (2026-06-24). **Action: we must file the bug ourselves** — nobody is tracking it. Local `validate-image.sh` mitigation remains required. See [2026-07-01-upstream-dependency-check.md](../research/2026-07-01-upstream-dependency-check.md).

## Forked skills break standalone UX

**Added:** 2026-05-06
**Problem:** Tasks 3-8 of the orchestration-context-pollution rollout (PR #143) added `context: fork` to 6 skills (`dx-pr-commit`, `dx-plan-validate`, `dx-plan-resolve`, `dx-plan`, `dx-req`, `dx-step-all`) and suppressed their inline summary blocks (`## Present Summary`, `## 8.`, `## Execution Complete` → "Suppressed — emit ONLY the `## Return` block"). That's correct when the skill is called by `dx-agent-all`, but `context: fork` is static at skill-definition time — there's no caller-side toggle. So a user running `/dx-req 2435084` standalone now sees only the `## Return` block instead of the human-friendly summary they used to see. Five of the six forked skills (all except `dx-step-all`) are routinely run standalone.
**Scope:**
- `plugins/dx-core/skills/dx-pr-commit/SKILL.md`
- `plugins/dx-core/skills/dx-plan/SKILL.md` (the suppressed Section 8)
- `plugins/dx-core/skills/dx-plan-validate/SKILL.md`
- `plugins/dx-core/skills/dx-plan-resolve/SKILL.md`
- `plugins/dx-core/skills/dx-req/SKILL.md` (the suppressed `## Present Summary`)
- `plugins/dx-core/skills/dx-agent-all/SKILL.md` (each `Skill(...)` call site needs `DX_ORCHESTRATED=1` exported beforehand)
**Done-when:** `/dx-req 2435084` run by a user (no orchestrator) prints the full `## Requirements Pipeline Complete` summary block AND the `## Return` block. `/dx-agent-all <id>` run still emits ONLY the `## Return` block from each forked sub-skill into the orchestrator's tool-result. `grep "DX_ORCHESTRATED" plugins/dx-core/skills/dx-agent-all/SKILL.md` shows the env var being set before each forked-skill invocation. `grep -n "DX_ORCHESTRATED" plugins/dx-core/skills/{dx-req,dx-plan,dx-plan-validate,dx-plan-resolve,dx-pr-commit,dx-step-all}/SKILL.md` shows each skill body branching on it.
**Approach:** Conditional output via env var.
1. In `dx-agent-all`, wrap each forked-skill invocation with `export DX_ORCHESTRATED=1` (and `unset` after, or scope it to the Skill call).
2. In each forked skill body, restore the previously suppressed verbose summary block, but guard with: "When `DX_ORCHESTRATED=1` is set (orchestrator path), emit ONLY the `## Return` block at the end. When unset (standalone path), emit the canonical summary AND the `## Return` block at the end."
3. The `## Return` block stays mandatory as the LAST emitted block in both paths — that way the orchestrator's "read only the Return block" instruction still works (the verbose part is in its tool result but not echoed to the user's main context).
4. Verify both paths empirically: standalone gives full UX, orchestrator path keeps the lean tool-result.

**Added:** 2026-03-03
**Resolved:** 2026-04-25
**Status:** Both Claude Code (`SubagentStart`/`SubagentStop` first-class events since v2.1.x) and Copilot CLI (`agentStop`/`subagentStop` shipped, [#1157](https://github.com/github/copilot-cli/issues/1157)/[#2253](https://github.com/github/copilot-cli/issues/2253) closed 2026-04-07) support these hooks natively. TaskCreate progress already covers most observability needs.
**Implementation guidance (if needed):** Add hooks to `.claude/settings.json` and `.github/hooks/hooks.json` that log agent name, start time, end time, and exit status to `.ai/logs/agents.log`. Useful for pipeline performance optimization in `dx-automation`.
**Evidence:** [2026-04-25-platform-state-update.md](../research/2026-04-25-platform-state-update.md#now-closed--actionable)
