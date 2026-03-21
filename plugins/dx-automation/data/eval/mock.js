/**
 * Mock layer for eval — intercepts ADO and LLM calls using fixture data.
 */

import { readFileSync, existsSync } from "fs";
import path from "path";

/**
 * Create a mock ADO client that returns fixture data instead of making API calls.
 */
export function createMockAdoClient(fixtureDir) {
  const inputPath = path.join(fixtureDir, "input.json");
  const contextPath = path.join(fixtureDir, "context.json");

  const input = existsSync(inputPath) ? JSON.parse(readFileSync(inputPath, "utf8")) : {};
  const context = existsSync(contextPath) ? JSON.parse(readFileSync(contextPath, "utf8")) : {};

  // Build file content lookup from context.files array
  const fileLookup = {};
  for (const f of context.files || []) {
    if (f.path) {
      fileLookup[f.path] = f.newContent || f.oldContent || "";
    }
  }

  return {
    // Work item APIs (DoR)
    fetchWorkItem: async () => ({ id: input.workItemId, fields: input.workItem || {} }),
    fetchWorkItemRelations: async () => ({ relations: [] }),
    getComments: async () => ({ comments: [] }),
    fetchWikiPageById: async (wikiId, pageId) => {
      const pages = context.linkedWikiPages || [];
      return pages[0] || null;
    },

    // PR APIs (PR Review + PR Answer)
    getPullRequest: async () => input,
    getPullRequestThreads: async () => ({ value: context.threads || [] }),
    getPullRequestIterations: async () => ({ value: [{ id: 1 }] }),
    getPullRequestChanges: async () => ({ changeEntries: (context.files || []).map((f) => ({ item: { path: f.path }, changeType: f.changeType === "add" ? 2 : 1 })) }),
    getFileAtVersion: async (repo, filePath) => fileLookup[filePath] || "",
    fetchFileContent: async (repo, filePath) => fileLookup[filePath] || "",
    searchCode: async () => ({ results: [] }),

    // Write APIs (stubs — eval never writes)
    postComment: async () => ({ id: "mock-comment-1" }),
    updateComment: async () => ({}),
    createPullRequestThread: async () => ({ id: "mock-thread-1" }),
    replyToThread: async () => ({}),
    updatePullRequestReviewerVote: async () => ({}),
  };
}

/**
 * Create a mock LLM client that returns baseline fixture output.
 * If options.useLiveLLM is true, use the real Azure OpenAI client instead.
 */
export function createMockLLM(fixtureDir, options = {}) {
  if (options.useLiveLLM) {
    // Dynamic import deferred to caller — return null to signal live mode
    return null;
  }

  const baselinePath = path.join(fixtureDir, "baseline-output.json");
  const baseline = existsSync(baselinePath) ? JSON.parse(readFileSync(baselinePath, "utf8")) : {};

  return {
    callLLM: async () => ({
      content: JSON.stringify(baseline),
      usage: { prompt_tokens: 100, completion_tokens: 50, total_tokens: 150 },
      _promptHash: "mock-prompt-hash",
      _cfgHash: "mock-cfg-hash",
    }),
    callLLMJson: async () => ({
      ...baseline,
      _promptHash: "mock-prompt-hash",
      _cfgHash: "mock-cfg-hash",
    }),
  };
}
