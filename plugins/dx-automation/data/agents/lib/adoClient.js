import config from "./config.js";
import { fetchWithRetry } from "./retry.js";

function authHeader() {
  const token = config.ado.token;
  // PATs use Basic auth, OAuth/System.AccessToken uses Bearer
  if (token.length > 100) {
    return `Bearer ${token}`;
  }
  return `Basic ${Buffer.from(`:${token}`).toString("base64")}`;
}

function headers() {
  return {
    "Content-Type": "application/json",
    Authorization: authHeader(),
  };
}

function projectUrl(projectName) {
  const { orgUrl, project } = config.ado;
  return `${orgUrl}${encodeURIComponent(projectName || project)}`;
}

function logReq(method, label, url) {
  console.log(`[ADO] ${method} ${label} → ${url}`);
}

export async function fetchWorkItem(workItemId, fields, projectName) {
  const qs = fields ? `fields=${encodeURIComponent(fields.join(","))}&` : "$expand=relations&";
  const url =
    `${projectUrl(projectName)}/_apis/wit/workitems/${workItemId}` +
    `?${qs}api-version=7.1-preview.3`;

  logReq("GET", "workitem", url);
  const res = await fetchWithRetry(url, { headers: headers() }, { label: "ADO API" });
  console.log(`[ADO] workitem response: ${res.status}`);
  const text = await res.text();
  if (!res.ok) throw new Error(`ADO GET workitem failed ${res.status}: ${text}`);
  return JSON.parse(text);
}

export async function fetchWorkItemRelations(workItemId, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/wit/workitems/${workItemId}` +
    `?$expand=relations&api-version=7.1-preview.3`;

  logReq("GET", "workitem relations", url);
  const res = await fetchWithRetry(url, { headers: headers() }, { label: "ADO API" });
  console.log(`[ADO] workitem relations response: ${res.status}`);
  const text = await res.text();
  if (!res.ok) throw new Error(`ADO GET workitem relations failed ${res.status}: ${text}`);
  return JSON.parse(text);
}

export async function postComment(workItemId, markdown, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/wit/workItems/${workItemId}/comments` +
    `?format=0&api-version=7.2-preview.4`;

  logReq("POST", "comment", url);
  const res = await fetchWithRetry(url, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({ text: markdown }),
  }, { label: "ADO comment" });
  console.log(`[ADO] postComment response: ${res.status} (${markdown.length} chars)`);
  const text = await res.text();
  if (!res.ok) throw new Error(`ADO comment failed ${res.status}: ${text}`);
  return JSON.parse(text);
}

export async function updateComment(workItemId, commentId, markdown, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/wit/workItems/${workItemId}/comments/${commentId}` +
    `?format=0&api-version=7.2-preview.4`;

  logReq("PATCH", `comment #${commentId}`, url);
  const res = await fetchWithRetry(url, {
    method: "PATCH",
    headers: headers(),
    body: JSON.stringify({ text: markdown }),
  }, { label: "ADO comment update" });
  console.log(`[ADO] updateComment response: ${res.status} (${markdown.length} chars)`);
  const text = await res.text();
  if (!res.ok) throw new Error(`ADO update comment failed ${res.status}: ${text}`);
  return JSON.parse(text);
}

export async function getComments(workItemId, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/wit/workItems/${workItemId}/comments` +
    `?$top=100&api-version=7.1-preview.3`;

  logReq("GET", "comments", url);
  const res = await fetchWithRetry(url, { headers: headers() }, { label: "ADO API" });
  console.log(`[ADO] getComments response: ${res.status}`);
  const text = await res.text();
  if (!res.ok) throw new Error(`ADO get comments failed ${res.status}: ${text}`);
  return JSON.parse(text);
}

export async function fetchWikiPage(wikiId, pagePath, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/wiki/wikis/${encodeURIComponent(wikiId)}` +
    `/pages?path=${encodeURIComponent(pagePath)}` +
    `&includeContent=true&api-version=7.1-preview.1`;

  logReq("GET", "wiki page", url);
  const res = await fetchWithRetry(url, { headers: headers() }, { label: "ADO API" });
  console.log(`[ADO] wikiPage response: ${res.status}`);
  const text = await res.text();
  if (!res.ok) throw new Error(`ADO wiki fetch failed ${res.status}: ${text}`);
  const page = JSON.parse(text);
  console.log(`[ADO] Wiki content: ${(page.content || "").length} chars`);
  return page.content || "";
}

export async function fetchWikiPageById(wikiId, pageId, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/wiki/wikis/${wikiId}` +
    `/pages/${pageId}?includeContent=true&api-version=7.1-preview.1`;

  logReq("GET", `wiki page #${pageId}`, url);
  const res = await fetchWithRetry(url, { headers: headers() }, { label: "ADO API" });
  console.log(`[ADO] wikiPageById response: ${res.status}`);
  if (!res.ok) return null;
  const page = await res.json();
  return { title: page.path || "", content: page.content || "" };
}

export async function fetchFileContent(repoName, path, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/git/repositories/${encodeURIComponent(repoName)}` +
    `/items?path=${encodeURIComponent(path)}&includeContent=true&api-version=7.1-preview.1`;

  logReq("GET", `file ${repoName}:${path}`, url);
  const res = await fetchWithRetry(url, { headers: headers() }, { label: "ADO API" });
  if (!res.ok) {
    console.log(`[ADO] fetchFile response: ${res.status} (skipped)`);
    return null;
  }
  const data = await res.json();
  console.log(`[ADO] fetchFile response: ${res.status} (${(data.content || "").length} chars)`);
  return data.content || null;
}

// ---- Pull Request APIs ----

export async function getPullRequest(repoName, prId, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/git/repositories/${encodeURIComponent(repoName)}` +
    `/pullRequests/${prId}?api-version=7.1-preview.1`;

  logReq("GET", `PR #${prId}`, url);
  const res = await fetchWithRetry(url, { headers: headers() }, { label: "ADO API" });
  console.log(`[ADO] getPullRequest response: ${res.status}`);
  const text = await res.text();
  if (!res.ok) throw new Error(`ADO GET PR failed ${res.status}: ${text}`);
  return JSON.parse(text);
}

export async function getPullRequestIterations(repoName, prId, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/git/repositories/${encodeURIComponent(repoName)}` +
    `/pullRequests/${prId}/iterations?api-version=7.1-preview.1`;

  logReq("GET", `PR #${prId} iterations`, url);
  const res = await fetchWithRetry(url, { headers: headers() }, { label: "ADO API" });
  console.log(`[ADO] getPullRequestIterations response: ${res.status}`);
  const text = await res.text();
  if (!res.ok) throw new Error(`ADO GET PR iterations failed ${res.status}: ${text}`);
  return JSON.parse(text);
}

export async function getPullRequestChanges(repoName, prId, iterationId, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/git/repositories/${encodeURIComponent(repoName)}` +
    `/pullRequests/${prId}/iterations/${iterationId}/changes?$top=500&api-version=7.1-preview.1`;

  logReq("GET", `PR #${prId} iteration ${iterationId} changes`, url);
  const res = await fetchWithRetry(url, { headers: headers() }, { label: "ADO API" });
  console.log(`[ADO] getPullRequestChanges response: ${res.status}`);
  const text = await res.text();
  if (!res.ok) throw new Error(`ADO GET PR changes failed ${res.status}: ${text}`);
  return JSON.parse(text);
}

export async function getFileAtVersion(repoName, path, version, versionType, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/git/repositories/${encodeURIComponent(repoName)}` +
    `/items?path=${encodeURIComponent(path)}` +
    `&versionDescriptor.version=${encodeURIComponent(version)}` +
    `&versionDescriptor.versionType=${encodeURIComponent(versionType || "branch")}` +
    `&includeContent=true&api-version=7.1-preview.1`;

  logReq("GET", `file ${repoName}:${path}@${version}`, url);
  const res = await fetchWithRetry(url, { headers: headers() }, { label: "ADO API" });
  if (!res.ok) {
    console.log(`[ADO] getFileAtVersion response: ${res.status} (skipped)`);
    return null;
  }
  const data = await res.json();
  console.log(`[ADO] getFileAtVersion response: ${res.status} (${(data.content || "").length} chars)`);
  return data.content || null;
}

export async function getPullRequestThreads(repoName, prId, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/git/repositories/${encodeURIComponent(repoName)}` +
    `/pullRequests/${prId}/threads?api-version=7.1-preview.1`;

  logReq("GET", `PR #${prId} threads`, url);
  const res = await fetchWithRetry(url, { headers: headers() }, { label: "ADO API" });
  console.log(`[ADO] getPullRequestThreads response: ${res.status}`);
  const text = await res.text();
  if (!res.ok) throw new Error(`ADO GET PR threads failed ${res.status}: ${text}`);
  return JSON.parse(text);
}

export async function createPullRequestThread(repoName, prId, thread, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/git/repositories/${encodeURIComponent(repoName)}` +
    `/pullRequests/${prId}/threads?api-version=7.1-preview.1`;

  logReq("POST", `PR #${prId} thread`, url);
  const res = await fetchWithRetry(url, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(thread),
  }, { label: "ADO PR thread" });
  console.log(`[ADO] createPullRequestThread response: ${res.status}`);
  const text = await res.text();
  if (!res.ok) throw new Error(`ADO POST PR thread failed ${res.status}: ${text}`);
  return JSON.parse(text);
}

export async function replyToThread(repoName, prId, threadId, content, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/git/repositories/${encodeURIComponent(repoName)}` +
    `/pullRequests/${prId}/threads/${threadId}/comments?api-version=7.1-preview.1`;

  logReq("POST", `PR #${prId} thread #${threadId} reply`, url);
  const res = await fetchWithRetry(url, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({ content, parentCommentId: 1, commentType: 1 }),
  }, { label: "ADO PR reply" });
  console.log(`[ADO] replyToThread response: ${res.status}`);
  const text = await res.text();
  if (!res.ok) throw new Error(`ADO POST PR thread reply failed ${res.status}: ${text}`);
  return JSON.parse(text);
}

export async function updatePullRequestReviewerVote(repoName, prId, reviewerId, vote, projectName) {
  const url =
    `${projectUrl(projectName)}/_apis/git/repositories/${encodeURIComponent(repoName)}` +
    `/pullRequests/${prId}/reviewers/${encodeURIComponent(reviewerId)}?api-version=7.1-preview.1`;

  logReq("PUT", `PR #${prId} reviewer vote=${vote}`, url);
  const res = await fetchWithRetry(url, {
    method: "PUT",
    headers: headers(),
    body: JSON.stringify({ vote }),
  }, { label: "ADO PR vote" });
  console.log(`[ADO] updatePullRequestReviewerVote response: ${res.status}`);
  const text = await res.text();
  if (!res.ok) throw new Error(`ADO PUT PR reviewer vote failed ${res.status}: ${text}`);
  return JSON.parse(text);
}

export async function searchCode(searchText, repoNames, projectName) {
  const { orgUrl } = config.ado;
  const url =
    `${orgUrl}${encodeURIComponent(projectName)}` +
    `/_apis/search/codesearchresults?api-version=7.1-preview.1`;

  const filters = {};
  if (repoNames?.length) filters.Repository = repoNames;

  logReq("POST", `search "${searchText}"`, url);
  const res = await fetchWithRetry(url, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      searchText,
      $top: 50,
      filters,
    }),
  }, { label: "ADO search" });
  console.log(`[ADO] search response: ${res.status}`);
  const text = await res.text();
  if (!res.ok) throw new Error(`ADO search failed ${res.status}: ${text}`);
  return JSON.parse(text);
}
