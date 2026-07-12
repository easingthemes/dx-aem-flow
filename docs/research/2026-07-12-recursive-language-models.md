# Recursive Language Models (RLMs) — research snapshot

**Date:** 2026-07-12
**Status:** Initial sweep — feeds TODO #164 (deep-dive) and #165 (implementation spike)

## What RLMs are

Proposed by Alex Zhang, Tim Kraska, and Omar Khattab (MIT) — [arXiv:2512.24601](https://arxiv.org/abs/2512.24601) (v1 Dec 2025, v3 May 2026); original write-up: [Alex Zhang's blog](https://alexzhang13.github.io/blog/2025/rlm/).

Instead of feeding a long prompt into the context window, the prompt is treated as **part of an external environment**: loaded as a variable in a persistent Python REPL. The root model never sees the raw content — it writes code to peek/grep/slice/transform the variable and can call a fresh sub-LLM (`rlm_agent(query, chunk)`) on any snippet, aggregating results programmatically. The final answer is built iteratively in an environment variable, not generated in one shot.

Key inversion vs. today's agent scaffolds: **the model manages its own context**, rather than the harness deciding what to compact/retrieve/summarize.

## Reported results

- Processes inputs ~100× beyond the native context window, at roughly comparable cost (root token count stays small).
- +26% over compaction baselines (GPT-5), +130% vs CodeAct with sub-calls, +13% vs Claude Code on long-context tasks; RLM-wrapped Qwen3-8B beats bare Qwen3-8B by 28.3% avg.

## State of the field (mid-2026)

- **Training > scaffolding is the 2026 frontier.** [Prime Intellect](https://www.primeintellect.ai/blog/rlm): zero-shot RLM behavior is underutilized by API models (math tasks got *worse* untrained); RL-training models to manage their own context end-to-end is the expected breakthrough. Open tooling: `verifiers`, `prime-rl`, Environments Hub.
- **Open problems:** recursion depth capped at 1 (root → sub-LLM); inefficient exploration code; underused parallelism; weak multi-modal support.
- **Implementations:** official [alexzhang13/rlm](https://github.com/alexzhang13/rlm) (plug-and-play, drivable from Claude Code/Copilot/Cursor, multi-provider); [hampton-io/RLM](https://github.com/hampton-io/RLM) (Node/TS); [grishahq/recursive-llm](https://github.com/grishahq/recursive-llm); [Google ADK integration](https://discuss.google.dev/t/recursive-language-models-in-adk/323523) adding lazy file loading, bounded parallel sub-agents, event streaming.

## Transferable workflow-design principles

1. **Context as environment, not prompt** — coordinators get handles + query tools, never raw bulk data.
2. **Cheap root, disposable workers** — root stays lean/long-lived; tools live with sub-agents, not the root.
3. **Programmatic aggregation** — combine sub-results in code (dedupe/vote/merge), not by re-prompting.
4. **Iterative answer construction** — the deliverable is a mutable artifact refined across turns.
5. **Bounded recursion + parallel fan-out** — one delegation level covers most value today.

## Fit with dx-aem-flow

Already RLM-shaped: `.ai/specs/` file-convention data passing, Haiku/Sonnet/Opus tiering, coordinator fan-out, branch-as-state-store recovery (#141/#150).

Genuinely new to borrow:

- **(a) Never-read-raw rule for coordinators** — `dx-agent-all`, `dx-bug-all`, `dx-pr-review` should dispatch a sub-agent per chunk for large inputs (big PRs, long ticket threads, AEM content trees) and aggregate structured results, instead of reading the artifact into the coordinator's context.
- **(b) Spec dir as the RLM "environment variable"** — the durable, programmatically-edited answer store. Branch-as-state already does this for *state*; extend to *content decomposition*.

Cross-refs: #47 (context budget), #49 (output discipline), #63 (progress handoff artifact), #158 (CodeAct — the complementary "reason in code" paradigm).

## All sources

- [arXiv:2512.24601 — Recursive Language Models](https://arxiv.org/abs/2512.24601)
- [Alex Zhang's original blog post](https://alexzhang13.github.io/blog/2025/rlm/)
- [Prime Intellect: RLM paradigm of 2026](https://www.primeintellect.ai/blog/rlm)
- [Official rlm library](https://github.com/alexzhang13/rlm)
- [RLMs in Google ADK](https://discuss.google.dev/t/recursive-language-models-in-adk/323523)
- [Introl overview](https://introl.com/blog/recursive-language-models-rlm-context-management-2026)
- [Agentic context management (RLM vs LCM comparison)](https://deadneurons.substack.com/p/agentic-context-management-why-the)
