#!/usr/bin/env bash
# stop-guard.test.sh — Watch the Stop guard block, and let go.
#
# Claude Code and Copilot CLI send stop_hook_active=true on the call after a
# block, so the guard lets the agent stop. As a backup for a host that omits the
# field (Copilot overrides a blocking hook only after 8 blocks, TODO-262), the
# guard remembers its last block in the git dir and never blocks the same
# findings twice in a row.
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
    input="{\"cwd\":\"$1\"}"   # host that omits stop_hook_active
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

# 6b. Conflict check: only real markers (line start + space) count. A changed
#     file that merely contains the marker text — stop-guard.sh itself, whose
#     own grep pattern holds it — must not be reported as a conflict.
reason() { printf '{"cwd":"%s"}' "$1" | bash "$GUARD" 2>/dev/null | jq -r '.reason // ""'; }
r5="$(repo)"
printf 'x\n' > "$r5/guard.sh"; git -C "$r5" add guard.sh; git -C "$r5" commit -q -m g
printf "x | xargs grep -l '<<<<<<<'\n" > "$r5/guard.sh"
check "marker text mid-line is not a conflict" no "$(reason "$r5" | grep -q 'merge conflicts' && echo yes || echo no)"
r6="$(repo)"
printf '<<<<<<< HEAD\na\n=======\nb\n>>>>>>> other\n' > "$r6/app.js"
check "real conflict markers are reported" yes "$(reason "$r6" | grep -q 'merge conflicts' && echo yes || echo no)"

# 8. Plan check: only the active ticket's plan counts, and a written reason
#    acknowledges a blocked step.
plan() { # plan <repo> <dir> <status> [reason] → writes .ai/specs/<dir>/implement.md
  mkdir -p "$1/.ai/specs/$2"
  { printf '# Implementation Plan: x\n\n**Status:** In Progress\n\n### Step 1: a\n**Status:** done\n\n### Step 2: b\n**Status:** %s\n' "$3"
    [ -n "${4:-}" ] && printf '**Blocked:** %s\n' "$4"; true; } > "$1/.ai/specs/$2/implement.md"
}
says() { rm -f "$1/.git/dx-stop-guard.last"; reason "$1" | grep -q "$2" && echo yes || echo no; }   # fresh state: no repeat-suppression
r7="$(repo)"; git -C "$r7" checkout -q -b feature/111-mine
plan "$r7" 111-mine done
plan "$r7" 222-other blocked; touch "$r7/.ai/specs/222-other/implement.md"   # newest file, other story
git -C "$r7" add -A && git -C "$r7" commit -q -m plans
check "plan: other story's blocked step ignored" no "$(says "$r7" blocked)"
plan "$r7" 111-mine blocked
check "plan: own blocked step, no reason, reported" yes "$(says "$r7" '111-mine/implement.md with no reason')"
plan "$r7" 111-mine blocked "manual QA on stage, waiting for content"
check "plan: own blocked step with reason accepted" no "$(says "$r7" blocked)"
plan "$r7" 111-mine in-progress
check "plan: own in-progress step reported" yes "$(says "$r7" 'in-progress in 111-mine')"
r8="$(repo)"   # main branch: only a changed plan counts
plan "$r8" 333-x blocked; git -C "$r8" add -A && git -C "$r8" commit -q -m p
check "plan: off-ticket, unchanged plan ignored" no "$(says "$r8" blocked)"
printf '\n' >> "$r8/.ai/specs/333-x/implement.md"
check "plan: off-ticket, changed plan checked" yes "$(says "$r8" '333-x/implement.md')"

# 7. Garbage input / not a repo → allow, exit 0
check "non-JSON input allows" allow "$(printf 'not json' | (cd "$TMP" && bash "$GUARD") >/dev/null 2>&1 && echo allow || echo fail)"
check "not a git repo allows" allow "$(run "$TMP")"

echo "stop-guard: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
