/**
 * Policy gate — enforces pipeline-policy.yaml at runtime.
 * Capabilities are checked before every ADO write operation.
 *
 * Fail-open: if policy file cannot be loaded, allows all actions
 * with a critical warning. This prevents policy file issues from
 * breaking working pipelines.
 *
 * Zero npm dependencies — uses a minimal YAML parser for the subset
 * of YAML used in pipeline-policy.yaml.
 */
import { readFileSync, existsSync } from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const POLICY_PATH = path.resolve(__dirname, "../../../../.ai/automation/policy/pipeline-policy.yaml");

let cachedPolicy = null;

// ─── Minimal YAML parser ────────────────────────────────────────────────────
// Handles: mappings, sequences, nested structures, comments, quoted strings.
// Does NOT handle: multi-line strings, anchors/aliases, tags, flow style.

function parseScalar(s) {
  if (!s) return "";
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
    return s.slice(1, -1);
  }
  if (s === "true") return true;
  if (s === "false") return false;
  if (s === "null" || s === "~") return null;
  if (/^-?\d+(\.\d+)?$/.test(s)) return Number(s);
  return s;
}

function stripInlineComment(line) {
  let inQuote = false;
  let quoteChar = "";
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (inQuote) {
      if (ch === quoteChar) inQuote = false;
    } else if (ch === '"' || ch === "'") {
      inQuote = true;
      quoteChar = ch;
    } else if (ch === "#" && i > 0 && line[i - 1] === " ") {
      return line.slice(0, i).trimEnd();
    }
  }
  return line;
}

function prepareLines(text) {
  const result = [];
  for (const raw of text.split("\n")) {
    const stripped = stripInlineComment(raw);
    const trimmed = stripped.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    result.push({ indent: stripped.search(/\S/), text: trimmed });
  }
  return result;
}

function parseMapping(lines, start, minIndent) {
  const obj = {};
  let i = start;
  while (i < lines.length) {
    const { indent, text } = lines[i];
    if (indent !== minIndent) break;
    if (text.startsWith("- ")) break;
    const colonIdx = text.indexOf(":");
    if (colonIdx < 0) { i++; continue; }
    const key = text.slice(0, colonIdx).trim();
    const rawValue = text.slice(colonIdx + 1).trim();
    if (rawValue) {
      obj[key] = parseScalar(rawValue);
      i++;
    } else {
      i++;
      if (i < lines.length && lines[i].indent > indent) {
        const childIndent = lines[i].indent;
        const { value, nextIndex } = parseBlock(lines, i, childIndent);
        obj[key] = value;
        i = nextIndex;
      } else {
        obj[key] = null;
      }
    }
  }
  return { value: obj, nextIndex: i };
}

function parseSequence(lines, start, minIndent) {
  const arr = [];
  let i = start;
  while (i < lines.length) {
    const { indent, text } = lines[i];
    if (indent < minIndent) break;
    if (!text.startsWith("- ")) break;
    const content = text.slice(2).trim();
    if (!content) {
      // Bare "- " with nested block
      i++;
      if (i < lines.length && lines[i].indent > indent) {
        const { value, nextIndex } = parseBlock(lines, i, lines[i].indent);
        arr.push(value);
        i = nextIndex;
      }
    } else {
      const colonIdx = content.indexOf(":");
      if (colonIdx > 0 && colonIdx < content.length - 1) {
        // - key: value (possibly multi-key item with continuation lines)
        const key = content.slice(0, colonIdx).trim();
        const val = content.slice(colonIdx + 1).trim();
        const itemObj = {};
        itemObj[key] = parseScalar(val);
        i++;
        // Consume continuation lines (same list item, higher indent, not a new "- ")
        while (i < lines.length && lines[i].indent > indent && !lines[i].text.startsWith("- ")) {
          const sub = lines[i];
          const subColon = sub.text.indexOf(":");
          if (subColon > 0) {
            const subKey = sub.text.slice(0, subColon).trim();
            const subVal = sub.text.slice(subColon + 1).trim();
            if (subVal) {
              itemObj[subKey] = parseScalar(subVal);
            }
          }
          i++;
        }
        arr.push(itemObj);
      } else if (colonIdx === content.length - 1) {
        // - key: (nested block follows)
        const key = content.slice(0, colonIdx).trim();
        const itemObj = {};
        i++;
        if (i < lines.length && lines[i].indent > indent) {
          const { value, nextIndex } = parseBlock(lines, i, lines[i].indent);
          itemObj[key] = value;
          i = nextIndex;
        } else {
          itemObj[key] = null;
        }
        arr.push(itemObj);
      } else {
        // - scalar
        arr.push(parseScalar(content));
        i++;
      }
    }
  }
  return { value: arr, nextIndex: i };
}

function parseBlock(lines, start, minIndent) {
  if (start >= lines.length) return { value: {}, nextIndex: start };
  if (lines[start].text.startsWith("- ")) {
    return parseSequence(lines, start, minIndent);
  }
  return parseMapping(lines, start, minIndent);
}

function parseYaml(text) {
  const lines = prepareLines(text);
  if (lines.length === 0) return {};
  const { value } = parseBlock(lines, 0, lines[0].indent);
  return value;
}

// ─── Policy loading ─────────────────────────────────────────────────────────

/**
 * Load and parse pipeline-policy.yaml. Caches in memory.
 * @param {string} [customPath] - Override path (for testing)
 * @returns {object|null} Parsed policy, or null on error (fail-open)
 */
export function loadPolicy(customPath) {
  if (cachedPolicy) return cachedPolicy;

  const policyPath = customPath || POLICY_PATH;

  if (!existsSync(policyPath)) {
    console.error(`[PolicyGate] CRITICAL: Policy file not found: ${policyPath} — fail-open`);
    return null;
  }

  try {
    const text = readFileSync(policyPath, "utf8");
    cachedPolicy = parseYaml(text);
    console.log(`[PolicyGate] Loaded policy v${cachedPolicy.version || "unknown"}`);
    return cachedPolicy;
  } catch (err) {
    console.error(`[PolicyGate] CRITICAL: Failed to parse policy: ${err.message} — fail-open`);
    return null;
  }
}

/**
 * Clear cached policy (for testing or hot-reload).
 */
export function clearPolicyCache() {
  cachedPolicy = null;
}

// ─── Capability check ───────────────────────────────────────────────────────

/**
 * Check if an action is allowed for a pipeline.
 * Fail-closed for unknown actions (not in allowlist).
 * Fail-open if policy cannot be loaded.
 *
 * @param {string} pipelineName - "dor", "pr-review", or "pr-answer"
 * @param {string} actionName - e.g. "postComment", "pushCode", "castVote"
 * @returns {{ allowed: boolean, reason?: string, degraded?: boolean }}
 */
export function checkCapability(pipelineName, actionName) {
  const policy = loadPolicy();

  if (!policy) {
    return { allowed: true, reason: "policy not loaded (fail-open)", degraded: true };
  }

  const pipeline = policy.pipelines?.[pipelineName];
  if (!pipeline) {
    return { allowed: false, reason: `unknown pipeline: ${pipelineName}` };
  }

  const forbidden = pipeline.forbidden_actions || [];
  if (forbidden.some((f) => normalize(f) === actionName)) {
    return { allowed: false, reason: `action '${actionName}' is forbidden for ${pipelineName}` };
  }

  const allowed = pipeline.allowed_actions || [];
  if (allowed.some((a) => normalize(a) === actionName)) {
    return { allowed: true };
  }

  // Fail-closed: action not in allowlist
  return { allowed: false, reason: `action '${actionName}' not in allowlist for ${pipelineName}` };
}

/** Strip annotations like "(gated)" from action names. */
function normalize(action) {
  return typeof action === "string" ? action.replace(/\s*\(.*\)/, "").trim() : action;
}

// ─── Risk level check ───────────────────────────────────────────────────────

/**
 * Determine what action to take based on scanner risk level.
 *
 * @param {string} pipelineName - "dor", "pr-review", or "pr-answer"
 * @param {string} riskLevel - "low", "medium", or "high"
 * @returns {{ action: string, degraded?: boolean }}
 *   action: "proceed" | "reduce_capability" | "suggest_only" | "skip_and_alert"
 */
export function checkRiskLevel(pipelineName, riskLevel) {
  const policy = loadPolicy();

  if (!policy) {
    return { action: "proceed", degraded: true };
  }

  // Pipeline-specific overrides take precedence
  const overrides = policy.pipelines?.[pipelineName]?.risk_overrides || {};
  if (overrides[riskLevel]) {
    return { action: String(overrides[riskLevel]) };
  }

  // Global risk level defaults
  const globalLevel = policy.risk_levels?.[riskLevel];
  if (globalLevel?.action) {
    return { action: String(globalLevel.action) };
  }

  // Unknown risk level — fail-safe
  return { action: "skip_and_alert" };
}

// ─── Push policy check ──────────────────────────────────────────────────────

/**
 * Check push policy conditions for PR Answer pipeline.
 * All conditions from pipeline-policy.yaml must pass for push to be allowed.
 *
 * @param {object} context - Evaluated condition values
 * @param {string} context.thread_category - e.g. "agree-will-fix"
 * @param {boolean} context.old_code_unique - whether old code appears exactly once
 * @param {boolean} context.lint_passes - whether lint check passed
 * @param {string} context.scanner_risk - "low", "medium", or "high"
 * @returns {{ allowed: boolean, fallback?: string, conditions: Array, degraded?: boolean }}
 */
export function checkPushPolicy(context) {
  const policy = loadPolicy();

  if (!policy) {
    return { allowed: true, fallback: null, conditions: [], degraded: true };
  }

  const pushPolicy = policy.pipelines?.["pr-answer"]?.push_policy;
  if (!pushPolicy) {
    return { allowed: true, fallback: null, conditions: [] };
  }

  const requires = pushPolicy.requires || [];
  const conditions = [];

  for (const req of requires) {
    const entries = Object.entries(req);
    if (entries.length === 0) continue;
    const [name, expected] = entries[0];
    const actual = context[name];
    const pass = String(actual) === String(expected);
    conditions.push({ name, pass, expected, actual });
  }

  const allPass = conditions.every((c) => c.pass);
  if (allPass) {
    return { allowed: true, fallback: null, conditions };
  }

  // Determine fallback based on which condition failed
  let fallback = "suggest_only";

  const scannerFailed = conditions.find((c) => c.name === "scanner_risk" && !c.pass);
  if (scannerFailed) {
    if (context.scanner_risk === "high") {
      fallback = String(pushPolicy.on_scanner_high || "skip_and_alert");
    } else if (context.scanner_risk === "medium") {
      fallback = String(pushPolicy.on_scanner_medium || "suggest_only");
    }
  }

  const lintFailed = conditions.find((c) => c.name === "lint_passes" && !c.pass);
  if (lintFailed && !scannerFailed) {
    fallback = String(pushPolicy.on_lint_failure || "suggest_only");
  }

  return { allowed: false, fallback, conditions };
}

// ─── Break-glass override ────────────────────────────────────────────────────

/**
 * Check if break-glass override is active for a given run.
 * Break-glass relaxes risk-level gating but NEVER bypasses:
 *   - Capability allowlist (can't grant forbidden actions)
 *   - Idempotency checks
 *   - Branch protection rules
 *   - Rate limits and token budget caps
 *
 * @param {string[]} prLabels - Labels on the PR (e.g. from ADO)
 * @param {string[]} approverIdentities - Identities of people who approved
 * @returns {{ active: boolean, reason?: string }}
 */
export function checkBreakGlass(prLabels = [], approverIdentities = []) {
  const policy = loadPolicy();

  if (!policy || !policy.break_glass) {
    return { active: false, reason: "no break_glass policy defined" };
  }

  const bg = policy.break_glass;
  const requires = bg.requires || [];

  // Check all requirements
  const labelReq = requires.find((r) => r.pr_label);
  const approverReq = requires.find((r) => r.approver_group);

  const hasLabel = labelReq
    ? prLabels.some((l) => l.toLowerCase() === String(labelReq.pr_label).toLowerCase())
    : true;

  const hasApprover = approverReq
    ? approverIdentities.some((id) => id.toLowerCase().includes(String(approverReq.approver_group).toLowerCase()))
    : true;

  if (hasLabel && hasApprover) {
    return { active: true };
  }

  const missing = [];
  if (!hasLabel) missing.push(`label "${labelReq.pr_label}"`);
  if (!hasApprover) missing.push(`approver from "${approverReq.approver_group}"`);
  return { active: false, reason: `missing: ${missing.join(", ")}` };
}

// ─── Vote policy ────────────────────────────────────────────────────────────

/**
 * Get vote policy for a pipeline.
 * @param {string} pipelineName
 * @returns {{ max_vote?: string, blocker_implies?: string } | null}
 */
export function getVotePolicy(pipelineName) {
  const policy = loadPolicy();
  if (!policy) return null;
  return policy.pipelines?.[pipelineName]?.vote_policy || null;
}
