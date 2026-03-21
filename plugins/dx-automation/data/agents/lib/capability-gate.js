/**
 * Capability gate — wraps ADO write operations with policy checks.
 * Every write action goes through gatedAction() which:
 *   1. Checks capability allowlist (from policy-gate.js)
 *   2. Executes the action if allowed
 *   3. Logs the decision to the bundle's decision journal
 *
 * Pre-built gated versions of common ADO operations are exported
 * for drop-in replacement in agent step files.
 *
 * Pipeline name is derived from bundleCtx.meta.pipeline — callers
 * don't need to specify it.
 */
import {
  postComment,
  updateComment,
  createPullRequestThread,
  replyToThread,
  updatePullRequestReviewerVote,
} from "./adoClient.js";
import { checkCapability, checkPushPolicy, getVotePolicy, checkBreakGlass } from "./policy-gate.js";
import { writeDecision } from "./bundle.js";
import { sendAlert } from "./alerts.js";

/**
 * Execute an ADO action through the capability gate.
 *
 * @param {object} bundleCtx - Bundle context (must have meta.pipeline)
 * @param {string} actionName - Policy action name (e.g. "postComment")
 * @param {Function} executeFn - Async function to execute if allowed
 * @returns {Promise<{result: *, allowed: boolean, reason?: string}>}
 */
export async function gatedAction(bundleCtx, actionName, executeFn) {
  const pipelineName = bundleCtx?.meta?.pipeline || "unknown";
  const capCheck = checkCapability(pipelineName, actionName);

  if (!capCheck.allowed) {
    console.warn(`[CapGate] REFUSED: ${pipelineName}/${actionName} — ${capCheck.reason}`);
    sendAlert("critical", `Capability REFUSED: ${pipelineName}/${actionName}`, {
      pipeline: pipelineName, step: "capability-gate",
      details: capCheck.reason,
    }, bundleCtx);
    writeDecision(bundleCtx, {
      pipeline: pipelineName,
      planned: actionName,
      executed: null,
      refused: capCheck.reason,
    });
    return { result: null, allowed: false, reason: capCheck.reason };
  }

  try {
    const result = await executeFn();
    writeDecision(bundleCtx, {
      pipeline: pipelineName,
      planned: actionName,
      executed: actionName,
    });
    return { result, allowed: true };
  } catch (err) {
    writeDecision(bundleCtx, {
      pipeline: pipelineName,
      planned: actionName,
      executed: null,
      refused: `execution error: ${err.message}`,
    });
    throw err;
  }
}

// ─── Pre-built gated actions ────────────────────────────────────────────────

/**
 * Gated postComment — for DoR pipeline.
 * @returns {Promise<object|null>} ADO response or null if refused
 */
export async function gatedPostComment(bundleCtx, workItemId, markdown, projectName) {
  const { result } = await gatedAction(bundleCtx, "postComment", () =>
    postComment(workItemId, markdown, projectName),
  );
  return result;
}

/**
 * Gated updateComment — for DoR pipeline.
 * @returns {Promise<object|null>} ADO response or null if refused
 */
export async function gatedUpdateComment(bundleCtx, workItemId, commentId, markdown, projectName) {
  const { result } = await gatedAction(bundleCtx, "updateComment", () =>
    updateComment(workItemId, commentId, markdown, projectName),
  );
  return result;
}

/**
 * Gated createPullRequestThread — for PR Review pipeline.
 * @returns {Promise<object|null>} ADO response or null if refused
 */
export async function gatedPostThread(bundleCtx, repoName, prId, thread, projectName) {
  const { result } = await gatedAction(bundleCtx, "postThread", () =>
    createPullRequestThread(repoName, prId, thread, projectName),
  );
  return result;
}

/**
 * Gated replyToThread — for PR Answer pipeline.
 * @returns {Promise<object|null>} ADO response or null if refused
 */
export async function gatedReplyToThread(bundleCtx, repoName, prId, threadId, content, projectName) {
  const { result } = await gatedAction(bundleCtx, "replyToThread", () =>
    replyToThread(repoName, prId, threadId, content, projectName),
  );
  return result;
}

/**
 * Gated castVote — for PR Review pipeline.
 * Applies vote policy enforcement: if findings contain blockers, vote is
 * clamped to "wait" regardless of computed vote.
 *
 * @param {object} bundleCtx
 * @param {string} repoName
 * @param {number} prId
 * @param {string} reviewerId
 * @param {number} vote - Computed vote value
 * @param {string} [projectName]
 * @param {{ hasBlockers?: boolean }} [context] - Optional context for vote policy
 * @returns {Promise<object|null>} ADO response or null if refused
 */
export async function gatedCastVote(bundleCtx, repoName, prId, reviewerId, vote, projectName, context) {
  const pipelineName = bundleCtx?.meta?.pipeline || "unknown";

  // Apply vote policy: blocker findings → clamp to "wait" (-5)
  let effectiveVote = vote;
  const votePolicy = getVotePolicy(pipelineName);
  if (votePolicy && context?.hasBlockers && votePolicy.blocker_implies === "wait") {
    // "wait" maps to vote value -5 in ADO
    if (vote > -5) {
      console.log(`[CapGate] Vote clamped: ${vote} → -5 (blocker_implies: wait)`);
      effectiveVote = -5;
    }
  }

  const { result } = await gatedAction(bundleCtx, "castVote", () =>
    updatePullRequestReviewerVote(repoName, prId, reviewerId, effectiveVote, projectName),
  );
  return result;
}

/**
 * Gated pushCode — for PR Answer pipeline.
 * Checks both capability allowlist AND push policy conditions.
 *
 * @param {object} bundleCtx
 * @param {object} pushContext - Push policy condition values
 * @param {string} pushContext.thread_category - e.g. "agree-will-fix"
 * @param {boolean} pushContext.old_code_unique
 * @param {boolean} pushContext.lint_passes
 * @param {string} pushContext.scanner_risk - "low", "medium", or "high"
 * @param {Function} executeFn - Async function that performs the git push
 * @param {{ prLabels?: string[], approverIdentities?: string[] }} [breakGlassContext] - Optional break-glass context
 * @returns {Promise<{result: *, allowed: boolean, fallback?: string, conditions?: Array}>}
 */
export async function gatedPushCode(bundleCtx, pushContext, executeFn, breakGlassContext) {
  const pipelineName = bundleCtx?.meta?.pipeline || "unknown";

  // 1. Capability check
  const capCheck = checkCapability(pipelineName, "pushCode");
  if (!capCheck.allowed) {
    console.warn(`[CapGate] REFUSED push: ${capCheck.reason}`);
    sendAlert("critical", `Push REFUSED: ${pipelineName}/pushCode`, {
      pipeline: pipelineName, step: "capability-gate",
      details: capCheck.reason,
    }, bundleCtx);
    writeDecision(bundleCtx, {
      pipeline: pipelineName,
      planned: "pushCode",
      executed: null,
      refused: capCheck.reason,
    });
    return { result: null, allowed: false, reason: capCheck.reason };
  }

  // 2. Push policy check
  const pushCheck = checkPushPolicy(pushContext);
  if (!pushCheck.allowed) {
    // Check break-glass override before denying
    const bg = breakGlassContext
      ? checkBreakGlass(breakGlassContext.prLabels || [], breakGlassContext.approverIdentities || [])
      : { active: false };

    if (bg.active) {
      const failedConditions = pushCheck.conditions.filter((c) => !c.pass).map((c) => c.name).join(", ");
      console.warn(`[CapGate] Push policy denied (${failedConditions}) but BREAK-GLASS active — proceeding with warning`);
      sendAlert("warning", `Break-glass override used for pushCode`, {
        pipeline: pipelineName, step: "capability-gate",
        details: { overriddenConditions: failedConditions, fallback: pushCheck.fallback },
      }, bundleCtx);
      writeDecision(bundleCtx, {
        pipeline: pipelineName,
        planned: "pushCode",
        executed: "pushCode (break-glass)",
        breakGlass: true,
        overriddenConditions: failedConditions,
      });
      // Fall through to execute push
    } else {
      const failedConditions = pushCheck.conditions.filter((c) => !c.pass).map((c) => c.name).join(", ");
      console.warn(`[CapGate] Push policy denied — fallback: ${pushCheck.fallback}`);
      sendAlert("warning", `Push policy denied: ${failedConditions}`, {
        pipeline: pipelineName, step: "capability-gate",
        details: { fallback: pushCheck.fallback, conditions: pushCheck.conditions },
      }, bundleCtx);
      writeDecision(bundleCtx, {
        pipeline: pipelineName,
        planned: "pushCode",
        executed: null,
        refused: `push policy: ${failedConditions}`,
        fallback: pushCheck.fallback,
      });
      return {
        result: null,
        allowed: false,
        fallback: pushCheck.fallback,
        conditions: pushCheck.conditions,
      };
    }
  }

  // 3. Execute push
  try {
    const result = await executeFn();
    writeDecision(bundleCtx, {
      pipeline: pipelineName,
      planned: "pushCode",
      executed: "pushCode",
      conditions: pushCheck.conditions,
    });
    return { result, allowed: true, conditions: pushCheck.conditions };
  } catch (err) {
    writeDecision(bundleCtx, {
      pipeline: pipelineName,
      planned: "pushCode",
      executed: null,
      refused: `push execution error: ${err.message}`,
    });
    throw err;
  }
}
