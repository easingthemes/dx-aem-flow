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

# Run the gate, returning only stdout. Use for the stdout-isolation tests,
# where discarding stderr is the point. `shift` keeps the no-flag call a
# genuine zero-argument invocation rather than passing one empty string.
gate() { ( cd "$1" || exit 1; shift; bash .ai/lib/pre-review-checks.sh "$@" 2>/dev/null ); }

# Run the gate the way the real caller does: dx-step-verify/SKILL.md runs
# `bash .ai/lib/pre-review-checks.sh --fix 2>&1`, merging stderr into the
# stdout it JSON-parses. The contract is therefore "both streams together
# must be valid JSON" — gate() alone cannot see a violation of that.
gate_merged() { ( cd "$1" || exit 1; shift; bash .ai/lib/pre-review-checks.sh "$@" 2>&1 ); }

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

# ===== the stream the skill actually parses =====
# gate() discards stderr, but SKILL.md runs the gate as `... --fix 2>&1` and
# JSON-parses the result. Assert on that merged stream too, or anything the
# script writes to stderr stays invisible to this suite.

R=$(mkrepo 'build:
  compile: "echo on-stdout; echo on-stderr >&2; false"
  test: "echo t"
')
OUT=$(gate_merged "$R")
check "merged stdout+stderr parses as JSON"   "ok"     "$(echo "$OUT" | jqq "'ok'")"
check "merged stream still reports phase 1"   "failed" "$(echo "$OUT" | jqq "d['phases'][0]['status']")"
OUT=$(gate_merged "$R" --fix)
check "merged stream parses with --fix too"   "ok"     "$(echo "$OUT" | jqq "'ok'")"

# ===== diagnostics window on the errors, not the footer =====
# log_lines used to tail the log. Build tools close with boilerplate (Maven
# spends eight lines on "-> [Help 1]" and "re-run with -X"), so the cap was
# consumed by the footer and the actual errors were truncated away.

R=$(mkrepo 'build:
  compile: "./fakemvn.sh"
')
cat > "$R/fakemvn.sh" <<'MEOF'
#!/usr/bin/env bash
echo "[INFO] Scanning for projects..."
echo "[ERROR] FIRST-ERROR /src/A.java:[5,9] cannot find symbol"
echo "[ERROR]   symbol:   variable foo"
echo "[ERROR]   location: class A"
echo "[ERROR] SECOND-ERROR /src/B.java:[9,3] cannot find symbol"
echo "[ERROR] Failed to execute goal maven-compiler-plugin:compile: Compilation failure"
echo "[ERROR] -> [Help 1]"
echo "[ERROR] To see the full stack trace of the errors, re-run Maven with the -e switch."
echo "[ERROR] Re-run Maven using the -X switch to enable full debug logging."
echo "[ERROR] For more information about the errors and possible solutions, read:"
echo "[ERROR] [Help 1] http://cwiki.apache.org/confluence/display/MAVEN/MojoFailureException"
echo "[ERROR] BOILERPLATE-TAIL-MARKER"
exit 1
MEOF
chmod +x "$R/fakemvn.sh"
( cd "$R" && git add -A && git -c user.email=t@t -c user.name=t commit -qm mvn ) >/dev/null 2>&1
OUT=$(gate "$R")
for marker in FIRST-ERROR SECOND-ERROR; do
  if echo "$OUT" | grep -q "| \[ERROR\] $marker"; then
    ok "$marker survives the diagnostics cap"
  else
    no "$marker survives the diagnostics cap" "$OUT"
  fi
done
if echo "$OUT" | grep -q "BOILERPLATE-TAIL-MARKER"; then
  no "footer past the cap is dropped" "boilerplate tail reported instead of errors"
else
  ok "footer past the cap is dropped"
fi
if echo "$OUT" | grep -q "| \[ERROR\]   symbol:   variable foo"; then
  ok "context lines after an error are kept"
else
  no "context lines after an error are kept" "$OUT"
fi

# Output with nothing error-shaped still gets reported (tail fallback).
R=$(mkrepo 'build:
  compile: "for i in 1 2 3; do echo plain-line-$i; done; false"
')
OUT=$(gate "$R")
if echo "$OUT" | grep -q "| plain-line-3"; then
  ok "unrecognised output falls back to the tail"
else
  no "unrecognised output falls back to the tail" "$OUT"
fi

# ===== phase 3 failure diagnostics =====
# No fixture made the test phase fail, so the Phase 3 log_lines call and the
# per-phase log naming (compile.log vs test.log) were both uncovered.

R=$(mkrepo 'build:
  compile: "echo compile-was-run"
  test: "./failtest.sh"
')
cat > "$R/failtest.sh" <<'TEOF'
#!/usr/bin/env bash
echo "surefire-preamble-noise"
echo "FAILURE-HEADLINE Tests run: 5, Failures: 1"
for i in 02 03 04 05 06 07 08 09 10; do echo "ctx-$i"; done
echo "BEYOND-CAP-LINE"
exit 1
TEOF
chmod +x "$R/failtest.sh"
( cd "$R" && git add -A && git -c user.email=t@t -c user.name=t commit -qm failtest ) >/dev/null 2>&1
OUT=$(gate "$R")
check "compile still passes when tests fail" "passed" "$(echo "$OUT" | jqq "d['phases'][0]['status']")"
check "failing tests mark phase 3 failed"    "failed" "$(echo "$OUT" | jqq "d['phases'][2]['status']")"
check "failing tests fail the gate"          "False"  "$(echo "$OUT" | jqq "d['passed']")"
check "diagnostics are capped at 10 lines"   "10"     "$(echo "$OUT" | jqq "len([i for i in d['issues'] if i.startswith('  | ')])")"
if echo "$OUT" | grep -q "| FAILURE-HEADLINE"; then
  ok "test failure output reaches issues"
else
  no "test failure output reaches issues" "$OUT"
fi
if echo "$OUT" | grep -q "BEYOND-CAP-LINE"; then
  no "lines past the cap are excluded" "BEYOND-CAP-LINE reported"
else
  ok "lines past the cap are excluded"
fi
# compile.log leaking into the test diagnostics would prove the logs collided.
if echo "$OUT" | grep -q "compile-was-run"; then
  no "compile and test logs stay separate" "compile output appeared in test diagnostics"
else
  ok "compile and test logs stay separate"
fi

# ===== phase 4: secret scan =====
# Fixture values are deliberately synthetic — never the canonical AWS doc key,
# which trips real scanners. Only the shape matters to the pattern.

R=$(mkrepo 'build: {}
')
mkdir -p "$R/conf"
cat > "$R/conf/creds.env" <<'SEOF'
AWS_SECRET_ACCESS_KEY=NOT-A-REAL-SECRET-0000000000000000000000
SEOF
printf -- '-----BEGIN RSA PRIVATE KEY-----\nNOT-A-REAL-KEY\n' > "$R/conf/id_rsa.pem"
cat > "$R/conf/app.properties" <<'SEOF'
password = "not-a-real-password"
SEOF
( cd "$R" && git add -A && git -c user.email=t@t -c user.name=t commit -qm secrets ) >/dev/null 2>&1
OUT=$(gate "$R")
check "secret scan flags planted credentials" "failed" "$(echo "$OUT" | jqq "d['phases'][3]['status']")"
for f in creds.env id_rsa.pem app.properties; do
  if echo "$OUT" | grep -q "Possible secret in: conf/$f"; then
    ok "secret scan reports conf/$f"
  else
    no "secret scan reports conf/$f" "$OUT"
  fi
done

# A mention of a credential name is not a credential. This is the regression
# that made every dx sync PR fail phase 4: the scanner's own pattern literal
# contains "aws_secret_access_key", so the gate flagged itself whenever it was
# one of the changed files.
R=$(mkrepo 'build: {}
')
mkdir -p "$R/docs"
cat > "$R/docs/security.md" <<'SEOF'
Never commit an aws_secret_access_key or aws_access_key_id to the repo.
Keep the private key outside version control. BEGIN RSA is a PEM marker.
SEOF
cat > "$R/docs/sample.yaml" <<'SEOF'
aws_access_key_id: ${env:AWS_KEY}
password = ""
SEOF
# The gate script itself, as a changed file — the real-world sync-PR case.
# This copies the *live* script, so the assertion tracks the real pattern:
# add a bare-keyword alternative back and the script self-matches again,
# reddening this case. That is the invariant, not just today's wording.
cp "$GATE" "$R/docs/pre-review-checks.sh.copy"
( cd "$R" && git add -A && git -c user.email=t@t -c user.name=t commit -qm mentions ) >/dev/null 2>&1
OUT=$(gate "$R")
check "mentions alone do not trip the secret scan" "passed" "$(echo "$OUT" | jqq "d['phases'][3]['status']")"
if echo "$OUT" | grep -q "Possible secret in"; then
  no "no file is falsely reported as a secret" "$(echo "$OUT" | grep 'Possible secret in')"
else
  ok "no file is falsely reported as a secret"
fi

# ===== temp logs are cleaned up =====
# Point the gate at a private TMPDIR so this asserts on the dir *this* run
# created. Globbing the real TMPDIR would read shared state and go red on any
# leftover — a SIGKILLed gate run, or a concurrent /dx-step-verify, both of
# which create dirs there too. This suite is discovered by CI, so it has to be
# hermetic.
LOGROOT="$TMP/logroot"; mkdir -p "$LOGROOT"
R=$(mkrepo 'build:
  compile: "true"
')
OUT=$( cd "$R" && TMPDIR="$LOGROOT" bash .ai/lib/pre-review-checks.sh 2>/dev/null )
leftover=$(ls -d "$LOGROOT"/dx-pre-review.* 2>/dev/null)
# The gate must have got past mktemp (valid JSON) and left nothing behind.
check "gate ran under a private TMPDIR" "passed" "$(echo "$OUT" | jqq "d['phases'][0]['status']")"
if [ -n "$leftover" ]; then
  no "temp log dir removed on exit" "leftover: $leftover"
else
  ok "temp log dir removed on exit"
fi

# ===== an unusable TMPDIR skips the gate instead of failing phases =====
# With no log dir every run_cmd redirect fails, which used to report phases as
# "failed" without running them and push mktemp's error onto stderr — the stream
# the skill merges into the JSON it parses.
R=$(mkrepo 'build:
  compile: "echo hi"
  test: "echo t"
')
OUT=$( cd "$R" && TMPDIR="$TMP/no-such-dir-xyz" bash .ai/lib/pre-review-checks.sh 2>&1 )
check "unusable TMPDIR still emits parseable JSON" "ok"   "$(echo "$OUT" | jqq "'ok'")"
check "unusable TMPDIR does not fail the gate"     "True" "$(echo "$OUT" | jqq "d['passed']")"
check "unusable TMPDIR reports no phases"          "0"    "$(echo "$OUT" | jqq "len(d['phases'])")"
if echo "$OUT" | grep -q "Could not create log dir"; then
  ok "unusable TMPDIR explains itself in issues"
else
  no "unusable TMPDIR explains itself in issues" "$OUT"
fi

echo "---"
echo "Total: $((PASS+FAIL)), Pass: $PASS, Fail: $FAIL"
[ "$FAIL" -eq 0 ]
