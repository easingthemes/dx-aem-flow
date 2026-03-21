/**
 * Event deduplication via DynamoDB conditional put (insert-or-fail pattern).
 * Fails open: if DynamoDB is unavailable, logs warning and proceeds.
 */

import { getAwsCredentials, getAwsRegion, dynamoPut } from "./aws-sig.js";

const TABLE_NAME = process.env.DYNAMODB_DEDUPE_TABLE;

/**
 * Check if an event has already been processed. If not, record it.
 *
 * @param {string} eventId - Unique event identifier
 * @param {string} pipelineName - Pipeline name (stored as attribute)
 * @returns {{ duplicate: boolean, degraded?: boolean }}
 */
export async function checkAndRecordEvent(eventId, pipelineName) {
  const credentials = getAwsCredentials();

  if (!credentials) {
    console.log("[Dedupe] No AWS credentials — deduplication disabled");
    return { duplicate: false, degraded: true };
  }
  if (!eventId) {
    console.log("[Dedupe] No eventId — skipping deduplication");
    return { duplicate: false, degraded: true };
  }

  try {
    const region = getAwsRegion();
    const ttl = Math.floor(Date.now() / 1000) + 3600; // 1 hour auto-expiry

    const item = {
      eventId: { S: eventId },
      pipeline: { S: pipelineName },
      timestamp: { S: new Date().toISOString() },
      runId: { S: process.env.RUN_ID || "" },
      ttl: { N: String(ttl) },
    };

    await dynamoPut(TABLE_NAME, item, "attribute_not_exists(eventId)", region, credentials);

    console.log(`[Dedupe] Recorded event: ${eventId} for ${pipelineName}`);
    return { duplicate: false };
  } catch (err) {
    // ConditionalCheckFailedException = duplicate (same as Azure 409)
    if (err.__type && err.__type.includes("ConditionalCheckFailedException")) {
      console.log(`[Dedupe] Duplicate event: ${eventId} for ${pipelineName}`);
      return { duplicate: true };
    }

    console.warn(`[Dedupe] Storage error: ${err.message} — proceeding (fail-open)`);
    return { duplicate: false, degraded: true };
  }
}
