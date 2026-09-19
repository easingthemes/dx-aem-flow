# SKILL.md Frontmatter — Spec Core vs Vendor Extensions

**Measured:** 2026-09-19 against 77 skills in `plugins/*/skills/*/SKILL.md`.
**Sources:** [Agent Skills specification](https://agentskills.io/specification) · [Claude Code skills reference](https://code.claude.com/docs/en/skills) · [Codex build-skills](https://learn.chatgpt.com/docs/build-skills) · [GitHub Copilot agent skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills)

This file exists to settle a claim we make in three shipped places — `AGENTS.md`,
`.codex/INSTALL.md` and the website — that our skills follow the Agent Skills open
standard. They do, but the accurate phrasing is **"Agent Skills core plus Claude Code
extensions"**: 8 of the 13 frontmatter keys we ship are not in the spec at all.

## The spec surface is six fields

The [specification](https://agentskills.io/specification) defines exactly six
frontmatter fields. Everything else is a vendor extension, and `metadata:` is the
spec's own escape hatch for vendor data.

| Field | Required | Spec constraint |
|---|---|---|
| `name` | **Yes** | 1–64 chars, `a-z0-9-` only, no leading/trailing/consecutive hyphen, **must match parent directory name** |
| `description` | **Yes** | 1–1024 chars, non-empty |
| `license` | No | License name or bundled file reference |
| `compatibility` | No | ≤500 chars, environment requirements |
| `metadata` | No | Map of string keys → string values; for client-specific properties |
| `allowed-tools` | No | **Space-separated string**. Experimental; support varies |

Body guidance (not validated by the spec): keep `SKILL.md` under 500 lines and the
instructions under ~5,000 tokens, with detail in `references/`.

## What we ship

| Key | In spec? | Claude Code | Copilot CLI | Codex | Skills using it |
|---|---|---|---|---|---|
| `name` | **core (req)** | documented | honored | honored | 77 / 77 |
| `description` | **core (req)** | documented | honored | honored | 77 / 77 |
| `when_to_use` | extension | documented — appended to `description` | ignored (v1.0.10+) | ignored | 77 / 77 |
| `argument-hint` | extension | documented — autocomplete hint | ignored | ignored | 77 / 77 |
| `allowed-tools` | **core (opt)** | documented | ignored (v1.0.10+) | ignored | 64 / 77 |
| `model` | extension | documented | ignored | ignored | 15 / 77 |
| `context` | extension | documented (`fork`) | **unsupported — GH #21** | ignored | 14 / 77 |
| `effort` | extension | documented (v2.1.267+) | ignored | ignored | 8 / 77 |
| `metadata` | **core (opt)** | accepted, not acted on | ignored | ignored | 6 / 77 |
| `compatibility` | **core (opt)** | accepted, not acted on | ignored | ignored | 6 / 77 |
| `agent` | extension | documented (needs `context: fork`) | **unsupported — GH #22** | ignored | 6 / 77 |
| `disable-model-invocation` | extension | documented | ignored | ignored | 4 / 77 |
| `hooks` | extension | documented | see hook table in `CLAUDE.md` | ignored | 2 / 77 |
| `paths` | extension | documented | ignored | ignored | 0 / 77 (TODO #38) |

Nested under `metadata:` in 6 skills: `version`, `mcp-server`, `category`. This is the
correct place for them — they are ours, not the spec's, and the spec names `metadata`
as where client-specific properties belong.

**Unknown fields degrade safely** on Copilot CLI since v1.0.10 (2026-03-20), which
suppressed unknown-frontmatter warnings — see
[`allowed-tools-compatibility.md`](allowed-tools-compatibility.md) for the version
history. Codex documents only `name` and `description` and keeps everything else in a
separate `agents/openai.yaml`, so our extensions are inert there rather than rejected.

## Conformance status

Measured 2026-09-19 with `scripts/validate-skills.sh` plus direct checks:

| Spec rule | Result |
|---|---|
| `name` matches parent directory | **77 / 77 pass** |
| `name` charset and length | **77 / 77 pass** (enforced in CI) |
| `description` present, ≤1024 chars | **77 / 77 pass** (enforced in CI) |
| Body ≤500 lines (guidance) | **64 pass, 13 over** — ratcheted baseline, TODO #108 / #113 |
| `allowed-tools` is a space-separated string | **0 / 64 conform** — see below |

### `allowed-tools`: we use a YAML list, the spec says string

All 64 skills that set `allowed-tools` use the YAML-list form:

```yaml
allowed-tools: ["read", "edit", "search", "write", "agent", "AEM/*", "playwright/*"]
```

Claude Code documents both forms ("accepts space/comma-separated string or YAML list"),
so this works on our primary platform. The spec says *space-separated string*. A skill
copied out of this repo into a stricter client may not get the grant. Low risk, but it
is a deviation and should be written down rather than discovered.

### Unverified: whether our `allowed-tools` values grant anything

The values above are lowercase (`read`, `edit`, `write`, `search`, `agent`) and come
from the Copilot-shaped table in `allowed-tools-compatibility.md`. Claude Code's actual
tool names are `Read`, `Edit`, `Write`, `Bash`, `Grep`, `Glob`. Whether Claude Code
matches these case-insensitively is **not documented and not tested here**, so it is
possible that 64 skills carry an allowlist that grants nothing on the platform we
primarily target. This is exactly the failure mode `CLAUDE.md` warns about — a
structural check passes over a field that does nothing. Tracked as TODO #213 with a
live probe as its Done-when. Do not treat the table above as evidence either way.

## claude.ai upload subset

Claude Code v2.1.275 added syncing of skills and plugins enabled on claude.ai into
terminal sessions (`syncClaudeAiSkills`, `syncClaudeAiPlugins`). The Claude Code skills
reference states that skills uploaded to claude.ai support only `name`, `description`,
`license`, `compatibility`, `metadata` and `allowed-tools` — i.e. **the spec core, and
nothing else**. A skill of ours routed through claude.ai loses `when_to_use`, `model`,
`effort`, `context` and `agent`. Relevant to how consumers install us; see TODO #214.

## Recommended wording for the conformance claims

Replace "Skills use the Agent Skills open standard" in `AGENTS.md:52`,
`.codex/INSTALL.md:42` and `website/src/pages/learn/intro.mdx` with a statement that is
true on inspection:

> Skills follow the [Agent Skills](https://agentskills.io/specification) open standard —
> spec-core fields (`name`, `description`, `allowed-tools`, `compatibility`, `metadata`)
> plus Claude Code extensions (`when_to_use`, `argument-hint`, `model`, `effort`,
> `context`, `agent`) that other clients ignore safely. See
> `docs/reference/skill-frontmatter-compatibility.md`.

(Link target written repo-root-relative above, since the three files that carry the claim
sit at different depths — adjust per file when applying.)

The website front page (`index.mdx:252`) also names "OpenSkills, OpenPlugins" — both
names are stale. Agent Skills is the current name of the first; Open Plugins was
absorbed into [Agent Plugins 1.0](https://github.com/agentplugins/agent-plugins-spec)
(2026-08-06) and `open-plugins.com`, still linked from
[`allowed-tools-compatibility.md`](allowed-tools-compatibility.md), is dead.

## Validation

`scripts/validate-skills.sh` already enforces spec rules 1, 2 and 5 (name/dir match,
name charset, description cap) and warns on the body-length guidance. It is, in
practice, a spec-conformance checker that nobody framed as one. The gap is
`allowed-tools` form and the `metadata`-vs-top-level placement of vendor keys.

The spec also ships a reference validator,
[`skills-ref`](https://github.com/agentskills/agentskills/tree/main/skills-ref)
(`skills-ref validate ./my-skill`). It is Python, and its own README calls it a
reference library "for demonstration purposes" — adopting it would put a Python
dependency into a bash/JS CI to re-check rules our own validator already covers.
**Extend `validate-skills.sh` instead** (TODO #212).

## Related

- [`allowed-tools-compatibility.md`](allowed-tools-compatibility.md) — per-version Copilot CLI behavior for the one spec field with cross-platform history
- [`skill-catalog.md`](skill-catalog.md) — the skills themselves
- [2026-09-19 platform state sweep](../research/2026-09-19-platform-state-sweep.md) — the sweep this file came out of
- [`docs/todo/todo-cross-platform.md`](../todo/todo-cross-platform.md) — first-class Codex and Gemini support
