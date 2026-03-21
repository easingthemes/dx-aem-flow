/**
 * Dead Letter Queue — sends failed events to AWS SQS for later retry.
 * Fails open: if not configured or send fails, logs warning and returns.
 */

import { getAwsCredentials, getAwsRegion, sqsSend } from "./aws-sig.js";

const QUEUE_URL = process.env.SQS_DLQ_URL;

/**
 * Send a failed event to the dead letter queue.
 *
 * @param {object} event - Original event payload
 * @param {Error} error - The error that caused failure
 * @param {{ runId?: string, eventId?: string, pipeline?: string }} context
 * @returns {{ sent: boolean, reason?: string }}
 */
export async function sendToDLQ(event, error, context = {}) {
  const credentials = getAwsCredentials();

  if (!credentials || !QUEUE_URL) {
    console.warn("[DLQ] No AWS credentials or SQS_DLQ_URL — DLQ disabled");
    return { sent: false, reason: "not configured" };
  }

  try {
    const region = getAwsRegion();

    const message = {
      event,
      error: { message: error.message, stack: error.stack },
      runId: context.runId || null,
      eventId: context.eventId || null,
      pipeline: context.pipeline || null,
      timestamp: new Date().toISOString(),
    };

    await sqsSend(QUEUE_URL, message, region, credentials);
    console.log(`[DLQ] Sent to DLQ: ${context.eventId || "unknown"}`);
    return { sent: true };
  } catch (err) {
    console.error(`[DLQ] Failed to send to DLQ: ${err.message}`);
    return { sent: false, reason: err.message };
  }
}
