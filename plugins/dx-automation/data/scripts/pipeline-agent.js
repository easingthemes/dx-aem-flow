/**
 * Universal pipeline runner using Claude Agent SDK.
 * Plain Node.js — no TypeScript, no tsx dependency.
 *
 * Usage:
 *   node pipeline-agent.js "<prompt>"
 *
 * Environment variables:
 *   ANTHROPIC_API_KEY     - required
 *   ADO_MCP_AUTH_TOKEN    - enables ADO MCP server with token auth
 *   AEM_INSTANCES          - enables AEM MCP server (e.g. local:http://localhost:4502:admin:admin,qa:https://qa-host:user:pass)
 *   AEM_AUTHOR_URL         - (pipeline) AEM author URL — composed into AEM_INSTANCES if AEM_INSTANCES is not set
 *   AEM_USER / AEM_PASS    - (pipeline) AEM credentials — composed into AEM_INSTANCES if AEM_INSTANCES is not set
 *   MAX_TURNS             - default: 30
 *   TIMEOUT_MINUTES       - default: 60 (kills process after N minutes)
 *   ALLOWED_TOOLS         - comma-separated, default: Skill,Read,Glob,Grep,Agent
 *                           ToolSearch is always added (subagents need it).
 *                           MCP wildcards are auto-added for configured servers.
 *   CLAUDE_MODEL          - optional model override
 *   PLUGIN_BASE_DIR       - path to plugins dir, default: ./dx-aem-flow/dx/plugins
 */

const { query } = require("@anthropic-ai/claude-agent-sdk");
const fs = require("fs");
const path = require("path");

// --- Args ---
const prompt = process.argv[2];
if (!prompt) {
  process.stderr.write("Usage: pipeline-agent.js <prompt>\n");
  process.exit(1);
}

const maxTurns = parseInt(process.env.MAX_TURNS || "30", 10);
const timeoutMinutes = parseInt(process.env.TIMEOUT_MINUTES, 10) || 60;
const allowedTools = (process.env.ALLOWED_TOOLS || "Skill,Read,Glob,Grep,Agent").split(",");

// Always include ToolSearch — subagents need it to discover deferred tools
if (!allowedTools.includes("ToolSearch")) allowedTools.push("ToolSearch");

// --- Timeout ---
const timeoutMs = timeoutMinutes * 60 * 1000;
const timer = setTimeout(() => {
  process.stderr.write(`\n--- timeout: killed after ${timeoutMinutes} minutes ---\n`);
  process.exit(2);
}, timeoutMs);
timer.unref();

// --- Discover plugins ---
const pluginBaseDir = process.env.PLUGIN_BASE_DIR || "./dx-aem-flow/dx/plugins";
const pluginNames = ["dx-core", "dx-aem", "dx-automation"];
const plugins = pluginNames
  .map((name) => path.resolve(pluginBaseDir, name))
  .filter((p) => fs.existsSync(p))
  .map((p) => ({ type: "local", path: p }));

// --- MCP servers ---
const mcpServers = {};
if (process.env.ADO_MCP_AUTH_TOKEN) {
  mcpServers.ado = {
    command: "npx",
    args: ["-y", "@azure-devops/mcp", process.env.ADO_ORG_NAME || "myorg", "--authentication", "envvar"],
    env: { ADO_MCP_AUTH_TOKEN: process.env.ADO_MCP_AUTH_TOKEN },
  };
}
// Build AEM_INSTANCES from individual vars (pipeline) or use pre-composed value (local dev)
let aemInstances = process.env.AEM_INSTANCES || "";
if (!aemInstances && process.env.AEM_AUTHOR_URL && process.env.AEM_USER) {
  aemInstances = `qa:${process.env.AEM_AUTHOR_URL}:${process.env.AEM_USER}:${process.env.AEM_PASS || ""}`;
}
if (aemInstances) {
  mcpServers.AEM = {
    command: "npx",
    args: ["-y", "aem-mcp-server", "-t", "stdio", "-I", aemInstances],
  };
}

// --- Auto-allow MCP tools for configured servers ---
// SDK requires explicit allowedTools for MCP (unlike CLI which bypasses).
// Add wildcard for each configured server + plugin MCP servers.
for (const name of Object.keys(mcpServers)) {
  const wildcard = `mcp__${name}__*`;
  if (!allowedTools.includes(wildcard)) allowedTools.push(wildcard);
}
// Plugin MCP servers get prefixed as mcp__plugin_<plugin>_<server>__*
// Allow all plugin MCP tools with a broad wildcard
if (plugins.length > 0) {
  const pluginWildcard = "mcp__plugin_*";
  if (!allowedTools.includes(pluginWildcard)) allowedTools.push(pluginWildcard);
}

// --- Logging ---
const log = process.stderr;

let totalIn = 0;
let totalOut = 0;
let totalCacheRead = 0;
let totalCacheWrite = 0;

// --- Per-skill token tracking ---
const skillTokens = {}; // { skillName: { in, out, cacheRead, cacheWrite, turns } }
let currentSkill = null; // name of skill currently executing (null = main agent)
let turnNumber = 0;

function getSkillBucket(name) {
  if (!skillTokens[name]) skillTokens[name] = { in: 0, out: 0, cacheRead: 0, cacheWrite: 0, turns: 0 };
  return skillTokens[name];
}

function trackTurnTokens(usage) {
  if (!usage) return;
  const inp = usage.input_tokens || 0;
  const out = usage.output_tokens || 0;
  const cr = usage.cache_read_input_tokens || 0;
  const cw = usage.cache_creation_input_tokens || 0;

  totalIn += inp;
  totalOut += out;
  totalCacheRead += cr;
  totalCacheWrite += cw;
  turnNumber++;

  // Attribute to current skill or "main"
  const bucket = getSkillBucket(currentSkill || "(main)");
  bucket.in += inp;
  bucket.out += out;
  bucket.cacheRead += cr;
  bucket.cacheWrite += cw;
  bucket.turns++;

  // Log per-turn token usage (compact)
  const label = currentSkill ? `[turn ${turnNumber} | ${currentSkill}]` : `[turn ${turnNumber}]`;
  log.write(`${prefix()}${label} ${fmtTokens(inp, out, cr, cw)}\n`);
}

function fmtTokens(inp, out, cr, cw) {
  const parts = [`${inp.toLocaleString()}in`, `${out.toLocaleString()}out`];
  if (cr) parts.push(`${cr.toLocaleString()}cached`);
  if (cw) parts.push(`${cw.toLocaleString()}cache-write`);
  return parts.join(" + ");
}

function printTokenBreakdown() {
  const entries = Object.entries(skillTokens).sort((a, b) => b[1].in - a[1].in);
  if (entries.length === 0) return;

  log.write("\n--- token breakdown by skill ---\n");
  const hdr = "Skill".padEnd(35) + "Input".padStart(12) + "Output".padStart(10) + "Cached".padStart(12) + "Turns".padStart(7);
  log.write(hdr + "\n");
  log.write("-".repeat(hdr.length) + "\n");
  for (const [name, t] of entries) {
    log.write(
      name.padEnd(35) +
      t.in.toLocaleString().padStart(12) +
      t.out.toLocaleString().padStart(10) +
      t.cacheRead.toLocaleString().padStart(12) +
      String(t.turns).padStart(7) +
      "\n"
    );
  }
  log.write("-".repeat(hdr.length) + "\n");
}

function formatToolInput(name, input) {
  if (!input) return "";
  if (name === "Skill") return [input.skill, input.args].filter(Boolean).join(" ");
  if (name === "Agent") {
    const p = input.prompt || input.task || "";
    return p.length > 120 ? p.slice(0, 120) + "..." : p;
  }
  if (name === "Read") return input.file_path || "";
  if (name === "Write" || name === "Edit") return input.file_path || "";
  if (name === "Glob") return input.pattern || "";
  if (name === "Grep") {
    const parts = [input.pattern];
    if (input.path) parts.push(`in ${input.path}`);
    return parts.join(" ");
  }
  if (name === "ToolSearch") return input.query || "";
  if (name === "Bash" || (typeof name === "string" && name.startsWith("Bash("))) {
    const cmd = input.command || "";
    return cmd.length > 120 ? cmd.slice(0, 120) + "..." : cmd;
  }
  // MCP tools — show compact JSON
  if (name.startsWith("mcp__")) {
    const short = name.replace(/^mcp__ado__/, "ado/").replace(/^mcp__/, "");
    const json = JSON.stringify(input);
    return `[${short}] ${json.length > 100 ? json.slice(0, 100) + "..." : json}`;
  }
  const json = JSON.stringify(input);
  return json.length > 120 ? json.slice(0, 120) + "..." : json;
}

// --- Streaming state ---
let currentToolName = null;
let currentToolInput = "";
let isSubagent = false; // tracks if current stream_event is from a subagent
let messageCount = 0;
let lastLogTime = Date.now();

// Set of tool_use IDs we've already logged via stream_event (to avoid double-logging)
const streamedToolIds = new Set();

// ToolSearch loop detection — catch agents stuck searching for unavailable tools
let consecutiveToolSearches = 0;
const MAX_CONSECUTIVE_TOOL_SEARCHES = 6;

function prefix() {
  return isSubagent ? "  " : "";
}

// Heartbeat — prints a status line every 60s of silence so ADO knows we're alive
const heartbeat = setInterval(() => {
  const silenceSec = Math.round((Date.now() - lastLogTime) / 1000);
  if (silenceSec >= 55) {
    log.write(`[heartbeat] alive, ${messageCount} messages, ${silenceSec}s since last log\n`);
    lastLogTime = Date.now();
  }
}, 60000);
heartbeat.unref();

function flushTool() {
  if (!currentToolName) return;
  let inp = "";
  let parsed = null;
  try {
    if (currentToolInput) {
      parsed = JSON.parse(currentToolInput);
      inp = formatToolInput(currentToolName, parsed);
    }
  } catch (_) {
    // partial JSON — show raw truncated
    inp = currentToolInput.length > 80 ? currentToolInput.slice(0, 80) + "..." : currentToolInput;
  }
  log.write(inp ? `${prefix()}-> ${currentToolName}: ${inp}\n` : `${prefix()}-> ${currentToolName}\n`);

  // Track Skill start for token attribution
  if (currentToolName === "Skill" && parsed && parsed.skill) {
    currentSkill = parsed.skill;
  }

  // Track consecutive ToolSearch calls — detect agents stuck in search loops
  if (currentToolName === "ToolSearch") {
    consecutiveToolSearches++;
    if (consecutiveToolSearches >= MAX_CONSECUTIVE_TOOL_SEARCHES) {
      log.write(`\n--- error: ToolSearch loop detected (${consecutiveToolSearches} consecutive searches). MCP server likely failed to start. Check ADO_MCP_AUTH_TOKEN and MCP server config. ---\n`);
      clearTimeout(timer);
      clearInterval(heartbeat);
      process.exit(1);
    }
  } else {
    consecutiveToolSearches = 0;
  }

  currentToolName = null;
  currentToolInput = "";
}

// --- Startup info ---
log.write(`[sdk] prompt: ${prompt}\n`);
log.write(`[sdk] plugins: ${plugins.map((p) => path.basename(p.path)).join(", ") || "none"}\n`);
log.write(`[sdk] mcp: ${Object.keys(mcpServers).join(", ") || "none"}\n`);
log.write(`[sdk] maxTurns: ${maxTurns}, timeout: ${timeoutMinutes}m, tools: ${allowedTools.join(",")}\n`);

// --- Build options ---
const options = {
  cwd: process.cwd(),
  settingSources: ["user", "project"],
  maxTurns,
  allowedTools,
  plugins,
  mcpServers,
  permissionMode: "bypassPermissions",
  allowDangerouslySkipPermissions: true,
  includePartialMessages: true,
};
if (process.env.CLAUDE_MODEL) {
  options.model = process.env.CLAUDE_MODEL;
}

// --- Run ---
(async () => {
  let gotResult = false;

  try {
    for await (const message of query({ prompt, options })) {
      const type = message.type;
      messageCount++;
      lastLogTime = Date.now();

      // Track subagent context
      if (message.parent_tool_use_id) {
        isSubagent = true;
      } else if (type !== "stream_event") {
        isSubagent = false;
      }

      if (type === "system") {
        const sub = message.subtype;
        if (sub === "init") {
          const version = message.claude_code_version || message.claudeCodeVersion || "?";
          const model = message.model || "?";
          log.write(`\n${prefix()}=== Claude Code v${version} | ${model} ===\n\n`);
        }

      } else if (type === "stream_event") {
        const event = message.event;
        if (!event) continue;

        // Track subagent from stream events
        if (message.parent_tool_use_id) isSubagent = true;

        if (event.type === "content_block_start") {
          // Flush any pending tool before starting a new block
          flushTool();
          const block = event.content_block;
          if (block && block.type === "tool_use") {
            currentToolName = block.name;
            currentToolInput = "";
            if (block.id) streamedToolIds.add(block.id);
            // Note: Skill name tracking happens in flushTool after JSON is complete
          }
        } else if (event.type === "content_block_delta") {
          const delta = event.delta;
          if (delta && delta.type === "text_delta") {
            // Flush any pending tool before text
            flushTool();
            log.write(prefix() + delta.text);
          } else if (delta && delta.type === "input_json_delta") {
            currentToolInput += delta.partial_json || "";
          }
        } else if (event.type === "content_block_stop") {
          flushTool();
        } else if (event.type === "message_delta") {
          trackTurnTokens(event.usage);
        }

      } else if (type === "assistant") {
        const inner = message.message || {};
        const usage = inner.usage;
        if (usage && !options.includePartialMessages) {
          trackTurnTokens(usage);
        }
        // Detect rate_limit or other SDK-level errors on assistant messages
        if (message.error) {
          log.write(`${prefix()}!! assistant error: ${message.error}\n`);
        }

        // Log tool calls and text from assistant messages that weren't already streamed
        // This catches subagent activity that the SDK doesn't forward as stream_events
        const content = inner.content || [];
        for (const block of content) {
          if (block.type === "tool_use") {
            // Track Skill start for token attribution
            if (block.name === "Skill" && block.input && block.input.skill) {
              currentSkill = block.input.skill;
            }
            if (!streamedToolIds.has(block.id)) {
              const inp = formatToolInput(block.name, block.input);
              log.write(inp ? `${prefix()}-> ${block.name}: ${inp}\n` : `${prefix()}-> ${block.name}\n`);
            }
          } else if (block.type === "text" && !streamedToolIds.size && message.parent_tool_use_id) {
            // Subagent text that wasn't streamed — show it
            const text = block.text || "";
            if (text.trim()) log.write(prefix() + text + "\n");
          }
        }

      } else if (type === "tool_result") {
        // Skill finished — clear context so next turns attribute to main
        if (message.tool_name === "Skill" || (!message.parent_tool_use_id && currentSkill)) {
          currentSkill = null;
        }
        // Tool results — log errors/failures
        if (message.is_error || message.error) {
          const errText = message.error || (message.content && typeof message.content === "string" ? message.content : "");
          log.write(`${prefix()}!! tool error: ${errText.length > 200 ? errText.slice(0, 200) + "..." : errText}\n`);
        }

      } else if (type === "result") {
        gotResult = true;
        clearTimeout(timer);
        clearInterval(heartbeat);
        const turns = message.num_turns ?? "?";
        const cost = message.total_cost_usd != null
          ? `$${message.total_cost_usd.toFixed(4)}`
          : "$?";
        const status = message.subtype === "success" ? "done" : message.subtype || "unknown";

        // Use authoritative totals from result.usage
        const ru = message.usage;
        if (ru) {
          totalIn = ru.input_tokens || totalIn;
          totalOut = ru.output_tokens || totalOut;
          totalCacheRead = ru.cache_read_input_tokens || totalCacheRead;
          totalCacheWrite = ru.cache_creation_input_tokens || totalCacheWrite;
        }

        // Per-run cost alert
        const costLimit = parseFloat(process.env.COST_ALERT_USD || "4.00");
        if (message.total_cost_usd != null && message.total_cost_usd > costLimit) {
          log.write(`\n!! COST ALERT: run cost ${cost} exceeds $${costLimit.toFixed(2)} limit. Review token breakdown below.\n`);
        }

        printTokenBreakdown();
        log.write(
          `\n--- ${status}: ${turns} turns, ${cost}, ${fmtTokens(totalIn, totalOut, totalCacheRead, totalCacheWrite)} ---\n`
        );

        if (message.subtype !== "success") {
          process.exit(1);
        }

      } else if (type === "rate_limit_event") {
        // SDK emits this on rate limit — log explicitly for diagnostics
        const info = message.rate_limit_info || {};
        log.write(`${prefix()}[rate-limit] status=${info.status || "?"}, resets=${info.resetsAt || "?"}, utilization=${info.utilization || "?"}\n`);

      } else {
        // Catch-all: log unknown message types so nothing is invisible
        const sub = message.subtype ? ` (${message.subtype})` : "";
        const pid = message.parent_tool_use_id ? " [subagent]" : "";
        log.write(`${prefix()}[${type}${sub}${pid}]\n`);
      }
    }
  } catch (err) {
    clearInterval(heartbeat);
    log.write(`\n--- error: ${err.message || err} ---\n`);
    process.exit(1);
  }

  clearTimeout(timer);
  clearInterval(heartbeat);

  if (!gotResult) {
    log.write("\n--- error: session ended without result message ---\n");
    process.exit(1);
  }
})();
