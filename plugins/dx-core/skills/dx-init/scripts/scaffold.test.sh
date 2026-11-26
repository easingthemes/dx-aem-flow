#!/usr/bin/env bash
# Hermetic check: dx-init's scaffold.sh installs every helper in data/lib/
# (*.sh, *.js, *.cjs at top level) into .ai/lib/, and no test files.
# Skills call these from .ai/lib/ — a helper missing there fails at runtime.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
LIB="$(cd "$HERE/../../../data/lib" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0 FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1"; }

(cd "$TMP" && bash "$HERE/scaffold.sh" >/dev/null) || fail "scaffold.sh exited non-zero"

for f in "$LIB"/*.sh "$LIB"/*.js "$LIB"/*.cjs; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  case "$name" in
    *.test.sh|*.test.js|*.test.cjs)
      [ -e "$TMP/.ai/lib/$name" ] && fail "test file installed: $name" || ok ;;
    *)
      if [ -x "$TMP/.ai/lib/$name" ]; then ok; else fail "not installed (or not executable): .ai/lib/$name"; fi ;;
  esac
done

# The helpers dx-aem skills reach through .ai/lib/ — named so a regression is obvious.
for name in run-result.sh upload-attachment.sh dx-common.sh; do
  [ -x "$TMP/.ai/lib/$name" ] && ok || fail "missing .ai/lib/$name"
done

[ -e "$TMP/.ai/lib/tests" ] || [ -e "$TMP/.ai/lib/fixtures" ] && fail "tests/ or fixtures/ copied" || ok

# Re-run is idempotent: everything validated, nothing installed or updated.
out="$(cd "$TMP" && bash "$HERE/scaffold.sh")"
echo "$out" | grep -qE '^(installed|updated) \.ai/lib/' && fail "re-run changed .ai/lib" || ok

echo "scaffold: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
