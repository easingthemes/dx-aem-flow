/**
 * Redaction engine — strips sensitive data from text and objects.
 * Based on pipeline-policy.yaml denylist patterns.
 */

const DENYLIST = [
  { pattern: /(?:password|secret|token|key|apikey)\s*[:=]\s*["']?([^"'\s,;}\]&]+)/gi, replace: (m, p1) => m.replace(p1, "[REDACTED]") },
  { pattern: /(?:jdbc:|mongodb(?:\+srv)?:\/\/|redis:\/\/|amqp:\/\/)\S+/gi, replace: "[CONNECTION_STRING]" },
  { pattern: /\S+@\S+\.\S+/g, replace: "[EMAIL]" },
  { pattern: /^([A-Z_]+)=(.+)$/gm, replace: "$1=[REDACTED]" },
  { pattern: /([?&](?:token|key|auth|secret))=[^&\s]+/gi, replace: "$1=[REDACTED]" },
  { pattern: /eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, replace: "[JWT]" },
  { pattern: /-----BEGIN (?:RSA |EC )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC )?PRIVATE KEY-----/g, replace: "[PRIVATE_KEY]" },
];

const ALLOWLIST_KEYS = new Set([
  "filePath", "path", "file", "lineStart", "lineEnd", "lineRange",
  "className", "interfaceName", "functionSignature",
  "importStatement", "contentHash", "hash", "promptHash", "configHash", "policyHash",
  "tokenCount", "tokens", "prompt_tokens", "completion_tokens", "total_tokens",
  "latency", "latencyMs", "duration",
  "timestamp", "startTime", "endTime",
  "status", "outcome", "outcomeReason",
  "runId", "eventId", "pipeline", "step",
]);

/**
 * Check if a field name is allowlisted (skip redaction).
 */
export function isAllowlisted(key) {
  return ALLOWLIST_KEYS.has(key);
}

/**
 * Apply all denylist redaction patterns to a string.
 */
export function redact(text) {
  if (typeof text !== "string") return text;
  let result = text;
  for (const rule of DENYLIST) {
    result = result.replace(rule.pattern, rule.replace);
  }
  result = truncateMethodBodies(result);
  return result;
}

/**
 * Deep-clone an object, redacting all string values (unless key is allowlisted).
 * Never mutates the input.
 */
export function redactObject(obj) {
  if (obj === null || obj === undefined) return obj;
  if (typeof obj === "string") return redact(obj);
  if (Array.isArray(obj)) return obj.map((item) => redactObject(item));
  if (typeof obj !== "object") return obj;

  const out = {};
  for (const [key, value] of Object.entries(obj)) {
    if (isAllowlisted(key)) {
      out[key] = value;
    } else if (typeof value === "string") {
      out[key] = redact(value);
    } else if (typeof value === "object") {
      out[key] = redactObject(value);
    } else {
      out[key] = value;
    }
  }
  return out;
}

/**
 * Truncate Java/JS method bodies longer than maxLines.
 * Keeps the first maxLines of each body, appends [TRUNCATED].
 */
function truncateMethodBodies(text, maxLines = 10) {
  // Match blocks: opening { ... closing } at the same or lower indent
  return text.replace(/\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}/g, (match, body) => {
    const lines = body.split("\n");
    if (lines.length <= maxLines) return match;
    const kept = lines.slice(0, maxLines).join("\n");
    return `{${kept}\n  // [TRUNCATED ${lines.length - maxLines} lines]\n}`;
  });
}
