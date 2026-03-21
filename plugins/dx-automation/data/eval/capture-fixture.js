#!/usr/bin/env node

/**
 * Capture a golden fixture from live ADO data.
 *
 * Usage:
 *   node eval/capture-fixture.js --agent dor --id <workItemId> --name story-001
 *   node eval/capture-fixture.js --agent pr-review --id <prId> --repo <repoName> --name pr-001
 *   node eval/capture-fixture.js --agent pr-answer --id <prId> --repo <repoName> --name thread-001
 *
 * Env vars: SYSTEM_COLLECTIONURI, SYSTEM_TEAMPROJECT
 * Auth: SYSTEM_ACCESSTOKEN (pipeline) or AZURE_DEVOPS_PAT (.env via --env-file=../../.env)
 */

import { mkdirSync, writeFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import { redactObject } from "../agents/lib/redact.js";
import {
  fetchWorkItem,
  fetchWorkItemRelations,
  getComments,
  fetchWikiPageById,
  getPullRequest,
  getPullRequestThreads,
  getPullRequestIterations,
  getPullRequestChanges,
  getFileAtVersion,
} from "../agents/lib/adoClient.js";
import { cleanField } from "../agents/lib/text.js";

const __dirname = dirname(fileURLToPath(import.meta.url));

// --- Parse args ---
const args = process.argv.slice(2);
const flags = {};
for (const a of args) {
  if (a.startsWith("--")) {
    const [key, ...rest] = a.slice(2).split("=");
    flags[key] = rest.length ? rest.join("=") : "true";
  }
}

const agent = flags.agent;
const id = flags.id;
const name = flags.name;
const repo = flags.repo || "";
const project = flags.project || process.env.SYSTEM_TEAMPROJECT || "";

if (!agent || !id || !name) {
  console.error("Usage: node eval/capture-fixture.js --agent <dor|pr-review|pr-answer> --id <id> --name <name> [--repo <repo>] [--project <project>]");
  process.exit(1);
}

if ((agent === "pr-review" || agent === "pr-answer") && !repo) {
  console.error("ERROR: --repo is required for pr-review and pr-answer agents");
  process.exit(1);
}

const fixtureDir = resolve(__dirname, "fixtures", agent, name);
mkdirSync(fixtureDir, { recursive: true });

function writeFixtureFile(filename, data) {
  const redacted = redactObject(data);
  writeFileSync(resolve(fixtureDir, filename), JSON.stringify(redacted, null, 2));
  console.log(`  Wrote ${filename}`);
}

console.log(`\nCapturing ${agent} fixture "${name}" from ID=${id}...\n`);

// --- DoR ---
if (agent === "dor") {
  const fields = [
    "System.Title", "System.Tags", "System.Description", "System.TeamProject",
    "Microsoft.VSTS.Common.AcceptanceCriteria", "Custom.UIDesigns", "Custom.BusinessBenefits",
  ];

  const wi = await fetchWorkItem(id, fields, project);
  const f = wi.fields;
  const wiProject = f["System.TeamProject"] || project;

  const wiRel = await fetchWorkItemRelations(id, project);
  const relations = wiRel.relations || [];

  const ctx = {
    title: f["System.Title"] || "",
    project: wiProject,
    tags: f["System.Tags"] || "",
    description: cleanField(f["System.Description"]),
    acceptanceCriteria: cleanField(f["Microsoft.VSTS.Common.AcceptanceCriteria"]),
    businessBenefits: cleanField(f["Custom.BusinessBenefits"], 5000),
    uiDesigns: cleanField(f["Custom.UIDesigns"], 3000),
    discussion: [],
    linkedWikiPages: [],
    detectedLinks: { figma: [], images: 0 },
  };

  // Fetch comments for discussion
  try {
    const commentsData = await getComments(id, wiProject);
    ctx.discussion = (commentsData.comments || [])
      .filter((c) => !(c.text || "").includes("[DoRAgent]"))
      .slice(-3)
      .map((c) => cleanField(c.text, 2000));
  } catch (e) {
    console.warn(`  Could not fetch comments: ${e.message}`);
  }

  // Fetch linked wiki pages
  const wikiLinks = relations
    .filter((r) => r.rel === "Hyperlink" && (r.url || "").includes("_wiki/wikis/"))
    .map((r) => {
      const m = r.url.match(/_wiki\/wikis\/([^/?]+)(?:\/(\d+))?/);
      if (!m) return null;
      return { wikiId: decodeURIComponent(m[1]), pageId: m[2] || null, project: wiProject };
    })
    .filter((l) => l && l.pageId);

  for (const link of wikiLinks.slice(0, 5)) {
    try {
      const page = await fetchWikiPageById(link.wikiId, link.pageId, link.project);
      if (page) ctx.linkedWikiPages.push(page);
    } catch { /* skip */ }
  }

  writeFixtureFile("input.json", { workItemId: id, project: wiProject, workItem: wi.fields });
  writeFixtureFile("context.json", ctx);
  writeFixtureFile("expected-output.json", {
    schema: "dor-check-v1",
    must_find: [],
    must_not_find: [],
    expected_action: "TODO",
    max_findings: 15,
  });
  writeFixtureFile("baseline-output.json", {});
  writeFixtureFile("metadata.json", {
    snapshotDate: new Date().toISOString(),
    source: `workitem:${id}`,
    agent: "dor",
    name,
    tags: [],
  });
}

// --- PR Review ---
if (agent === "pr-review") {
  const pr = await getPullRequest(repo, id, project);
  const prDetails = {
    prId: pr.pullRequestId,
    title: pr.title,
    description: pr.description || "",
    status: pr.status,
    sourceRefName: pr.sourceRefName,
    targetRefName: pr.targetRefName,
    author: { displayName: pr.createdBy?.displayName || "", uniqueName: pr.createdBy?.uniqueName || "" },
    reviewers: (pr.reviewers || []).map((r) => ({ displayName: r.displayName, vote: r.vote })),
    workItemRefs: (pr.workItemRefs || []).map((w) => ({ id: w.id })),
    repoName: repo,
    project,
  };

  // Fetch changed files from latest iteration
  const iters = await getPullRequestIterations(repo, id, project);
  const latestIter = (iters.value || []).length;
  const changes = latestIter > 0
    ? await getPullRequestChanges(repo, id, latestIter, project)
    : { changeEntries: [] };

  const files = [];
  for (const entry of (changes.changeEntries || []).slice(0, 20)) {
    const filePath = entry.item?.path;
    if (!filePath) continue;
    const changeType = entry.changeType === 1 ? "edit" : entry.changeType === 2 ? "add" : "edit";
    let newContent = null;
    try {
      newContent = await getFileAtVersion(repo, filePath, pr.sourceRefName.replace("refs/heads/", ""), "branch", project);
    } catch { /* skip */ }
    files.push({ path: filePath, changeType, newContent: newContent?.slice(0, 5000) || null });
  }

  writeFixtureFile("input.json", prDetails);
  writeFixtureFile("context.json", { files });
  writeFixtureFile("expected-output.json", {
    schema: "pr-review-v1",
    must_find: [],
    must_not_find: [],
    expected_action: "post_review",
    max_findings: 20,
  });
  writeFixtureFile("baseline-output.json", {});
  writeFixtureFile("metadata.json", {
    snapshotDate: new Date().toISOString(),
    source: `pr:${repo}/${id}`,
    agent: "pr-review",
    name,
    tags: [],
  });
}

// --- PR Answer ---
if (agent === "pr-answer") {
  const pr = await getPullRequest(repo, id, project);
  const prDetails = {
    prId: pr.pullRequestId,
    title: pr.title,
    description: pr.description || "",
    status: pr.status,
    sourceRefName: pr.sourceRefName,
    targetRefName: pr.targetRefName,
    author: { displayName: pr.createdBy?.displayName || "", uniqueName: pr.createdBy?.uniqueName || "" },
    repoName: repo,
    project,
  };

  const threadsData = await getPullRequestThreads(repo, id, project);
  const threads = (threadsData.value || [])
    .filter((t) => (t.comments || []).length > 0 && t.status === 1)
    .slice(0, 10)
    .map((t) => ({
      threadId: t.id,
      isBot: false,
      filePath: t.threadContext?.filePath || null,
      lineStart: t.threadContext?.rightFileStart?.line || null,
      lineEnd: t.threadContext?.rightFileEnd?.line || null,
      comments: (t.comments || []).map((c) => ({
        author: c.author?.displayName || "",
        content: c.content || "",
      })),
    }));

  writeFixtureFile("input.json", prDetails);
  writeFixtureFile("context.json", { threads });
  writeFixtureFile("expected-output.json", {
    schema: "pr-answer-v1",
    must_find: [],
    must_not_find: [],
    expected_action: "TODO",
    expected_categories: {},
  });
  writeFixtureFile("baseline-output.json", {});
  writeFixtureFile("metadata.json", {
    snapshotDate: new Date().toISOString(),
    source: `pr:${repo}/${id}`,
    agent: "pr-answer",
    name,
    tags: [],
  });
}

console.log(`\nFixture saved to: ${fixtureDir}`);
console.log("Next: edit expected-output.json with assertions, then run eval.");
