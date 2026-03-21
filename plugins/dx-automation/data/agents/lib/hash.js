/**
 * Version tracking via deterministic hashing.
 * Produces SHA-256 hashes for prompts, configs, and policy files.
 */

import crypto from "crypto";
import { readFileSync } from "fs";

/**
 * Hash a prompt (system + user) for change tracking.
 */
export function hashPrompt(systemPrompt, userPrompt) {
  return crypto.createHash("sha256")
    .update(systemPrompt || "")
    .update("\n---\n")
    .update(userPrompt || "")
    .digest("hex");
}

/**
 * Hash model config parameters for change tracking.
 * Keys are sorted for deterministic output.
 */
export function hashConfig(params) {
  const keys = Object.keys(params).sort();
  const canonical = JSON.stringify(params, keys);
  return crypto.createHash("sha256").update(canonical).digest("hex");
}

/**
 * Hash a policy file by its content.
 */
export function hashPolicy(policyFilePath) {
  const content = readFileSync(policyFilePath, "utf8");
  return crypto.createHash("sha256").update(content).digest("hex");
}

/**
 * Combine prompt, config, and policy hashes into a short composite hash.
 */
export function computeConfigHash(promptHash, configHash, policyHash) {
  return crypto.createHash("sha256")
    .update(promptHash)
    .update(configHash)
    .update(policyHash || "")
    .digest("hex")
    .slice(0, 16);
}
