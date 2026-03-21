/**
 * Monthly token budget tracking with 3-tier degradation via DynamoDB.
 * Fails open: if DynamoDB is unavailable, allows the request in normal mode.
 *
 * Tiers:
 *   < 80%  → normal (full functionality)
 *   80-90% → alert (warning logged, still normal)
 *   90-100% → suggest-only (no push, reduced votes)
 *   >= 100% → halted (LLM calls blocked)
 */

import { getAwsCredentials, getAwsRegion, dynamoGet, dynamoUpdate } from "./aws-sig.js";

const TABLE_NAME = process.env.DYNAMODB_TOKEN_BUDGET_TABLE;
const MONTHLY_CAP = parseInt(process.env.MONTHLY_TOKEN_CAP || "5000000"); // 5M default
const ALERT_THRESHOLD = 0.80;
const DEGRADE_THRESHOLD = 0.90;
const HALT_THRESHOLD = 1.00;

/**
 * Check current token budget status.
 * @returns {{ allowed: boolean, mode: string, utilization?: number, totalTokens?: number, cap?: number, degraded?: boolean }}
 */
export async function checkTokenBudget() {
  const credentials = getAwsCredentials();

  if (!credentials) {
    return { allowed: true, mode: "normal", degraded: true };
  }

  try {
    const region = getAwsRegion();
    const month = new Date().toISOString().slice(0, 7); // YYYY-MM

    const item = await dynamoGet(TABLE_NAME, { pk: { S: month } }, region, credentials);
    const totalTokens = item ? parseInt(item.totalTokens?.N || "0", 10) : 0;
    const utilization = totalTokens / MONTHLY_CAP;

    if (utilization >= HALT_THRESHOLD) {
      console.log(`[TokenBudget] HALTED: ${(utilization * 100).toFixed(1)}% of monthly cap (${totalTokens}/${MONTHLY_CAP})`);
      return { allowed: false, mode: "halted", utilization, totalTokens, cap: MONTHLY_CAP };
    }
    if (utilization >= DEGRADE_THRESHOLD) {
      console.warn(`[TokenBudget] DEGRADED: ${(utilization * 100).toFixed(1)}% — suggest-only mode`);
      return { allowed: true, mode: "suggest-only", utilization, totalTokens, cap: MONTHLY_CAP };
    }
    if (utilization >= ALERT_THRESHOLD) {
      console.warn(`[TokenBudget] WARNING: ${(utilization * 100).toFixed(1)}% of monthly cap used`);
    }

    return { allowed: true, mode: "normal", utilization, totalTokens, cap: MONTHLY_CAP };
  } catch (err) {
    console.warn(`[TokenBudget] Error: ${err.message} — allowing (fail-open)`);
    return { allowed: true, mode: "normal", degraded: true };
  }
}

/**
 * Record token usage for a pipeline run.
 * @param {string} pipelineName
 * @param {{ prompt_tokens?: number, completion_tokens?: number, total_tokens?: number }} usage
 */
export async function recordTokenUsage(pipelineName, usage) {
  const credentials = getAwsCredentials();
  if (!credentials || !usage) return;

  try {
    const region = getAwsRegion();
    const month = new Date().toISOString().slice(0, 7);

    // Increment monthly totals (atomic ADD)
    await dynamoUpdate(
      TABLE_NAME,
      { pk: { S: month } },
      "ADD totalTokens :tt, promptTokens :pt, completionTokens :ct",
      {
        ":tt": { N: String(usage.total_tokens || 0) },
        ":pt": { N: String(usage.prompt_tokens || 0) },
        ":ct": { N: String(usage.completion_tokens || 0) },
      },
      region,
      credentials,
    );

    // Increment per-pipeline totals (atomic ADD)
    await dynamoUpdate(
      TABLE_NAME,
      { pk: { S: `${month}#${pipelineName}` } },
      "ADD totalTokens :tt, promptTokens :pt, completionTokens :ct",
      {
        ":tt": { N: String(usage.total_tokens || 0) },
        ":pt": { N: String(usage.prompt_tokens || 0) },
        ":ct": { N: String(usage.completion_tokens || 0) },
      },
      region,
      credentials,
    );
  } catch (err) {
    console.warn(`[TokenBudget] Failed to record usage: ${err.message}`);
  }
}
