/**
 * Per-pipeline and per-identity daily rate limits using DynamoDB atomic counters.
 * Fails open: if DynamoDB is unavailable, allows the request.
 */

import { getAwsCredentials, getAwsRegion, dynamoUpdate } from "./aws-sig.js";

const TABLE_NAME = process.env.DYNAMODB_RATE_LIMIT_TABLE;

const LIMITS = {
  dor: 20,
  "pr-review": 50,
  "pr-answer": 30,
};

const PER_IDENTITY_LIMIT = 10;

/**
 * Atomically increment a counter and return the new value.
 * Uses DynamoDB ADD expression — no read-then-write race.
 */
async function incrementCounter(key, region, credentials) {
  const attrs = await dynamoUpdate(
    TABLE_NAME,
    { pk: { S: key } },
    "ADD #cnt :inc",
    { ":inc": { N: "1" } },
    region,
    credentials,
    { "#cnt": "count" },
  );
  return parseInt(attrs.count?.N || "1", 10);
}

/**
 * Check rate limits for a pipeline invocation.
 *
 * @param {string} pipelineName - Pipeline name (dor, pr-review, pr-answer)
 * @param {string} [identityId] - Optional identity for per-identity limits
 * @returns {{ allowed: boolean, degraded?: boolean, reason?: string, current?: number, limit?: number, remaining?: number }}
 */
export async function checkRateLimit(pipelineName, identityId) {
  const credentials = getAwsCredentials();

  if (!credentials) {
    console.log("[RateLimit] No AWS credentials — rate limits disabled");
    return { allowed: true, degraded: true };
  }

  try {
    const region = getAwsRegion();
    const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD

    // Check pipeline daily limit
    const pipelineKey = `${pipelineName}#${today}`;
    const pipelineCount = await incrementCounter(pipelineKey, region, credentials);
    const pipelineLimit = LIMITS[pipelineName] || 50;
    if (pipelineCount > pipelineLimit) {
      console.log(`[RateLimit] ${pipelineName} daily limit exceeded: ${pipelineCount}/${pipelineLimit}`);
      return { allowed: false, reason: `${pipelineName} limit exceeded: ${pipelineCount}/${pipelineLimit}`, current: pipelineCount, limit: pipelineLimit };
    }

    // Check per-identity daily limit
    if (identityId) {
      const identityKey = `identity:${identityId}#${today}`;
      const identityCount = await incrementCounter(identityKey, region, credentials);
      if (identityCount > PER_IDENTITY_LIMIT) {
        console.log(`[RateLimit] Identity ${identityId} daily limit exceeded: ${identityCount}/${PER_IDENTITY_LIMIT}`);
        return { allowed: false, reason: `identity limit exceeded: ${identityCount}/${PER_IDENTITY_LIMIT}`, current: identityCount, limit: PER_IDENTITY_LIMIT };
      }
    }

    return { allowed: true, current: pipelineCount, limit: pipelineLimit, remaining: pipelineLimit - pipelineCount };
  } catch (err) {
    console.warn(`[RateLimit] Error: ${err.message} — allowing (fail-open)`);
    return { allowed: true, degraded: true };
  }
}
