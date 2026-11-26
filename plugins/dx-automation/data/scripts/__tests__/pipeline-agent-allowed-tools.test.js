// pipeline-agent-allowed-tools.test.js — ALLOWED_TOOLS reaches the SDK as clean entries.
//
// Runs the real pipeline-agent.js with a stub @anthropic-ai/claude-agent-sdk
// whose query() prints the allowedTools it was handed and exits, so no API
// call, no ADO and no network (same pattern as pipeline-agent-ado-args.test.js).
//
// Why: pipelines write ALLOWED_TOOLS as a folded YAML scalar (`>-`), which
// joins lines with a space, so a plain split(",") yields " Bash(git *)",
// " mcp__ado__wit_work_item", … The SDK does not trim; it joins the array
// back into one --allowedTools argument.

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const AGENT = path.join(__dirname, "..", "pipeline-agent.js");

function allowedTools(extraEnv) {
  const stub = fs.mkdtempSync(path.join(os.tmpdir(), "sdk-stub-"));
  const dir = path.join(stub, "node_modules", "@anthropic-ai", "claude-agent-sdk");
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, "package.json"), '{"name":"@anthropic-ai/claude-agent-sdk","main":"index.js"}');
  fs.writeFileSync(path.join(dir, "index.js"),
    'exports.query = ({ options }) => { process.stdout.write("ALLOWED=" + JSON.stringify(options.allowedTools) + "\\n"); process.exit(0); };');
  try {
    const env = { PATH: process.env.PATH, HOME: stub, NODE_PATH: path.join(stub, "node_modules"),
                  PLUGIN_BASE_DIR: path.join(stub, "no-plugins"), ...extraEnv };
    for (const k of Object.keys(env)) if (env[k] === undefined) delete env[k];
    const r = spawnSync(process.execPath, [AGENT, "hi"], { env, encoding: "utf8", timeout: 30000 });
    const line = (r.stdout || "").split("\n").find((l) => l.startsWith("ALLOWED="));
    assert.ok(line, `no ALLOWED line; stderr:\n${r.stderr}`);
    return JSON.parse(line.slice("ALLOWED=".length));
  } finally {
    fs.rmSync(stub, { recursive: true, force: true });
  }
}

// What `ALLOWED_TOOLS: >-` with one group per line delivers to the process.
const FOLDED = "Skill,Read,Write,Edit,Glob,Grep,Agent, Bash(git *),Bash(mvn *),Bash(npm *), mcp__ado__wit_work_item, mcp__ado__wit_work_item_comment_write";

test("folded multi-line ALLOWED_TOOLS yields trimmed entries", () => {
  const tools = allowedTools({ ALLOWED_TOOLS: FOLDED });
  for (const t of tools) assert.equal(t, t.trim(), `untrimmed entry ${JSON.stringify(t)}`);
  for (const t of ["Bash(git *)", "mcp__ado__wit_work_item", "mcp__ado__wit_work_item_comment_write"]) {
    assert.ok(tools.includes(t), `missing ${t}`);
  }
});

test("spaces inside a rule are kept", () => {
  assert.ok(allowedTools({ ALLOWED_TOOLS: "Read, Bash(git diff*)" }).includes("Bash(git diff*)"));
});

test("trailing and doubled commas leave no empty entries", () => {
  const tools = allowedTools({ ALLOWED_TOOLS: "Read,,Grep, ," });
  assert.ok(!tools.includes(""), JSON.stringify(tools));
  assert.deepEqual(tools, ["Read", "Grep", "ToolSearch"]);
});

test("ToolSearch is added once, even when listed with a space", () => {
  const tools = allowedTools({ ALLOWED_TOOLS: "Read, ToolSearch" });
  assert.equal(tools.filter((t) => t.trim() === "ToolSearch").length, 1, JSON.stringify(tools));
});

test("default list when ALLOWED_TOOLS is unset", () => {
  assert.deepEqual(allowedTools({ ALLOWED_TOOLS: undefined }), ["Skill", "Read", "Glob", "Grep", "Agent", "ToolSearch"]);
});

test("configured MCP servers still get their wildcard", () => {
  const tools = allowedTools({ ALLOWED_TOOLS: FOLDED, ADO_MCP_AUTH_TOKEN: "x", ADO_ORG_NAME: "myorg" });
  assert.ok(tools.includes("mcp__ado__*"), JSON.stringify(tools));
});
