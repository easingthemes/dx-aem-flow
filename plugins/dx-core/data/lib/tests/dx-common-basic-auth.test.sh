#!/usr/bin/env bash
# Hermetic tests for `dx-common.sh curl-basic-auth` (fake curl on PATH, no network).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../dx-common.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat > "$TMP/bin/curl" <<'FAKE'
#!/bin/sh
: > "$FAKE_CURL_OUT"
for a in "$@"; do printf '%s\n' "$a" >> "$FAKE_CURL_OUT"; done
exit "${FAKE_CURL_EXIT:-0}"
FAKE
chmod +x "$TMP/bin/curl"
export FAKE_CURL_OUT="$TMP/argv"
PASS=0; FAIL=0

# run <sites> <args...>: sets ARGV (newline-joined), OUT, ERR, RC
run() {
  local sites="$1"; shift
  if [ "$sites" = "__unset__" ]; then unset BASIC_AUTH_SITES; else export BASIC_AUTH_SITES="$sites"; fi
  rm -f "$FAKE_CURL_OUT"
  OUT="$(PATH="$TMP/bin:$PATH" bash "$SCRIPT" curl-basic-auth "$@" 2>"$TMP/err")"; RC=$?
  ERR="$(cat "$TMP/err")"
  ARGV="$(cat "$FAKE_CURL_OUT" 2>/dev/null)"
}
check() { # name expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "ok   - $1"
  else FAIL=$((FAIL+1)); echo "FAIL - $1"; echo "  expected: $(printf %q "$2")"; echo "  actual:   $(printf %q "$3")"; fi
}
nl=$'\n'

run "qa:https://qa.example.com:user:pass" https://qa.example.com/p -sf -o /dev/null
check "adds -u for listed origin" "-sf${nl}-o${nl}/dev/null${nl}-u${nl}user:pass${nl}https://qa.example.com/p" "$ARGV"

run "qa:https://qa.example.com:user:pass" https://other.example.com/p -s
check "adds nothing for unlisted origin" "-s${nl}https://other.example.com/p" "$ARGV"

run "__unset__" https://qa.example.com/p -s
check "adds nothing when unset" "-s${nl}https://qa.example.com/p" "$ARGV"
run "" https://qa.example.com/p -s
check "adds nothing when empty" "-s${nl}https://qa.example.com/p" "$ARGV"

run "qa:https://qa.example.com:us%3Aer:p%2Cw%25d" https://qa.example.com/
check "decodes escapes" "-u${nl}us:er:p,w%d${nl}https://qa.example.com/" "$ARGV"

run "bad,nocolon:x,qa:https://qa.example.com:user:pass,web:ftp://qa.example.com:u:p" https://qa.example.com/
check "skips malformed, still matches" "-u${nl}user:pass${nl}https://qa.example.com/" "$ARGV"
check "malformed warning names index" "BASIC_AUTH_SITES: entry 0 skipped (expected name:url:user:pass)${nl}BASIC_AUTH_SITES: entry 1 skipped (expected name:url:user:pass)${nl}BASIC_AUTH_SITES: entry 3 skipped (expected name:url:user:pass)" "$ERR"

run "qa:HTTPS://QA.Example.com:443/ignored/path:user:pass" https://qa.example.com/x
check "origin normalises :443, case, path" "-u${nl}user:pass${nl}https://qa.example.com/x" "$ARGV"
run "qa:http://qa.example.com:user:pass" http://QA.example.com:80/x
check "origin normalises :80" "-u${nl}user:pass${nl}http://QA.example.com:80/x" "$ARGV"
run "qa:https://qa.example.com:8443:user:pass" https://qa.example.com/x
check "different port does not match" "https://qa.example.com/x" "$ARGV"
run "qa:https://qa.example.com:user:pass" http://qa.example.com/x
check "different scheme does not match" "http://qa.example.com/x" "$ARGV"

run "qa:https://qa.example.com:user:SECRETPASS" https://qa.example.com/ -sf
case "$OUT$ERR" in *SECRETPASS*) r=leaked;; *) r=clean;; esac
check "never prints the password" clean "$r"
run "qa:https://qa.example.com:user:SECRETPASS,bad" https://qa.example.com/
case "$OUT$ERR" in *SECRETPASS*) r=leaked;; *) r=clean;; esac
check "never prints the password (with malformed)" clean "$r"

FAKE_CURL_EXIT=22 run "qa:https://qa.example.com:user:pass" https://qa.example.com/
check "exit code is curl's" 22 "$RC"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
