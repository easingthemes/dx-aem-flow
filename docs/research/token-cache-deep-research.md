# Deep Research: AI Model Token Caching for Claude Code

**Date:** 2026-03-31
**Scope:** Prompt caching mechanics, Claude Code context management, pricing, provider comparison, and practical recommendations for dx-aem-flow automation pipelines.

---

## 1. What Is Prompt/Token Caching?

Prompt caching allows the API to **reuse previously processed input tokens** across requests. When you send the same prompt prefix repeatedly (system instructions, tool definitions, shared context), the model's internal key-value (KV) representations are stored in memory and reused on subsequent calls instead of being recomputed from scratch.

**Key benefits:**
- **Up to 90% cost reduction** on cached input tokens
- **Up to 85% latency reduction** for long prompts (e.g., 100K-token prompt: 11.5s -> 2.4s)
- Enables richer context (more examples, longer system prompts) without proportional cost increase

Caching operates on the **prompt prefix** -- everything from the start of the request up to and including the block marked with `cache_control`. The cached segment must be **100% identical** (byte-for-byte) across requests to achieve a cache hit.

---

## 2. Anthropic API Prompt Caching -- Technical Details

### 2.1 How to Enable

Add `"cache_control": {"type": "ephemeral"}` to any content block (system, tools, or messages). The API caches all content from the start of the request up to and including that block.

```json
{
  "system": [
    {
      "type": "text",
      "text": "You are an expert AEM developer...",
      "cache_control": {"type": "ephemeral"}
    }
  ],
  "messages": [...]
}
```

### 2.2 Cache Duration (TTL)

| TTL Option | Write Cost Multiplier | Read Cost (Cache Hit) | Notes |
|------------|----------------------|----------------------|-------|
| 5-minute (default) | 1.25x base input price | 0.1x base input price | Standard; refreshes on each hit |
| 1-hour (extended) | 2.0x base input price | 0.1x base input price | For less frequent access patterns |

Cache entries **refresh their TTL on each hit** -- a cache used every 4 minutes with a 5-minute TTL will persist indefinitely.

### 2.3 Minimum Token Requirements

Cache checkpoints have model-specific minimums:
- **Claude Sonnet 4.6 / Opus 4.6:** 1,024 tokens per checkpoint
- Second checkpoint requires 2,048 cumulative tokens, etc.

### 2.4 Cacheable Content (in precedence order)

1. **Tools** -- tool definitions are processed first
2. **System prompt** -- system instructions
3. **Messages** -- conversation history, in order

The cache matches the longest prefix possible. Adding, removing, or reordering tools/system blocks will invalidate the cache.

### 2.5 Workspace Isolation (2026 Change)

Starting **February 5, 2026**, prompt caching uses **workspace-level isolation** (previously organization-level) on the direct Anthropic API and Azure AI Foundry. Amazon Bedrock and Google Vertex AI maintain organization-level isolation.

### 2.6 Security Model

- Raw prompt text is **never stored** -- only KV cache representations and cryptographic hashes
- Cache entries are held **in memory only**, not at rest
- Entries are **deleted after TTL expiration**
- Cache entries are **isolated between organizations/workspaces**

---

## 3. Pricing Impact

### 3.1 Per-Model Pricing (2026)

| Model | Base Input | Cache Write (5m) | Cache Write (1h) | Cache Read | Output |
|-------|-----------|-------------------|-------------------|------------|--------|
| **Opus 4.6** | $15/MTok | $18.75/MTok | $30/MTok | **$1.50/MTok** | $75/MTok |
| **Sonnet 4.6** | $3/MTok | $3.75/MTok | $6/MTok | **$0.30/MTok** | $15/MTok |
| **Haiku 4.5** | $1/MTok | $1.25/MTok | $2/MTok | **$0.10/MTok** | $5/MTok |

### 3.2 Break-Even Analysis

With the 5-minute cache:
- **Write cost:** 1.25x (25% premium on first call)
- **Read cost:** 0.1x (90% savings on every subsequent call)
- **Break-even:** Just **2 API calls** with the same prefix

For a typical dx-automation pipeline run that makes 10-50 API calls with shared system context, caching reduces input token costs by **~85-90%** after the initial write.

### 3.3 Combined Discounts

Prompt caching stacks with the **Batch API** (50% discount), enabling up to **95% total cost reduction** on input tokens.

---

## 4. Claude Code Context Management

Claude Code manages context through several mechanisms that interact with -- but are distinct from -- API-level prompt caching.

### 4.1 Automatic Context Compaction

Claude Code monitors token usage in real-time and triggers **auto-compaction** when approaching context limits (~95% capacity / ~25% remaining). The process:

1. Analyzes conversation to identify key information
2. Strips images, PDFs, and empty blocks
3. Creates a condensed summary preserving decisions, file states, and task progress
4. Replaces old messages with the summary
5. Continues seamlessly

**What's preserved:** Current files, decisions made, task state, key code snippets
**What's lost:** Detailed back-and-forth, early instructions (put persistent rules in `CLAUDE.md`)

### 4.2 Manual Compaction (`/compact`)

Run `/compact` proactively at natural breakpoints (after completing a phase of work). You can focus it: `/compact focus on the API changes`.

**`/compact` vs `/clear`:**
- `/compact` -- summarizes and preloads as new context (retains key info)
- `/clear` -- wipes everything, fresh start

### 4.3 Extended Thinking & Token Budget

Extended thinking blocks are **not carried forward** as input tokens. Effective context:
```
context_window = (input_tokens - previous_thinking_tokens) + current_turn_tokens
```

This means thinking doesn't consume your cached prefix or conversation history.

### 4.4 Subagents for Context Isolation

Subagents get their own **fresh, isolated context window**. When complete, only a summary returns to the parent. This is critical for long-running sessions -- detailed work happens in isolation without bloating the main context.

### 4.5 How Claude Code Leverages API Caching

Claude Code benefits from prompt caching transparently:
- **System prompt + tool definitions** remain stable across turns, forming a cacheable prefix
- **Conversation history** accumulates as a growing prefix that caches incrementally
- Dynamic content has been removed from tool descriptions to improve cache hit rates (especially for Bedrock/Vertex users)

### 4.6 Server-Side Compaction API

For programmatic use, enable compaction via the Messages API:
```json
{
  "context_management": {
    "edits": ["compact_20260112"]
  }
}
```
This handles context management automatically for long-running agentic workflows.

---

## 5. Provider Comparison

| Feature | Anthropic | OpenAI | Google (Gemini) |
|---------|-----------|--------|-----------------|
| **Caching model** | Explicit (`cache_control`) + automatic | Automatic only | Explicit (`CachedContent`) |
| **Cache discount** | 90% (0.1x read) | 50% (0.5x read) | 75% (0.25x read) |
| **Write premium** | 25% (5m) / 100% (1h) | None | None |
| **Min TTL** | 5 minutes | ~5-10 min (automatic) | 1 hour (minimum) |
| **Max TTL** | 1 hour (explicit) | Session-based | Configurable |
| **Developer control** | High (explicit breakpoints) | None (fully automatic) | High (named cache objects) |
| **Min tokens** | 1,024 (model-dependent) | 1,024 | 32,768 |

**Key differences:**
- **Anthropic** gives the most control with explicit cache breakpoints and offers the deepest discount (90%)
- **OpenAI** is zero-effort (automatic) but only 50% savings and no control over what's cached
- **Google** requires the most setup (create named cache objects) and has a high minimum (32K tokens) but offers long-lived caches

---

## 6. Best Practices for Maximizing Cache Hits

### 6.1 Prompt Structure

Order content for maximum cache reuse:
1. **Tools** (most stable -- rarely change between calls)
2. **System prompt** (changes infrequently)
3. **Static context** (reference docs, examples)
4. **Conversation history** (grows but prefix is stable)
5. **Current user message** (always different -- never cache this)

### 6.2 For dx-automation Pipelines

- **Place `cache_control` on the system prompt** -- shared across all pipeline agent calls
- **Stable tool definitions** -- don't dynamically generate tool schemas per-call
- **Batch similar requests** within the 5-minute TTL window
- **Use model tiering** -- cache benefits compound: Haiku reads at $0.10/MTok vs Opus at $1.50/MTok
- **Monitor cache metrics** -- track `cache_read_input_tokens` and `cache_creation_input_tokens` in responses (already implemented in `pipeline-agent.js`)

### 6.3 Multi-Turn Conversations

Each turn extends the cached prefix. The growing conversation history naturally caches because the API sees the same prefix (system + tools + previous messages) with only the new user message appended.

### 6.4 Avoid Cache-Busting

- Don't add timestamps, random IDs, or dynamic content to system prompts
- Don't reorder tools between calls
- Don't modify content blocks that precede the cache breakpoint

---

## 7. Recent Developments (2025-2026)

1. **Automatic prompt caching** (Feb 2026) -- Anthropic now automatically caches content on all API calls, even without explicit `cache_control` markers. Explicit markers still give finer control.

2. **Workspace-level cache isolation** (Feb 2026) -- Caches are now isolated per workspace on direct API, improving security for multi-team organizations.

3. **Server-side compaction API** (`compact_20260112`) -- Official API support for context compaction, removing the need for client-side implementation.

4. **Extended thinking is not cached** -- Thinking tokens are generated fresh each turn and don't consume the cached prefix, keeping cache efficiency high for thinking-heavy workflows.

5. **1-hour TTL option** -- Extended cache duration for workloads with less frequent access patterns.

---

## 8. Relevance to dx-aem-flow

### Current Implementation

The project already tracks cache metrics in `pipeline-agent.js` (lines 95-162):
- Per-turn breakdown: `cache_read_input_tokens`, `cache_creation_input_tokens`
- Per-skill token attribution
- Cost alert thresholds via `COST_ALERT_USD`

### Documented in Project

The costs page (`website/src/pages/costs.mdx`) documents:
- 90% cache read discount per model tier
- Three-state degradation: Normal -> Suggest-only -> Halted

### Optimization Opportunities

1. **System prompt stability** -- ensure automation agent system prompts don't include dynamic content that would bust the cache
2. **Pipeline batching** -- group agent calls within 5-minute windows to maximize cache reuse
3. **Model tiering alignment** -- the existing Opus/Sonnet/Haiku tiering already optimizes cost; caching amplifies these savings
4. **Subagent isolation** -- already used to prevent context bloat; also prevents cache-busting from unrelated context

---

## Sources

- [Anthropic Prompt Caching Docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- [Anthropic Pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- [Anthropic Compaction Docs](https://platform.claude.com/docs/en/build-with-claude/compaction)
- [Claude Code Context Windows](https://platform.claude.com/docs/en/build-with-claude/context-windows)
- [Automatic Context Compaction Cookbook](https://platform.claude.com/cookbook/tool-use-automatic-context-compaction)
- [Anthropic Prompt Caching Announcement](https://www.anthropic.com/news/prompt-caching)
