/**
 * Tier 1 eval gates — 7 deterministic structural checks.
 * Each gate: (output, expected, actions?) => { pass, gate, detail }
 */

/**
 * Flatten all string values from an object into a single searchable string.
 */
function flattenText(obj) {
  if (!obj) return "";
  if (typeof obj === "string") return obj;
  if (Array.isArray(obj)) return obj.map(flattenText).join(" ");
  if (typeof obj === "object") return Object.values(obj).map(flattenText).join(" ");
  return String(obj);
}

const SCHEMAS = {
  "dor-check-v1": {
    required: ["checklist"],
    arrays: ["checklist", "missing", "questions"],
  },
  "pr-review-v1": {
    required: ["findings"],
    arrays: ["findings"],
  },
  "pr-answer-v1": {
    required: ["answers"],
    arrays: ["answers"],
  },
};

export const gates = [
  {
    name: "json-schema-valid",
    check: (output, expected) => {
      const schema = SCHEMAS[expected.schema];
      if (!schema) {
        return { pass: true, gate: "json-schema-valid", detail: `Unknown schema "${expected.schema}" — skipped` };
      }
      for (const key of schema.required) {
        if (!(key in output)) {
          return { pass: false, gate: "json-schema-valid", detail: `Missing required field: "${key}"` };
        }
      }
      for (const key of schema.arrays) {
        if (key in output && !Array.isArray(output[key])) {
          return { pass: false, gate: "json-schema-valid", detail: `"${key}" must be an array` };
        }
      }
      return { pass: true, gate: "json-schema-valid", detail: "Schema valid" };
    },
  },

  {
    name: "no-forbidden-actions",
    check: (output, expected, actions) => {
      const ALLOWED = new Set([
        "post_comment", "update_comment",
        "post_review", "post_thread", "reply_thread",
        "vote", "push_commit",
        "post_dor_check", "post_impl_plan",
        "post_review_threads_and_vote",
        "post_replies", "apply_fix_and_push",
      ]);
      if (!actions || !actions.length) {
        return { pass: true, gate: "no-forbidden-actions", detail: "No actions recorded" };
      }
      const forbidden = actions.filter((a) => a.planned && !ALLOWED.has(a.planned));
      if (forbidden.length) {
        return { pass: false, gate: "no-forbidden-actions", detail: `Forbidden actions: ${forbidden.map((a) => a.planned).join(", ")}` };
      }
      return { pass: true, gate: "no-forbidden-actions", detail: "All actions allowed" };
    },
  },

  {
    name: "max-findings-cap",
    check: (output, expected) => {
      const max = expected.max_findings;
      if (max === undefined || max === null) {
        return { pass: true, gate: "max-findings-cap", detail: "No cap defined — skipped" };
      }
      const count =
        (output.checklist || []).length +
        (output.missing || []).length +
        (output.findings || []).length +
        (output.answers || []).length;
      if (count > max) {
        return { pass: false, gate: "max-findings-cap", detail: `${count} items exceeds cap of ${max}` };
      }
      return { pass: true, gate: "max-findings-cap", detail: `${count} <= ${max}` };
    },
  },

  {
    name: "source-citations-present",
    check: (output, expected) => {
      const findings = output.findings || [];
      if (!findings.length) {
        return { pass: true, gate: "source-citations-present", detail: "No findings to check" };
      }
      const missing = findings.filter((f) => f.filePath || f.path || f.file ? !(f.lineStart || f.line || f.lineRange) : false);
      if (missing.length) {
        return { pass: false, gate: "source-citations-present", detail: `${missing.length} finding(s) reference files without line numbers` };
      }
      return { pass: true, gate: "source-citations-present", detail: "All file references have line numbers" };
    },
  },

  {
    name: "must-find",
    check: (output, expected) => {
      const mustFind = expected.must_find || [];
      if (!mustFind.length) {
        return { pass: true, gate: "must-find", detail: "No must_find assertions" };
      }
      const text = flattenText(output).toLowerCase();
      const missing = mustFind.filter((term) => !text.includes(term.toLowerCase()));
      if (missing.length) {
        return { pass: false, gate: "must-find", detail: `Missing: ${missing.join(", ")}` };
      }
      return { pass: true, gate: "must-find", detail: `All ${mustFind.length} terms found` };
    },
  },

  {
    name: "must-not-find",
    check: (output, expected) => {
      const mustNotFind = expected.must_not_find || [];
      if (!mustNotFind.length) {
        return { pass: true, gate: "must-not-find", detail: "No must_not_find assertions" };
      }
      const text = flattenText(output).toLowerCase();
      const found = mustNotFind.filter((term) => text.includes(term.toLowerCase()));
      if (found.length) {
        return { pass: false, gate: "must-not-find", detail: `Found forbidden: ${found.join(", ")}` };
      }
      return { pass: true, gate: "must-not-find", detail: `None of ${mustNotFind.length} forbidden terms found` };
    },
  },

  {
    name: "vote-consistency",
    check: (output, expected) => {
      // Only applies to PR Review
      if (expected.schema !== "pr-review-v1") {
        return { pass: true, gate: "vote-consistency", detail: "Not a PR review — skipped" };
      }
      const findings = output.findings || [];
      const hasBlocker = findings.some((f) =>
        (f.severity || "").toLowerCase() === "blocker" ||
        (f.severity || "").toLowerCase() === "critical",
      );
      const vote = output.suggestedVote || output.vote;
      if (hasBlocker && vote === "approve") {
        return { pass: false, gate: "vote-consistency", detail: "Has blocker/critical findings but vote is approve" };
      }
      return { pass: true, gate: "vote-consistency", detail: hasBlocker ? `Blocker found, vote: ${vote}` : "No blockers" };
    },
  },
];

/**
 * Run all gates against an output.
 * @param {object} output - LLM output (or baseline)
 * @param {object} expected - expected-output.json contents
 * @param {Array} [actions] - decision journal entries (optional)
 * @returns {{ results: Array, overall: string, failed: Array }}
 */
export function runAllGates(output, expected, actions) {
  const results = gates.map((g) => g.check(output, expected, actions));
  return {
    results,
    overall: results.every((r) => r.pass) ? "pass" : "fail",
    failed: results.filter((r) => !r.pass),
  };
}
