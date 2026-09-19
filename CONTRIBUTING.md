# Contributing

Thanks for helping. This page gets you from clone to merged PR. It is deliberately short.

**Read this first, then stop.** [`CLAUDE.md`](CLAUDE.md) is the architecture guide — 31 KB, and
Claude Code loads it automatically in this repo. You do not need to read it up front, and you do
not need to paste any of it into a prompt. Your agent already has it.

There is **no build step**. The plugins are Markdown plus shell. That is why a careless change is
cheap to make and expensive to ship.

---

## 1. The one rule: know whether your change ships

Consumers install with `/plugin marketplace add easingthemes/dx-aem-flow`, which resolves plugins
through relative paths in `.claude-plugin/marketplace.json` with **no git ref pinned**. In practice
that means consumers track **`main`**, not the released tag.

> A `docs:` commit that edits a `SKILL.md` reaches real projects on their next refresh — no version
> bump, no changelog entry, nothing to notice. Conventional-commit type is **not** a safety valve
> for plugin content.

So the thing that matters is the **path**, not the commit type:

| Tier | Paths | Blast radius |
|---|---|---|
| **A — inert** | `docs/` · `website/` · `scripts/` · `plugins/*/evals/` · `cli/test/` · `CLAUDE.md` · `AGENTS.md` · `README.md` | none, by construction |
| **B — ships** | `plugins/*/{skills,agents,rules,templates,data,hooks}/` · `*/plugin.json` · `*/.mcp.json` · `marketplace.json` · `templates/config.yaml.template` | every consumer project |
| **C — needs a live system** | anything that can only be checked against real ADO / AEM / Copilot CLI / Figma / a pipeline | as B, plus you cannot verify it alone |

Check yourself before every push:

```bash
bash scripts/check-tier.sh
```

Exit 0 means Tier A and the diff cannot change behaviour in a consumer project. Exit 1 lists the
shipped paths — say so in the PR, and expect it to wait for a maintainer with a real consumer
project. Tier C is a property of the work rather than the diff, so the script cannot detect it;
that one is on you to flag.

**If you were invited to help: take Tier A work only**, unless a maintainer says otherwise in the
issue. CI enforces this on PRs labelled `tier-a`, so you cannot break anyone by accident.

---

## 2. Setup

```bash
git clone https://github.com/easingthemes/dx-aem-flow
cd dx-aem-flow
bash scripts/validate-skills.sh   # ~3s, no install needed
```

Node 24 is only needed for the JS suites. Nothing else to install.

`.claude/settings.json` pre-approves the read-only Bash tools, so an agent working here gets far
fewer permission prompts than in a fresh repo. That is intentional — don't strip it.

---

## 3. The dev loop

Load **all four plugins at once** from the repo you are editing:

```bash
claude --plugin-dir ./plugins
```

Claude Code reads the folder's top level and loads each subfolder that has a
`.claude-plugin/plugin.json` — so `dx-core`, `dx-aem`, `dx-hub` and `dx-automation` all come up
together. (Needs Claude Code v2.1.265+.)

Four things worth knowing, in rough order of how much time they save:

- **`/reload-plugins` after every edit.** Skills, agents, hooks, and plugin MCP servers are read
  when they load. Edit a `SKILL.md` and nothing changes until you reload. This is the single
  biggest time-waster for people new to plugin work — you edit, you test, nothing is different,
  and you go looking for a bug that isn't there.
- **`--plugin-dir` beats an installed copy of the same plugin for that session.** If you already
  have `dx-core` installed from the marketplace, you do *not* need to uninstall it to test your
  branch.
- **In an interactive session the folder is watched.** Add or remove a plugin subfolder and it
  loads or unloads live; Claude Code prints a line and tells you if a reload is needed.
- **`/context` lists what actually loaded** — custom agents included. When a skill "isn't
  triggering", check here before debugging the skill.

For hooks specifically: trigger the event the matcher targets (ask Claude to edit a file for a
`PostToolUse` hook) and read the [hook debug log](https://code.claude.com/docs/en/hooks#debug-hooks)
— it records which hooks matched, their exit codes and their output. Guessing from behaviour alone
is slow.

`CLAUDE.md` still documents the older `/plugin marketplace add /local/path` loop. That works too,
but it is slower and needs a reinstall per change. Prefer `--plugin-dir`.

---

## 4. Verify before you push

```bash
for s in scripts/validate-*.sh; do bash "$s" || break; done
```

Four structural validators, ~14s total. CI runs the same four plus **every** test suite it
discovers — any `*.test.js` under `plugins/` or `cli/`, any `run-tests.sh` / `*.test.sh` under
`plugins/` or `scripts/`. There are 12 today. Suites are **discovered, not listed**, so a new one
is picked up with no workflow change.

The constraint that comes with that: **a new suite must be hermetic.** No live ADO, AEM or
network, and no dependence on ambient git config. Copy one of the two existing patterns —
`cli/test/helpers.js` (seeds throwaway repos, sets an unroutable `http.proxy` so git fails fast
instead of dialling out) or `plugins/dx-automation/data/lambda/__tests__/helpers.js` (clears AWS
credentials, stubs `globalThis.fetch`).

**What the validators cannot tell you:** whether anything works. They read frontmatter, manifests
and counts. They pass happily over a script that dies on its first call — that is how two fatal
defects in `.ai/lib` shipped in a release (#197, #198). And `node --check` / `bash -n` are **not**
verification either; they parse syntax and cannot see a rejected argument or a wrong enum value.

> If you changed anything under `data/lib/` or `skills/*/scripts/`, run its suite. Actually run it.

Optional, useful:

```bash
claude plugin validate ./plugins/dx-core          # manifest + structure, --strict to fail on warnings
TMPDIR=/tmp claude plugin eval plugins/dx-core --runs 1 --max-cost-usd 1   # billed, see CLAUDE.md
```

`TMPDIR=/tmp` stops the eval sandbox from discovering your personal `~/.claude/skills`. Without it
your local skills leak into the run and the scores are meaningless.

---

## 5. Working with Claude Code in this repo

**Don't re-explain the repo.** `CLAUDE.md` is already in context. Prompts that start with "this is
a plugin repo with four plugins…" waste tokens and sometimes contradict the real guide.

**A good first prompt** is the TODO row and nothing else:

```
Work TODO #174 (docs/todo/TODO.md). Read its detail file first.
Satisfy the Done-when exactly — don't widen scope.
Tier A only: nothing under plugins/*/skills, agents, rules, templates, data, hooks.
Run the validators before you show me a diff.
```

Every TODO carries a **`Done-when`** — a concrete, checkable condition. Treat it as the spec. If
you find yourself deciding what "done" means, the row is underspecified: say so in the issue rather
than inventing a definition.

**Don't let the agent read 77 skills.** It will try. Point it at
[`docs/reference/skill-catalog.md`](docs/reference/skill-catalog.md) (264 lines, covers all of
them) and [`agent-catalog.md`](docs/reference/agent-catalog.md). For genuine cross-cutting
searches, use the `Explore` subagent so the file dumps stay out of your main context.

**Ask it to run the validators before you read the diff.** Three seconds, and it catches the
boring class of mistake so your review can be about the interesting class.

**`/code-review` before you open the PR** costs a minute and saves a round trip.

**Split risky work into a Tier A half.** Most Tier B items have a measurement hiding inside them.
*"Fix `allowed-tools` across 64 skills"* is Tier B and scary. *"Run a probe on two throwaway skills
and write down whether lowercase tool names actually grant anything"* is Tier A, takes an hour, and
decides whether the scary version is needed at all (that is TODO #213, and it is the pattern to
copy). Do the measurement, land it as docs, then the fix is obvious and small.

**One plugin per PR.** Several open TODOs (#106, #113, #114) are sweeps across dozens of skills. An
agent will happily rewrite 30 files in one pass. Don't let it — the diff becomes unreviewable and
the blast radius is the whole marketplace.

---

## 6. Never let the agent do these

Each of these has cost us something real.

| Don't | Why |
|---|---|
| Bump a version number by hand | semantic-release owns all 11 version files. `scripts/bump-versions.sh` is the source of truth; hand edits desync and `validate-structure.sh` fails. |
| Add `agents` or `skills` to `plugin.json` | **Breaks Claude Code** with `agents: Invalid input`. Both platforms auto-discover the default dirs. Only for non-standard paths. |
| Use `exit 1` in a hook to block | `exit 1` is a *non-blocking* error — shown only in verbose mode. Blocking is **`exit 2`**, with the message on stderr. This was a real bug (#34). |
| Shorten an MCP tool prefix | Plugin MCP tools register as `mcp__plugin_<plugin>_<server>__<tool>`. `mcp__AEM__…` matches nothing and fails at runtime as "tool not found". |
| Trim an over-length skill as a drive-by | `validate-skills.sh` ratchets on `BODY_OVER_BASELINE=13`. If you genuinely trim one, **lower the baseline in the same PR** — the validator prints the reminder. Otherwise the ratchet goes stale and stops protecting anything. |
| Rename a skill | TODO #12 is an open decision, not a task. 77 directories, every cross-reference, and six months of user muscle memory. |
| Hardcode a URL, branch, build command or path | Everything project-specific comes from `.ai/config.yaml` at runtime. Read `build.command`, not `mvn clean install`. |
| Add a `github` value to `scm.provider` | `ado` is the only implemented path. There is no GitHub code path behind it — config-driven is not provider-agnostic. |
| Say it works because CI is green | See §4. Structural checks cannot tell you a script runs. |

---

## 7. Authoring notes

Only the parts people get wrong. Full detail in `CLAUDE.md`.

- **Naming**: `{plugin}-{name}`, kebab-case — `dx-step-verify`, `aem-init`. Coordinators end `-all`.
  The `name:` in frontmatter must match the directory name exactly (CI enforces this).
- **`description`** is capped at 1,024 characters and CI **errors** above it. Body over 500 lines
  **warns**, under the ratchet above.
- **Branching skills use a DOT digraph as the single source of truth.** Change the graph first,
  then the sections. Every node needs a matching `### Section` heading, exact string match. Linear
  skills use numbered steps instead — don't mix the two.
- **Frontmatter**: five fields are Agent Skills spec, eight are Claude Code extensions. Which is
  which, and what other platforms do with them, is in
  [`docs/reference/skill-frontmatter-compatibility.md`](docs/reference/skill-frontmatter-compatibility.md).
- **Shell scripts need `chmod +x`.**
- **New TODO?** Add a numbered row in `docs/todo/TODO.md` **and** a detail entry with
  **Problem / Scope / Done-when** in the matching `todo-<topic>.md`. A row without a `Done-when`
  cannot be handed to anyone — which is exactly why about half the backlog can't be delegated yet.

---

## 8. Commit and PR

Conventional commits. The prefix decides the release:

| Prefix | Release |
|---|---|
| `feat:` | minor |
| `fix:` `perf:` `refactor:` | patch |
| `docs:` `chore:` `ci:` `test:` `style:` | **none** |
| `BREAKING CHANGE:` in body | major |

Remember §1: no release still reaches consumers if you touched a Tier B path.

Fill in [the PR template](.github/PULL_REQUEST_TEMPLATE.md). Two sections people skip and
maintainers need:

- **which tier** your diff is, and the output of the check in §1
- **what you actually ran** — not "should work". If you could not verify something, say which part
  and why. An honest gap is reviewable; a confident guess is not.

---

## 9. Picking something up

[`docs/todo/TODO.md`](docs/todo/TODO.md) is the single index. Good entry points:

- **Tier A, self-contained, no plugin knowledge needed** — backfilling `Scope:` on rows that lack
  one. Run `node scripts/triage-todos.mjs --gaps` for the live list: **38 of 149** open items
  cannot be classified or delegated until someone writes down which files they touch. The
  `#63`–`#68` harness-design series is the biggest cluster and predates the convention.
  Unglamorous, needs no plugin knowledge, and it is what unblocks handing the rest out.
- **Tier A, docs** — `#39`, `#40`, `#110`, `#145`.
- **Tier A, tests and evals** — `#173`, `#174`, `#175`, `#180`. These are the items that turn future
  Tier B work into Tier A work, so they are worth more than their priority label suggests.

Off-limits without asking: anything Tier C, and the open *decisions* (`#12`, `#10`) which need a
maintainer call, not an implementation.

Before starting, comment on the issue or open a draft PR so two people don't take the same row.
