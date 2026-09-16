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

**Upstream check (2026-07-01):** STILL UNTRACKED UPSTREAM — no issue exists in `microsoft/azure-devops-mcp` for this truncation bug (closest #392/#1213/#299 are unrelated & closed). Latest ADO MCP is `@azure-devops/mcp` v2.8.0 (2026-06-24). Local tracking issue [#179](https://github.com/easingthemes/dx-aem-flow/issues/179) opened with the ready-to-file report; **still needs submitting to `microsoft/azure-devops-mcp`**. Local `validate-image.sh` mitigation remains required. See [2026-07-01-upstream-dependency-check.md](../research/2026-07-01-upstream-dependency-check.md).

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

## Subagent hooks

**Added:** 2026-03-03
**Resolved:** 2026-04-25
**Status:** Both Claude Code (`SubagentStart`/`SubagentStop` first-class events since v2.1.x) and Copilot CLI (`agentStop`/`subagentStop` shipped, [#1157](https://github.com/github/copilot-cli/issues/1157)/[#2253](https://github.com/github/copilot-cli/issues/2253) closed 2026-04-07) support these hooks natively. TaskCreate progress already covers most observability needs.
**Implementation guidance (if needed):** Add hooks to `.claude/settings.json` and `.github/hooks/hooks.json` that log agent name, start time, end time, and exit status to `.ai/logs/agents.log`. Useful for pipeline performance optimization in `dx-automation`.
**Evidence:** [2026-04-25-platform-state-update.md](../research/2026-04-25-platform-state-update.md#now-closed--actionable)

## Skill prose still names pre-v2.9.0 consolidated ADO MCP tools

**Added:** 2026-09-02
**Problem:** `@azure-devops/mcp` v2.9.0 consolidated several single-purpose tools into action-dispatched ones: `wit_get_work_item` + `wit_list_work_item_comments` → `wit_work_item` (with an `action` param: `get`/`list_comments`/etc.), `wit_get_work_item_attachment` → `wit_work_item_attachment` (rename only), `repo_get_pull_request_by_id` → `repo_pull_request` (`action: "get"`). This broke `plugins/dx-core/data/lib/fetch-raw-story.js`, which called the old names directly via JSON-RPC and got no match — flagged and fixed in a separate pass. The same old names are still referenced as literal MCP tool calls in ~20 `SKILL.md`/reference files, which risks the same "tool not found" failure wherever a skill or agent expects to call them by exact name rather than via natural-language tool resolution.
**Scope:** `plugins/dx-core/skills/{dx-req,dx-req-dod,dx-req-tasks,dx-dor,dx-bug-triage,dx-bug-all,dx-agent-re,dx-simple,dx-pr-answer,dx-pr-review,dx-pr-review-report,dx-pr-review-all,dx-pr-reviews-report,dx-ticket-analyze,dx-doc-retro,dx-estimate}/`, `plugins/dx-core/shared/git-rules.md`, `plugins/dx-hub/skills/{dx-hub-dispatch,dx-hub-init}/`, `plugins/dx-aem/skills/aem-qa-handoff/`.
**Done-when:** `grep -rln 'wit_get_work_item\b\|wit_list_work_item_comments\|wit_get_work_item_attachment\|repo_get_pull_request_by_id' plugins/` returns nothing (or only files where the reference is clearly historical/comparison prose, not an instruction to call the tool by that name).
**Update 2026-09-17 (partial progress):** `plugins/dx-core/skills/dx-req/SKILL.md` is **done** — all 8 references renamed (`wit_work_item` with `action:`, `wit_work_item_attachment`, `repo_pull_request` with `action:`) and `expand` recased. Review flagged that the half-updated state it was left in (old tool name + new enum casing) matched no real API, which is a fair reason not to leave a file half-swept. Accurate remaining scope: **36 files** under `plugins/` still match the old names — the earlier "~20" undercounted. The consolidation also changed the `expand` enum on `wit_work_item` — it is built from the `WorkItemExpand` TS enum *keys*, so the accepted values are capitalized (`None|Relations|Fields|Links|All`). Lowercase `"all"`, valid on the old `wit_get_work_item`, now fails zod validation before the handler runs. Fixed in `fetch-raw-story.js` and recased in the three `dx-req/SKILL.md` references; **any other prose this sweep touches must recase `expand` as well as rename the tool.** Separately, v2.10.0 wraps tool output in `<<nonce>> [UNTRUSTED …] <<nonce>>` sentinels, which broke `JSON.parse` in `fetch-raw-story.js` (silently — empty story, exit 0); handled there by `parseToolText`, but any other script parsing MCP text output needs the same treatment.
**Approach:** Sweep each file, replace the old tool name + implicit params with the new action-dispatched call (see `fetch-raw-story.js` diff in the same commit for the exact old→new mapping and param shapes). Low risk — these are prose instructions to the model, which may already fuzzy-resolve via `ToolSearch`, but exact names should be kept current to avoid relying on that fallback.
