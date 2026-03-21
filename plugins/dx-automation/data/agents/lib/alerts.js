/**
 * Alert routing by severity — structured logging + bundle storage.
 *
 * Severity levels:
 *   critical — scanner high risk, policy violations, push failures
 *   warning  — rate limit approaching, budget at 80%, DLQ depth > 3
 *   info     — pipeline completion, skip reasons
 *
 * Current destinations: structured console log + bundle artifact.
 * Future: Azure Monitor alerts, Teams webhook, email.
 */
import { writeArtifact } from "./bundle.js";

const alerts = [];

/**
 * Send an alert. Routes based on severity.
 *
 * @param {string} severity - "critical" | "warning" | "info"
 * @param {string} message - Human-readable alert message
 * @param {object} [context] - Additional context (pipeline, step, details)
 * @param {object} [bundleCtx] - Bundle context for artifact storage
 */
export function sendAlert(severity, message, context = {}, bundleCtx = null) {
  const alert = {
    severity,
    message,
    timestamp: new Date().toISOString(),
    pipeline: context.pipeline || process.env.AUTOMATION_PIPELINE || "unknown",
    step: context.step || null,
    ...context,
  };

  // Remove redundant fields from spread
  delete alert.bundleCtx;

  alerts.push(alert);

  // Structured console output
  const prefix = severity === "critical" ? "[ALERT:CRITICAL]"
    : severity === "warning" ? "[ALERT:WARNING]"
    : "[ALERT:INFO]";

  const logFn = severity === "critical" ? console.error
    : severity === "warning" ? console.warn
    : console.log;

  logFn(`${prefix} ${message}`, context.details ? `— ${typeof context.details === "string" ? context.details : JSON.stringify(context.details)}` : "");

  // Write to bundle if available
  if (bundleCtx) {
    writeArtifact(bundleCtx, "actions", "alerts.json", alerts);
  }
}

/**
 * Get all alerts collected in this run.
 * @returns {Array<object>}
 */
export function getAlerts() {
  return [...alerts];
}

/**
 * Get alerts filtered by severity.
 * @param {string} severity
 * @returns {Array<object>}
 */
export function getAlertsBySeverity(severity) {
  return alerts.filter((a) => a.severity === severity);
}

/**
 * Check if any critical alerts were raised.
 * @returns {boolean}
 */
export function hasCriticalAlerts() {
  return alerts.some((a) => a.severity === "critical");
}

/**
 * Clear alerts (for testing or between steps).
 */
export function clearAlerts() {
  alerts.length = 0;
}

/**
 * Check SQS DLQ depth and raise alerts if above thresholds.
 *
 * @param {object} [bundleCtx] - Bundle context for artifact storage
 * @returns {{ depth: number, status: string }} depth and alert status
 */
export async function checkDlqDepth(bundleCtx = null) {
  const queueUrl = process.env.SQS_DLQ_URL;
  if (!queueUrl) return { depth: 0, status: "unconfigured" };

  try {
    const { getAwsCredentials, getAwsRegion, sqsGetQueueAttributes } = await import("./aws-sig.js");
    const credentials = getAwsCredentials();
    if (!credentials) return { depth: 0, status: "no-credentials" };

    const region = getAwsRegion();
    const attrs = await sqsGetQueueAttributes(
      queueUrl,
      ["ApproximateNumberOfMessages"],
      region,
      credentials,
    );
    const depth = parseInt(attrs.ApproximateNumberOfMessages || "0", 10);

    if (depth > 10) {
      sendAlert("critical", `DLQ depth critical: ${depth} messages pending`, { step: "health-check", details: { depth, threshold: 10 } }, bundleCtx);
      return { depth, status: "critical" };
    }
    if (depth > 5) {
      sendAlert("warning", `DLQ depth elevated: ${depth} messages pending`, { step: "health-check", details: { depth, threshold: 5 } }, bundleCtx);
      return { depth, status: "warning" };
    }

    return { depth, status: "ok" };
  } catch (err) {
    console.warn(`[Alerts] DLQ depth check failed: ${err.message}`);
    return { depth: -1, status: "error" };
  }
}
