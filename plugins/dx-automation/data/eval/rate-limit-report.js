#!/usr/bin/env node
/**
 * Rate Limit Report — per-pipeline and per-identity daily usage.
 *
 * Usage:
 *   node eval/rate-limit-report.js            # Last 7 days
 *   node eval/rate-limit-report.js --days 14  # Last 14 days
 *   node eval/rate-limit-report.js --json     # Output JSON to eval/metrics/
 *
 * Requires: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
 */

import { writeFileSync, mkdirSync } from "fs";
import { fileURLToPath } from "url";
import path from "path";
import {
  getAwsCredentials,
  getAwsRegion,
  dynamoScan,
} from "../agents/lib/aws-sig.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TABLE_NAME = process.env.DYNAMODB_RATE_LIMIT_TABLE;

const LIMITS = {
  dor: 20,
  "pr-review": 50,
  "pr-answer": 30,
};
const PER_IDENTITY_LIMIT = 10;

function parseArgs() {
  const args = process.argv.slice(2);
  return {
    days: (() => {
      const idx = args.indexOf("--days");
      return idx >= 0 && args[idx + 1] ? parseInt(args[idx + 1], 10) : 7;
    })(),
    json: args.includes("--json"),
  };
}

function pad(str, len) {
  return String(str).padEnd(len);
}

function dateRange(days) {
  const dates = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    dates.push(d.toISOString().slice(0, 10));
  }
  return dates;
}

async function main() {
  const opts = parseArgs();
  const credentials = getAwsCredentials();
  if (!credentials) {
    console.error("No AWS credentials found. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.");
    process.exit(1);
  }

  const region = getAwsRegion();
  const dates = dateRange(opts.days);

  console.log(`Rate Limit Report — last ${opts.days} days`);
  console.log("=".repeat(60));

  // Scan all items from the table
  const items = await dynamoScan(TABLE_NAME, {}, region, credentials);

  // Parse items into structured data
  const pipelineUsage = {}; // { pipeline: { date: count } }
  const identityUsage = {}; // { identity: { date: count } }

  for (const item of items) {
    const pk = item.pk?.S || "";
    const count = parseInt(item.count?.N || "0", 10);

    if (pk.startsWith("identity:")) {
      // identity:user@email.com#2026-03-01
      const rest = pk.slice("identity:".length);
      const hashIdx = rest.lastIndexOf("#");
      if (hashIdx < 0) continue;
      const identity = rest.slice(0, hashIdx);
      const date = rest.slice(hashIdx + 1);
      if (!dates.includes(date)) continue;
      if (!identityUsage[identity]) identityUsage[identity] = {};
      identityUsage[identity][date] = count;
    } else {
      // dor#2026-03-01
      const hashIdx = pk.lastIndexOf("#");
      if (hashIdx < 0) continue;
      const pipeline = pk.slice(0, hashIdx);
      const date = pk.slice(hashIdx + 1);
      if (!dates.includes(date)) continue;
      if (!pipelineUsage[pipeline]) pipelineUsage[pipeline] = {};
      pipelineUsage[pipeline][date] = count;
    }
  }

  // Pipeline usage table
  console.log("\nPer-Pipeline Daily Usage:");
  console.log("-".repeat(60));

  const header = pad("Date", 14) + Object.keys(LIMITS).map((p) => pad(p, 14)).join("");
  console.log(header);

  for (const date of dates) {
    const cols = Object.keys(LIMITS).map((p) => {
      const count = pipelineUsage[p]?.[date] || 0;
      const limit = LIMITS[p];
      const pct = count > 0 ? ` (${Math.round((count / limit) * 100)}%)` : "";
      return pad(`${count}/${limit}${pct}`, 14);
    }).join("");
    console.log(pad(date, 14) + cols);
  }

  // Totals
  console.log("-".repeat(60));
  const totalRow = Object.keys(LIMITS).map((p) => {
    const total = dates.reduce((sum, d) => sum + (pipelineUsage[p]?.[d] || 0), 0);
    return pad(String(total), 14);
  }).join("");
  console.log(pad("Total", 14) + totalRow);

  // Identity usage
  const identities = Object.keys(identityUsage);
  if (identities.length > 0) {
    console.log("\nPer-Identity Usage (limit: " + PER_IDENTITY_LIMIT + "/day):");
    console.log("-".repeat(60));

    // Sort by total usage descending
    const sorted = identities.map((id) => {
      const total = Object.values(identityUsage[id]).reduce((s, c) => s + c, 0);
      const maxDay = Math.max(...Object.values(identityUsage[id]));
      return { id, total, maxDay, days: Object.keys(identityUsage[id]).length };
    }).sort((a, b) => b.total - a.total);

    console.log(pad("Identity", 30) + pad("Total", 10) + pad("Max/Day", 10) + pad("Days", 8) + "Status");
    for (const entry of sorted) {
      const status = entry.maxDay >= PER_IDENTITY_LIMIT ? "AT LIMIT"
        : entry.maxDay >= PER_IDENTITY_LIMIT * 0.8 ? "NEAR LIMIT"
        : "ok";
      console.log(
        pad(entry.id.slice(0, 28), 30)
        + pad(String(entry.total), 10)
        + pad(String(entry.maxDay), 10)
        + pad(String(entry.days), 8)
        + status,
      );
    }
  } else {
    console.log("\nNo per-identity usage data found.");
  }

  // Write JSON output
  if (opts.json) {
    const metricsDir = path.join(__dirname, "metrics");
    mkdirSync(metricsDir, { recursive: true });
    const report = {
      period: { from: dates[0], to: dates[dates.length - 1], days: opts.days },
      generatedAt: new Date().toISOString(),
      limits: LIMITS,
      perIdentityLimit: PER_IDENTITY_LIMIT,
      pipelineUsage,
      identityUsage,
    };
    const outPath = path.join(metricsDir, "rate-limit-report.json");
    writeFileSync(outPath, JSON.stringify(report, null, 2));
    console.log(`\nJSON report written to: ${outPath}`);
  }
}

main().catch((err) => {
  console.error(`Fatal: ${err.message}`);
  process.exit(1);
});
