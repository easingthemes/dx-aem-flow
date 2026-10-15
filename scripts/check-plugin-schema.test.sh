#!/usr/bin/env bash
# check-plugin-schema.test.sh — Watch check-plugin-schema.sh fail.
#
# A validator nobody has watched fail is indistinguishable from a blind one.
# Each case breaks a copy of dx-core in one way and expects a non-zero exit;
# the clean copy must pass. Hermetic: `claude plugin validate` is local, needs
# no login, network or HOME.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
CHECK="$HERE/check-plugin-schema.sh"

if ! command -v "${CLAUDE_BIN:-claude}" >/dev/null 2>&1; then
  if [ "${CI:-}" = "true" ]; then echo "FAIL: claude not installed in CI"; exit 1; fi
  echo "SKIP: claude not installed"; exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"; mkdir -p "$HOME"

fail=0
fresh() { rm -rf "$TMP/p"; cp -R "$REPO_ROOT/plugins/dx-core" "$TMP/p"; }
expect() { # expect <0|1> <label>
  if bash "$CHECK" "$TMP/p" >"$TMP/out" 2>&1; then got=0; else got=1; fi
  if [ "$got" = "$1" ]; then echo "PASS $2"; else echo "FAIL $2 (exit $got, want $1)"; sed 's/^/    /' "$TMP/out"; fail=1; fi
}
setjson() { node -e 'const f=process.argv[1],d=JSON.parse(require("fs").readFileSync(f));'"$2"';require("fs").writeFileSync(f,JSON.stringify(d,null,2))' "$1"; }

fresh; expect 0 "clean dx-core copy passes"
fresh; setjson "$TMP/p/.claude-plugin/plugin.json" 'd.agents="./agents"'; expect 1 "agents field in plugin.json"
fresh; setjson "$TMP/p/.claude-plugin/plugin.json" 'd.version=123'; expect 1 "non-string version"
fresh; echo '{ broken' > "$TMP/p/hooks/hooks.json"; expect 1 "hooks.json does not parse"
fresh; echo '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"bogus"}]}]}}' > "$TMP/p/hooks/hooks.json"; expect 1 "unknown hook type"

exit $fail
