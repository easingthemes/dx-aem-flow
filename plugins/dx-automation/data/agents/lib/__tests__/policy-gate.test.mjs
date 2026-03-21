import { describe, it, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import { writeFileSync, mkdirSync, rmSync } from "fs";
import {
  loadPolicy,
  clearPolicyCache,
  checkCapability,
  checkRiskLevel,
  checkPushPolicy,
  checkBreakGlass,
} from "../policy-gate.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const FIXTURE_DIR = resolve(__dirname, "_fixtures");
const FIXTURE_POLICY = resolve(FIXTURE_DIR, "test-policy.yaml");

// Minimal policy YAML for testing
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
    risk_overrides:
      medium: "proceed"
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
  scope: "single_run"
`;

// Set up test fixture
mkdirSync(FIXTURE_DIR, { recursive: true });
writeFileSync(FIXTURE_POLICY, TEST_POLICY);

describe("policy-gate", () => {
  beforeEach(() => {
    clearPolicyCache();
  });

  describe("checkCapability()", () => {
    it("allows listed actions", () => {
      loadPolicy(FIXTURE_POLICY);
      const result = checkCapability("dor", "postComment");
      assert.equal(result.allowed, true);
    });

    it("blocks forbidden actions", () => {
      loadPolicy(FIXTURE_POLICY);
      const result = checkCapability("dor", "pushCode");
      assert.equal(result.allowed, false);
      assert.ok(result.reason.includes("forbidden"));
    });

    it("blocks unknown actions (fail-closed)", () => {
      loadPolicy(FIXTURE_POLICY);
      const result = checkCapability("dor", "deleteWorkItem");
      assert.equal(result.allowed, false);
      assert.ok(result.reason.includes("not in allowlist"));
    });
  });

  describe("checkRiskLevel()", () => {
    it("returns proceed for low risk", () => {
      loadPolicy(FIXTURE_POLICY);
      const result = checkRiskLevel("dor", "low");
      assert.equal(result.action, "proceed");
    });

    it("returns pipeline override for medium risk when configured", () => {
      loadPolicy(FIXTURE_POLICY);
      const result = checkRiskLevel("dor", "medium");
      // dor has risk_overrides.medium = "proceed"
      assert.equal(result.action, "proceed");
    });

    it("returns skip_and_alert for high risk", () => {
      loadPolicy(FIXTURE_POLICY);
      const result = checkRiskLevel("dor", "high");
      assert.equal(result.action, "skip_and_alert");
    });
  });

  describe("checkPushPolicy()", () => {
    it("allows push when all conditions pass", () => {
      loadPolicy(FIXTURE_POLICY);
      const result = checkPushPolicy({
        thread_category: "agree-will-fix",
        old_code_unique: true,
        lint_passes: true,
        scanner_risk: "low",
      });
      assert.equal(result.allowed, true);
    });

    it("denies push when scanner_risk is high", () => {
      loadPolicy(FIXTURE_POLICY);
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

  describe("checkBreakGlass()", () => {
    it("returns active when label and approver match", () => {
      loadPolicy(FIXTURE_POLICY);
      const result = checkBreakGlass(
        ["ai-policy-override", "other-label"],
        ["user@ai-admins"],
      );
      assert.equal(result.active, true);
    });

    it("returns inactive when label is missing", () => {
      loadPolicy(FIXTURE_POLICY);
      const result = checkBreakGlass(
        ["other-label"],
        ["user@ai-admins"],
      );
      assert.equal(result.active, false);
      assert.ok(result.reason.includes("label"));
    });
  });
});

// Cleanup
rmSync(FIXTURE_DIR, { recursive: true, force: true });
