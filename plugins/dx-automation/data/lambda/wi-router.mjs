import crypto from "crypto";
import { checkAndRecordEvent } from "./dedupe.js";
import { sendToDLQ } from "./dlq.js";
import { checkRateLimit } from "./rate-limiter.js";

/**
 * Work Item Router — single Lambda handling all workitem.updated webhook events.
 *
 * A single API Gateway route (POST /wi) points here. The Lambda scans the
 * work item's tags against the AGENTS config to determine which pipeline to queue.
 * Adding a new agent only requires new Lambda env vars — no new route or hook needed.
 *
 * Each agent has:
 *   - pipeline: env var name holding the ADO pipeline definition ID
 *   - tag:      env var name holding the tag gate string
 *   - type:     expected work item type ("User Story" or "Bug")
 *   - paramKey: template parameter key for the work item ID
 */
const AGENTS = [
  { name: "dor",      pipeline: "ADO_DOR_PIPELINE_ID",    tag: "TAG_GATE_DOR",    type: "User Story", paramKey: "workItemId" },
  { name: "dod",      pipeline: "ADO_DOD_PIPELINE_ID",    tag: "TAG_GATE_DOD",    type: "User Story", paramKey: "workItemId" },
  { name: "bugfix",   pipeline: "ADO_BUGFIX_PIPELINE_ID", tag: "TAG_GATE_BUGFIX", type: "Bug",        paramKey: "bugId" },
  { name: "qa",       pipeline: "ADO_QA_PIPELINE_ID",     tag: "TAG_GATE_QA",     type: "User Story", paramKey: "workItemId" },
  { name: "devagent", pipeline: "ADO_DEV_PIPELINE_ID",    tag: "TAG_GATE_DEV",    type: "User Story", paramKey: "workItemId" },
  { name: "docagent",    pipeline: "ADO_DOC_PIPELINE_ID",        tag: "TAG_GATE_DOC",        type: "User Story", paramKey: "workItemId" },
  { name: "estimation", pipeline: "ADO_ESTIMATION_PIPELINE_ID", tag: "TAG_GATE_ESTIMATION", type: "User Story", paramKey: "workItemId" },
];

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

export const handler = async (event) => {
  let agent = null;
  let workItemId = null;

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
    const fields = r.revision?.fields || {};

    workItemId = r.workItemId ?? r.revision?.id;
    if (workItemId == null) {
      return json(400, {
        status: "rejected",
        reason: "Payload missing workItemId (resource.workItemId or resource.revision.id)",
      });
    }

    // Extract tags and work item type from payload
    const workItemType = fields["System.WorkItemType"];
    const tags = String(fields["System.Tags"] || "")
      .split(";")
      .map((s) => s.trim().toLowerCase());

    console.log(`[WI-Router] workItemId=${workItemId} type=${workItemType} tags=[${tags.join(", ")}]`);

    // Match agent by tag + work item type
    for (const candidate of AGENTS) {
      const tagGate = (process.env[candidate.tag] || "").toLowerCase();
      if (!tagGate) continue; // env var not set — agent not enabled
      if (candidate.type !== workItemType) continue;
      if (!tags.includes(tagGate)) continue;
      agent = candidate;
      break;
    }

    if (!agent) {
      console.log(`[WI-Router] No matching agent — skipped`);
      return json(200, {
        status: "skipped",
        reason: "No matching agent (tag + work item type)",
        workItemId,
      });
    }

    console.log(`[WI-Router] Matched agent: ${agent.name}`);

    const runId = crypto.randomUUID();
    // body.id is unique per notification (GUID). x-vss-subscriptionid is the hook ID
    // (constant per hook — NOT unique per event), so we don't use it for dedup.
    const eventId = body.id || headers["x-ms-delivery-id"] || null;

    // Deduplication
    const dedupe = await checkAndRecordEvent(eventId, agent.name);
    if (dedupe.duplicate) {
      console.log(`[WI-Router] Duplicate event ${eventId} for ${agent.name} — skipped`);
      return json(200, { status: "duplicate", eventId, workItemId });
    }

    // Rate limit
    const identityId = (fields["System.ChangedBy"] || "").toLowerCase() || null;
    const rateCheck = await checkRateLimit(agent.name, identityId);
    if (!rateCheck.allowed) {
      console.log(`[WI-Router] Rate limited: ${rateCheck.reason}`);
      return json(429, { status: "rate_limited", reason: rateCheck.reason, workItemId });
    }

    // Queue pipeline
    const pipelineId = process.env[agent.pipeline];
    if (!pipelineId) {
      throw new Error(`Env var ${agent.pipeline} not set`);
    }
    const pat = process.env.ADO_PAT;
    if (!pat) {
      throw new Error("Env var ADO_PAT not set");
    }
    const orgUrl = body.resourceContainers?.account?.baseUrl?.replace(/\/+$/, "");
    if (!orgUrl) {
      throw new Error("Payload missing resourceContainers.account.baseUrl");
    }
    // Pipelines live in the project specified by ADO_PIPELINE_PROJECT env var,
    // which may differ from the work item's project (System.TeamProject).
    const project = process.env.ADO_PIPELINE_PROJECT || fields["System.TeamProject"];

    const url =
      `${orgUrl}/${encodeURIComponent(project)}` +
      `/_apis/pipelines/${pipelineId}/runs?api-version=7.1-preview.1`;

    const authHeader = Buffer.from(`:${pat}`).toString("base64");

    console.log(`[WI-Router] Queuing ${agent.name} pipeline ${pipelineId} in project "${project}" for WI ${workItemId}`);

    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${authHeader}`,
      },
      body: JSON.stringify({
        templateParameters: {
          [agent.paramKey]: String(workItemId),
          dryRun: "false",
          eventId: eventId || "",
        },
      }),
    });

    if (!res.ok) {
      const t = await res.text();
      console.error(`[WI-Router] ADO API error: ${res.status} ${t}`);
      console.error(`[WI-Router] Request URL: ${url.replace(/\/\/.*@/, "//***@")}`);
      throw new Error(`Queue ${agent.name} pipeline failed: ${res.status} — ${t.slice(0, 200)}`);
    }

    const result = await res.json();
    console.log(`[WI-Router] ${agent.name.toUpperCase()} TRIGGERED: workItemId=${workItemId} pipelineRunId=${result.id} runId=${runId} eventId=${eventId}`);

    return json(200, { status: "queued", pipeline: agent.name, workItemId, runId, pipelineRunId: result.id });
  } catch (err) {
    console.error(`[WI-Router] ERROR for agent=${agent?.name ?? "unknown"} workItemId=${workItemId ?? "unknown"}: ${err.message}`);
    await sendToDLQ({ workItemId: workItemId ?? "unknown" }, err, { pipeline: agent?.name ?? "unknown" }).catch(() => {});
    return json(500, { status: "error", reason: err.message });
  }
};
