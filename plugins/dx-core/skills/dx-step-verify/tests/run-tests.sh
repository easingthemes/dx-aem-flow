#!/usr/bin/env bash
# Smoke tests for pre-review-checks.sh (the 5-phase gate /dx-step-verify runs).
# Run from repo root. Prints PASS/FAIL per test; exits non-zero on any failure.
#
# NOTE: -e is intentionally omitted — the gate exits 1 whenever a phase fails,
# which is the expected outcome in most of these tests.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../../../data/lib/pre-review-checks.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok() { echo "PASS: $1"; PASS=$((PASS+1)); }
no() { echo "FAIL: $1"; [ -n "${2:-}" ] && echo "  $2"; FAIL=$((FAIL+1)); }

check() {  # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then ok "$1"; else no "$1" "expected [$2], got [$3]"; fi
}

# Build a throwaway repo with one changed .java file and the given build: config.
# Usage: mkrepo <config-body>
mkrepo() {
  local d="$TMP/repo"
  rm -rf "$d"; mkdir -p "$d/.ai/lib" "$d/frontend"
  cp "$GATE" "$d/.ai/lib/"
  printf 'scm:\n  base-branch: "main"\n%s' "$1" > "$d/.ai/config.yaml"
  (
    cd "$d" || exit 1
    git init -q -b main .
    git add -A && git -c user.email=t@t -c user.name=t commit -qm base
    git checkout -q -b feat
    echo "class A {}" > A.java
    echo "body { color: red; }" > frontend/a.css
    git add -A && git -c user.email=t@t -c user.name=t commit -qm work
  ) >/dev/null 2>&1
  echo "$d"
}

# Run the gate, returning only stdout (the JSON contract).
gate() { ( cd "$1" && bash .ai/lib/pre-review-checks.sh "${2:-}" 2>/dev/null ); }

jqq() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)" 2>/dev/null; }

# ===== stdout isolation =====
# Regression guard: phase commands used to run as `eval "$CMD" -q 2>/dev/null`,
# which silenced stderr but left stdout attached to ours. Any build tool that
# prints to stdout (most of them) landed in the middle of the JSON the skill
# parses, so a passing build could still break the gate.

R=$(mkrepo 'build:
  compile: "echo downloading-500-deps; echo BUILD-CHATTER"
  test: "echo Tests-run-42; true"
')
OUT=$(gate "$R")
check "chatty passing build still emits parseable JSON" "ok" "$(echo "$OUT" | jqq "'ok'")"
check "all five phases ran"                             "5"  "$(echo "$OUT" | jqq "len(d['phases'])")"
check "gate passes"                                     "True" "$(echo "$OUT" | jqq "d['passed']")"
if echo "$OUT" | grep -q "BUILD-CHATTER"; then
  no "build stdout does not leak into the JSON" "BUILD-CHATTER found in output"
else
  ok "build stdout does not leak into the JSON"
fi

# ===== failure diagnostics =====
# stderr used to go to /dev/null, so a failed phase reported only "run: <cmd>".
# Output is captured now, so the actual error reaches the caller.

R=$(mkrepo 'build:
  compile: "echo noise-on-stdout; echo a.java:3:_cannot_find_symbol >&2; false"
')
OUT=$(gate "$R")
check "failing compile marks phase 1 failed" "failed" "$(echo "$OUT" | jqq "d['phases'][0]['status']")"
check "failing compile fails the gate"       "False"  "$(echo "$OUT" | jqq "d['passed']")"
if echo "$OUT" | grep -q '| a.java:3:_cannot_find_symbol'; then
  ok "compiler stderr is surfaced in issues"
else
  no "compiler stderr is surfaced in issues" "$OUT"
fi

# ===== JSON stays valid however hostile the tool output =====
R=$(mkrepo 'build:
  frontend-dir: "frontend"
  lint-css: "./lint.sh"
')
cat > "$R/lint.sh" <<'LEOF'
#!/usr/bin/env bash
echo 'a.css:1  unexpected "quote", a \ backslash and {"fake":"json"}'
exit 1
LEOF
chmod +x "$R/lint.sh"
( cd "$R" && git add -A && git -c user.email=t@t -c user.name=t commit -qm lint ) >/dev/null 2>&1
OUT=$(gate "$R")
check "quotes/backslashes in lint output keep JSON valid" "ok"     "$(echo "$OUT" | jqq "'ok'")"
check "lint failure marks phase 2 failed"                 "failed" "$(echo "$OUT" | jqq "d['phases'][1]['status']")"

# ===== no hardcoded -q on config-driven commands =====
# `-q` was appended to whatever `build.compile` held, which is Maven-specific;
# any command that rejects unknown flags failed for that reason alone.
R=$(mkrepo 'build:
  compile: "./strict.sh"
')
cat > "$R/strict.sh" <<'SEOF'
#!/usr/bin/env bash
[ $# -eq 0 ] || { echo "unexpected argument: $*" >&2; exit 2; }
SEOF
chmod +x "$R/strict.sh"
( cd "$R" && git add -A && git -c user.email=t@t -c user.name=t commit -qm strict ) >/dev/null 2>&1
OUT=$(gate "$R")
check "compile command runs with no injected flags" "passed" "$(echo "$OUT" | jqq "d['phases'][0]['status']")"

# ===== --fix is still honoured =====
R=$(mkrepo 'build:
  frontend-dir: "frontend"
  lint-js: "false"
')
OUT=$(gate "$R" --fix)
if echo "$OUT" | grep -q "auto-fix applied"; then
  ok "--fix selects the auto-fix wording"
else
  no "--fix selects the auto-fix wording" "$OUT"
fi

# ===== temp logs are cleaned up =====
if ls -d "${TMPDIR:-/tmp}"/dx-pre-review.* >/dev/null 2>&1; then
  no "temp log dir removed on exit" "leftover dx-pre-review.* dir"
else
  ok "temp log dir removed on exit"
fi

echo "---"
echo "Total: $((PASS+FAIL)), Pass: $PASS, Fail: $FAIL"
[ "$FAIL" -eq 0 ]
