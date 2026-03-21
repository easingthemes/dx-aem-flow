export async function queuePrAnswerPipeline({ prId, repoName, project, runId, eventId }) {
  const orgUrl = (process.env.ADO_ORG_URL || "").replace(/\/+$/, "");
  if (!orgUrl) throw new Error("Missing ADO_ORG_URL environment variable");
  if (!project) throw new Error("Missing project name from webhook payload");
  const pat = process.env.ADO_PAT;

  // Resolve pipeline ID from repo→pipeline map.
  // ADO_PR_ANSWER_PIPELINE_MAP = {"My-Repo":"123","Other-Repo":"456"}
  const mapJson = process.env.ADO_PR_ANSWER_PIPELINE_MAP;
  if (!mapJson) {
    throw new Error("Missing ADO_PR_ANSWER_PIPELINE_MAP environment variable");
  }

  let pipelineId;
  try {
    const map = JSON.parse(mapJson);
    pipelineId = map[repoName];
  } catch {
    throw new Error("Failed to parse ADO_PR_ANSWER_PIPELINE_MAP as JSON");
  }

  if (!pipelineId) {
    throw new Error(`No PR Answer pipeline mapped for repo "${repoName}". Update ADO_PR_ANSWER_PIPELINE_MAP.`);
  }
  if (!pat) {
    throw new Error("Missing ADO_PAT environment variable");
  }

  const url =
    `${orgUrl}/${encodeURIComponent(project)}` +
    `/_apis/pipelines/${pipelineId}/runs?api-version=7.1-preview.1`;

  const auth = Buffer.from(`:${pat}`).toString("base64");

  // Construct full PR URL for the pipeline (matches prUrl parameter in YAML)
  const prUrl = `${orgUrl}/${encodeURIComponent(project)}/_git/${encodeURIComponent(repoName)}/pullrequest/${prId}`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Basic ${auth}`,
    },
    body: JSON.stringify({
      templateParameters: {
        prUrl,
        eventId: eventId || "",
      },
    }),
  });

  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Queue failed: ${res.status} ${t}`);
  }

  console.log("Pipeline queued for PR:", prId, "repo:", repoName);
}
