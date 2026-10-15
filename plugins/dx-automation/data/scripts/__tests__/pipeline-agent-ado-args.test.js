// pipeline-agent-ado-args.test.js — the ADO MCP server gets the domains we think.
//
// Runs the real pipeline-agent.js with a stub @anthropic-ai/claude-agent-sdk
// whose query() prints the options it was handed and exits, so no API call,
// no ADO and no network. TODO #233.
//
// Why each domain must be its own argv entry: @azure-devops/mcp declares
// `domains` as a yargs array option, so `-d "a,b"` arrives as ONE invalid name
// and the server silently falls back to loading every domain.

const { test } = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const AGENT = path.join(__dirname, "..", "pipeline-agent.js");

function adoArgs(extraEnv) {
  const stub = fs.mkdtempSync(path.join(os.tmpdir(), "sdk-stub-"));
  const dir = path.join(stub, "node_modules", "@anthropic-ai", "claude-agent-sdk");
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, "package.json"), '{"name":"@anthropic-ai/claude-agent-sdk","main":"index.js"}');
  fs.writeFileSync(path.join(dir, "index.js"),
    'exports.query = ({ options }) => { process.stdout.write("ADO_ARGS=" + JSON.stringify((options.mcpServers.ado || {}).args || null) + "\\n"); process.exit(0); };');
  try {
    const r = spawnSync(process.execPath, [AGENT, "hi"], {
      env: { PATH: process.env.PATH, HOME: stub, NODE_PATH: path.join(stub, "node_modules"),
             ADO_MCP_AUTH_TOKEN: "x", ADO_ORG_NAME: "myorg", ...extraEnv },
      encoding: "utf8", timeout: 30000,
    });
    const line = (r.stdout || "").split("\n").find((l) => l.startsWith("ADO_ARGS="));
    assert.ok(line, `no ADO_ARGS line; stderr:\n${r.stderr}`);
    return JSON.parse(line.slice("ADO_ARGS=".length));
  } finally {
    fs.rmSync(stub, { recursive: true, force: true });
  }
}

const domainsOf = (args) => args.slice(args.indexOf("-d") + 1);

test("ADO MCP version is pinned", () => {
  assert.match(adoArgs({})[1], /^@azure-devops\/mcp@\d+\.\d+\.\d+$/);
});

test("default domains drop pipelines, test-plans and advanced-security", () => {
  const d = domainsOf(adoArgs({}));
  assert.deepEqual(d, ["core", "work", "work-items", "search", "repositories", "wiki"]);
  for (const risky of ["pipelines", "test-plans", "advanced-security"]) assert.ok(!d.includes(risky), risky);
});

test("each domain is its own argv entry, and -d comes last", () => {
  const args = adoArgs({ ADO_MCP_DOMAINS: "core, work-items,wiki" });
  assert.deepEqual(domainsOf(args), ["core", "work-items", "wiki"]);
  assert.ok(domainsOf(args).every((d) => !d.includes(",")));
});

test("ADO_MCP_DOMAINS=all restores every domain", () => {
  assert.deepEqual(domainsOf(adoArgs({ ADO_MCP_DOMAINS: "all" })), ["all"]);
});
