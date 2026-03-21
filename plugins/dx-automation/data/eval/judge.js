/**
 * Tier 2 LLM-as-Judge — pairwise comparison of baseline vs current output.
 *
 * Calls Claude API (temp 0) to compare two outputs and
 * return a verdict: "better", "same", or "worse".
 *
 * Used by `eval/run.js --tier2` for trend tracking (non-blocking).
 */

import { fetchWithRetry } from "../agents/lib/retry.js";

export const JUDGE_CONFIG = {
  model: process.env.CLAUDE_JUDGE_MODEL || "claude-sonnet-4-20250514",
  temperature: 0,
  max_tokens: 500,
};

export const JUDGE_PROMPT = `Compare two outputs for the same input.
Output A is the baseline (known-good). Output B is the current output.
Rate: "better", "same", or "worse".
Criteria: actionability, accuracy, conciseness, appropriate severity.
Respond with JSON: { "verdict": "better|same|worse", "reason": "..." }`;

/**
 * Run LLM-as-judge comparison between current and baseline output.
 * @param {string} fixture - Fixture path (e.g., "dor/story-001")
 * @param {object} currentOutput - Current LLM output
 * @param {object} baselineOutput - Known-good baseline output
 * @returns {{ verdict: string, reason: string }}
 */
export async function runJudge(fixture, currentOutput, baselineOutput) {
  const apiKey = process.env.ANTHROPIC_API_KEY;

  if (!apiKey) {
    return { verdict: "error", reason: "Missing ANTHROPIC_API_KEY — skipping judge" };
  }

  const userMessage = [
    `Fixture: ${fixture}`,
    "",
    "=== Output A (baseline) ===",
    JSON.stringify(baselineOutput, null, 2),
    "",
    "=== Output B (current) ===",
    JSON.stringify(currentOutput, null, 2),
  ].join("\n");

  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), 30_000);

  try {
    const res = await fetchWithRetry("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: JUDGE_CONFIG.model,
        temperature: JUDGE_CONFIG.temperature,
        max_tokens: JUDGE_CONFIG.max_tokens,
        system: JUDGE_PROMPT,
        messages: [
          { role: "user", content: userMessage },
        ],
      }),
      signal: controller.signal,
    }, { label: "Judge LLM" });

    if (!res.ok) {
      const text = await res.text();
      return { verdict: "error", reason: `HTTP ${res.status}: ${text.slice(0, 200)}` };
    }

    const data = await res.json();
    const content = data?.content?.[0]?.text ?? "";

    // Extract JSON from response
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      return { verdict: "error", reason: `Could not parse JSON from: ${content.slice(0, 200)}` };
    }

    const parsed = JSON.parse(jsonMatch[0]);
    const verdict = parsed.verdict;

    if (!["better", "same", "worse"].includes(verdict)) {
      return { verdict: "error", reason: `Invalid verdict "${verdict}" — expected better/same/worse` };
    }

    return { verdict, reason: parsed.reason || "" };
  } catch (err) {
    return { verdict: "error", reason: err.message };
  } finally {
    clearTimeout(t);
  }
}
