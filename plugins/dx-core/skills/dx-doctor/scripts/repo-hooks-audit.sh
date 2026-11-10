#!/usr/bin/env bash
# repo-hooks-audit.sh — audit (and optionally repair) Copilot repo hooks in
# .github/hooks/*.json against what /dx-init step 9i installs today.
#
# Usage:
#   repo-hooks-audit.sh [--fix] [--template <path>] [<project-dir>]
#
# Without --fix: read-only. Prints one TSV row per finding:
#   <severity>\t<file>\t<event>\t<code>\t<detail>
# severity: error | warn ; code:
#   plugin-root        command needs PLUGIN_ROOT/COPILOT_PLUGIN_ROOT/CLAUDE_PLUGIN_ROOT —
#                      Copilot does not set these for repo hooks, so it runs
#                      `bash /hooks/...` and exits 127
#   permission-matcher matcher uses permission-rule syntax (`Bash(git commit*)`) —
#                      read as a regex against the tool name, it matches nothing
#   exit-1             command exits 1 to "block" — exit 1 is a non-blocking error
#   stale-guard        a dx branch guard that differs from the current template
#   missing-guard      hooks.json has no dx branch guard
#   missing-stop-guard hooks.json has no dx agentStop guard
#   duplicate          the same dx guard appears more than once
# Every row whose detail starts with "dx:" is a dx-installed entry --fix repairs;
# the rest are someone else's hooks and are reported for a human to fix.
#
# With --fix: rewrites only dx-installed entries, in place, in each file —
# removes plugin-root commands dx-init used to install (session-start.sh,
# next-step.sh, validate-plugin-edit.sh), replaces stale branch guards with the
# template's, drops duplicates, and adds the template's guards to hooks.json if
# missing. Unrelated hooks are never touched. Then re-runs the check and
# prints the findings left.
#
# Exit: 0 no findings left, 3 findings left, 2 usage/parse error.
# No .github/hooks directory → no output, exit 0.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FIX=0
TEMPLATE="$HERE/../../../templates/hooks/branch-guard-hooks.json.template"
DIR="."
while [ $# -gt 0 ]; do
  case "$1" in
    --fix) FIX=1 ;;
    --template) shift; TEMPLATE="${1:-}" ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) DIR="$1" ;;
  esac
  shift
done

[ -f "$TEMPLATE" ] || { echo "template not found: $TEMPLATE" >&2; exit 2; }
[ -d "$DIR/.github/hooks" ] || exit 0
command -v node >/dev/null || { echo "node is required" >&2; exit 2; }

audit() { # audit <fix 0|1>
node - "$DIR/.github/hooks" "$TEMPLATE" "$1" <<'JS'
const fs = require("fs"), path = require("path");
const [hooksDir, templatePath, fixArg] = process.argv.slice(2);
const FIX = fixArg === "1";

const KNOWN_PLUGIN_SCRIPTS = /(session-start|next-step)\.sh|validate-plugin-edit\.sh/;
const PLUGIN_ROOT = /\b(PLUGIN_ROOT|COPILOT_PLUGIN_ROOT|CLAUDE_PLUGIN_ROOT)\b/;
const GUARD = /Do not commit on/;
const STOP_GUARD = /\.claude\/hooks\/stop-guard\.sh/;
// Claude Code matcher rules: only letters/digits/_/-/space/,/| is a name list;
// `Tool(arg…)` is permission-rule syntax and never matches a tool name.
const PERMISSION_MATCHER = /^\s*[A-Za-z_][\w-]*\(.*\)\s*$/;

const cmdOf = h => [h.command, h.bash, h.powershell].filter(x => typeof x === "string").join("\n");

let template;
try { template = JSON.parse(fs.readFileSync(templatePath, "utf8")); }
catch (e) { console.error(`cannot parse template: ${e.message}`); process.exit(2); }
const tGuardGroup = template.hooks.PreToolUse.find(g => g.hooks.some(h => GUARD.test(cmdOf(h))));
const tGuard = tGuardGroup.hooks.find(h => GUARD.test(cmdOf(h)));
const tStopGroup = template.hooks.agentStop.find(g => g.hooks.some(h => STOP_GUARD.test(cmdOf(h))));

// Normalise an event's array into groups: Claude-style {matcher, hooks:[…]} or
// Copilot-native flat handlers {type, bash, …} (one handler, no matcher).
const groupsOf = arr => (Array.isArray(arr) ? arr : []).map(item =>
  Array.isArray(item?.hooks) ? { item, flat: false, handlers: item.hooks }
                             : { item, flat: true, handlers: [item] });

const files = fs.readdirSync(hooksDir).filter(f => f.endsWith(".json")).sort();
const findings = [];
let parseError = false;

for (const f of files) {
  const file = path.join(hooksDir, f);
  const rel = path.join(".github/hooks", f);
  let doc;
  try { doc = JSON.parse(fs.readFileSync(file, "utf8")); }
  catch (e) { findings.push(["error", rel, "-", "parse", `invalid JSON: ${e.message}`]); parseError = true; continue; }
  const hooks = doc && typeof doc.hooks === "object" && doc.hooks ? doc.hooks : {};
  let changed = false;
  let guards = 0, stopGuards = 0;

  for (const event of Object.keys(hooks)) {
    const out = [];
    for (const g of groupsOf(hooks[event])) {
      const isGuardGroup = g.handlers.some(h => GUARD.test(cmdOf(h)));
      const keep = [];
      for (const h of g.handlers) {
        const cmd = cmdOf(h);
        const dxGuard = GUARD.test(cmd), dxStop = STOP_GUARD.test(cmd);
        const dxPluginScript = PLUGIN_ROOT.test(cmd) && KNOWN_PLUGIN_SCRIPTS.test(cmd);

        if (dxPluginScript) {
          findings.push(["error", rel, event, "plugin-root", `dx: ${cmd.match(KNOWN_PLUGIN_SCRIPTS)[0]} needs a plugin root Copilot does not set for repo hooks (exit 127)`]);
          if (FIX) { changed = true; continue; }
        } else if (PLUGIN_ROOT.test(cmd)) {
          findings.push(["error", rel, event, "plugin-root", "command needs a plugin root Copilot does not set for repo hooks (exit 127) — fix or remove it by hand"]);
        }

        if (dxGuard) {
          guards++;
          if (guards > 1) {
            findings.push(["warn", rel, event, "duplicate", "dx: branch guard appears more than once"]);
            if (FIX) { changed = true; continue; }
          }
          const stale = cmd !== cmdOf(tGuard) || g.flat || event !== "PreToolUse" || g.item.matcher !== tGuardGroup.matcher;
          if (stale) {
            const why = [];
            if (/exit 1\b/.test(cmd)) why.push("exits 1 (does not block)");
            if (!/grep -q \\?"git commit/.test(cmd)) why.push("no git-commit filter on stdin");
            if (!g.flat && PERMISSION_MATCHER.test(g.item.matcher ?? "")) why.push(`matcher ${JSON.stringify(g.item.matcher)} is permission-rule syntax (never matches)`);
            findings.push(["error", rel, event, "stale-guard", `dx: branch guard differs from the template${why.length ? " — " + why.join("; ") : ""}`]);
          }
          keep.push(FIX && stale ? { ...tGuard } : h);
          if (FIX && stale) changed = true;
          continue;
        }
        if (dxStop) {
          stopGuards++;
          if (stopGuards > 1) {
            findings.push(["warn", rel, event, "duplicate", "dx: stop guard appears more than once"]);
            if (FIX) { changed = true; continue; }
          }
        }
        if (!dxGuard && /\bexit 1\b/.test(cmd) && />&2/.test(cmd)) {
          findings.push(["warn", rel, event, "exit-1", "command exits 1 after writing to stderr — exit 1 does not block; use exit 2 if it should"]);
        }
        keep.push(h);
      }

      if (!g.flat && !isGuardGroup && PERMISSION_MATCHER.test(g.item.matcher ?? "")) {
        findings.push(["error", rel, event, "permission-matcher", `matcher ${JSON.stringify(g.item.matcher)} is permission-rule syntax and matches no tool — put the tool name in matcher and filter in the command`]);
      }
      if (keep.length === 0) continue;               // group emptied by --fix
      if (g.flat) { out.push(keep[0]); continue; }
      const item = { ...g.item, hooks: keep };
      // A replaced guard brings the template's matcher with it.
      if (FIX && isGuardGroup && keep.some(h => cmdOf(h) === cmdOf(tGuard))) item.matcher = tGuardGroup.matcher;
      out.push(item);
    }
    if (FIX) {
      if (out.length) hooks[event] = out; else { delete hooks[event]; changed = true; }
    }
  }

  // A guard filed under the wrong event (e.g. a flat handler) is re-homed by the
  // stale-guard replacement above only within its event; move it to PreToolUse.
  if (FIX) {
    for (const event of Object.keys(hooks)) {
      if (event === "PreToolUse") continue;
      const moved = hooks[event].filter(g => groupsOf([g])[0].handlers.some(h => GUARD.test(cmdOf(h))));
      if (!moved.length) continue;
      hooks[event] = hooks[event].filter(g => !moved.includes(g));
      if (!hooks[event].length) delete hooks[event];
      if (!(hooks.PreToolUse || []).some(g => groupsOf([g])[0].handlers.some(h => GUARD.test(cmdOf(h)))))
        (hooks.PreToolUse ||= []).push(JSON.parse(JSON.stringify(tGuardGroup)));
      changed = true;
    }
  }

  if (f === "hooks.json") {
    if (guards === 0) {
      findings.push(["error", rel, "PreToolUse", "missing-guard", "dx: no branch guard"]);
      if (FIX) { (hooks.PreToolUse ||= []).push(JSON.parse(JSON.stringify(tGuardGroup))); changed = true; }
    }
    if (stopGuards === 0) {
      findings.push(["warn", rel, "agentStop", "missing-stop-guard", "dx: no agentStop guard"]);
      if (FIX) { (hooks.agentStop ||= []).push(JSON.parse(JSON.stringify(tStopGroup))); changed = true; }
    }
  }

  if (FIX && changed) {
    doc.hooks = hooks;
    if (doc.version === undefined) doc = { version: 1, ...doc };
    fs.writeFileSync(file, JSON.stringify(doc, null, 2) + "\n");
  }
}

if (FIX) process.exit(parseError ? 2 : 0);   // findings come from the re-check
for (const r of findings) console.log(r.join("\t"));
process.exit(parseError ? 2 : findings.length ? 3 : 0);
JS
}

if [ "$FIX" = 1 ]; then
  audit 1 || exit $?
fi
audit 0
