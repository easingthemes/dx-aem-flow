/**
 * Prompt injection scanner — runtime content safety for all 3 pipelines.
 *
 * Primary: Azure Content Safety Prompt Shields (if configured via env vars).
 * Fallback: Local pattern-based detection (zero npm deps).
 *
 * Interface:
 *   scanContent(text, contentType) → { risk, details, scanner, degraded? }
 *   scanInputs(inputs, pipelineName) → { risk, results, details }
 *
 * Fail-open: API errors return { risk: 'low', degraded: true }.
 * Timeout: 5 seconds per scan call.
 */

const TIMEOUT_MS = 5_000;

// ─── Azure Prompt Shields ────────────────────────────────────────────────────

const SHIELDS_ENDPOINT = process.env.AZURE_CONTENT_SAFETY_ENDPOINT;
const SHIELDS_KEY = process.env.AZURE_CONTENT_SAFETY_KEY;
const SHIELDS_API_VERSION = process.env.AZURE_CONTENT_SAFETY_API_VERSION || "2024-09-01";

function isShieldsConfigured() {
  return !!(SHIELDS_ENDPOINT && SHIELDS_KEY);
}

/**
 * Call Azure Prompt Shields API.
 * @param {string} text - Content to scan
 * @param {string} contentType - "user_input" or "document"
 * @returns {Promise<{ risk: string, details: string, scanner: string }>}
 */
async function callPromptShields(text, contentType) {
  const url = `${SHIELDS_ENDPOINT.replace(/\/$/, "")}/contentsafety/text:shieldPrompt?api-version=${SHIELDS_API_VERSION}`;

  // Prompt Shields expects userPrompt for user input, documents for document content
  const body = contentType === "document"
    ? { userPrompt: "", documents: [text] }
    : { userPrompt: text, documents: [] };

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Ocp-Apim-Subscription-Key": SHIELDS_KEY,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });

    clearTimeout(timer);

    if (!res.ok) {
      const errText = await res.text().catch(() => "");
      console.warn(`[Scanner] Prompt Shields HTTP ${res.status}: ${errText.slice(0, 200)}`);
      return { risk: "low", details: `API error: HTTP ${res.status}`, scanner: "prompt-shields", degraded: true };
    }

    const data = await res.json();

    // Prompt Shields response:
    // userPromptAnalysis.attackDetected: boolean
    // documentsAnalysis[0].attackDetected: boolean
    const userAttack = data.userPromptAnalysis?.attackDetected === true;
    const docAttack = (data.documentsAnalysis || []).some((d) => d.attackDetected === true);

    if (userAttack || docAttack) {
      return { risk: "high", details: "Prompt injection detected by Azure Prompt Shields", scanner: "prompt-shields" };
    }

    return { risk: "low", details: "clean", scanner: "prompt-shields" };
  } catch (err) {
    clearTimeout(timer);
    if (err.name === "AbortError") {
      console.warn("[Scanner] Prompt Shields timeout (5s)");
      return { risk: "low", details: "timeout", scanner: "prompt-shields", degraded: true };
    }
    console.warn(`[Scanner] Prompt Shields error: ${err.message}`);
    return { risk: "low", details: `error: ${err.message}`, scanner: "prompt-shields", degraded: true };
  }
}

// ─── Local pattern-based scanner ─────────────────────────────────────────────

/**
 * Prompt injection patterns grouped by severity.
 * High: direct instruction override / role-play injection.
 * Medium: suspicious patterns that could be benign in code context.
 */
const HIGH_PATTERNS = [
  // Direct instruction override
  /ignore\s+(all\s+)?(previous|prior|above|earlier)\s+(instructions|prompts|rules|guidelines)/i,
  /disregard\s+(all\s+)?(previous|prior|above)\s+(instructions|prompts|rules)/i,
  /forget\s+(all\s+)?(previous|prior|your)\s+(instructions|prompts|rules|context)/i,
  // Role-play injection
  /you\s+are\s+now\s+(a|an|the|my)\s+/i,
  /act\s+as\s+(a|an|the|my)\s+/i,
  /pretend\s+(to\s+be|you\s+are)\s+/i,
  /from\s+now\s+on,?\s+you\s+(are|will|should|must)\s+/i,
  // System prompt extraction
  /(?:print|show|reveal|output|display|repeat)\s+(?:your\s+)?(?:system\s+)?(?:prompt|instructions|rules)/i,
  /what\s+(?:are|is)\s+your\s+(?:system\s+)?(?:prompt|instructions|rules)/i,
  // Delimiter-based attacks
  /```\s*system\b/i,
  /<\|(?:system|im_start|im_end)\|>/i,
  /\[INST\]/i,
  /<<\s*SYS\s*>>/i,
  // Direct override
  /new\s+instructions?\s*:/i,
  /override\s+(?:your\s+)?(?:instructions|rules|system)/i,
];

const MEDIUM_PATTERNS = [
  // Indirect manipulation
  /do\s+not\s+follow\s+(the|your|any)\s+(previous|original|initial)\s+/i,
  /instead\s+of\s+(following|doing|your)\s+(the|your|normal|original)\s+/i,
  // Data exfiltration
  /send\s+(?:all\s+)?(?:the\s+)?(?:data|content|information)\s+to\s+/i,
  /(?:curl|wget|fetch)\s+https?:\/\//i,
  // Encoding attacks (base64/hex instructions)
  /base64\s*(?:decode|encoded?).*(?:instruction|prompt|command)/i,
  // Multi-step jailbreak patterns
  /step\s*1\s*:\s*(?:ignore|forget|disregard)/i,
  /first,?\s*(?:ignore|forget|disregard)\s+(?:all|the|your)/i,
];

/**
 * Scan text using local pattern matching.
 * @param {string} text
 * @returns {{ risk: string, details: string, scanner: string }}
 */
function scanWithPatterns(text) {
  if (!text || text.length === 0) {
    return { risk: "low", details: "empty input", scanner: "pattern" };
  }

  // Check high patterns first
  for (const pattern of HIGH_PATTERNS) {
    const match = text.match(pattern);
    if (match) {
      return { risk: "high", details: `pattern match: ${match[0].slice(0, 60)}`, scanner: "pattern" };
    }
  }

  // Check medium patterns
  for (const pattern of MEDIUM_PATTERNS) {
    const match = text.match(pattern);
    if (match) {
      return { risk: "medium", details: `pattern match: ${match[0].slice(0, 60)}`, scanner: "pattern" };
    }
  }

  return { risk: "low", details: "clean", scanner: "pattern" };
}

// ─── Public API ──────────────────────────────────────────────────────────────

/**
 * Scan a single piece of content for prompt injection.
 *
 * @param {string} text - Content to scan
 * @param {string} [contentType="user_input"] - "user_input" or "document"
 * @returns {Promise<{ risk: 'low'|'medium'|'high', details: string, scanner: string, degraded?: boolean }>}
 */
export async function scanContent(text, contentType = "user_input") {
  if (!text || text.length === 0) {
    return { risk: "low", details: "empty input", scanner: "none" };
  }

  // Truncate very large inputs — scanning full file contents is wasteful
  const scanText = text.length > 10_000 ? text.slice(0, 10_000) : text;

  if (isShieldsConfigured()) {
    return callPromptShields(scanText, contentType);
  }

  return scanWithPatterns(scanText);
}

/**
 * Scan multiple inputs and return the highest risk level.
 * Designed for pipeline integration — scan all user-controlled inputs at once.
 *
 * @param {Array<{ text: string, label: string, contentType?: string }>} inputs
 * @param {string} pipelineName - For logging
 * @returns {Promise<{ risk: 'low'|'medium'|'high', results: Array, details: string }>}
 */
export async function scanInputs(inputs, pipelineName) {
  if (!inputs || inputs.length === 0) {
    return { risk: "low", results: [], details: "no inputs to scan" };
  }

  const results = [];
  let maxRisk = "low";
  const riskOrder = { low: 0, medium: 1, high: 2 };

  for (const input of inputs) {
    if (!input.text) {
      results.push({ label: input.label, risk: "low", details: "empty", scanner: "none" });
      continue;
    }

    const result = await scanContent(input.text, input.contentType || "user_input");
    results.push({ label: input.label, ...result });

    if (riskOrder[result.risk] > riskOrder[maxRisk]) {
      maxRisk = result.risk;
    }

    if (result.risk !== "low") {
      console.warn(`[Scanner] ${pipelineName}: ${input.label} flagged as ${result.risk} — ${result.details}`);
    }
  }

  const scanner = isShieldsConfigured() ? "prompt-shields" : "pattern";
  const flagged = results.filter((r) => r.risk !== "low");
  const details = flagged.length
    ? `${flagged.length}/${results.length} inputs flagged (max: ${maxRisk})`
    : `${results.length} inputs scanned — all clean`;

  console.log(`[Scanner] ${pipelineName}: ${details} [${scanner}]`);

  return { risk: maxRisk, results, details };
}
