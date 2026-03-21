#!/usr/bin/env node

/**
 * Eval runner — runs fixtures through Tier 1 gates and optionally Tier 2 judge.
 *
 * Usage:
 *   node eval/run.js --all                    Run all fixtures (Tier 1 only)
 *   node eval/run.js --all --tier2            Run all fixtures + Tier 2 LLM judge
 *   node eval/run.js --agent dor              Run all fixtures for one agent
 *   node eval/run.js --fixture dor/story-001  Run a single fixture
 */

import { readFileSync, readdirSync, mkdirSync, writeFileSync, existsSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import { runAllGates } from "./gates.js";
import { runJudge } from "./judge.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const FIXTURES_DIR = resolve(__dirname, "fixtures");
const RESULTS_DIR = resolve(__dirname, "results");

// --- Parse CLI args ---
const args = process.argv.slice(2);
const flags = {};
for (const a of args) {
  if (a.startsWith("--")) {
    const [key, ...rest] = a.slice(2).split("=");
    flags[key] = rest.length ? rest.join("=") : args[args.indexOf(a) + 1] || "true";
  }
}

// Support both --flag value and --flag=value
for (let i = 0; i < args.length; i++) {
  if (args[i].startsWith("--") && !args[i].includes("=")) {
    const key = args[i].slice(2);
    const val = args[i + 1] && !args[i + 1].startsWith("--") ? args[i + 1] : "true";
    flags[key] = val;
  }
}

const AGENTS = ["dor", "pr-review", "pr-answer"];
const tier2Enabled = "tier2" in flags;

// --- Core ---

function loadJSON(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8"));
}

function runFixture(agent, fixtureName) {
  const fixtureDir = resolve(FIXTURES_DIR, agent, fixtureName);
  const expectedPath = resolve(fixtureDir, "expected-output.json");
  const baselinePath = resolve(fixtureDir, "baseline-output.json");

  if (!existsSync(expectedPath)) {
    return { agent, fixture: fixtureName, overall: "skip", results: [], failed: [{ gate: "setup", detail: "Missing expected-output.json" }] };
  }
  if (!existsSync(baselinePath)) {
    return { agent, fixture: fixtureName, overall: "skip", results: [], failed: [{ gate: "setup", detail: "Missing baseline-output.json" }] };
  }

  const expected = loadJSON(expectedPath);
  const baseline = loadJSON(baselinePath);

  // Load actions from baseline if present (for no-forbidden-actions gate)
  const actions = baseline._actions || [];

  const gateResults = runAllGates(baseline, expected, actions);

  return {
    agent,
    fixture: fixtureName,
    baseline,
    ...gateResults,
  };
}

function discoverFixtures(agent) {
  const agentDir = resolve(FIXTURES_DIR, agent);
  if (!existsSync(agentDir)) return [];
  return readdirSync(agentDir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort();
}

function runAgent(agent) {
  const fixtures = discoverFixtures(agent);
  return fixtures.map((f) => runFixture(agent, f));
}

function runAll() {
  const results = [];
  for (const agent of AGENTS) {
    results.push(...runAgent(agent));
  }
  return results;
}

// --- Tier 2 Judge ---

async function runTier2(results) {
  console.log("\n--- Tier 2: LLM-as-Judge ---\n");
  for (const r of results) {
    if (r.overall === "skip") {
      r.judge = { verdict: "skip", reason: "fixture skipped" };
      continue;
    }
    // Compare baseline against itself (since we don't have a separate "current" output yet).
    // When live LLM baselines are generated, this will compare current vs baseline.
    const verdict = await runJudge(`${r.agent}/${r.fixture}`, r.baseline, r.baseline);
    r.judge = verdict;
    console.log(`  ${r.agent}/${r.fixture}: ${verdict.verdict} — ${verdict.reason}`);
  }
}

// --- Output formatting ---

function padRight(str, len) {
  return str.length >= len ? str.slice(0, len) : str + " ".repeat(len - str.length);
}

function printTable(results) {
  const COL1 = 28;
  const COL2 = 32;
  const COL3 = 8;
  const COL4 = tier2Enabled ? 10 : 0;

  const sep = tier2Enabled
    ? `+${"-".repeat(COL1 + 2)}+${"-".repeat(COL2 + 2)}+${"-".repeat(COL3 + 2)}+${"-".repeat(COL4 + 2)}+`
    : `+${"-".repeat(COL1 + 2)}+${"-".repeat(COL2 + 2)}+${"-".repeat(COL3 + 2)}+`;

  const header = tier2Enabled
    ? `| ${padRight("Fixture", COL1)} | ${padRight("Failed Gates", COL2)} | ${padRight("Result", COL3)} | ${padRight("Judge", COL4)} |`
    : `| ${padRight("Fixture", COL1)} | ${padRight("Failed Gates", COL2)} | ${padRight("Result", COL3)} |`;

  console.log("");
  console.log(sep);
  console.log(header);
  console.log(sep);

  for (const r of results) {
    const name = `${r.agent}/${r.fixture}`;
    const failedNames = r.failed.length ? r.failed.map((f) => f.gate).join(", ") : "—";
    const status = r.overall === "pass" ? "PASS" : r.overall === "skip" ? "SKIP" : "FAIL";

    if (tier2Enabled) {
      const judgeVerdict = r.judge?.verdict || "—";
      console.log(`| ${padRight(name, COL1)} | ${padRight(failedNames, COL2)} | ${padRight(status, COL3)} | ${padRight(judgeVerdict, COL4)} |`);
    } else {
      console.log(`| ${padRight(name, COL1)} | ${padRight(failedNames, COL2)} | ${padRight(status, COL3)} |`);
    }
  }

  console.log(sep);

  const passed = results.filter((r) => r.overall === "pass").length;
  const skipped = results.filter((r) => r.overall === "skip").length;
  const total = results.length;
  const skipNote = skipped > 0 ? ` (${skipped} skipped)` : "";
  console.log(`${passed}/${total} passed${skipNote}`);

  if (tier2Enabled) {
    const judged = results.filter((r) => r.judge && r.judge.verdict !== "skip" && r.judge.verdict !== "error");
    const worse = judged.filter((r) => r.judge.verdict === "worse").length;
    const better = judged.filter((r) => r.judge.verdict === "better").length;
    const same = judged.filter((r) => r.judge.verdict === "same").length;
    const errors = results.filter((r) => r.judge?.verdict === "error").length;
    console.log(`Judge: ${better} better, ${same} same, ${worse} worse${errors ? `, ${errors} errors` : ""}`);
  }

  console.log("");
}

function writeResults(results) {
  mkdirSync(RESULTS_DIR, { recursive: true });
  const output = {
    timestamp: new Date().toISOString(),
    summary: {
      total: results.length,
      passed: results.filter((r) => r.overall === "pass").length,
      failed: results.filter((r) => r.overall === "fail").length,
      skipped: results.filter((r) => r.overall === "skip").length,
    },
    fixtures: results.map((r) => ({
      name: `${r.agent}/${r.fixture}`,
      overall: r.overall,
      gates: r.results.map((g) => ({ gate: g.gate, pass: g.pass, detail: g.detail })),
      failed: r.failed.map((f) => ({ gate: f.gate, detail: f.detail })),
      ...(r.judge ? { judge: r.judge } : {}),
    })),
  };
  writeFileSync(resolve(RESULTS_DIR, "latest.json"), JSON.stringify(output, null, 2));
}

// --- Main ---

let results;

if (flags.fixture) {
  const [agent, fixtureName] = flags.fixture.split("/");
  if (!agent || !fixtureName) {
    console.error("ERROR: --fixture must be in format agent/name (e.g., dor/story-001)");
    process.exit(2);
  }
  results = [runFixture(agent, fixtureName)];
} else if (flags.agent) {
  if (!AGENTS.includes(flags.agent)) {
    console.error(`ERROR: Unknown agent "${flags.agent}". Valid: ${AGENTS.join(", ")}`);
    process.exit(2);
  }
  results = runAgent(flags.agent);
} else if ("all" in flags) {
  results = runAll();
} else {
  console.error("Usage:");
  console.error("  node eval/run.js --all                    Run all fixtures");
  console.error("  node eval/run.js --all --tier2            Run all + Tier 2 LLM judge");
  console.error("  node eval/run.js --agent dor              Run all fixtures for one agent");
  console.error("  node eval/run.js --fixture dor/story-001  Run a single fixture");
  process.exit(2);
}

// Run Tier 2 if requested
if (tier2Enabled) {
  await runTier2(results);
}

printTable(results);
writeResults(results);

// Tier 1 failures affect exit code; Tier 2 does not (trend-tracking only)
const anyFailed = results.some((r) => r.overall === "fail");
process.exit(anyFailed ? 1 : 0);
