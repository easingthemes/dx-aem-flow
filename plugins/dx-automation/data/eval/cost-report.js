#!/usr/bin/env node
/**
 * Cost Report — token budget dashboard.
 *
 * Usage:
 *   node eval/cost-report.js                  # Current month
 *   node eval/cost-report.js --month 2026-02  # Specific month
 *   node eval/cost-report.js --json           # Output JSON to eval/metrics/
 *
 * Requires: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
 */

import { writeFileSync, mkdirSync } from "fs";
import { fileURLToPath } from "url";
import path from "path";
import {
  getAwsCredentials,
  getAwsRegion,
  dynamoGet,
  dynamoScan,
} from "../agents/lib/aws-sig.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TABLE_NAME = process.env.DYNAMODB_TOKEN_BUDGET_TABLE;
const MONTHLY_CAP = parseInt(process.env.MONTHLY_TOKEN_CAP || "5000000", 10);

// Azure OpenAI pricing (GPT-4o) — $/1K tokens
const PRICING = {
  prompt: 0.005,
  completion: 0.015,
};

function parseArgs() {
  const args = process.argv.slice(2);
  return {
    month: (() => {
      const idx = args.indexOf("--month");
      return idx >= 0 && args[idx + 1] ? args[idx + 1] : new Date().toISOString().slice(0, 7);
    })(),
    json: args.includes("--json"),
  };
}

function fmtNum(n) {
  return n.toLocaleString("en-US");
}

function fmtCost(n) {
  return `$${n.toFixed(4)}`;
}

function progressBar(pct, width = 30) {
  const filled = Math.min(Math.round(pct * width), width);
  return "[" + "=".repeat(filled) + " ".repeat(width - filled) + "]";
}

async function main() {
  const opts = parseArgs();
  const credentials = getAwsCredentials();
  if (!credentials) {
    console.error("No AWS credentials found. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.");
    process.exit(1);
  }

  const region = getAwsRegion();
  const month = opts.month;

  console.log(`Token Budget Report — ${month}`);
  console.log("=".repeat(50));

  // Get monthly total
  const monthItem = await dynamoGet(TABLE_NAME, { pk: { S: month } }, region, credentials);
  const total = {
    totalTokens: parseInt(monthItem?.totalTokens?.N || "0", 10),
    promptTokens: parseInt(monthItem?.promptTokens?.N || "0", 10),
    completionTokens: parseInt(monthItem?.completionTokens?.N || "0", 10),
  };

  const utilization = total.totalTokens / MONTHLY_CAP;
  const promptCost = (total.promptTokens / 1000) * PRICING.prompt;
  const completionCost = (total.completionTokens / 1000) * PRICING.completion;
  const totalCost = promptCost + completionCost;

  console.log(`\nMonthly Cap:    ${fmtNum(MONTHLY_CAP)} tokens`);
  console.log(`Total Used:     ${fmtNum(total.totalTokens)} tokens`);
  console.log(`Utilization:    ${(utilization * 100).toFixed(1)}% ${progressBar(utilization)}`);
  console.log(`  Prompt:       ${fmtNum(total.promptTokens)} tokens (${fmtCost(promptCost)})`);
  console.log(`  Completion:   ${fmtNum(total.completionTokens)} tokens (${fmtCost(completionCost)})`);
  console.log(`  Est. Cost:    ${fmtCost(totalCost)}`);

  // Budget mode
  const mode = utilization >= 1.0 ? "HALTED"
    : utilization >= 0.9 ? "SUGGEST-ONLY"
    : utilization >= 0.8 ? "WARNING"
    : "NORMAL";
  console.log(`  Budget Mode:  ${mode}`);

  // Projection
  const now = new Date();
  const dayOfMonth = now.getDate();
  const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  if (dayOfMonth > 1 && total.totalTokens > 0) {
    const dailyRate = total.totalTokens / dayOfMonth;
    const projected = Math.round(dailyRate * daysInMonth);
    const projectedUtil = projected / MONTHLY_CAP;
    console.log(`\nProjected month-end: ${fmtNum(projected)} tokens (${(projectedUtil * 100).toFixed(1)}%)`);
    if (projectedUtil >= 1.0) {
      const daysUntilHalt = Math.ceil((MONTHLY_CAP - total.totalTokens) / dailyRate);
      console.log(`  WARNING: Budget exhaustion projected in ~${daysUntilHalt} days`);
    }
  }

  // Per-pipeline breakdown
  const pipelines = ["dor", "pr-review", "pr-answer"];
  console.log("\nPer-Pipeline Breakdown:");
  console.log("-".repeat(50));
  console.log(pad("Pipeline", 14) + pad("Total", 12) + pad("Prompt", 12) + pad("Completion", 12) + "Cost");

  const pipelineData = [];
  for (const p of pipelines) {
    const key = `${month}#${p}`;
    const item = await dynamoGet(TABLE_NAME, { pk: { S: key } }, region, credentials);
    const data = {
      pipeline: p,
      totalTokens: parseInt(item?.totalTokens?.N || "0", 10),
      promptTokens: parseInt(item?.promptTokens?.N || "0", 10),
      completionTokens: parseInt(item?.completionTokens?.N || "0", 10),
    };
    data.cost = (data.promptTokens / 1000) * PRICING.prompt + (data.completionTokens / 1000) * PRICING.completion;
    pipelineData.push(data);

    console.log(
      pad(p, 14)
      + pad(fmtNum(data.totalTokens), 12)
      + pad(fmtNum(data.promptTokens), 12)
      + pad(fmtNum(data.completionTokens), 12)
      + fmtCost(data.cost),
    );
  }

  // Write JSON output
  if (opts.json) {
    const metricsDir = path.join(__dirname, "metrics");
    mkdirSync(metricsDir, { recursive: true });
    const report = {
      month,
      generatedAt: new Date().toISOString(),
      cap: MONTHLY_CAP,
      total,
      utilization,
      mode,
      estimatedCost: totalCost,
      pipelines: pipelineData,
    };
    const outPath = path.join(metricsDir, "cost-report.json");
    writeFileSync(outPath, JSON.stringify(report, null, 2));
    console.log(`\nJSON report written to: ${outPath}`);
  }
}

function pad(str, len) {
  return String(str).padEnd(len);
}

main().catch((err) => {
  console.error(`Fatal: ${err.message}`);
  process.exit(1);
});
