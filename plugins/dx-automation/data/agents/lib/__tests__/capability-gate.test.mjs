import { describe, it, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import { writeFileSync, mkdirSync, rmSync } from "fs";
import { clearPolicyCache, loadPolicy, checkCapability, checkPushPolicy } from "../policy-gate.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const FIXTURE_DIR = resolve(__dirname, "_fixtures");
const FIXTURE_POLICY = resolve(FIXTURE_DIR, "test-policy.yaml");

const TEST_POLICY = `
version: "1.0"
risk_levels:
  low:
    action: "proceed"
  medium:
    action: "reduce_capability"
  high:
    action: "skip_and_alert"
pipelines:
  dor:
    allowed_actions:
      - readWorkItem
      - postComment
    forbidden_actions:
      - pushCode
  pr-review:
    allowed_actions:
      - readPR
      - postThread
      - castVote
    forbidden_actions:
      - pushCode
    vote_policy:
      max_vote: "wait"
      blocker_implies: "wait"
  pr-answer:
    allowed_actions:
      - readPR
      - replyToThread
      - pushCode
    forbidden_actions:
      - castVote
    push_policy:
      requires:
        - thread_category: "agree-will-fix"
        - old_code_unique: true
        - lint_passes: true
        - scanner_risk: "low"
      on_lint_failure: "suggest_only"
      on_scanner_medium: "suggest_only"
      on_scanner_high: "skip_and_alert"
break_glass:
  requires:
    - pr_label: "ai-policy-override"
    - approver_group: "ai-admins"
`;

mkdirSync(FIXTURE_DIR, { recursive: true });
writeFileSync(FIXTURE_POLICY, TEST_POLICY);

describe("capability-gate (via policy-gate)", () => {
  beforeEach(() => {
    clearPolicyCache();
    loadPolicy(FIXTURE_POLICY);
  });

  describe("allowed action gating", () => {
    it("allows replyToThread for pr-answer", () => {
      const result = checkCapability("pr-answer", "replyToThread");
      assert.equal(result.allowed, true);
    });

    it("blocks castVote for pr-answer (forbidden)", () => {
      const result = checkCapability("pr-answer", "castVote");
      assert.equal(result.allowed, false);
      assert.ok(result.reason.includes("forbidden"));
    });
  });

  describe("vote clamping (via vote policy)", () => {
    it("vote policy exists for pr-review", () => {
      const result = checkCapability("pr-review", "castVote");
      assert.equal(result.allowed, true);
    });
  });

  describe("push policy integration", () => {
    it("allows push when all conditions met", () => {
      const result = checkPushPolicy({
        thread_category: "agree-will-fix",
        old_code_unique: true,
        lint_passes: true,
        scanner_risk: "low",
      });
      assert.equal(result.allowed, true);
    });

    it("denies push with suggest_only fallback on lint failure", () => {
      const result = checkPushPolicy({
        thread_category: "agree-will-fix",
        old_code_unique: true,
        lint_passes: false,
        scanner_risk: "low",
      });
      assert.equal(result.allowed, false);
      assert.equal(result.fallback, "suggest_only");
    });

    it("denies push with skip_and_alert on high scanner risk", () => {
      const result = checkPushPolicy({
        thread_category: "agree-will-fix",
        old_code_unique: true,
        lint_passes: true,
        scanner_risk: "high",
      });
      assert.equal(result.allowed, false);
      assert.equal(result.fallback, "skip_and_alert");
    });
  });
});

rmSync(FIXTURE_DIR, { recursive: true, force: true });
