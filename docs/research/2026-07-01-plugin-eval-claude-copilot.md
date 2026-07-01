# Plugin Evaluation — Claude Code + Copilot CLI Focus (July 2026)

Rating refresh scoped to **Claude Code and Copilot CLI only** (other platforms disregarded).
Delta to: [2026-06-15-dev-agency-harness-review.md](2026-06-15-dev-agency-harness-review.md)

---

## TL;DR

| Scope | Rating | Change vs. June | Driver |
|-------|--------|-----------------|--------|
| **Claude Code** | **8 / 10** | ↓ from 8.5 | Strong architecture; held back by skill bloat now violating the official <500-line rule, Stop-hook verify unwired, no circuit-breaker/observability. |
| **Copilot CLI** | **6.5 / 10** | ↓ from ~8 (combined) | Agents + skills + env-vars + MCP mapping correct, but `.github/hooks/hooks.json` still absent (zero harness safety) and oversized skills hit partial-read truncation hardest. |
| **Overall (these two)** | **7.5 / 10** | flat | Excellent Claude-first design; Copilot remains second-class due to missing hooks file and skill length. |

**Standout change since June:** skill bloat got materially worse. Median skill is now 283 lines and **13 skills exceed Anthropic's own 500-line ceiling** (max 1121). In June only 3 skills crossed ~260. This is now a violation of official Claude Code guidance — not just a Copilot partial-read problem — and it taxes every turn's token budget and gets clipped at compaction.

---

## Official-Docs Grounding

### Claude Code ([skills docs](https://code.claude.com/docs/en/skills))

- **Hard guidance: "Keep SKILL.md under 500 lines. Move detailed reference material to separate files."**
- Body target ~1,500–2,000 words; progressive disclosure via `references/`.
- Loaded skills **stay in context across turns** — every line is a recurring token cost.
- `description` + `when_to_use` are the trigger; each entry capped at 1,536 chars; skill-listing budget is 1% of context (`/doctor` shows truncation).
- Auto-compaction keeps only the first 5,000 tokens per skill (25k combined) — long skills get clipped after compaction.

### Copilot CLI ([plugin docs](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-creating), [hooks docs](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-hooks))

- Plugin = `plugin.json` + `agents/` (`NAME.agent.md`) + `skills/NAME/SKILL.md` + `hooks.json` + `.mcp.json`.
- Repo hooks live in **`.github/hooks/*.json`**; personal hooks in `~/.copilot/hooks/*.json`.
- Components are **cached on install** — must reinstall to pick up local edits.

### Best-practices sweep

Anthropic 2026 Agentic Coding Trends, Sourcegraph, Kilo, timdeschryver: hybrid = plan → sandbox execute → CI/PR gate; **context assembly upfront is the #1 failure point**; verification loops ("when the agent says done, grep for touched symbols it never opened"); don't over-use multi-agent (single agent matches multi on ~64% of tasks). Our architecture already reflects all of these.

---

## Codebase Verification — July 1, 2026

| Check | June state | July state | Verdict |
|-------|-----------|-----------|---------|
| `.github/hooks/hooks.json` (Copilot safety) | Missing | **Still missing** | ❌ Copilot users get zero branch-guard / next-step / workflow-state hooks |
| Stop hook → verification loop | Not wired | **Still not wired** (`Stop` only calls an optional project `stop-guard.sh` passthrough) | ❌ Victory-declaration bias unguarded |
| Skills over 500-line official limit | "3 skills >260" | **13 skills >500**, max **1121** (`dx-pr-review`), `dx-simple` 1025, `dx-init` 941, `dx-pr-answer` 938 | ❌ **Regressed** — hurts both platforms |
| `when_to_use` on every skill | All 76 done | **All 77 done** | ✅ Discovery signal intact |
| MCP tool-prefix naming | All correct | Correct | ✅ |
| Claude hook semantics (exit 2, precise matchers, `if` filters) | Good | Good | ✅ |
| Copilot env vars wired in `dx-init` | Done | Done | ✅ |

Skill size distribution (77 skills): median **283** lines, **13 over 500 lines**, max **1121**.

---

## Highest-ROI Fixes (priority order)

1. **Split the 13 oversized skills** into `SKILL.md` (<500 lines) + `references/*` (TODO #108/#113). Single fix that raises *both* scores — now an official-guidance violation for Claude Code, not only a Copilot issue.
2. **Port `.github/hooks/hooks.json`** (TODO #22) — closes the entire Claude↔Copilot safety gap. Env vars already wired, so the precondition is satisfied.
3. **Wire `Stop` → `dx-step-verify`** (TODO #159) — guards the #1 documented production failure mode (victory declaration). The verify skill already exists; the guard is ~10 lines.

---

## Sources

- [Claude Code skills](https://code.claude.com/docs/en/skills)
- [Copilot CLI plugins](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-creating)
- [Copilot CLI hooks](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-hooks)
- [Anthropic 2026 Agentic Coding Trends Report](https://resources.anthropic.com/hubfs/2026%20Agentic%20Coding%20Trends%20Report.pdf)
- [Sourcegraph — Agentic Coding in 2026](https://sourcegraph.com/blog/agentic-coding)
