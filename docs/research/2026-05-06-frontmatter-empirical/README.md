# Frontmatter empirical test — Phase 0

**Goal:** resolve the contradictions in `docs/research/2026-05-05-skill-frontmatter-research.md` by direct test in Claude Code, Copilot CLI, and VS Code Chat. Specifically:

1. Does Claude Code pre-approve **lowercase** tool names in `allowed-tools`, or silently drop them?
2. Does Copilot CLI pre-approve **PascalCase** tool names?
3. For Copilot CLI MCP wildcards, is the syntax `ado/*` (tip #29), `ado(*)` (paren — doc-research finding), or bare `ado`?
4. Does VS Code Chat 1.118 still warn on `allowed-tools` (issue #14131) and is it non-blocking?

We change *only* the `allowed-tools:` line on 4 probe skills, run each probe, count prompts, restore.

## Probes

| Probe | Plugin | Reason chosen |
|---|---|---|
| `dx-help` | dx-core | Lightweight; uses `ado/*` MCP wildcard; haiku/low |
| `dx-pr-review` | dx-core | Same MCP shape but opus/high — control for "does model affect prompt behavior?" |
| `aem-init` | dx-aem | Plugin-scoped MCPs (`AEM/*` + `chrome-devtools-mcp/*`) — different from project-level `ado` |
| `auto-status` | dx-automation | **No `allowed-tools` baseline** — control for "what's the baseline prompt rate?" |

## Variants

`./swap.sh <probe> <variant>` switches a probe between:

| Variant | Standard tools | MCP wildcard |
|---|---|---|
| `baseline` | (whatever was in the file originally; restores from `.bak`) | |
| `pascal` | `Read, Edit, Write, Grep, Glob, Bash, Agent` | `mcp__ado__*` (project) / `mcp__plugin_dx-aem_AEM__*` (plugin) |
| `lowercase-slash` | `read, edit, write, grep, glob, bash, agent` | `ado/*` |
| `lowercase-paren` | `read, edit, write, grep, glob, bash, agent` | `ado(*)` |

`auto-status` has no MCP, so its three variants only differ in casing of the standard tools.

## Prerequisites

- **Copilot CLI v1.0.40+ env vars** must be exported in the shell that runs `copilot`:

  ```bash
  export GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS=1
  export GITHUB_COPILOT_PROMPT_MODE_WORKSPACE_MCP=1
  ```

  Without these, repo-level skills and `.mcp.json` are silently ignored — the test will appear to fail for unrelated reasons.

- All four probe skills must be installed in each platform:
  - Claude Code: this repo's marketplace already provides them via `dx-core`/`dx-aem`/`dx-automation` plugins.
  - Copilot CLI: needs the plugins linked under `~/.copilot/plugins/` or invoked from this repo.
  - VS Code Chat: same plugin discovery as Claude Code (1.111+).

- Each platform must be running with **a fresh session** between variants. Permission state can be cached per-session.

## Probe action (per skill)

Invoke the skill and watch the **first 3 tool calls**. Record each tool's name and whether it triggered a permission prompt.

| Probe | Invocation | Expected first tools |
|---|---|---|
| `dx-help` | `/dx-help what components are in this project?` | Read (`.ai/index.md`), Grep, Bash (rg) |
| `dx-pr-review` | `/dx-pr-review 99999` (fake ID — first tool call is the ADO fetch, which is enough to test MCP wildcard) | `mcp__ado__repo_get_pull_request_by_id` (or `ado/...` in Copilot) |
| `aem-init` | `/aem-init` then cancel at first prompt | Read (config.yaml), Bash, AEM MCP probe |
| `auto-status` | `/auto-status` | Read (`.ai/automation/infra.json`), Bash (`aws sqs ...`) |

**You don't need to complete the skill — observe the first 3 tools then abort.** That's enough signal to know whether each tool was pre-approved or prompted.

## Test matrix

12 cells (4 probes × 3 variants). Plus baseline = 16 observations total. Run them in this order to minimise context-switching:

1. Test all 4 probes at `baseline` in **Claude Code** (sanity check — does the existing config behave the way the original author expected?)
2. Switch to `pascal`, retest all 4 in Claude Code → record
3. Switch to `lowercase-slash`, retest in Claude Code → record
4. Switch to `lowercase-paren`, retest in Claude Code → record
5. `swap.sh restore` to baseline
6. Repeat 1–5 in **Copilot CLI**
7. Repeat 1–5 in **VS Code Chat** (only if `allowed-tools` issue #14131 status is in question — otherwise skip; the warning is the data point)

After each platform, run `./swap.sh restore` and verify `git diff` shows no unintended drift.

## Observations template

Copy into `observations.md` and fill as you test.

```markdown
## Claude Code (version: ___)

### dx-help

| Variant | Read prompted? | Bash prompted? | MCP tool prompted? | Notes |
|---|---|---|---|---|
| baseline (lowercase + ado/*) |  |  |  |  |
| pascal |  |  |  |  |
| lowercase-slash |  |  |  |  |
| lowercase-paren |  |  |  |  |

### dx-pr-review
... (same table)

### aem-init
... (same table)

### auto-status
... (same table)

## Copilot CLI (version: ___, env vars set: yes/no)

(same structure × 4 probes)

## VS Code Chat (version: ___)

(same structure × 4 probes; also note any "not supported" warning text)
```

## Decision matrix (fill in after testing)

| Question | Answer |
|---|---|
| Claude Code accepts lowercase `read`/`edit`? |  |
| Claude Code accepts `ado/*`? |  |
| Copilot CLI accepts `Read`/`Edit` PascalCase? |  |
| Copilot CLI accepts `mcp__ado__*` Claude format? |  |
| Copilot CLI MCP wildcard syntax: `ado/*` / `ado(*)` / bare `ado`? |  |
| VS Code Chat warns on `allowed-tools`? Blocking? |  |
| Plugin-scoped MCPs (`AEM/*`) work the same as project-level (`ado/*`) in Copilot? |  |

## After Phase 0

- Update `docs/research/2026-05-05-skill-frontmatter-research.md` with verified facts (or supersede it with this doc as the source of truth).
- **Then** proceed to Phase 1 (fix tip pages) and Phase 2 (`search` removal + missing `effort:` on the 5 sonnet skills).
- Do NOT proceed to Phase 3 (60-skill rewrite) until the cross-platform `allowed-tools` syntax is empirically confirmed.

## Safety notes

- `swap.sh` only edits the four probe SKILL.md files. It never touches anything else.
- It backs up to `<file>.bak` on the first swap; subsequent swaps replace in place. `restore` moves `.bak` back.
- If something goes wrong: `git checkout -- plugins/` is always a clean rollback (the swap doesn't stage changes).
- Verify nothing leaked: `git status` should only show changes inside the four probe paths during testing, and clean after `restore`.
