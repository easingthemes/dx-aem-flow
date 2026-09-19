/**
 * WI-Router Lambda — webhook auth, payload validation, tag routing, pipeline queueing.
 *
 * Hermetic: no AWS credentials are set, so dedupe / rate-limit / DLQ take their
 * fail-open path; the ADO call is stubbed. See helpers.js.
 */

import test from "node:test";
import assert from "node:assert/strict";

import { handler } from "../wi-router.mjs";
import {
  setEnv, authHeaders, basicAuth, stubFetch, muteConsole, parse,
  WEBHOOK_SECRET, BASIC_USER, BASIC_PASS,
} from "./helpers.js";

const unmute = muteConsole();
test.after(() => unmute());

const BASE_ENV = {
  BASIC_USER,
  BASIC_PASS,
  WEBHOOK_SECRET,
  ADO_PAT: "pat-token",
  ADO_DOD_PIPELINE_ID: "101",
  TAG_GATE_DOD: "KAI-DOD",
};

function wiEvent({ headers, body } = {}) {
  return {
    headers: headers ?? authHeaders(),
    body: JSON.stringify(body ?? payload()),
  };
}

function payload(overrides = {}) {
  const { fields = {}, ...rest } = overrides;
  return {
    id: "notification-guid-1",
    resource: {
      workItemId: 4711,
      revision: {
        fields: {
          "System.WorkItemType": "User Story",
          "System.Tags": "KAI-DOD; needs-review",
          "System.TeamProject": "Work Item Project",
          "System.ChangedBy": "dev@example.com",
          ...fields,
        },
      },
    },
    resourceContainers: { account: { baseUrl: "https://dev.azure.com/myorg/" } },
    ...rest,
  };
}

// --- Auth gates ------------------------------------------------------------

test("rejects a request with no Authorization header", async () => {
  setEnv(BASE_ENV);
  const res = await handler(wiEvent({ headers: { "X-Webhook-Secret": WEBHOOK_SECRET } }));
  assert.equal(res.statusCode, 401);
  assert.match(parse(res).reason, /Authorization header/);
});

test("rejects Basic auth with no colon", async () => {
  setEnv(BASE_ENV);
  const bad = `Basic ${Buffer.from("nocolon").toString("base64")}`;
  const res = await handler(wiEvent({ headers: { Authorization: bad, "X-Webhook-Secret": WEBHOOK_SECRET } }));
  assert.equal(res.statusCode, 401);
  assert.match(parse(res).reason, /no colon/);
});

test("rejects a wrong password", async () => {
  setEnv(BASE_ENV);
  const headers = { Authorization: basicAuth(BASIC_USER, "wrong"), "X-Webhook-Secret": WEBHOOK_SECRET };
  const res = await handler(wiEvent({ headers }));
  assert.equal(res.statusCode, 401);
  assert.equal(parse(res).reason, "Invalid credentials");
});

test("rejects a wrong shared secret", async () => {
  setEnv(BASE_ENV);
  const res = await handler(wiEvent({ headers: { Authorization: basicAuth(), "X-Webhook-Secret": "nope" } }));
  assert.equal(res.statusCode, 401);
  assert.match(parse(res).reason, /x-webhook-secret/);
});

test("accepts header names in any case", async () => {
  setEnv(BASE_ENV);
  const fetchStub = stubFetch();
  try {
    const headers = { AUTHORIZATION: basicAuth(), "x-WEBHOOK-secret": WEBHOOK_SECRET };
    const res = await handler(wiEvent({ headers }));
    assert.equal(res.statusCode, 200);
    assert.equal(parse(res).status, "queued");
  } finally {
    fetchStub.restore();
  }
});

// --- Payload validation ----------------------------------------------------

test("rejects a payload with no work item id", async () => {
  setEnv(BASE_ENV);
  const body = payload();
  delete body.resource.workItemId;
  delete body.resource.revision.id;
  const res = await handler(wiEvent({ body }));
  assert.equal(res.statusCode, 400);
  assert.equal(parse(res).status, "rejected");
});

test("falls back to resource.revision.id for the work item id", async () => {
  setEnv(BASE_ENV);
  const fetchStub = stubFetch();
  try {
    const body = payload();
    delete body.resource.workItemId;
    body.resource.revision.id = 9001;
    const res = await handler(wiEvent({ body }));
    assert.equal(parse(res).workItemId, 9001);
    assert.equal(fetchStub.calls[0].body.templateParameters.workItemId, "9001");
  } finally {
    fetchStub.restore();
  }
});

// --- Tag routing -----------------------------------------------------------

test("skips when no tag gate env var is set (agent not enabled)", async () => {
  setEnv({ ...BASE_ENV, TAG_GATE_DOD: undefined });
  delete process.env.TAG_GATE_DOD;
  const res = await handler(wiEvent());
  assert.equal(res.statusCode, 200);
  assert.equal(parse(res).status, "skipped");
});

test("skips when the tag matches but the work item type does not", async () => {
  setEnv(BASE_ENV);
  const res = await handler(wiEvent({ body: payload({ fields: { "System.WorkItemType": "Bug" } }) }));
  assert.equal(parse(res).status, "skipped");
});

test("skips when the work item carries no matching tag", async () => {
  setEnv(BASE_ENV);
  const res = await handler(wiEvent({ body: payload({ fields: { "System.Tags": "other; unrelated" } }) }));
  assert.equal(parse(res).status, "skipped");
});

test("matches tags case-insensitively and ignores surrounding whitespace", async () => {
  setEnv({ ...BASE_ENV, TAG_GATE_DOD: "kai-dod" });
  const fetchStub = stubFetch();
  try {
    const res = await handler(wiEvent({ body: payload({ fields: { "System.Tags": "first ;   KAI-DOD   ; last" } }) }));
    assert.equal(parse(res).status, "queued");
  } finally {
    fetchStub.restore();
  }
});

test("routes to the agent whose tag gate matches, not the first enabled one", async () => {
  setEnv({
    ...BASE_ENV,
    TAG_GATE_QA: "KAI-QA",
    ADO_QA_PIPELINE_ID: "202",
  });
  const fetchStub = stubFetch();
  try {
    const res = await handler(wiEvent({ body: payload({ fields: { "System.Tags": "KAI-QA" } }) }));
    assert.equal(parse(res).pipeline, "qa");
    assert.match(fetchStub.calls[0].url, /\/_apis\/pipelines\/202\/runs/);
  } finally {
    fetchStub.restore();
  }
});

// --- Queueing --------------------------------------------------------------

test("queues the pipeline with the expected URL, auth and template parameters", async () => {
  setEnv(BASE_ENV);
  const fetchStub = stubFetch({ json: { id: 55 } });
  try {
    const res = await handler(wiEvent());
    const parsed = parse(res);
    assert.equal(res.statusCode, 200);
    assert.equal(parsed.status, "queued");
    assert.equal(parsed.pipeline, "dod");
    assert.equal(parsed.pipelineRunId, 55);

    assert.equal(fetchStub.calls.length, 1);
    const call = fetchStub.calls[0];
    // Trailing slash on baseUrl must not produce a double slash.
    assert.equal(
      call.url,
      "https://dev.azure.com/myorg/Work%20Item%20Project/_apis/pipelines/101/runs?api-version=7.1-preview.1",
    );
    assert.equal(call.options.method, "POST");
    assert.equal(call.options.headers.Authorization, `Basic ${Buffer.from(":pat-token").toString("base64")}`);
    assert.deepEqual(call.body.templateParameters, {
      workItemId: "4711",
      dryRun: "false",
      eventId: "notification-guid-1",
    });
  } finally {
    fetchStub.restore();
  }
});

test("ADO_PIPELINE_PROJECT overrides the work item's own project", async () => {
  setEnv({ ...BASE_ENV, ADO_PIPELINE_PROJECT: "Pipeline Project" });
  const fetchStub = stubFetch();
  try {
    await handler(wiEvent());
    assert.match(fetchStub.calls[0].url, /\/Pipeline%20Project\//);
  } finally {
    fetchStub.restore();
  }
});

test("dedupes on the notification id, never on the subscription id", async () => {
  // x-vss-subscriptionid is constant per hook, so it must not reach the dedupe key.
  setEnv(BASE_ENV);
  const fetchStub = stubFetch();
  try {
    const headers = authHeaders({ "x-vss-subscriptionid": "hook-id-constant" });
    await handler(wiEvent({ headers }));
    assert.equal(fetchStub.calls[0].body.templateParameters.eventId, "notification-guid-1");
  } finally {
    fetchStub.restore();
  }
});

// --- Failure paths ---------------------------------------------------------

test("returns 500 when the matched agent has no pipeline id configured", async () => {
  setEnv({ ...BASE_ENV, ADO_DOD_PIPELINE_ID: undefined });
  delete process.env.ADO_DOD_PIPELINE_ID;
  const res = await handler(wiEvent());
  assert.equal(res.statusCode, 500);
  assert.match(parse(res).reason, /ADO_DOD_PIPELINE_ID/);
});

test("returns 500 when ADO_PAT is missing", async () => {
  setEnv({ ...BASE_ENV, ADO_PAT: undefined });
  delete process.env.ADO_PAT;
  const res = await handler(wiEvent());
  assert.equal(res.statusCode, 500);
  assert.match(parse(res).reason, /ADO_PAT/);
});

test("returns 500 when the payload has no organization base URL", async () => {
  setEnv(BASE_ENV);
  const body = payload();
  delete body.resourceContainers;
  const res = await handler(wiEvent({ body }));
  assert.equal(res.statusCode, 500);
  assert.match(parse(res).reason, /baseUrl/);
});

test("returns 500 when the ADO API rejects the queue request", async () => {
  setEnv(BASE_ENV);
  const fetchStub = stubFetch({ ok: false, status: 403, text: "forbidden" });
  try {
    const res = await handler(wiEvent());
    assert.equal(res.statusCode, 500);
    assert.match(parse(res).reason, /403/);
  } finally {
    fetchStub.restore();
  }
});

test("returns 500 on malformed JSON rather than throwing", async () => {
  setEnv(BASE_ENV);
  const res = await handler({ headers: authHeaders(), body: "{not json" });
  assert.equal(res.statusCode, 500);
  assert.equal(parse(res).status, "error");
});
