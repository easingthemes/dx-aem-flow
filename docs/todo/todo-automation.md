# TODO: Clean Up Old Automation

## Clean Up Old Automation in Plugin — DONE

**Added:** 2026-03-22
**Completed:** 2026-03-22 — commit `1800b25`
**Problem:** `plugins/dx-automation/data/` contained ~40 files of obsolete custom JS agents, old pipelines, old eval framework, old runner scripts. Only CLI approach (`pipelines/cli/` + `pipeline-agent.js`) was current. Dead code caused confusion.
**Scope:** `plugins/dx-automation/data/agents/` (22 files), `data/eval/` (9 files), `data/docs/` (5 files), `data/pipelines/eval/` (1 file), `data/run.sh`, `data/setup-cli.sh`, `data/repos.template.json`.
**Done-when:** `ls plugins/dx-automation/data/agents/ 2>&1` returns "No such file or directory" AND `grep -r "agents/lib" plugins/dx-automation/skills/auto-init/SKILL.md` returns no matches.
**Resolution:** Deleted 40 files (-6,370 lines). Updated `auto-init` to stop scaffolding deleted files. Updated `auto-test` to use `pipeline-agent.js`.

**Note:** Existing consumer repos may still have old files in `.ai/automation/agents/`, `.ai/automation/eval/`, etc. That's a per-repo cleanup task, not a plugin issue.
