/**
 * PR-Router Lambda — webhook auth and the five loop-prevention gates, plus the
 * repo→pipeline mapping in queuePrAnswerPipeline.mjs.
 *
 * Hermetic: no AWS credentials are set, so dedupe / rate-limit / DLQ take their
 * fail-open path; the ADO call is stubbed. See helpers.js.
 */

import test from "node:test";
import assert from "node:assert/strict";

import { handler } from "../pr-router.mjs";
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
  ADO_ORG_URL: "https://dev.azure.com/myorg/",
  ADO_PR_ANSWER_PIPELINE_MAP: '{"My-Repo":"303"}',
  MY_IDENTITIES: "me@example.com",
};

function payload(overrides = {}) {
  const { pullRequest = {}, comment = {}, ...rest } = overrides;
  return {
    id: "notification-guid-1",
    eventType: "git.pullrequest.comment-event",
    resource: {
      pullRequest: {
        pullRequestId: 77,
        status: "active",
        createdBy: { uniqueName: "me@example.com" },
        repository: { name: "My-Repo", project: { name: "My Project" } },
        ...pullRequest,
      },
      comment: {
        author: { uniqueName: "reviewer@example.com" },
        content: "please rename this variable",
        ...comment,
      },
    },
    ...rest,
  };
}

function prEvent({ headers, body } = {}) {
  return {
    headers: headers ?? authHeaders(),
    body: JSON.stringify(body ?? payload()),
  };
}

// --- Auth gates ------------------------------------------------------------

test("rejects a request with no Authorization header", async () => {
  setEnv(BASE_ENV);
  const res = await handler(prEvent({ headers: { "X-Webhook-Secret": WEBHOOK_SECRET } }));
  assert.equal(res.statusCode, 401);
});

test("rejects a wrong password", async () => {
  setEnv(BASE_ENV);
  const headers = { Authorization: basicAuth(BASIC_USER, "wrong"), "X-Webhook-Secret": WEBHOOK_SECRET };
  const res = await handler(prEvent({ headers }));
  assert.equal(res.statusCode, 401);
  assert.equal(parse(res).reason, "Invalid credentials");
});

test("rejects a wrong shared secret", async () => {
  setEnv(BASE_ENV);
  const res = await handler(prEvent({ headers: { Authorization: basicAuth(), "X-Webhook-Secret": "nope" } }));
  assert.equal(res.statusCode, 401);
});

// --- Loop-prevention gates -------------------------------------------------

test("skips a non-comment event type", async () => {
  setEnv(BASE_ENV);
  const res = await handler(prEvent({ body: payload({ eventType: "git.push" }) }));
  assert.equal(res.statusCode, 200);
  assert.match(parse(res).reason, /not a comment event/);
});

test("skips a PR that is not active", async () => {
  setEnv(BASE_ENV);
  const res = await handler(prEvent({ body: payload({ pullRequest: { status: "completed" } }) }));
  assert.match(parse(res).reason, /expected "active"/);
});

test("skips a PR created by someone outside MY_IDENTITIES", async () => {
  setEnv(BASE_ENV);
  const body = payload({ pullRequest: { createdBy: { uniqueName: "someone@example.com" } } });
  const res = await handler(prEvent({ body }));
  assert.match(parse(res).reason, /not in MY_IDENTITIES/);
});

test("matches MY_IDENTITIES case-insensitively and trims the list", async () => {
  setEnv({ ...BASE_ENV, MY_IDENTITIES: " Other@Example.com , ME@example.COM " });
  const fetchStub = stubFetch();
  try {
    const res = await handler(prEvent());
    assert.equal(parse(res).status, "queued");
  } finally {
    fetchStub.restore();
  }
});

test("skips a comment written by the PR author (self-loop)", async () => {
  setEnv(BASE_ENV);
  const body = payload({ comment: { author: { uniqueName: "me@example.com" } } });
  const res = await handler(prEvent({ body }));
  assert.match(parse(res).reason, /from PR author/);
});

test("skips a comment written by the bot itself", async () => {
  setEnv(BASE_ENV);
  const body = payload({ comment: { content: "[PRAnswerAgent] already replied" } });
  const res = await handler(prEvent({ body }));
  assert.match(parse(res).reason, /PR Answer bot/);
});

test("rejects a payload with no repository name", async () => {
  setEnv(BASE_ENV);
  const body = payload({ pullRequest: { repository: { project: { name: "My Project" } } } });
  const res = await handler(prEvent({ body }));
  assert.equal(res.statusCode, 400);
  assert.match(parse(res).reason, /repository.name/);
});

// --- Queueing --------------------------------------------------------------

test("queues the mapped pipeline with a well-formed PR URL", async () => {
  setEnv(BASE_ENV);
  const fetchStub = stubFetch();
  try {
    const res = await handler(prEvent());
    assert.equal(res.statusCode, 200);
    assert.equal(parse(res).status, "queued");

    const call = fetchStub.calls[0];
    assert.equal(
      call.url,
      "https://dev.azure.com/myorg/My%20Project/_apis/pipelines/303/runs?api-version=7.1-preview.1",
    );
    assert.equal(
      call.body.templateParameters.prUrl,
      "https://dev.azure.com/myorg/My%20Project/_git/My-Repo/pullrequest/77",
    );
  } finally {
    fetchStub.restore();
  }
});

test("dedupes on the notification id, not the subscription id", async () => {
  // Regression: x-vss-subscriptionid is constant per hook, so using it as the dedupe
  // key made every comment after the first look like a duplicate for the whole TTL.
  setEnv(BASE_ENV);
  const fetchStub = stubFetch();
  try {
    const headers = authHeaders({ "x-vss-subscriptionid": "hook-id-constant" });
    await handler(prEvent({ headers }));
    assert.equal(fetchStub.calls[0].body.templateParameters.eventId, "notification-guid-1");
  } finally {
    fetchStub.restore();
  }
});

test("falls back to x-ms-delivery-id when the payload carries no notification id", async () => {
  setEnv(BASE_ENV);
  const fetchStub = stubFetch();
  try {
    const body = payload();
    delete body.id;
    const headers = authHeaders({ "x-ms-delivery-id": "delivery-1" });
    await handler(prEvent({ headers, body }));
    assert.equal(fetchStub.calls[0].body.templateParameters.eventId, "delivery-1");
  } finally {
    fetchStub.restore();
  }
});

// --- Failure paths ---------------------------------------------------------

test("returns 500 when the repo has no pipeline mapping", async () => {
  setEnv({ ...BASE_ENV, ADO_PR_ANSWER_PIPELINE_MAP: '{"Other-Repo":"999"}' });
  const res = await handler(prEvent());
  assert.equal(res.statusCode, 500);
  assert.match(parse(res).reason, /No PR Answer pipeline mapped/);
});

test("returns 500 when the pipeline map is not valid JSON", async () => {
  setEnv({ ...BASE_ENV, ADO_PR_ANSWER_PIPELINE_MAP: "{not json" });
  const res = await handler(prEvent());
  assert.equal(res.statusCode, 500);
  assert.match(parse(res).reason, /ADO_PR_ANSWER_PIPELINE_MAP/);
});

test("returns 500 when ADO_ORG_URL is missing", async () => {
  setEnv({ ...BASE_ENV, ADO_ORG_URL: undefined });
  delete process.env.ADO_ORG_URL;
  const res = await handler(prEvent());
  assert.equal(res.statusCode, 500);
  assert.match(parse(res).reason, /ADO_ORG_URL/);
});

test("returns 500 when the ADO API rejects the queue request", async () => {
  setEnv(BASE_ENV);
  const fetchStub = stubFetch({ ok: false, status: 500, text: "boom" });
  try {
    const res = await handler(prEvent());
    assert.equal(res.statusCode, 500);
    assert.match(parse(res).reason, /Queue failed: 500/);
  } finally {
    fetchStub.restore();
  }
});
