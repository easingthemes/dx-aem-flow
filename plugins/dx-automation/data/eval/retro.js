#!/usr/bin/env node

/**
 * Retro CLI — generates weekly retrospective from bundle data and eval results.
 *
 * Usage:
 *   node eval/retro.js --week latest         Current week (default)
 *   node eval/retro.js --week 2026-W09       Specific ISO week
 *   node eval/retro.js --all                 All weeks with data
 */

import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import { readFileSync, readdirSync, existsSync } from "fs";
import {
  generateRetro,
  writeRetro,
  getWeekLabel,
} from "../agents/lib/retro.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const BASE_DIR = resolve(__dirname, "..");
const RUNS_DIR = resolve(BASE_DIR, "runs");
const EVAL_RESULTS = resolve(__dirname, "results", "latest.json");
const RETRO_DIR = resolve(BASE_DIR, "retro");

// --- Parse CLI args ---
const args = process.argv.slice(2);
const flags = {};
for (let i = 0; i < args.length; i++) {
  if (args[i].startsWith("--")) {
    const key = args[i].slice(2);
    if (args[i].includes("=")) {
      const [k, ...rest] = key.split("=");
      flags[k] = rest.join("=");
    } else {
      flags[key] = args[i + 1] && !args[i + 1].startsWith("--") ? args[i + 1] : "true";
    }
  }
}

// --- Main ---
async function main() {
  if ("help" in flags || args.length === 0) {
    if (args.length === 0) {
      // Default to --week latest
      flags.week = "latest";
    } else {
      console.log("AI Automation Retro — Weekly Retrospective Generator");
      console.log("");
      console.log("Usage:");
      console.log("  node eval/retro.js --week latest         Current week");
      console.log("  node eval/retro.js --week 2026-W09       Specific ISO week");
      console.log("  node eval/retro.js --all                 All weeks with data");
      console.log("");
      console.log("Output: retro/{week}-summary.md + retro/{week}-data.json");
      process.exit(0);
    }
  }

  const weekLabel = flags.week || "latest";

  if ("all" in flags) {
    // Scan all runs and generate retro for each week
    console.log("Scanning runs/ for all weeks with data...");

    if (!existsSync(RUNS_DIR)) {
      console.log("No runs/ directory found. No data to analyze.");
      console.log("");
      console.log("Generating empty retro for current week...");
      const current = getWeekLabel();
      generateAndWrite(current.label);
      return;
    }

    // Collect all week labels from run data
    const weekSet = new Set();
    const entries = readdirSync(RUNS_DIR, { withFileTypes: true });

    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      const runJson = resolve(RUNS_DIR, entry.name, "run.json");
      if (!existsSync(runJson)) continue;
      try {
        const meta = JSON.parse(readFileSync(runJson, "utf8"));
        if (meta.startTime) {
          weekSet.add(getWeekLabel(new Date(meta.startTime)).label);
        }
      } catch {
        // skip
      }
    }

    const weeks = [...weekSet].sort();
    if (weeks.length === 0) {
      console.log("No run data found. Generating empty retro for current week.");
      const current = getWeekLabel();
      generateAndWrite(current.label);
      return;
    }

    console.log(`Found data for ${weeks.length} week(s): ${weeks.join(", ")}`);
    for (const w of weeks) {
      generateAndWrite(w);
    }
  } else {
    generateAndWrite(weekLabel);
  }
}

function generateAndWrite(week) {
  console.log(`\nGenerating retro for ${week}...`);

  const { markdown, data } = generateRetro({
    runsDir: RUNS_DIR,
    evalResultsPath: EVAL_RESULTS,
    weekLabel: week,
  });

  // Use resolved week label (handles "latest" → "2026-W09")
  const resolvedWeek = data.week;
  const { mdPath, jsonPath } = writeRetro(RETRO_DIR, markdown, data, resolvedWeek);

  console.log(`  Markdown: ${mdPath}`);
  console.log(`  Data:     ${jsonPath}`);

  // Print summary
  const t = data.runs._total;
  const evalStatus = data.eval.total > 0
    ? `${data.eval.passed}/${data.eval.total} fixtures passing`
    : "no eval data";
  console.log(`  Runs: ${t.total} (${t.succeeded} ok, ${t.failed} failed) | Eval: ${evalStatus}`);
}

main().catch((err) => {
  console.error("Retro failed:", err.message);
  process.exit(1);
});
