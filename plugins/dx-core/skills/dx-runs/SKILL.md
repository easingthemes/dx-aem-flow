---
name: dx-runs
description: "Summarize past dx runs: success rate, failures, run time, interrupted runs."
argument-hint: "[--days N] [--skill <name>] [--json]"
model: haiku
effort: low
allowed-tools: ["read", "search"]
---

Summarize the dx runs recorded in `.ai/run-results/` (written by `run-result.sh`; schema `docs/reference/run-result.md` in the plugin repo). Read-only.

1. Run the summary, passing the user's arguments through (`--days N`, `--skill <name>`, `--json`, `--stale-hours H`):

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/data/lib/run-history.sh" <arguments>
   ```

   On a host that does not substitute `${CLAUDE_PLUGIN_ROOT}`, run `data/lib/run-history.sh` from the dx-core plugin folder.

2. With `--json`: print the script's output as-is and stop — it is for tools.

3. Otherwise print the table, then at most three short observations from it, each tied to a number in the table: a skill with a low success rate and its most common stop, a skill whose median time stands out, and stale markers (a run that started and never wrote a result — interrupted; re-run it or delete the marker). No observations when there are fewer than 3 runs.

If the script reports no history: say that runs are recorded from dx-core 6.4 on, by the skills that write run results.
