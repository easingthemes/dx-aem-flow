#!/usr/bin/env bash
# playwright-owner-audit.test.sh — the audit dx-doctor runs read-only and
# dx-upgrade runs with --fix, after the playwright MCP server moved from dx-aem
# to dx-core. Every check also has a known-bad or known-clean counterpart, so a
# blind check shows up. Hermetic: temp dirs only, no network.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
AUDIT="$HERE/../playwright-owner-audit.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
OLD='mcp__plugin_dx-aem''_playwright'   # split: repo-wide grep for it should find only history

PASS=0; FAIL=0
check() { # check <label> <want> <got>
  if [ "$2" = "$3" ]; then echo "  ok   $1"; PASS=$((PASS+1)); else echo "  FAIL $1 (want [$2], got [$3])"; FAIL=$((FAIL+1)); fi
}

seed() { # seed <dir> — a project with old names in all three places + a foreign server
  mkdir -p "$1/.claude" "$1/.github/agents"
  cat > "$1/.claude/settings.json" <<'JSON'
{
  "permissions": {
    "allow": [
      "@OLD@__browser_navigate",
      "@OLD@",
      "mcp__plugin_dx-aem_AEM__getNodeContent",
      "@OLD@-extra__thing"
    ]
  }
}
JSON
  cat > "$1/.claude/settings.local.json" <<'JSON'
{ "permissions": { "allow": ["@OLD@__browser_take_screenshot"] } }
JSON
  cat > "$1/.github/agents/AEMVerify.agent.md" <<'MD'
---
name: AEMVerify
tools:
  - '@OLD@__browser_snapshot'
  - 'AEM/getNodeContent'
---
Call @OLD@__browser_click.
MD
  cat > "$1/.github/agents/Clean.agent.md" <<'MD'
---
name: Clean
tools: ['mcp__plugin_dx-core_playwright__browser_navigate']
---
MD
  for f in "$1/.claude/settings.json" "$1/.claude/settings.local.json" "$1/.github/agents/AEMVerify.agent.md"; do
    sed "s/@OLD@/$OLD/g" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  done
}

# 1. Clean project → no output, exit 0
P="$TMP/clean"; mkdir -p "$P/.claude"; echo '{"permissions":{"allow":["mcp__plugin_dx-core_playwright__browser_navigate"]}}' > "$P/.claude/settings.json"
out="$(bash "$AUDIT" "$P")"; rc=$?
check "clean: exit 0" 0 "$rc"
check "clean: no output" "" "$out"

# 2. No .claude / .github at all → exit 0
P="$TMP/empty"; mkdir -p "$P"
bash "$AUDIT" "$P" >/dev/null; check "empty project: exit 0" 0 "$?"

# 3. Audit finds old names, does not touch files
P="$TMP/old"; seed "$P"
before="$(cat "$P/.claude/settings.json")"
out="$(bash "$AUDIT" "$P")"; rc=$?
check "audit: exit 3" 3 "$rc"
check "audit: settings.json count" ".claude/settings.json	2" "$(echo "$out" | grep '^.claude/settings.json')"
check "audit: settings.local.json count" ".claude/settings.local.json	1" "$(echo "$out" | grep 'settings.local')"
check "audit: agent count" ".github/agents/AEMVerify.agent.md	2" "$(echo "$out" | grep AEMVerify)"
check "audit: clean agent not listed" 0 "$(echo "$out" | grep -c Clean)"
check "audit: read-only" "$before" "$(cat "$P/.claude/settings.json")"

# 4. --fix rewrites only the old owner
out="$(bash "$AUDIT" --fix "$P")"; rc=$?
check "fix: exit 0" 0 "$rc"
check "fix: reports 3 files" 3 "$(echo "$out" | grep -c '^fixed')"
check "fix: no old names left" 0 "$(grep -rc "$OLD\(__\|\"\|\$\)" "$P/.claude" "$P/.github" | awk -F: '{s+=$2} END {print s}')"
check "fix: tool name rewritten" 1 "$(grep -c '"mcp__plugin_dx-core_playwright__browser_navigate"' "$P/.claude/settings.json")"
check "fix: bare server rewritten" 1 "$(grep -c '"mcp__plugin_dx-core_playwright"' "$P/.claude/settings.json")"
check "fix: AEM server untouched" 1 "$(grep -c 'mcp__plugin_dx-aem_AEM__getNodeContent' "$P/.claude/settings.json")"
check "fix: other server untouched" 1 "$(grep -c "$OLD-extra__thing" "$P/.claude/settings.json")"
check "fix: prose in agent body rewritten" 1 "$(grep -c 'Call mcp__plugin_dx-core_playwright__browser_click' "$P/.github/agents/AEMVerify.agent.md")"
node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$P/.claude/settings.json" 2>/dev/null
check "fix: settings.json still valid JSON" 0 "$?"

# 5. Second --fix and a re-audit are no-ops
out="$(bash "$AUDIT" --fix "$P")"; check "fix twice: no output" "" "$out"
bash "$AUDIT" "$P" >/dev/null; check "re-audit after fix: exit 0" 0 "$?"

# 6. Usage error
bash "$AUDIT" --bogus >/dev/null 2>&1; check "unknown option: exit 2" 2 "$?"

echo "playwright-owner-audit: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
