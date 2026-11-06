# TODO — Upstream Changes (November 2026 intake)

From [2026-11-06-claude-code-vs-copilot-cli.md](../research/2026-11-06-claude-code-vs-copilot-cli.md):
Claude Code v2.1.302–v2.1.318 and Copilot CLI v1.0.99–v1.0.106. Notes for existing items
went into #200, #244 and #246. Each item's **Done-when** is checkable in this repo.

## Lint Copilot agent templates with `-p --agent` ignored-key warning

**Added:** 2026-11-06
**Problem:** Copilot CLI v1.0.106 warns on stderr when `copilot -p --agent <name>` loads an agent whose frontmatter has keys Copilot ignores. Our generated `.github/agents/*.agent.md` carry `model:` lists, `reasoning-effort:` and agent-scoped `hooks:` (TODO-228, TODO-245); a key Copilot silently drops looks exactly like one it honours. No check of ours can see that today — `validate-structure.sh` only checks shape.
**Scope:** `plugins/*/templates/agents/*.agent.md.template`, `scripts/validate-structure.sh`, `docs/todo/todo-copilot-cli.md`.
**Done-when:** a dated note in this section lists, per template, the stderr output of one `copilot -p --agent <name> "noop"` run on Copilot ≥ v1.0.106 in a scaffolded project, and every reported key is either removed from the template or explained in `todo-copilot-cli.md`.
**Approach:** manual run first; only script it if keys turn up. Needs a live Copilot login, so it can not be a CI suite (hermetic rule).

## Agent Plugins 1.0 — watch Claude Code adoption

**Added:** 2026-11-06
**Problem:** Agent Plugins 1.0 (2026-08-06) packages skills + MCP servers as a portable plugin; hooks, subagents and rules stay outside the core. Copilot-side vendors back it, Anthropic's plugin format was not a launch client. If Claude Code adopts it, we could ship one manifest instead of `.claude-plugin/` + `.cursor-plugin/` + `gemini-extension.json`; if not, nothing changes. Source is secondary (blogs) — the spec itself has not been read.
**Scope:** `.claude-plugin/`, `.cursor-plugin/`, `gemini-extension.json`, `plugins/*/.claude-plugin/plugin.json`, `scripts/validate-structure.sh`.
**Done-when:** a dated note in this section records, from the official spec and the Claude Code changelog, whether Claude Code reads an Agent Plugins 1.0 manifest — and if yes, a follow-up item exists for manifest consolidation.
