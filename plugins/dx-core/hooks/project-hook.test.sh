#!/usr/bin/env bash
# project-hook.test.sh — project-hook.sh finds the project on every host.
#
# Claude Code and Copilot CLI set CLAUDE_PROJECT_DIR; Codex CLI does not and
# sends `cwd` in the hook's stdin JSON instead. The wrapper must run the project
# script in all three cases, pass stdin and stdout through, and always exit 0.
# Also checks that hooks.json no longer uses a bare $CLAUDE_PROJECT_DIR.
# Hermetic: throwaway dirs and repos, no network.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WRAP="$HERE/scripts/project-hook.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
unset CLAUDE_PROJECT_DIR

PASS=0; FAIL=0
check() { if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS + 1)); else echo "FAIL $1 (want '$2', got '$3')"; FAIL=$((FAIL + 1)); fi; }

P="$TMP/proj"
mkdir -p "$P/.claude/hooks" "$P/sub/dir" "$TMP/elsewhere"
git -C "$P" init -q
# Project script: echoes the dir it was given, its stdin, and fails on purpose.
cat > "$P/.claude/hooks/probe.sh" <<'EOF'
echo "dir=$CLAUDE_PROJECT_DIR in=$(cat)"
exit 3
EOF

run() { (cd "$1" && shift && printf '%s' "$1" | bash "$WRAP" .claude/hooks/probe.sh); }

# 1. Claude Code / Copilot: env var wins, even from an unrelated cwd.
out=$(cd "$TMP/elsewhere" && printf 'x' | CLAUDE_PROJECT_DIR="$P" bash "$WRAP" .claude/hooks/probe.sh); rc=$?
check "env var used" "dir=$P in=x" "$out"
check "exit 0 when project script fails" 0 "$rc"

# 2. Codex: no env var, stdin cwd is a subdir of the project → git root.
in="{\"hook_event_name\":\"Stop\",\"cwd\":\"$P/sub/dir\"}"
out=$(run "$TMP/elsewhere" "$in")
check "stdin cwd → git root" "dir=$P in=$in" "$out"

# 3. No env var, no cwd in stdin, started in a subdir → git root of PWD.
out=$(run "$P/sub/dir" '{}')
check "PWD subdir → git root" "dir=$P in={}" "$out"

# 4. Not a git repo, no env, no cwd → PWD.
mkdir -p "$TMP/plain/.claude/hooks"; cp "$P/.claude/hooks/probe.sh" "$TMP/plain/.claude/hooks/"
out=$(run "$TMP/plain" '{}')
check "no git → PWD" "dir=$TMP/plain in={}" "$out"

# 5. Missing project script → silent, exit 0.
out=$(cd "$P" && printf '{}' | bash "$WRAP" .claude/hooks/missing.sh); rc=$?
check "missing script silent" "" "$out"
check "missing script exit 0" 0 "$rc"

# 6. hooks.json: every $CLAUDE_PROJECT_DIR use has a fallback.
bare=$(grep -o '\$CLAUDE_PROJECT_DIR' "$HERE/hooks.json" | wc -l | tr -d ' ')
check "hooks.json has no bare \$CLAUDE_PROJECT_DIR" 0 "$bare"

echo "---"; echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
