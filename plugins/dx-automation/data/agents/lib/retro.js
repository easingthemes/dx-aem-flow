/**
 * Retrospective analysis — aggregates bundle data and eval results into weekly insights.
 * Reads local bundle directories (runs/) and eval results (eval/results/).
 * Outputs markdown summary to retro/ directory.
 *
 * Data sources:
 *   - runs/{runId}/run.json — pipeline metadata (status, tokens, timing)
 *   - runs/{runId}/actions/decision-journal.json — decisions per run
 *   - eval/results/latest.json — fixture pass/fail data
 *
 * Fails gracefully: if no data found, outputs empty summary noting the gap.
 */

import { readFileSync, readdirSync, existsSync, statSync, writeFileSync, mkdirSync } from "fs";
import path from "path";

const PIPELINES = ["dor", "pr-review", "pr-answer"];

/**
 * Get ISO week number and year for a date.
 * @returns {{ year: number, week: number, label: string }}
 */
export function getWeekLabel(date = new Date()) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
  return {
    year: d.getUTCFullYear(),
    week,
    label: `${d.getUTCFullYear()}-W${String(week).padStart(2, "0")}`,
  };
}

/**
 * Scan local runs/ directory and load run.json from each bundle.
 * @param {string} runsDir - Path to runs/ directory
 * @param {{ start: Date, end: Date }} window - Time window to filter
 * @returns {Array<object>} Run metadata objects
 */
export function loadRuns(runsDir, window) {
  if (!existsSync(runsDir)) return [];

  const runs = [];
  let entries;
  try {
    entries = readdirSync(runsDir, { withFileTypes: true });
  } catch {
    return [];
  }

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const runJson = path.join(runsDir, entry.name, "run.json");
    if (!existsSync(runJson)) continue;

    try {
      const meta = JSON.parse(readFileSync(runJson, "utf8"));
      const startTime = new Date(meta.startTime);
      if (startTime >= window.start && startTime < window.end) {
        runs.push({ ...meta, _dir: entry.name });
      }
    } catch {
      // skip malformed bundles
    }
  }

  return runs;
}

/**
 * Load decision journals for a set of runs.
 * @param {string} runsDir
 * @param {Array<object>} runs
 * @returns {Array<object>} All decisions with runId attached
 */
export function loadDecisions(runsDir, runs) {
  const decisions = [];
  for (const run of runs) {
    const journalPath = path.join(runsDir, run._dir, "actions", "decision-journal.json");
    if (!existsSync(journalPath)) continue;
    try {
      const entries = JSON.parse(readFileSync(journalPath, "utf8"));
      for (const d of entries) {
        decisions.push({ ...d, runId: run.runId, pipeline: run.pipeline });
      }
    } catch {
      // skip
    }
  }
  return decisions;
}

/**
 * Load latest eval results.
 * @param {string} evalResultsPath - Path to eval/results/latest.json
 * @returns {object|null}
 */
export function loadEvalResults(evalResultsPath) {
  if (!existsSync(evalResultsPath)) return null;
  try {
    return JSON.parse(readFileSync(evalResultsPath, "utf8"));
  } catch {
    return null;
  }
}

/**
 * Aggregate run data into per-pipeline statistics.
 * @param {Array<object>} runs
 * @returns {object} Stats keyed by pipeline name
 */
export function aggregateRunStats(runs) {
  const stats = {};

  for (const pipeline of PIPELINES) {
    const pipelineRuns = runs.filter((r) => r.pipeline === pipeline);
    const succeeded = pipelineRuns.filter((r) => r.status === "success" || r.status === "completed");
    const failed = pipelineRuns.filter((r) => r.status === "error" || r.status === "failed");

    // Calculate durations
    const durations = pipelineRuns
      .filter((r) => r.startTime && r.endTime)
      .map((r) => new Date(r.endTime) - new Date(r.startTime));

    const avgDuration = durations.length
      ? Math.round(durations.reduce((a, b) => a + b, 0) / durations.length / 1000)
      : null;

    stats[pipeline] = {
      total: pipelineRuns.length,
      succeeded: succeeded.length,
      failed: failed.length,
      successRate: pipelineRuns.length
        ? Math.round((succeeded.length / pipelineRuns.length) * 100)
        : null,
      avgDurationSec: avgDuration,
    };
  }

  stats._total = {
    total: runs.length,
    succeeded: runs.filter((r) => r.status === "success" || r.status === "completed").length,
    failed: runs.filter((r) => r.status === "error" || r.status === "failed").length,
  };

  return stats;
}

/**
 * Aggregate decision patterns.
 * @param {Array<object>} decisions
 * @returns {{ refused: Array, patterns: object }}
 */
export function aggregateDecisions(decisions) {
  const refused = decisions.filter((d) => d.refused);
  const planned = {};
  for (const d of decisions) {
    if (d.planned) {
      planned[d.planned] = (planned[d.planned] || 0) + 1;
    }
  }
  return { refused, plannedActions: planned };
}

/**
 * Analyze eval fixture results for regressions.
 * @param {object} evalResults - From eval/results/latest.json
 * @returns {{ total: number, passed: number, failed: number, failedFixtures: Array }}
 */
export function analyzeEvalResults(evalResults) {
  if (!evalResults || !evalResults.summary) {
    return { total: 0, passed: 0, failed: 0, failedFixtures: [] };
  }

  const failedFixtures = (evalResults.fixtures || [])
    .filter((f) => f.overall === "fail")
    .map((f) => ({
      name: f.name,
      failedGates: f.failed.map((g) => `${g.gate}: ${g.detail}`),
    }));

  return {
    total: evalResults.summary.total,
    passed: evalResults.summary.passed,
    failed: evalResults.summary.failed,
    failedFixtures,
  };
}

/**
 * Calculate time window for a given week.
 * @param {string} weekLabel - "YYYY-WNN" format, or "latest" for current week
 * @returns {{ start: Date, end: Date, label: string }}
 */
export function getWeekWindow(weekLabel) {
  if (weekLabel === "latest") {
    const now = getWeekLabel();
    return getWeekWindow(now.label);
  }

  const match = weekLabel.match(/^(\d{4})-W(\d{2})$/);
  if (!match) throw new Error(`Invalid week format: ${weekLabel}. Use YYYY-WNN.`);

  const year = parseInt(match[1]);
  const week = parseInt(match[2]);

  // ISO week date to calendar date
  const jan4 = new Date(Date.UTC(year, 0, 4));
  const dayOfWeek = jan4.getUTCDay() || 7;
  const start = new Date(jan4);
  start.setUTCDate(jan4.getUTCDate() - dayOfWeek + 1 + (week - 1) * 7);

  const end = new Date(start);
  end.setUTCDate(start.getUTCDate() + 7);

  return { start, end, label: weekLabel };
}

/**
 * Generate the full retro analysis and return markdown + data.
 * @param {object} options
 * @param {string} options.runsDir - Path to runs/ directory
 * @param {string} options.evalResultsPath - Path to eval/results/latest.json
 * @param {string} options.weekLabel - "YYYY-WNN" or "latest"
 * @returns {{ markdown: string, data: object }}
 */
export function generateRetro({ runsDir, evalResultsPath, weekLabel = "latest" }) {
  const window = getWeekWindow(weekLabel);
  const runs = loadRuns(runsDir, window);
  const decisions = loadDecisions(runsDir, runs);
  const evalResults = loadEvalResults(evalResultsPath);

  const runStats = aggregateRunStats(runs);
  const decisionStats = aggregateDecisions(decisions);
  const evalAnalysis = analyzeEvalResults(evalResults);

  const data = {
    week: window.label,
    generated: new Date().toISOString(),
    window: { start: window.start.toISOString(), end: window.end.toISOString() },
    runs: runStats,
    decisions: decisionStats,
    eval: evalAnalysis,
  };

  const markdown = renderMarkdown(data);
  return { markdown, data };
}

/**
 * Render retro data as markdown summary.
 */
function renderMarkdown(data) {
  const lines = [];

  lines.push(`# AI Automation Weekly Retro — ${data.week}`);
  lines.push("");
  lines.push(`Generated: ${data.generated}`);
  lines.push(`Window: ${data.window.start.slice(0, 10)} to ${data.window.end.slice(0, 10)}`);
  lines.push("");

  // --- Run summary ---
  lines.push("## Pipeline Runs");
  lines.push("");

  if (data.runs._total.total === 0) {
    lines.push("No pipeline runs found for this week.");
    lines.push("");
    lines.push("> **Note:** If S3 is unreachable, bundles are stored locally in `runs/`.");
    lines.push("> Check that the `runs/` directory contains bundle directories with `run.json` files.");
  } else {
    lines.push("| Pipeline | Runs | Succeeded | Failed | Success Rate | Avg Duration |");
    lines.push("|----------|------|-----------|--------|-------------|-------------|");

    for (const pipeline of ["dor", "pr-review", "pr-answer"]) {
      const s = data.runs[pipeline];
      const rate = s.successRate !== null ? `${s.successRate}%` : "—";
      const duration = s.avgDurationSec !== null ? `${s.avgDurationSec}s` : "—";
      lines.push(`| ${pipeline} | ${s.total} | ${s.succeeded} | ${s.failed} | ${rate} | ${duration} |`);
    }

    const t = data.runs._total;
    lines.push(`| **Total** | **${t.total}** | **${t.succeeded}** | **${t.failed}** | | |`);
  }
  lines.push("");

  // --- Decision patterns ---
  lines.push("## Decision Patterns");
  lines.push("");

  const { plannedActions, refused } = data.decisions;
  const actionEntries = Object.entries(plannedActions).sort((a, b) => b[1] - a[1]);

  if (actionEntries.length === 0) {
    lines.push("No decision journal entries found for this week.");
  } else {
    lines.push("### Actions Taken");
    lines.push("");
    lines.push("| Action | Count |");
    lines.push("|--------|-------|");
    for (const [action, count] of actionEntries) {
      lines.push(`| ${action} | ${count} |`);
    }
  }
  lines.push("");

  if (refused.length > 0) {
    lines.push("### Refused Actions");
    lines.push("");
    for (const r of refused) {
      lines.push(`- **${r.pipeline}** (run ${r.runId?.slice(0, 8)}): refused "${r.refused}"`);
    }
    lines.push("");
  }

  // --- Eval results ---
  lines.push("## Eval Gate Status");
  lines.push("");

  if (data.eval.total === 0) {
    lines.push("No eval results found. Run `node eval/run.js --all` to generate.");
  } else {
    lines.push(`**${data.eval.passed}/${data.eval.total}** fixtures passing`);
    lines.push("");

    if (data.eval.failedFixtures.length > 0) {
      lines.push("### Failing Fixtures");
      lines.push("");
      for (const f of data.eval.failedFixtures) {
        lines.push(`- **${f.name}**`);
        for (const gate of f.failedGates) {
          lines.push(`  - ${gate}`);
        }
      }
    } else {
      lines.push("All fixtures passing. No regressions detected.");
    }
  }
  lines.push("");

  // --- Insights ---
  lines.push("## Insights");
  lines.push("");

  const insights = [];

  // High failure rate
  for (const pipeline of ["dor", "pr-review", "pr-answer"]) {
    const s = data.runs[pipeline];
    if (s.total > 0 && s.successRate !== null && s.successRate < 80) {
      insights.push(`- **${pipeline}** has ${s.successRate}% success rate (${s.failed} failures). Investigate error patterns in bundle logs.`);
    }
  }

  // Eval regressions
  if (data.eval.failed > 0) {
    insights.push(`- **${data.eval.failed} eval fixture(s) failing.** Review failing gates and update prompts or expected outputs.`);
  }

  // Refused actions
  if (refused.length > 0) {
    insights.push(`- **${refused.length} action(s) refused** by decision journal. Review if policy gates are too strict or if agents are attempting forbidden operations.`);
  }

  // No data
  if (data.runs._total.total === 0) {
    insights.push("- **No run data for this week.** Ensure pipelines are writing bundles to `runs/` and S3 archiving is configured (the configured S3 bundle bucket).");
  }

  if (insights.length === 0) {
    lines.push("No issues detected. System operating normally.");
  } else {
    for (const insight of insights) {
      lines.push(insight);
    }
  }

  lines.push("");
  lines.push("---");
  lines.push(`*Generated by retro.js — ${data.generated}*`);
  lines.push("");

  return lines.join("\n");
}

/**
 * Write retro output to disk.
 * @param {string} retroDir - Output directory (e.g., retro/)
 * @param {string} markdown
 * @param {object} data
 * @param {string} weekLabel
 */
export function writeRetro(retroDir, markdown, data, weekLabel) {
  mkdirSync(retroDir, { recursive: true });

  const mdPath = path.join(retroDir, `${weekLabel}-summary.md`);
  const jsonPath = path.join(retroDir, `${weekLabel}-data.json`);

  writeFileSync(mdPath, markdown);
  writeFileSync(jsonPath, JSON.stringify(data, null, 2));

  return { mdPath, jsonPath };
}
