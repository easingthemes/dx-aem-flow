import crypto from "crypto";
import { mkdirSync, writeFileSync, readFileSync, existsSync, appendFileSync, copyFileSync } from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { redact, redactObject } from "./redact.js";
import { hashPolicy } from "./hash.js";
import { uploadBundle } from "./storage.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const BUNDLE_CTX_FILE = "bundle-ctx.json";

/**
 * Initialize a new bundle for a pipeline run.
 * Creates the run directory structure under cwd/runs/{runId}/.
 *
 * Extended directory structure (v1.1):
 *   inputs/         — input data (work items, specs)
 *   context/        — codebase context snapshots
 *   outputs/        — pipeline step outputs
 *   actions/        — decision journal, ADO mutations
 *   role-outputs/   — per-role structured outputs (re-agent.json, dev-agent.json, qa-agent.json)
 *   screenshots/    — QA Agent AEM UI captures (local only)
 */
export function initBundle(pipelineName) {
  const runId = crypto.randomUUID();
  const bundleDir = path.join(process.cwd(), "runs", runId);

  try {
    for (const sub of ["inputs", "context", "outputs", "actions", "role-outputs", "screenshots"]) {
      mkdirSync(path.join(bundleDir, sub), { recursive: true });
    }
  } catch (err) {
    console.warn(`[Bundle] Failed to create bundle dirs: ${err.message}`);
  }

  const ctx = {
    runId,
    bundleDir,
    meta: {
      runId,
      eventId: null,
      pipeline: pipelineName,
      startTime: new Date().toISOString(),
      endTime: null,
      status: null,
      model: process.env.CLAUDE_CODE_MODEL || "claude-code",
      provider: "claude-code",
      promptHash: null,
      configHash: null,
      policyHash: null,
    },
    decisions: [],
    timings: [],
    tokenUsageByStep: [],
    commands: [],      // Shell commands with exit codes
    adoActions: [],    // ADO work item mutations
  };

  return ctx;
}

/**
 * Set a metadata field on the bundle context.
 */
export function setBundleMeta(ctx, key, value) {
  if (!ctx || !ctx.meta) return;
  ctx.meta[key] = value;
}

/**
 * Write an artifact file to the bundle directory.
 * @param {object} ctx - Bundle context
 * @param {string} category - Subdirectory: inputs, context, outputs, actions
 * @param {string} filename - File name
 * @param {*} data - String or object (will be JSON-stringified)
 */
export function writeArtifact(ctx, category, filename, data) {
  if (!ctx || !ctx.bundleDir) return;
  try {
    const dir = path.join(ctx.bundleDir, category);
    mkdirSync(dir, { recursive: true });
    const content = typeof data === "string" ? redact(data) : JSON.stringify(redactObject(data), null, 2);
    writeFileSync(path.join(dir, filename), content);
  } catch (err) {
    console.warn(`[Bundle] Failed to write artifact ${category}/${filename}: ${err.message}`);
  }
}

/**
 * Record timing for a pipeline step.
 * @param {object} ctx - Bundle context
 * @param {string} step - Step name (e.g. "2-fetch-changes")
 * @param {number} durationMs - Duration in milliseconds
 */
export function recordStepTiming(ctx, step, durationMs) {
  if (!ctx) return;
  if (!ctx.timings) ctx.timings = [];
  ctx.timings.push({ step, durationMs: Math.round(durationMs), timestamp: new Date().toISOString() });
}

/**
 * Record token usage for a pipeline step.
 * @param {object} ctx - Bundle context
 * @param {string} step - Step name
 * @param {{ prompt_tokens: number, completion_tokens: number, total_tokens: number }} usage
 */
export function recordStepTokenUsage(ctx, step, usage) {
  if (!ctx || !usage) return;
  if (!ctx.tokenUsageByStep) ctx.tokenUsageByStep = [];
  ctx.tokenUsageByStep.push({ step, ...usage, timestamp: new Date().toISOString() });
}

/**
 * Append a decision entry to the bundle's decision journal.
 * @param {object} ctx - Bundle context
 * @param {{ planned: string, executed: string|null, refused: string|null }} decision
 */
export function writeDecision(ctx, decision) {
  if (!ctx || !ctx.decisions) return;
  ctx.decisions.push({
    ...decision,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Record a shell command and its result in the bundle.
 * Written to commands.log as an append-only log.
 * @param {object} ctx - Bundle context
 * @param {string} command - The command executed
 * @param {number} exitCode - Process exit code
 * @param {string} [output] - Truncated stdout/stderr (optional)
 */
export function recordCommand(ctx, command, exitCode, output) {
  if (!ctx) return;
  const entry = {
    command: redact(command),
    exitCode,
    timestamp: new Date().toISOString(),
  };
  if (!ctx.commands) ctx.commands = [];
  ctx.commands.push(entry);

  // Append to commands.log
  if (ctx.bundleDir) {
    try {
      const line = `[${entry.timestamp}] exit=${exitCode} ${redact(command)}` +
        (output ? `\n${redact(output).slice(0, 2000)}` : "") + "\n";
      appendFileSync(path.join(ctx.bundleDir, "commands.log"), line);
    } catch { /* non-fatal */ }
  }
}

/**
 * Record an ADO work item mutation (create, update, link).
 * @param {object} ctx - Bundle context
 * @param {{ action: string, type: string, id?: number, fields?: object, role?: string }} mutation
 */
export function recordAdoAction(ctx, mutation) {
  if (!ctx) return;
  if (!ctx.adoActions) ctx.adoActions = [];
  ctx.adoActions.push({
    ...mutation,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Write a role-specific output file to the bundle.
 * @param {object} ctx - Bundle context
 * @param {string} role - Role name (e.g., "re-agent", "dev-agent", "qa-agent")
 * @param {object} data - Structured role output
 */
export function writeRoleOutput(ctx, role, data) {
  writeArtifact(ctx, "role-outputs", `${role}.json`, data);
}

/**
 * Write the unified diff of all code changes to the bundle.
 * @param {object} ctx - Bundle context
 * @param {string} diff - Unified diff content
 */
export function writePatchDiff(ctx, diff) {
  if (!ctx || !ctx.bundleDir) return;
  try {
    writeFileSync(path.join(ctx.bundleDir, "patch.diff"), diff);
  } catch (err) {
    console.warn(`[Bundle] Failed to write patch.diff: ${err.message}`);
  }
}

/**
 * Write structured test results (compilation, unit tests, lint) to the bundle.
 * @param {object} ctx - Bundle context
 * @param {{ compilation?: object, unitTests?: object, lint?: object, frontendBuild?: object }} results
 */
export function writeTestResults(ctx, results) {
  writeArtifact(ctx, ".", "test-results.json", {
    ...results,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Add a screenshot to the bundle's screenshots directory.
 * @param {object} ctx - Bundle context
 * @param {string} sourcePath - Path to the screenshot file
 * @param {string} filename - Target filename in screenshots/
 */
export function addScreenshot(ctx, sourcePath, filename) {
  if (!ctx || !ctx.bundleDir) return;
  try {
    const destDir = path.join(ctx.bundleDir, "screenshots");
    mkdirSync(destDir, { recursive: true });
    copyFileSync(sourcePath, path.join(destDir, filename));
  } catch (err) {
    console.warn(`[Bundle] Failed to add screenshot ${filename}: ${err.message}`);
  }
}

/**
 * Write the final outcome summary to the bundle.
 * @param {object} ctx - Bundle context
 * @param {{ verdict: string, summary: string, roles?: object, errors?: string[] }} outcome
 */
export function writeOutcome(ctx, outcome) {
  if (!ctx || !ctx.bundleDir) return;
  try {
    writeFileSync(
      path.join(ctx.bundleDir, "outcome.json"),
      JSON.stringify({
        ...outcome,
        runId: ctx.runId,
        pipeline: ctx.meta?.pipeline,
        timestamp: new Date().toISOString(),
      }, null, 2),
    );
  } catch (err) {
    console.warn(`[Bundle] Failed to write outcome.json: ${err.message}`);
  }
}

/**
 * Finalize the bundle — write run.json and decision-journal.json, upload to blob.
 */
export async function finalizeBundle(ctx, status) {
  if (!ctx || !ctx.bundleDir) return;

  ctx.meta.endTime = new Date().toISOString();
  ctx.meta.status = status;

  // Compute policy hash
  try {
    const policyPath = path.resolve(__dirname, "../../../../.ai/automation/policy/pipeline-policy.yaml");
    if (existsSync(policyPath)) {
      ctx.meta.policyHash = hashPolicy(policyPath);
    }
  } catch { /* policy file optional */ }

  // Write run.json (redacted)
  try {
    writeFileSync(
      path.join(ctx.bundleDir, "run.json"),
      JSON.stringify(redactObject(ctx.meta), null, 2),
    );
  } catch (err) {
    console.warn(`[Bundle] Failed to write run.json: ${err.message}`);
  }

  // Write decision journal (redacted)
  try {
    writeFileSync(
      path.join(ctx.bundleDir, "actions", "decision-journal.json"),
      JSON.stringify(redactObject(ctx.decisions), null, 2),
    );
  } catch (err) {
    console.warn(`[Bundle] Failed to write decision-journal.json: ${err.message}`);
  }

  // Write timing data
  if (ctx.timings && ctx.timings.length > 0) {
    try {
      writeFileSync(
        path.join(ctx.bundleDir, "timing.json"),
        JSON.stringify(ctx.timings, null, 2),
      );
    } catch (err) {
      console.warn(`[Bundle] Failed to write timing.json: ${err.message}`);
    }
  }

  // Write token usage by step
  if (ctx.tokenUsageByStep && ctx.tokenUsageByStep.length > 0) {
    try {
      writeFileSync(
        path.join(ctx.bundleDir, "token-usage-by-step.json"),
        JSON.stringify(ctx.tokenUsageByStep, null, 2),
      );
    } catch (err) {
      console.warn(`[Bundle] Failed to write token-usage-by-step.json: ${err.message}`);
    }
  }

  // Write ADO actions log
  if (ctx.adoActions && ctx.adoActions.length > 0) {
    try {
      writeFileSync(
        path.join(ctx.bundleDir, "ado-actions.json"),
        JSON.stringify(redactObject(ctx.adoActions), null, 2),
      );
    } catch (err) {
      console.warn(`[Bundle] Failed to write ado-actions.json: ${err.message}`);
    }
  }

  // Upload to S3 bucket (non-blocking, fail-open)
  await uploadBundle(ctx.bundleDir, ctx.runId).catch(() => {});

  console.log(`[Bundle] Finalized: runs/${ctx.runId}/ (status: ${status})`);
}

/**
 * Load bundle context from bundle-ctx.json in cwd.
 * Returns null if file doesn't exist (non-fatal).
 */
export function loadBundleCtx() {
  try {
    const filePath = path.join(process.cwd(), BUNDLE_CTX_FILE);
    if (!existsSync(filePath)) {
      console.warn("[Bundle] No bundle-ctx.json found — bundle writes disabled for this step");
      return null;
    }
    const raw = JSON.parse(readFileSync(filePath, "utf8"));
    return {
      runId: raw.runId,
      bundleDir: raw.bundleDir,
      meta: raw.meta || {},
      decisions: raw.decisions || [],
      timings: raw.timings || [],
      tokenUsageByStep: raw.tokenUsageByStep || [],
      commands: raw.commands || [],
      adoActions: raw.adoActions || [],
    };
  } catch (err) {
    console.warn(`[Bundle] Failed to load bundle-ctx.json: ${err.message}`);
    return null;
  }
}

/**
 * Save bundle context to bundle-ctx.json in cwd (for subsequent steps).
 */
export function saveBundleCtx(ctx) {
  if (!ctx) return;
  try {
    writeFileSync(
      path.join(process.cwd(), BUNDLE_CTX_FILE),
      JSON.stringify({
        runId: ctx.runId,
        bundleDir: ctx.bundleDir,
        meta: ctx.meta,
        decisions: ctx.decisions,
        timings: ctx.timings || [],
        tokenUsageByStep: ctx.tokenUsageByStep || [],
        commands: ctx.commands || [],
        adoActions: ctx.adoActions || [],
      }, null, 2),
    );
  } catch (err) {
    console.warn(`[Bundle] Failed to save bundle-ctx.json: ${err.message}`);
  }
}
