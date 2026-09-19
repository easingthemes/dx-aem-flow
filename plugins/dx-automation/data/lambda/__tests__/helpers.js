/**
 * Shared helpers for the Lambda router suites.
 *
 * Hermetic by construction: every test clears AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY,
 * which makes lib/{dedupe,rate-limiter,dlq}.js take their documented fail-open path and
 * touch no network. The only outbound call left is the ADO pipeline queue, and that goes
 * through `globalThis.fetch`, which `stubFetch()` replaces.
 */

export const BASIC_USER = "hook-user";
export const BASIC_PASS = "hook-pass";
export const WEBHOOK_SECRET = "s3cret";

const AWS_VARS = [
  "AWS_ACCESS_KEY_ID",
  "AWS_SECRET_ACCESS_KEY",
  "AWS_SESSION_TOKEN",
  "DYNAMODB_DEDUPE_TABLE",
  "DYNAMODB_RATE_LIMIT_TABLE",
  "SQS_DLQ_URL",
];

const MANAGED = [
  "BASIC_USER",
  "BASIC_PASS",
  "WEBHOOK_SECRET",
  "ADO_PAT",
  "ADO_ORG_URL",
  "ADO_PIPELINE_PROJECT",
  "ADO_PR_ANSWER_PIPELINE_MAP",
  "MY_IDENTITIES",
  "ADO_DOD_PIPELINE_ID",
  "ADO_QA_PIPELINE_ID",
  "ADO_DEV_PIPELINE_ID",
  "ADO_DOC_PIPELINE_ID",
  "ADO_ESTIMATION_PIPELINE_ID",
  "TAG_GATE_DOD",
  "TAG_GATE_QA",
  "TAG_GATE_DEV",
  "TAG_GATE_DOC",
  "TAG_GATE_ESTIMATION",
  ...AWS_VARS,
];

/** Reset every env var these handlers read, then apply `env`. */
export function setEnv(env = {}) {
  for (const key of MANAGED) delete process.env[key];
  Object.assign(process.env, env);
}

export function basicAuth(user = BASIC_USER, pass = BASIC_PASS) {
  return `Basic ${Buffer.from(`${user}:${pass}`).toString("base64")}`;
}

/** Headers that pass both auth gates. */
export function authHeaders(extra = {}) {
  return {
    Authorization: basicAuth(),
    "X-Webhook-Secret": WEBHOOK_SECRET,
    ...extra,
  };
}

/**
 * Replace globalThis.fetch with a recorder.
 * Returns { calls, restore }. Each call is { url, options, body }.
 */
export function stubFetch({ ok = true, status = 200, json: jsonBody = { id: 4242 }, text = "" } = {}) {
  const original = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (url, options = {}) => {
    calls.push({
      url: String(url),
      options,
      body: options.body ? JSON.parse(options.body) : null,
    });
    return {
      ok,
      status,
      json: async () => jsonBody,
      text: async () => text,
    };
  };
  return { calls, restore: () => { globalThis.fetch = original; } };
}

/** Silence the handlers' console output for the duration of a test run. */
export function muteConsole() {
  const saved = { log: console.log, warn: console.warn, error: console.error };
  console.log = () => {};
  console.warn = () => {};
  console.error = () => {};
  return () => Object.assign(console, saved);
}

export function parse(response) {
  return JSON.parse(response.body);
}
