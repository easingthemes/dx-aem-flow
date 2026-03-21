import crypto from "crypto";
import { queuePrAnswerPipeline } from "./queuePrAnswerPipeline.mjs";
import { checkAndRecordEvent } from "./dedupe.js";
import { sendToDLQ } from "./dlq.js";
import { checkRateLimit } from "./rate-limiter.js";

function safeEq(a = "", b = "") {
  const ab = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  if (ab.length !== bb.length) return false;
  return crypto.timingSafeEqual(ab, bb);
}

function json(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  };
}

function unauthorized(reason) {
  return json(401, { status: "unauthorized", reason });
}

/**
 * PR Router — Lambda handler for ADO Service Hook: git.pullrequest.comment-event
 *
 * Triggered when a reviewer posts a comment on a PR.
 * Gates:
 *   1. Basic Auth + shared secret
 *   2. Event type includes "comment"
 *   3. PR is active
 *   4. PR is mine (createdBy matches MY_IDENTITIES)
 *   5. Comment is NOT from me (avoid infinite loop)
 *   6. Comment is NOT from the bot (avoid infinite loop)
 */
export const handler = async (event) => {
  try {
    const headers = Object.fromEntries(
      Object.entries(event.headers || {}).map(([k, v]) => [k.toLowerCase(), v])
    );

    // Basic auth
    const auth = headers["authorization"] || "";
    if (!auth.toLowerCase().startsWith("basic ")) {
      return unauthorized("Missing or invalid Authorization header");
    }
    const decoded = Buffer.from(auth.slice(6).trim(), "base64").toString("utf8");
    const i = decoded.indexOf(":");
    if (i < 0) return unauthorized("Malformed Basic auth (no colon)");
    if (
      !safeEq(decoded.slice(0, i), process.env.BASIC_USER) ||
      !safeEq(decoded.slice(i + 1), process.env.BASIC_PASS)
    ) {
      return unauthorized("Invalid credentials");
    }

    // Shared secret header
    if (!safeEq(headers["x-webhook-secret"] || "", process.env.WEBHOOK_SECRET || "")) {
      return unauthorized("Invalid x-webhook-secret header");
    }

    // Parse payload
    const body = JSON.parse(event.body || "{}");
    const r = body.resource || {};

    // Gate 1: Must be a comment event
    const eventType = body.eventType || "";
    if (!eventType.includes("comment")) {
      return json(200, {
        status: "skipped",
        reason: `Event type "${eventType}" is not a comment event`,
      });
    }

    // Gate 2: PR must be active
    const pr = r.pullRequest || {};
    if (pr.status !== "active") {
      return json(200, {
        status: "skipped",
        reason: `PR status is "${pr.status || "unknown"}", expected "active"`,
      });
    }

    // Gate 3: PR must be mine
    const myIdentities = (process.env.MY_IDENTITIES || "")
      .split(",").map((s) => s.trim().toLowerCase()).filter(Boolean);

    const prAuthor = (pr.createdBy?.uniqueName || "").toLowerCase();
    const isMine = myIdentities.some((id) => id === prAuthor);
    if (!isMine) {
      return json(200, {
        status: "skipped",
        reason: `PR author "${pr.createdBy?.uniqueName || "unknown"}" is not in MY_IDENTITIES`,
      });
    }

    // Gate 4: Comment must NOT be from me (avoid infinite loop)
    const comment = r.comment || {};
    const commentAuthor = (comment.author?.uniqueName || "").toLowerCase();
    const isMyComment = myIdentities.some((id) => id === commentAuthor);
    if (isMyComment) {
      return json(200, {
        status: "skipped",
        reason: "Comment is from PR author (self) — skipping to avoid loop",
      });
    }

    // Gate 5: Comment must NOT be from the bot (avoid infinite loop)
    const commentContent = (comment.content || "").toLowerCase();
    if (commentContent.includes("[pransweragent]")) {
      return json(200, {
        status: "skipped",
        reason: "Comment is from PR Answer bot — skipping to avoid loop",
      });
    }

    const prId = pr.pullRequestId;
    const repoName = pr.repository?.name || "";
    const project = pr.repository?.project?.name || "";

    if (prId == null || !repoName) {
      return json(400, {
        status: "rejected",
        reason: `Missing required fields: ${prId == null ? "pullRequestId" : ""}${prId == null && !repoName ? ", " : ""}${!repoName ? "repository.name" : ""}`,
      });
    }

    const runId = crypto.randomUUID();
    const eventId = headers["x-vss-subscriptionid"] || headers["x-ms-delivery-id"] || null;

    // Deduplication check
    const dedupe = await checkAndRecordEvent(eventId, "pr-answer");
    if (dedupe.duplicate) {
      return json(200, { status: "duplicate", eventId, prId });
    }

    // Rate limit check
    const commentAuthorId = (comment.author?.uniqueName || "").toLowerCase() || null;
    const rateCheck = await checkRateLimit("pr-answer", commentAuthorId);
    if (!rateCheck.allowed) {
      return json(429, { status: "rate_limited", reason: rateCheck.reason, prId });
    }

    console.log("TRIGGERED: prId=", prId, "repoName=", repoName, "runId=", runId, "eventId=", eventId);
    await queuePrAnswerPipeline({ prId, repoName, project, runId, eventId });

    return json(200, { status: "queued", prId, repoName, runId });
  } catch (err) {
    console.error(err);
    await sendToDLQ({ prId: "unknown" }, err, { pipeline: "pr-answer" }).catch(() => {});
    return json(500, { status: "error", reason: err.message });
  }
};
