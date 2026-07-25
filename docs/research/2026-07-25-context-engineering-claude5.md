# Context Engineering for Claude 5 Models — Anthropic

**Source:** Anthropic thread on context engineering (Claude 5 generation — Opus 5, Fable 5)
**Captured:** 2026-07-25
**Status:** Complete
**Relevance:** Directly informs this repo's skill/CLAUDE.md/rules conventions —
Model Tier Strategy, concise-body audit (TODO #113), lean system prompt default,
progressive disclosure, three-layer override system.

Anthropic removed **over 80% of Claude Code's system prompt** for the newest
models (Opus 5, Fable 5) with **no measurable loss** on coding evals. The core
message: newer models have better judgement, so over-constraining them with
rules, examples, and repetition now *hurts*. Best practices are shipped via
`/doctor` ("rightsize your skills and CLAUDE.md files").

---

## The core insight: unhobbling

Claude Code was over-constrained through the system prompt, CLAUDE.md, and
skills. Reading internal transcripts, they found **conflicting instructions in a
single request** — e.g. "leave documentation as appropriate" vs. "DO NOT add
comments" — as system prompt, skills, and user requests clash. Claude *can*
resolve these, but it burns reasoning deciding what to obey. Many guardrails
that were once needed to avoid worst-case behavior (deleting files, bad
comments) can now be deleted and left to model judgement.

---

## "Then vs. Now" — the eight myths

| Then (old best practice) | Now (Claude 5 era) |
|--------------------------|--------------------|
| Give Claude **rules** | Let Claude use **judgement** |
| Give Claude **examples** | **Design interfaces** (expressive params) |
| Put it all **upfront** | Use **progressive disclosure** |
| **Repeat yourself** | **Simple tool descriptions** |
| Memory in **CLAUDE.md** | **Auto-memory** (Claude saves relevant memories) |
| **Simple specs** (markdown plans) | **Rich references** (HTML artifacts, code, tests, rubrics) |

**Rules → judgement.** Old system prompt: *"default to writing no comments,
never multi-line comment blocks…"* — wrong for a subset of prompts. New system
prompt: *"Write code that reads like the surrounding code: match its comment
density, naming, and idiom."*

**Examples → interfaces.** Examples constrain the model's exploration space.
Instead, make tool parameters expressive. A Todo tool's `status` enum
(pending/in_progress/completed) plus "keep one item in_progress" defines behavior
without examples.

**Upfront → progressive disclosure.** Move situational context (code review,
verification) into skills that load on demand. Applies to tools too: "deferred
loading" tools require `ToolSearch` before use, so they cost no context until
needed. Same for CLAUDE.md/SKILL.md — prefer **a tree of files loaded at the
right time** over one central repository of every practice.

**Repeat → simple descriptions.** Older models needed repetition and favored
end-of-context instructions. Now: put tool instructions in the tool description,
not duplicated in the system prompt.

**CLAUDE.md memory → auto-memory.** Claude now automatically saves memories
relevant to the work and the user, instead of manual `#` writes.

**Simple specs → rich references.** Claude handles richer references now: HTML
artifacts, **code as spec** (a test suite or a function to port), and **rubrics**
(let verifier agents check your taste, e.g. "what does good API design look
like"). Prefer references that live *in code* — high-fidelity, in a language
Claude knows well.

---

## How to assemble your context

- **System prompt** — tied to product context (what product, what it's doing).
  For Claude Code you'll never touch it; if building your own harness, spend time
  here.
- **CLAUDE.md** — keep lightweight. Briefly say what the repo is for, then spend
  most tokens on **gotchas** (e.g. "types live in one monolithic file"). Avoid
  stating the obvious that Claude can see from the filesystem. Use progressive
  disclosure — push detailed verification steps into a skill referenced from
  CLAUDE.md.
- **Skills** — lightweight guides to find info when needed. Avoid
  over-constraining except in highly important areas. Split long skills into many
  files (progressive disclosure). Best when they encode **opinions, knowledge, or
  best practices particular to you/your team/product**.
- **References** — `@`-mention files (specs, mockups, whole codebases). Prefer
  code/files: an HTML mockup beats a screenshot or prose description.

**Tooling:** `/doctor` ("claude doctor") auto-simplifies your system prompt,
skills, and CLAUDE.md. See the Fable field guide for advanced-model prompting.
