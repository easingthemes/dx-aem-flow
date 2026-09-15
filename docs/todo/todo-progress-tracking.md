# Progress Tracking

How dx coordinators report run progress, after Claude Code stopped offering the
task-tracking tools by default.

**Background.** Claude Code v2.1.233 (2026-08-14) removed `TodoWrite`,
`TaskCreate`, `TaskGet`, `TaskUpdate` and `TaskList` from the default tool set
on Opus 4.8, Sonnet 5, Fable 5, Mythos 5 and newer. v2.1.260 narrowed it again:
the tools now ship only on Claude 3.x, Opus 4.0–4.7, Sonnet 4.0–4.6 and Haiku
4.5. Codex CLI 0.152.0 (2026-09-01) made `update_plan` opt-in for every model.
Anthropic's [tools reference](https://code.claude.com/docs/en/tools-reference):
*"On newer models, Claude keeps track of multi-step work without a written
checklist, and the tools' definitions and reminders take up context."* The
[Agent SDK todo page](https://code.claude.com/docs/en/agent-sdk/todo-tracking)
adds the decision rule: *"Opt a session in only when your application reads
those tool calls."*

Nothing in dx read those tool calls — they were a live checklist for a human
watching a transcript, and `dx-automation` runs headless in ADO where nobody is.

## File-first progress in every coordinator — DONE

**Added:** 2026-09-12
**Completed:** 2026-09-12
**Problem:** Seven skills (`dx-agent-all`, `dx-step-all`, `dx-step`, `dx-req`,
`dx-req-dod`, `dx-bug-all`, `dx-figma-all`) instructed `TaskCreate`/`TaskList`/
`TaskUpdate` unconditionally ("you MUST"), on models that no longer have them.
`dx-step` and `dx-req` pin `model: sonnet`, which resolves to Sonnet 5, so no
tier escaped. The only guard — "check if `TaskCreate` exists before using it" in
`rules/task-progress.md` — had **zero references** in `plugins/` and no
`templates/rules/` counterpart, so it never reached `.ai/rules/` or the model.
Not a crash (a missing tool means the model improvises) but wasted turns and
progress that differed run to run. Only 2 of 7 skills had a file fallback.
**Scope:** `plugins/dx-core/rules/task-progress.md`,
`plugins/dx-core/templates/rules/task-progress.md.template`,
`plugins/dx-core/shared/update-progress.sh`, the 7 SKILL.md files above plus
`dx-simple`, `plugins/dx-core/skills/dx-doctor/SKILL.md`.
**Done-when:** `grep -L "update-progress.sh" plugins/dx-core/skills/dx-{agent-all,step-all,step,req,req-dod,bug-all,figma-all,simple}/SKILL.md`
returns nothing, AND `grep -rl "task-progress" plugins/` returns more than the
rule file itself.
**Resolution:** The progress *file* is the source of truth everywhere, written
by one shared `shared/update-progress.sh` (the near-identical `dx-simple` and
`dx-bug-all` copies became thin wrappers over it, and their `progress.md.tmpl`
templates were dropped — the script emits the header). Task tools are an
optional mirror the outermost coordinator may use when the session has them.
`rules/task-progress.md` is rewritten as a contract and finally wired: a
`templates/rules/` counterpart installs it to `.ai/rules/`, `/dx-doctor` checks
it, and all 8 skills reference it by name.

## Live checklist as an explicit opt-in

**Added:** 2026-09-12
**Problem:** The live checklist was genuinely useful in interactive Claude Code
runs, and it is still available — just opt-in. Today nothing in dx offers it, so
a team that wants it has to discover `CLAUDE_CODE_ENABLE_TODO_TOOLS` themselves.
Four mechanisms exist and only one is an env var, which is not obvious:

| Where | How |
|---|---|
| Shell | `export CLAUDE_CODE_ENABLE_TODO_TOOLS=1` |
| Project | name `TaskCreate` in `.claude/settings.json` permissions allow list |
| One session | `claude --allowedTools TaskCreate` |
| ADO pipeline | add `TaskCreate,TaskUpdate,TaskList` to `ALLOWED_TOOLS` |
| Agent SDK | `allowedTools` / `tools` / `env` (TypeScript `env` **replaces** the subprocess environment — spread `...process.env`) |

**Scope:** `plugins/dx-core/skills/dx-init/SKILL.md` (settings.json step),
`plugins/dx-automation/data/pipelines/cli/*.yml` (`ALLOWED_TOOLS`),
`docs/reference/config-reference.md`.
**Done-when:** `/dx-init` asks once whether to enable the live checklist and,
on yes, writes `TaskCreate` into the project's `.claude/settings.json` allow
list; the answer is recorded in `.ai/config.yaml` so a re-run does not re-ask.
**Approach:** Keep it a display preference. Nothing in a skill may require it —
that is the mistake #13 made the first time. Cross-ref #119, which should stop
treating `TaskCreate` in `ALLOWED_TOOLS` as a permissions fix.

## Re-inject the progress file per turn, and gate Stop on it

**Added:** 2026-09-12
**Problem:** A long `dx-agent-all` run loses the plan to context rot and
compaction. The progress file survives, but nothing re-reads it mid-run, and
nothing stops a session ending with phases still `in_progress`. The
[planning-with-files](https://github.com/othmanadi/planning-with-files) pattern
closes both gaps with hooks and measures the difference: resuming after a
context wipe took 5.0 turns with the pattern versus 13.3 without.
**Scope:** `plugins/dx-core/hooks/hooks.json`,
`plugins/dx-core/hooks/scripts/next-step.sh` (already greps `implement.md`
checkboxes on `SessionStart` — extend it to the active progress file), a new
`UserPromptSubmit` / `PreCompact` handler, and the `stop-guard.sh` slot the
`Stop` hook already calls.
**Done-when:** a session resumed after `/clear` mid-run reports the correct
current phase without being told the ticket id, AND `stop-guard.sh` exits 2 with
a message naming the phase when a progress file still has an `in_progress` row.
**Approach:** Reuse what exists rather than adopting the upstream skill —
`.ai/specs/<id>-<slug>/` is a better anchor than `.planning/<date>-<slug>/`, and
`resume-state.json` + `save-state.sh` (dx-simple, TODO #141) already do durable
checkpointing better than anything upstream. Only the re-injection and the Stop
gate are missing. Respect `DX_HOOK_PROFILE` — the gate is `strict`, the
re-injection is `standard`.
