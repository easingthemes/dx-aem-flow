/**
 * AWS SigV4 signing + DynamoDB / SQS / S3 helpers.
 * Zero dependencies — uses only Node.js crypto + fetch.
 *
 * Auth credentials come from standard AWS env vars:
 *   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN (optional)
 *   AWS_REGION (defaults to us-east-1)
 */

import crypto from "crypto";
import { fetchWithRetry } from "./retry.js";

// ---------------------------------------------------------------------------
// Credentials
// ---------------------------------------------------------------------------

export function getAwsCredentials() {
  const accessKeyId = process.env.AWS_ACCESS_KEY_ID;
  const secretAccessKey = process.env.AWS_SECRET_ACCESS_KEY;
  const sessionToken = process.env.AWS_SESSION_TOKEN; // optional (Lambda sets this)
  if (!accessKeyId || !secretAccessKey) return null;
  return { accessKeyId, secretAccessKey, sessionToken };
}

export function getAwsRegion() {
  return process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || "us-east-1";
}

// ---------------------------------------------------------------------------
// SigV4 core
// ---------------------------------------------------------------------------

function hmac(key, data) {
  return crypto.createHmac("sha256", key).update(data, "utf8").digest();
}

function sha256(data) {
  return crypto.createHash("sha256").update(data, "utf8").digest("hex");
}

function getSigningKey(secretKey, dateStamp, region, service) {
  const kDate = hmac(`AWS4${secretKey}`, dateStamp);
  const kRegion = hmac(kDate, region);
  const kService = hmac(kRegion, service);
  return hmac(kService, "aws4_request");
}

/**
 * Sign an AWS request using SigV4.
 * Mutates and returns the headers object with Authorization, x-amz-date,
 * and optionally x-amz-security-token.
 */
export function signRequest(method, url, headers, body, service, region, credentials) {
  const parsedUrl = new URL(url);
  const host = parsedUrl.host;
  const path = parsedUrl.pathname + parsedUrl.search;

  const now = new Date();
  const amzDate = now.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
  const dateStamp = amzDate.slice(0, 8);

  headers["host"] = host;
  headers["x-amz-date"] = amzDate;
  if (credentials.sessionToken) {
    headers["x-amz-security-token"] = credentials.sessionToken;
  }

  // Canonical headers: sorted lowercase header names
  const signedHeaderKeys = Object.keys(headers)
    .map((k) => k.toLowerCase())
    .sort();
  const canonicalHeaders = signedHeaderKeys
    .map((k) => `${k}:${headers[Object.keys(headers).find((h) => h.toLowerCase() === k)].trim()}`)
    .join("\n") + "\n";
  const signedHeaders = signedHeaderKeys.join(";");

  const payloadHash = sha256(body || "");

  const canonicalRequest = [
    method,
    parsedUrl.pathname,
    parsedUrl.search.slice(1), // query string without ?
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join("\n");

  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    credentialScope,
    sha256(canonicalRequest),
  ].join("\n");

  const signingKey = getSigningKey(credentials.secretAccessKey, dateStamp, region, service);
  const signature = crypto.createHmac("sha256", signingKey).update(stringToSign, "utf8").digest("hex");

  headers["Authorization"] = `AWS4-HMAC-SHA256 Credential=${credentials.accessKeyId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  return headers;
}

// ---------------------------------------------------------------------------
// DynamoDB helpers
// ---------------------------------------------------------------------------

function dynamoEndpoint(region) {
  return `https://dynamodb.${region}.amazonaws.com`;
}

async function dynamoRequest(target, payload, region, credentials, retryOpts = {}) {
  const url = dynamoEndpoint(region);
  const body = JSON.stringify(payload);
  const headers = {
    "Content-Type": "application/x-amz-json-1.0",
    "X-Amz-Target": `DynamoDB_20120810.${target}`,
  };

  signRequest("POST", url, headers, body, "dynamodb", region, credentials);

  const res = await fetchWithRetry(url, {
    method: "POST",
    headers,
    body,
  }, { label: `DynamoDB ${target}`, maxRetries: 1, ...retryOpts });

  return res;
}

/**
 * DynamoDB PutItem with optional condition expression.
 * Returns { ok: true } or throws with __type for conditional check failures.
 */
export async function dynamoPut(tableName, item, conditionExpression, region, credentials) {
  const payload = { TableName: tableName, Item: item };
  if (conditionExpression) payload.ConditionExpression = conditionExpression;

  const res = await dynamoRequest("PutItem", payload, region, credentials);

  if (!res.ok) {
    const errBody = await res.json().catch(() => ({}));
    const err = new Error(errBody.message || errBody.Message || `PutItem failed (${res.status})`);
    err.__type = errBody.__type || "";
    err.status = res.status;
    throw err;
  }

  return { ok: true };
}

/**
 * DynamoDB GetItem. Returns the item attributes or null if not found.
 */
export async function dynamoGet(tableName, key, region, credentials) {
  const res = await dynamoRequest("GetItem", { TableName: tableName, Key: key }, region, credentials);

  if (!res.ok) {
    const errBody = await res.json().catch(() => ({}));
    throw new Error(errBody.message || errBody.Message || `GetItem failed (${res.status})`);
  }

  const data = await res.json();
  return data.Item || null;
}

/**
 * DynamoDB UpdateItem with update expression.
 * Returns updated attributes (ReturnValues=ALL_NEW).
 */
export async function dynamoUpdate(tableName, key, updateExpression, expressionAttrValues, region, credentials, expressionAttrNames) {
  const payload = {
    TableName: tableName,
    Key: key,
    UpdateExpression: updateExpression,
    ExpressionAttributeValues: expressionAttrValues,
    ReturnValues: "ALL_NEW",
  };
  if (expressionAttrNames) payload.ExpressionAttributeNames = expressionAttrNames;

  const res = await dynamoRequest("UpdateItem", payload, region, credentials);

  if (!res.ok) {
    const errBody = await res.json().catch(() => ({}));
    throw new Error(errBody.message || errBody.Message || `UpdateItem failed (${res.status})`);
  }

  const data = await res.json();
  return data.Attributes || {};
}

// ---------------------------------------------------------------------------
// SQS helpers
// ---------------------------------------------------------------------------

/**
 * Send a message to an SQS queue.
 */
export async function sqsSend(queueUrl, messageBody, region, credentials) {
  const body = JSON.stringify({
    QueueUrl: queueUrl,
    MessageBody: typeof messageBody === "string" ? messageBody : JSON.stringify(messageBody),
  });
  const headers = {
    "Content-Type": "application/x-amz-json-1.0",
    "X-Amz-Target": "AmazonSQS.SendMessage",
  };

  // SQS endpoint derived from queue URL region
  const url = `https://sqs.${region}.amazonaws.com`;
  signRequest("POST", url, headers, body, "sqs", region, credentials);

  const res = await fetchWithRetry(url, {
    method: "POST",
    headers,
    body,
  }, { label: "SQS SendMessage", maxRetries: 1 });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`SQS SendMessage failed (${res.status}): ${text.slice(0, 200)}`);
  }

  return { ok: true };
}

/**
 * Receive messages from an SQS queue.
 * @param {string} queueUrl - Full SQS queue URL
 * @param {number} [maxMessages=10] - Max messages to receive (1-10)
 * @param {number} [waitTimeSeconds=0] - Long poll wait (0 = short poll)
 */
export async function sqsReceive(queueUrl, maxMessages = 10, waitTimeSeconds = 0, region, credentials) {
  const body = JSON.stringify({
    QueueUrl: queueUrl,
    MaxNumberOfMessages: Math.min(maxMessages, 10),
    WaitTimeSeconds: waitTimeSeconds,
  });
  const headers = {
    "Content-Type": "application/x-amz-json-1.0",
    "X-Amz-Target": "AmazonSQS.ReceiveMessage",
  };
  const url = `https://sqs.${region}.amazonaws.com`;
  signRequest("POST", url, headers, body, "sqs", region, credentials);

  const res = await fetchWithRetry(url, { method: "POST", headers, body }, { label: "SQS ReceiveMessage", maxRetries: 1 });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`SQS ReceiveMessage failed (${res.status}): ${text.slice(0, 200)}`);
  }
  const data = await res.json();
  return data.Messages || [];
}

/**
 * Delete a message from an SQS queue.
 * @param {string} queueUrl - Full SQS queue URL
 * @param {string} receiptHandle - Receipt handle from ReceiveMessage
 */
export async function sqsDelete(queueUrl, receiptHandle, region, credentials) {
  const body = JSON.stringify({
    QueueUrl: queueUrl,
    ReceiptHandle: receiptHandle,
  });
  const headers = {
    "Content-Type": "application/x-amz-json-1.0",
    "X-Amz-Target": "AmazonSQS.DeleteMessage",
  };
  const url = `https://sqs.${region}.amazonaws.com`;
  signRequest("POST", url, headers, body, "sqs", region, credentials);

  const res = await fetchWithRetry(url, { method: "POST", headers, body }, { label: "SQS DeleteMessage", maxRetries: 1 });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`SQS DeleteMessage failed (${res.status}): ${text.slice(0, 200)}`);
  }
  return { ok: true };
}

/**
 * Get queue attributes (e.g. ApproximateNumberOfMessages).
 * @param {string} queueUrl - Full SQS queue URL
 * @param {string[]} [attributeNames] - Attributes to fetch (default: All)
 */
export async function sqsGetQueueAttributes(queueUrl, attributeNames, region, credentials) {
  const body = JSON.stringify({
    QueueUrl: queueUrl,
    AttributeNames: attributeNames || ["All"],
  });
  const headers = {
    "Content-Type": "application/x-amz-json-1.0",
    "X-Amz-Target": "AmazonSQS.GetQueueAttributes",
  };
  const url = `https://sqs.${region}.amazonaws.com`;
  signRequest("POST", url, headers, body, "sqs", region, credentials);

  const res = await fetchWithRetry(url, { method: "POST", headers, body }, { label: "SQS GetQueueAttributes", maxRetries: 1 });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`SQS GetQueueAttributes failed (${res.status}): ${text.slice(0, 200)}`);
  }
  const data = await res.json();
  return data.Attributes || {};
}

// ---------------------------------------------------------------------------
// DynamoDB scan helper
// ---------------------------------------------------------------------------

/**
 * DynamoDB Scan — returns all items (or filtered).
 * Use sparingly; Scan reads every item in the table.
 *
 * @param {string} tableName
 * @param {object} [opts] - Optional filter: { filterExpression, expressionAttrValues, expressionAttrNames, limit }
 */
export async function dynamoScan(tableName, opts = {}, region, credentials) {
  const payload = { TableName: tableName };
  if (opts.filterExpression) payload.FilterExpression = opts.filterExpression;
  if (opts.expressionAttrValues) payload.ExpressionAttributeValues = opts.expressionAttrValues;
  if (opts.expressionAttrNames) payload.ExpressionAttributeNames = opts.expressionAttrNames;
  if (opts.limit) payload.Limit = opts.limit;

  const items = [];
  let lastKey = undefined;

  do {
    if (lastKey) payload.ExclusiveStartKey = lastKey;
    const res = await dynamoRequest("Scan", payload, region, credentials, { maxRetries: 1 });
    if (!res.ok) {
      const errBody = await res.json().catch(() => ({}));
      throw new Error(errBody.message || errBody.Message || `Scan failed (${res.status})`);
    }
    const data = await res.json();
    items.push(...(data.Items || []));
    lastKey = data.LastEvaluatedKey;
  } while (lastKey);

  return items;
}

// ---------------------------------------------------------------------------
// S3 helpers
// ---------------------------------------------------------------------------

/**
 * Upload a file to S3 using PutObject.
 */
export async function s3Put(bucket, key, content, contentType, region, credentials) {
  const url = `https://${bucket}.s3.${region}.amazonaws.com/${encodeURIComponent(key).replace(/%2F/g, "/")}`;
  const bodyBuf = typeof content === "string" ? Buffer.from(content) : content;
  const headers = {
    "Content-Type": contentType || "application/octet-stream",
    "Content-Length": String(bodyBuf.length),
  };

  signRequest("PUT", url, headers, bodyBuf, "s3", region, credentials);

  const res = await fetchWithRetry(url, {
    method: "PUT",
    headers,
    body: bodyBuf,
  }, { label: "S3 PutObject", maxRetries: 1 });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`S3 PutObject failed (${res.status}): ${text.slice(0, 200)}`);
  }

  return { ok: true };
}
