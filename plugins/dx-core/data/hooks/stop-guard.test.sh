#!/usr/bin/env bash
# stop-guard.test.sh — Watch the Stop guard block, and let go.
#
# Claude Code sends stop_hook_active=true on the retry after a block, so the
# guard lets the agent stop. Copilot CLI's agentStop input has no such field and
# only overrides a blocking hook after 8 consecutive blocks (TODO-262). The
# guard therefore remembers its last block in the git dir and never blocks the
# same findings twice in a row.
# Hermetic: throwaway git repos, no global git config, no network.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GUARD="$HERE/stop-guard.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

PASS=0; FAIL=0
check() { # check <label> <want> <got>
  if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS + 1)); else echo "FAIL $1 (want $2, got $3)"; FAIL=$((FAIL + 1)); fi
}

repo() { # repo → path with one commit
  local d; d="$(mktemp -d "$TMP/r-XXXXXX")"
  git -C "$d" init -q -b main
  git -C "$d" config user.email bot@example.com
  git -C "$d" config user.name bot
  echo "a" > "$d/app.js"
  git -C "$d" add app.js && git -C "$d" commit -q -m init
  echo "$d"
}

run() { # run <repo> [stop_hook_active] → "block" | "allow" | "exit<N>"
  local out rc input
  if [ -n "${2:-}" ]; then
    input="{\"cwd\":\"$1\",\"stop_hook_active\":$2}"
  else
    input="{\"cwd\":\"$1\"}"   # Copilot agentStop shape: no stop_hook_active
  fi
  out="$(printf '%s' "$input" | bash "$GUARD" 2>/dev/null)"; rc=$?
  [ "$rc" -ne 0 ] && { echo "exit$rc"; return; }
  if printf '%s' "$out" | jq -e '.decision == "block"' >/dev/null 2>&1; then echo block; else echo allow; fi
}

# 1. Clean repo → allow
r="$(repo)"
check "clean repo allows" allow "$(run "$r")"

# 2. Dirty source, Copilot shape → block once, then allow (no 8-block loop)
echo "b" >> "$r/app.js"
check "dirty: first stop blocks" block "$(run "$r")"
check "dirty: same findings allow" allow "$(run "$r")"
check "dirty: state cleared after allow" no "$([ -f "$r/.git/dx-stop-guard.last" ] && echo yes || echo no)"
check "dirty: next stop blocks again" block "$(run "$r")"

# 3. Findings change → block again even inside the window
r2="$(repo)"
echo "b" >> "$r2/app.js"
check "changed: first block" block "$(run "$r2")"
echo "x" > "$r2/other.js"; git -C "$r2" add other.js; git -C "$r2" commit -q -m other
echo "y" >> "$r2/other.js"
check "changed: new findings block" block "$(run "$r2")"

# 4. Stale state (outside window) → block
r3="$(repo)"
echo "b" >> "$r3/app.js"
check "stale: first block" block "$(run "$r3")"
sig=none; read -r sig _ < "$r3/.git/dx-stop-guard.last" 2>/dev/null || true
echo "$sig 1" > "$r3/.git/dx-stop-guard.last"
check "stale: old state does not allow" block "$(run "$r3")"

# 5. Claude Code shape: stop_hook_active=true → allow at once
r4="$(repo)"
echo "b" >> "$r4/app.js"
check "claude: stop_hook_active allows" allow "$(run "$r4" true)"
check "claude: stop_hook_active=false blocks" block "$(run "$r4" false)"

# 6. Clean again after a block → state removed
git -C "$r4" checkout -q -- app.js
check "cleaned: allows" allow "$(run "$r4")"
check "cleaned: state removed" no "$([ -f "$r4/.git/dx-stop-guard.last" ] && echo yes || echo no)"

# 7. Garbage input / not a repo → allow, exit 0
check "non-JSON input allows" allow "$(printf 'not json' | (cd "$TMP" && bash "$GUARD") >/dev/null 2>&1 && echo allow || echo fail)"
check "not a git repo allows" allow "$(run "$TMP")"

echo "stop-guard: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
