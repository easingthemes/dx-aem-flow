/**
 * Generic retry with exponential backoff — wraps async operations.
 *
 * Retryable: timeouts, 429 (rate limited), 408 (request timeout), 5xx.
 * Non-retryable: 400, 401, 403, 404, 409 (conflict/dedupe).
 *
 * Usage:
 *   import { withRetry } from "../lib/retry.js";
 *   const result = await withRetry(() => fetch(url), { label: "ADO API" });
 *
 * For fetch specifically:
 *   const res = await fetchWithRetry(url, fetchOptions, { label: "ADO API" });
 */

const DEFAULT_MAX_RETRIES = 2;
const DEFAULT_BASE_DELAY_MS = 1_000;
const DEFAULT_MAX_DELAY_MS = 10_000;

const RETRYABLE_STATUS = new Set([408, 429, 500, 502, 503, 504]);

/**
 * Check if an HTTP status code is retryable.
 * @param {number} status
 * @returns {boolean}
 */
export function isRetryableStatus(status) {
  return RETRYABLE_STATUS.has(status);
}

/**
 * Check if an error is retryable (network/timeout errors).
 * @param {Error} err
 * @returns {boolean}
 */
export function isRetryableError(err) {
  if (err.name === "AbortError") return true; // timeout
  if (err.code === "ECONNRESET" || err.code === "ECONNREFUSED") return true;
  if (err.code === "ETIMEDOUT" || err.code === "ESOCKETTIMEDOUT") return true;
  if (err.message?.includes("fetch failed")) return true;
  return false;
}

/**
 * Calculate delay with exponential backoff + jitter.
 * Respects Retry-After header if provided.
 *
 * @param {number} attempt - 0-based attempt number
 * @param {number} baseDelay
 * @param {number} maxDelay
 * @param {number} [retryAfterMs] - from Retry-After header
 * @returns {number} delay in ms
 */
function calcDelay(attempt, baseDelay, maxDelay, retryAfterMs) {
  if (retryAfterMs && retryAfterMs > 0) {
    return Math.min(retryAfterMs, maxDelay);
  }
  const exp = baseDelay * Math.pow(2, attempt);
  const jitter = Math.random() * baseDelay * 0.5;
  return Math.min(exp + jitter, maxDelay);
}

/**
 * Parse Retry-After header value to milliseconds.
 * @param {string|null} value - header value (seconds or HTTP date)
 * @returns {number|null} delay in ms, or null
 */
function parseRetryAfter(value) {
  if (!value) return null;
  const secs = Number(value);
  if (!isNaN(secs)) return secs * 1_000;
  const date = Date.parse(value);
  if (!isNaN(date)) return Math.max(0, date - Date.now());
  return null;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Retry an async operation with exponential backoff.
 *
 * @param {() => Promise<any>} fn - async function to retry
 * @param {object} [opts]
 * @param {string} [opts.label] - for logging
 * @param {number} [opts.maxRetries=2]
 * @param {number} [opts.baseDelay=1000]
 * @param {number} [opts.maxDelay=10000]
 * @returns {Promise<any>} result of fn()
 */
export async function withRetry(fn, opts = {}) {
  const { label = "operation", maxRetries = DEFAULT_MAX_RETRIES, baseDelay = DEFAULT_BASE_DELAY_MS, maxDelay = DEFAULT_MAX_DELAY_MS } = opts;

  let lastErr;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;

      if (attempt >= maxRetries) break;

      if (!isRetryableError(err)) {
        // Check if it's a fetch response error with status
        const status = err.status || err.statusCode;
        if (status && !isRetryableStatus(status)) break;
        if (!status) break; // unknown error type — don't retry
      }

      const delay = calcDelay(attempt, baseDelay, maxDelay);
      console.warn(`[Retry] ${label}: attempt ${attempt + 1}/${maxRetries + 1} failed (${err.message}), retrying in ${Math.round(delay)}ms`);
      await sleep(delay);
    }
  }
  throw lastErr;
}

/**
 * Fetch with automatic retry on transient errors.
 * Checks HTTP status and retries on retryable status codes.
 *
 * @param {string} url
 * @param {RequestInit} fetchOpts
 * @param {object} [retryOpts]
 * @param {string} [retryOpts.label]
 * @param {number} [retryOpts.maxRetries=2]
 * @param {number} [retryOpts.baseDelay=1000]
 * @param {number} [retryOpts.maxDelay=10000]
 * @returns {Promise<Response>} fetch Response object
 */
export async function fetchWithRetry(url, fetchOpts = {}, retryOpts = {}) {
  const { label = "fetch", maxRetries = DEFAULT_MAX_RETRIES, baseDelay = DEFAULT_BASE_DELAY_MS, maxDelay = DEFAULT_MAX_DELAY_MS } = retryOpts;

  let lastRes;
  let lastErr;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const res = await fetch(url, fetchOpts);
      lastRes = res;

      if (res.ok || !isRetryableStatus(res.status)) {
        return res; // success or non-retryable error — return as-is
      }

      // Retryable HTTP status
      if (attempt >= maxRetries) return res;

      const retryAfterMs = parseRetryAfter(res.headers?.get?.("Retry-After"));
      const delay = calcDelay(attempt, baseDelay, maxDelay, retryAfterMs);
      console.warn(`[Retry] ${label}: HTTP ${res.status}, retrying in ${Math.round(delay)}ms (${attempt + 1}/${maxRetries + 1})`);
      await sleep(delay);
    } catch (err) {
      lastErr = err;

      if (attempt >= maxRetries) throw err;

      if (!isRetryableError(err)) throw err;

      const delay = calcDelay(attempt, baseDelay, maxDelay);
      console.warn(`[Retry] ${label}: ${err.message}, retrying in ${Math.round(delay)}ms (${attempt + 1}/${maxRetries + 1})`);
      await sleep(delay);
    }
  }

  if (lastRes) return lastRes;
  throw lastErr;
}
