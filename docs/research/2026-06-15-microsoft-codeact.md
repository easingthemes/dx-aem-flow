# Microsoft CodeAct — Research File

**Announced:** Microsoft Agent Framework at BUILD 2026 (May 2026)
**Source:** [devblogs.microsoft.com/agent-framework/microsoft-agent-framework-at-build-2026-announce](https://devblogs.microsoft.com/agent-framework/microsoft-agent-framework-at-build-2026-announce/)
**Related TODO:** #158

---

## What CodeAct Is

CodeAct replaces multi-turn tool-calling with a single short Python program.

**Traditional multi-turn pattern:**
```
Turn 1: model picks tool → runs → reads result
Turn 2: model picks next tool → runs → reads result
Turn 3: model picks next tool → runs → reads result
...N turns for N tools
```

**CodeAct pattern:**
```python
# model writes one program, runs once in a sandbox
result_a = call_tool("ado_get_work_item", id=ticket_id)
result_b = call_tool("ado_get_attachments", id=ticket_id)
docs = call_tool("confluence_search", query=result_a["title"])
call_tool("ado_add_comment", id=ticket_id, text=summarize(result_a, docs))
```

The program is stateless Python — no imports beyond the `call_tool()` helper. All tool calls are logged, sandboxed, and run atomically.

---

## Verified Performance Numbers (Microsoft's Own Benchmarks)

| Metric | Traditional | CodeAct | Delta |
|--------|------------|---------|-------|
| Execution time | baseline | 52.4% faster | significant |
| Token usage | baseline | 63.9% fewer | very significant |

**Caveat:** These are Microsoft's internal benchmark numbers from their BUILD announcement. Self-reported. No independent replication found as of June 2026. Treat as directionally correct, not universally applicable. Their benchmark likely used workflows where all tool calls are independent (no branching, no error recovery).

---

## How It Compares to Our Architecture

### Where CodeAct Would Help Us

**dx-automation diagnosis phase** (triage → verify → fix):
- Today: each ADO REST call is a separate tool use turn
- CodeAct: one program reads WI + attachments + PR status + CI results in one shot
- Saves: ~5-8 turns of context per diagnosis

**dx-req (story analysis)**:
- Today: get-work-item → get-attachments → search-confluence → get-figma → assemble
- CodeAct: one program, all reads parallelizable, result assembled before model thinks
- Saves: context + latency

**aem-page-finder**:
- Today: search MCP → refine → get-node-content → assemble
- CodeAct: one read program, no back-and-forth

### Where CodeAct Would NOT Help Us

**Interactive skills** (dx-step, dx-plan, dx-req with clarification loop):
- CodeAct is fire-and-forget; it cannot pause for human input mid-execution
- Our AskUserQuestion gate at Phase 2 of dx-req would break

**Skills with error-recovery branches** (dx-step-fix, dx-bug-all):
- CodeAct assumes success; error handling requires the model to branch after the result
- A failing `mvn clean install` in a CodeAct program doesn't naturally trigger dx-step-fix

**AEM MCP write operations**:
- JCR writes (setProperty, createNode) need to be conditional on reads
- Conditional logic in the Python program is possible but increases program complexity and risk of silent errors

---

## Applicability Assessment

| dx-automation phase | CodeAct fit | Notes |
|---------------------|-------------|-------|
| Read-only diagnosis (triage) | **High** | All ADO reads can batch |
| Story analysis (dx-req) | **High** | Read-only, no branching |
| Page discovery (aem-page-finder) | **High** | Read-only search + fetch |
| Code implementation (dx-step) | **Low** | Needs verify→fix loops |
| PR creation (dx-pr-commit) | **Low** | Needs confirmation gates |
| AEM content writes (dx-simple) | **Medium** | Reads are batchable; writes need guards |

**Recommendation:** Pilot CodeAct on read-heavy automation phases first (triage, discovery, analysis). Do not apply to write/fix phases until the pattern is proven stable in our tool chain.

---

## Microsoft Agent Framework Context (Build 2026)

CodeAct shipped alongside two other announcements:

**Agent Harness** — Microsoft's production layer combining model reasoning with shell/filesystem access, human-in-the-loop approval flows, and context management. Includes automatic context compaction, built-in memory providers, and middleware for long-running sessions. Analogous to what we've built in dx-aem-flow but for Azure-first workloads.

**Hosted Agents** — Deploy agents on Azure Foundry with scale-to-zero, persistent filesystem state, per-session isolation, and OpenTelemetry observability. Relevant if we ever want to offer hosted dx-automation without AWS Lambda.

---

## Integration Path (If We Proceed)

1. **Identify pilot phases** — Start with `dx-req` Phase 1 (story fetch) and `auto-triage` (BugFix Phase 1)
2. **Build `call_tool()` wrapper** — Thin Node.js or Python shim that wraps Claude Code MCP calls for the sandbox
3. **Evaluate token/latency savings** in our actual ADO tool chain (not Microsoft's benchmark)
4. **Gate on independence** — Only apply to phases where all tool calls are reads and don't branch on results
5. **Track** Dynamic Workflows (v2.1.154 experimental) — Anthropic's potential native equivalent

---

## Open Questions

- Does Claude Code v2.1.154 Dynamic Workflows solve the same problem as CodeAct natively?
- Can the CodeAct sandbox handle ADO REST authentication (PAT tokens, Azure AD)?
- What's the error behavior when one `call_tool()` in the program fails — does it abort the whole program or continue?
- Is there an open-source implementation of the `call_tool()` sandbox, or is it Microsoft-specific?

---

**Status:** Research only. No implementation started. See TODO #158.
**Next step:** Check if Claude Code Dynamic Workflows (v2.1.154+) makes CodeAct moot for our use case.
