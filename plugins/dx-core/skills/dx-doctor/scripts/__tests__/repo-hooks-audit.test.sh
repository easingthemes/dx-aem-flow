#!/usr/bin/env bash
# repo-hooks-audit.test.sh — the Copilot repo-hooks template /dx-init 9i installs,
# and repo-hooks-audit.sh, which dx-doctor runs read-only and dx-upgrade with --fix.
#
# 1. The template is self-contained: no PLUGIN_ROOT (Copilot does not set it for
#    .github/hooks commands, so `bash /hooks/...` exits 127), and its branch guard
#    blocks `git commit` on main with exit 2 — run, not grepped.
# 2. The audit flags the shapes older /dx-init installs wrote (plugin-root
#    commands, `Bash(git commit*)` matcher, exit 1, no stdin filter), plus foreign
#    hooks with the same defects; --fix repairs only dx entries and leaves the
#    foreign ones byte-identical; a second --fix is a no-op.
# Every check also runs against a known-bad input so a blind check shows up.
# Hermetic: throwaway dirs and git repos, no global git config, no network.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
AUDIT="$HERE/../repo-hooks-audit.sh"
TEMPLATE="$(cd "$HERE/../../../../templates/hooks" && pwd)/branch-guard-hooks.json.template"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

PASS=0; FAIL=0
check() { # check <label> <want> <got>
  if [ "$2" = "$3" ]; then echo "  ok   $1"; PASS=$((PASS+1)); else echo "  FAIL $1 (want [$2], got [$3])"; FAIL=$((FAIL+1)); fi
}

# --- helpers -----------------------------------------------------------------
no_plugin_root() { grep -qE 'PLUGIN_ROOT' "$1" && echo 0 || echo 1; }

guard_cmd() { # guard_cmd <hooks.json> → the branch guard command
  node -e '
    const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    for (const g of d.hooks.PreToolUse || []) for (const h of g.hooks || [])
      if (/Do not commit on/.test(h.command)) { process.stdout.write(h.command); process.exit(0); }
    process.exit(1);' "$1"
}

guard_exit() { # guard_exit <hooks.json> <branch> <tool command> → exit code
  local d cmd; d="$(mktemp -d "$TMP/r-XXXXXX")"; git -C "$d" init -q -b "$2"
  cmd="$(guard_cmd "$1")" || { echo none; return; }
  (cd "$d" && printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$3" | bash -c "$cmd" >/dev/null 2>&1); echo $?
}

project() { # project <name> → dir with .github/hooks/
  local p="$TMP/$1"; mkdir -p "$p/.github/hooks"; echo "$p"
}

codes() { cut -f4 | sort | tr '\n' ' ' | sed 's/ $//'; }

# A pre-5d9c047 install: plugin-root SessionStart/PostToolUse, permission-rule
# matcher on the guard, plus the stop guard.
OLD_GUARD='bash -c '"'"'BRANCH=$(git branch --show-current 2>/dev/null); if [ \"$BRANCH\" = \"main\" ] || [ \"$BRANCH\" = \"master\" ] || [ \"$BRANCH\" = \"development\" ] || [ \"$BRANCH\" = \"develop\" ]; then echo \"BLOCKED: Do not commit on $BRANCH. Create a feature/* or bugfix/* branch first.\" >&2; exit 2; fi'"'"''
old_install() { # old_install <matcher> <guard command, JSON-escaped>
cat <<EOF
{
  "version": 1,
  "hooks": {
    "SessionStart": [
      { "matcher": "", "hooks": [ { "type": "command", "command": "bash \"\${PLUGIN_ROOT:-\${COPILOT_PLUGIN_ROOT:-\${CLAUDE_PLUGIN_ROOT}}}/hooks/scripts/session-start.sh\"" } ] },
      { "matcher": "", "hooks": [ { "type": "command", "command": "bash \"\${PLUGIN_ROOT:-\${COPILOT_PLUGIN_ROOT:-\${CLAUDE_PLUGIN_ROOT}}}/hooks/scripts/next-step.sh\"" } ] },
      { "matcher": "", "hooks": [ { "type": "command", "command": "echo team-banner" } ] }
    ],
    "PreToolUse": [
      { "matcher": "$1", "hooks": [ { "type": "command", "command": "$2" } ] },
      { "matcher": "Write(**/*.env)", "hooks": [ { "type": "command", "command": "echo no-env >&2; exit 2" } ] },
      { "matcher": "Edit", "hooks": [ { "type": "command", "command": "echo nope >&2; exit 1" } ] }
    ],
    "agentStop": [
      { "matcher": "", "hooks": [ { "type": "command", "command": "[ -f \"\${CLAUDE_PROJECT_DIR:-\$PWD}/.claude/hooks/stop-guard.sh\" ] && bash \"\${CLAUDE_PROJECT_DIR:-\$PWD}/.claude/hooks/stop-guard.sh\" || true" } ] }
    ],
    "PostToolUse": [
      { "matcher": "Edit", "hooks": [ { "type": "command", "if": "Edit(**/.claude-plugin/**)", "command": "bash \"\${PLUGIN_ROOT:-\${COPILOT_PLUGIN_ROOT:-\${CLAUDE_PLUGIN_ROOT}}}/data/lib/validate-plugin-edit.sh\" \"\$CLAUDE_TOOL_ARG_file_path\"" } ] }
    ]
  }
}
EOF
}
json_escape() { node -e 'process.stdout.write(JSON.stringify(process.argv[1]).slice(1,-1))' "$1"; }

# Foreign entries, as JSON, to prove --fix leaves them alone.
foreign() { node -e '
  const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  const dx = /Do not commit on|stop-guard\.sh|session-start\.sh|next-step\.sh|validate-plugin-edit\.sh/;
  const out = {};
  for (const [e, gs] of Object.entries(d.hooks)) for (const g of gs)
    for (const h of g.hooks || [g]) if (!dx.test(h.command || h.bash || "")) (out[e] ||= []).push([g.matcher, h]);
  process.stdout.write(JSON.stringify(out));' "$1"; }

# --- 1. template -------------------------------------------------------------
echo "== template"
check "template has no PLUGIN_ROOT reference" 1 "$(no_plugin_root "$TEMPLATE")"
check "template events are PreToolUse + agentStop only" "PreToolUse agentStop" \
  "$(node -e 'console.log(Object.keys(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).hooks).join(" "))' "$TEMPLATE")"
check "template guard: git commit on main → exit 2" 2 "$(guard_exit "$TEMPLATE" main 'git commit -m x')"
check "template guard: git commit on develop → exit 2" 2 "$(guard_exit "$TEMPLATE" develop 'git commit -am x')"
check "template guard: ls on main → exit 0" 0 "$(guard_exit "$TEMPLATE" main 'ls -la')"
check "template guard: git commit on feature branch → exit 0" 0 "$(guard_exit "$TEMPLATE" feature/x 'git commit -m x')"

echo "== known-bad inputs for the template checks"
P="$(project bad-template)"; old_install "Bash(git commit*)" "$(json_escape "$OLD_GUARD")" > "$P/.github/hooks/hooks.json"
check "PLUGIN_ROOT check fails on an old install" 0 "$(no_plugin_root "$P/.github/hooks/hooks.json")"
sed 's/exit 2; fi/exit 1; fi/' "$TEMPLATE" > "$TMP/exit1.json"
check "exit-code check fails on an exit-1 guard" 1 "$(guard_exit "$TMP/exit1.json" main 'git commit -m x')"

# --- 2. audit ------------------------------------------------------------------
echo "== audit: no .github/hooks"
mkdir -p "$TMP/empty"
OUT="$(bash "$AUDIT" --template "$TEMPLATE" "$TMP/empty")"; rc=$?
check "no hooks dir → exit 0" 0 "$rc"; check "no hooks dir → no output" "" "$OUT"

echo "== audit: fresh install from the template"
P="$(project fresh)"; cp "$TEMPLATE" "$P/.github/hooks/hooks.json"
OUT="$(bash "$AUDIT" --template "$TEMPLATE" "$P")"; rc=$?
check "template install → exit 0" 0 "$rc"; check "template install → no findings" "" "$OUT"

echo "== audit: pre-5d9c047 install (Bash(git commit*) matcher) + foreign hooks"
P="$(project old)"; F="$P/.github/hooks/hooks.json"
old_install "Bash(git commit*)" "$(json_escape "$OLD_GUARD")" > "$F"
echo '{"version":1,"hooks":{"sessionStart":[{"type":"command","bash":"bash \"$PLUGIN_ROOT/x.sh\""}]}}' > "$P/.github/hooks/team.json"
BEFORE_FOREIGN="$(foreign "$F")"; BEFORE_TEAM="$(cat "$P/.github/hooks/team.json")"
OUT="$(bash "$AUDIT" --template "$TEMPLATE" "$P")"; rc=$?
check "old install → exit 3" 3 "$rc"
check "old install → finding codes" "exit-1 permission-matcher plugin-root plugin-root plugin-root plugin-root stale-guard" "$(codes <<<"$OUT")"
check "stale guard names the permission-rule matcher" 1 "$(grep -c 'stale-guard.*permission-rule syntax' <<<"$OUT")"
check "stale guard names the missing stdin filter" 1 "$(grep -c 'stale-guard.*no git-commit filter' <<<"$OUT")"
check "check mode is read-only" "$(old_install "Bash(git commit*)" "$(json_escape "$OLD_GUARD")")" "$(cat "$F")"

echo "== audit --fix"
OUT="$(bash "$AUDIT" --fix --template "$TEMPLATE" "$P")"; rc=$?
check "after fix → foreign findings remain (exit 3)" 3 "$rc"
check "after fix → only foreign findings left" "exit-1 permission-matcher plugin-root" "$(codes <<<"$OUT")"
check "after fix → foreign entries in hooks.json unchanged" "$BEFORE_FOREIGN" "$(foreign "$F")"
check "after fix → other files in .github/hooks untouched" "$BEFORE_TEAM" "$(cat "$P/.github/hooks/team.json")"
check "after fix → no dx plugin-root command left" 0 "$(grep -cE 'session-start|next-step|validate-plugin-edit' "$F")"
check "after fix → PostToolUse event emptied and removed" 0 "$(grep -c PostToolUse "$F")"
check "after fix → guard blocks git commit on main (exit 2)" 2 "$(guard_exit "$F" main 'git commit -m x')"
check "after fix → guard allows ls on main" 0 "$(guard_exit "$F" main 'ls')"
check "after fix → one stop guard" 2 "$(grep -o 'stop-guard.sh' "$F" | wc -l | tr -d ' ')"   # 2 mentions in one command
SUM="$(cksum < "$F")"; bash "$AUDIT" --fix --template "$TEMPLATE" "$P" >/dev/null
check "second --fix is a no-op" "$SUM" "$(cksum < "$F")"

echo "== audit: other historic guard shapes"
P="$(project exit1)"; F="$P/.github/hooks/hooks.json"
old_install "Bash(git commit*)" "$(json_escape "${OLD_GUARD/exit 2; fi/exit 1; fi}")" > "$F"
OUT="$(bash "$AUDIT" --template "$TEMPLATE" "$P")"
check "exit-1 guard → stale-guard says it does not block" 1 "$(grep -c 'stale-guard.*exits 1 (does not block)' <<<"$OUT")"
bash "$AUDIT" --fix --template "$TEMPLATE" "$P" >/dev/null
check "exit-1 guard fixed → blocks with exit 2" 2 "$(guard_exit "$F" main 'git commit -m x')"

P="$(project bare-bash)"; F="$P/.github/hooks/hooks.json"
old_install "Bash" "$(json_escape "$OLD_GUARD")" > "$F"
check "Bash matcher, no stdin filter → blocks every Bash on main (the bug)" 2 "$(guard_exit "$F" main 'ls')"
OUT="$(bash "$AUDIT" --template "$TEMPLATE" "$P")"
check "→ stale-guard (no stdin filter)" 1 "$(grep -c 'stale-guard.*no git-commit filter' <<<"$OUT")"
bash "$AUDIT" --fix --template "$TEMPLATE" "$P" >/dev/null
check "fixed → ls on main allowed" 0 "$(guard_exit "$F" main 'ls')"

echo "== audit: hooks.json without dx guards, plus a duplicate"
P="$(project missing)"; F="$P/.github/hooks/hooks.json"
echo '{"version":1,"hooks":{"PreToolUse":[{"matcher":"Write","hooks":[{"type":"command","command":"true"}]}]}}' > "$F"
OUT="$(bash "$AUDIT" --template "$TEMPLATE" "$P")"
check "missing guards → reported" "missing-guard missing-stop-guard" "$(codes <<<"$OUT")"
bash "$AUDIT" --fix --template "$TEMPLATE" "$P" >/dev/null
check "missing guards fixed → clean" "" "$(bash "$AUDIT" --template "$TEMPLATE" "$P")"
check "missing guards fixed → foreign Write hook kept" 1 "$(grep -c '"Write"' "$F")"
node -e 'const f=process.argv[1],d=JSON.parse(require("fs").readFileSync(f,"utf8"));d.hooks.PreToolUse.push(JSON.parse(JSON.stringify(d.hooks.PreToolUse.at(-1))));require("fs").writeFileSync(f,JSON.stringify(d,null,2))' "$F"
check "duplicate guard → reported" "duplicate" "$(bash "$AUDIT" --template "$TEMPLATE" "$P" | codes)"
bash "$AUDIT" --fix --template "$TEMPLATE" "$P" >/dev/null
check "duplicate guard fixed → clean" "" "$(bash "$AUDIT" --template "$TEMPLATE" "$P")"

echo "== audit: invalid JSON"
P="$(project broken)"; echo '{ nope' > "$P/.github/hooks/hooks.json"
bash "$AUDIT" --template "$TEMPLATE" "$P" >/dev/null; rc=$?
check "invalid JSON → exit 2" 2 "$rc"
bash "$AUDIT" --fix --template "$TEMPLATE" "$P" >/dev/null
check "invalid JSON → --fix leaves it alone" '{ nope' "$(cat "$P/.github/hooks/hooks.json")"

echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
