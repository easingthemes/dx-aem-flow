#!/usr/bin/env bash
# check-plugin-schema.sh — Ask Claude Code itself whether each manifest is valid.
#
# Usage: check-plugin-schema.sh [dir ...]   (default: the marketplace + all 4 plugins)
#
# Runs `claude plugin validate <dir> --json` and fails on any reported error.
# This is the schema owner's check: it catches what our greps cannot, e.g. an
# unknown hook type, a hooks.json that does not parse, an `agents` field in
# plugin.json, a non-string `version`. Warnings (unknown fields like `logo`,
# which other platforms read) are counted, not failed on.
#
# No login is needed: validation is local. Without the `claude` binary the check
# is skipped locally but FAILS under CI (CI=true) — a check that silently skips
# in CI is a check nobody runs.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"

if [ "$#" -gt 0 ]; then
  TARGETS=("$@")
else
  TARGETS=("$REPO_ROOT" "$REPO_ROOT"/plugins/*/)
fi

if ! command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
  if [ "${CI:-}" = "true" ]; then
    echo "  ERROR: '$CLAUDE_BIN' not found — CI must install Claude Code before this check"
    exit 1
  fi
  echo "  SKIP: '$CLAUDE_BIN' not installed (npm i -g @anthropic-ai/claude-code to run this check)"
  exit 0
fi

echo "  $("$CLAUDE_BIN" --version 2>/dev/null | head -1)"
errors=0
for t in "${TARGETS[@]}"; do
  t="${t%/}"
  name="${t#"$REPO_ROOT"/}"; [ "$t" = "$REPO_ROOT" ] && name="(marketplace)"
  out="$("$CLAUDE_BIN" plugin validate "$t" --json 2>/dev/null || true)"
  # One line per error, then a last line "<errors> <warnings>".
  report="$(printf '%s' "$out" | node -e '
    let s = ""; process.stdin.on("data", c => s += c).on("end", () => {
      let d; try { d = JSON.parse(s); } catch { console.log("    error: no JSON from claude plugin validate"); console.log("1 0"); return; }
      let n = 0, w = 0;
      const walk = x => {
        if (Array.isArray(x)) return x.forEach(walk);
        if (!x || typeof x !== "object") return;
        for (const e of x.errors || []) { n++; console.log(`    error: ${e.path || "-"}: ${e.message}`); }
        w += (x.warnings || []).length;
        for (const [k, v] of Object.entries(x)) if (k !== "errors" && k !== "warnings") walk(v);
      };
      walk(d);
      if (d.success === false && n === 0) { n = 1; console.log("    error: validation reported success=false"); }
      console.log(`${n} ${w}`);
    });')"
  read -r count warns <<<"$(printf '%s\n' "$report" | tail -1)"
  printf '%s\n' "$report" | sed '$d'
  if [ "$count" -gt 0 ]; then
    echo "  FAIL $name ($count error(s))"
    errors=$((errors + count))
  else
    echo "  ok   $name (${warns:-0} warning(s) — unknown fields Claude Code ignores; run claude plugin validate for detail)"
  fi
done

[ "$errors" -eq 0 ]
