#!/usr/bin/env bash
# Hermetic tests for data/lib/upload-attachment.sh. A fake `curl` on PATH records
# each request and answers from canned files — no network, no az, no git.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
UP="$HERE/../upload-attachment.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0 FAIL=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi
}
command -v jq >/dev/null 2>&1 || { echo "upload-attachment: jq missing, skipped"; exit 0; }

BIN="$TMP/bin"; mkdir -p "$BIN"
# Fake curl: logs "METHOD URL" + auth + content-type + body file to $LOG,
# writes the canned response for the method to the -o file, prints the HTTP code.
cat > "$BIN/curl" <<'SH'
#!/usr/bin/env bash
out="" method="GET" url="" auth="" ctype="" body=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -X) method="$2"; shift 2 ;;
    -w) shift 2 ;;
    -H) case "$2" in Authorization:*) auth="$2" ;; Content-Type:*) ctype="${2#Content-Type: }" ;; esac; shift 2 ;;
    --data-binary) body="${2#@}"; shift 2 ;;
    -sS) shift ;;
    *) url="$1"; shift ;;
  esac
done
n=$(( $(wc -l < "$LOG" 2>/dev/null || echo 0) ))
echo "$method $url" >> "$LOG"
echo "$auth" >> "$LOG.auth"
echo "$ctype" >> "$LOG.ctype"
[ -n "$body" ] && cp "$body" "$LOG.body.$method"
cp "$FAKE/$method.json" "$out"
cat "$FAKE/$method.code"
SH
chmod +x "$BIN/curl"
# az must not be found unless a test provides it
export PATH="$BIN:/usr/bin:/bin"

FAKE="$TMP/fake"; mkdir -p "$FAKE"; export FAKE
export LOG="$TMP/log"
printf 'PNGDATA' > "$TMP/shot.png"

reset() {
  rm -f "$LOG"*
  echo '{"id":"g1","url":"https://dev.azure.com/my-org/_apis/wit/attachments/g1?fileName=shot.png"}' > "$FAKE/POST.json"
  echo 201 > "$FAKE/POST.code"
  echo '{"id":12345,"relations":[]}' > "$FAKE/GET.json"
  echo 200 > "$FAKE/GET.code"
  echo '{"id":12345}' > "$FAKE/PATCH.json"
  echo 200 > "$FAKE/PATCH.code"
}
run() { env -u SYSTEM_ACCESSTOKEN ADO_PAT=pat123 bash "$UP" --org https://dev.azure.com/my-org/ --project "my project" --id 12345 --file "$TMP/shot.png" "$@" 2>"$TMP/err"; }

# --- happy path: upload, read, link ---
reset
out=$(run); rc=$?
check "ok: exit 0" 0 "$rc"
check "ok: prints attachment url" "https://dev.azure.com/my-org/_apis/wit/attachments/g1?fileName=shot.png" "$out"
check "ok: three requests" 3 "$(wc -l < "$LOG" | tr -d ' ')"
check "ok: upload url (project encoded, org slash trimmed)" \
  "POST https://dev.azure.com/my-org/my%20project/_apis/wit/attachments?fileName=shot.png&api-version=7.1" "$(sed -n 1p "$LOG")"
check "ok: upload is octet-stream" application/octet-stream "$(sed -n 1p "$LOG.ctype")"
check "ok: upload sends the file bytes" PNGDATA "$(cat "$LOG.body.POST")"
check "ok: reads relations" 'GET https://dev.azure.com/my-org/my%20project/_apis/wit/workitems/12345?$expand=relations&api-version=7.1' "$(sed -n 2p "$LOG")"
check "ok: link is json-patch" application/json-patch+json "$(sed -n 3p "$LOG.ctype")"
check "ok: patch adds one AttachedFile" '[{"op":"add","path":"/relations/-","value":{"rel":"AttachedFile","url":"https://dev.azure.com/my-org/_apis/wit/attachments/g1?fileName=shot.png","attributes":{"name":"shot.png"}}}]' \
  "$(jq -c . "$LOG.body.PATCH")"
check "ok: PAT sent as Basic" "Authorization: Basic $(printf ':pat123' | base64)" "$(sed -n 1p "$LOG.auth")"

# --- --name overrides file name; same-name relations replaced, highest index first ---
reset
cat > "$FAKE/GET.json" <<'J'
{"relations":[
 {"rel":"AttachedFile","url":"u0","attributes":{"name":"12345-preview-hero.png"}},
 {"rel":"System.LinkTypes.Hierarchy-Reverse","url":"p"},
 {"rel":"AttachedFile","url":"u2","attributes":{"name":"other.png"}},
 {"rel":"AttachedFile","url":"u3","attributes":{"name":"12345-preview-hero.png"}}
]}
J
out=$(run --name 12345-preview-hero.png); rc=$?
check "replace: exit 0" 0 "$rc"
check "replace: upload uses --name" yes "$(sed -n 1p "$LOG" | grep -q 'fileName=12345-preview-hero.png&' && echo yes)"
check "replace: removes 3 then 0, then adds" '["remove /relations/3","remove /relations/0","add /relations/-"]' \
  "$(jq -c '[.[] | "\(.op) \(.path)"]' "$LOG.body.PATCH")"
check "replace: reports it" yes "$(grep -q "replaced 2 earlier '12345-preview-hero.png'" "$TMP/err" && echo yes)"

# --- SYSTEM_ACCESSTOKEN wins over ADO_PAT ---
reset
SYSTEM_ACCESSTOKEN=tok ADO_PAT=pat bash "$UP" --org https://o --project p --id 1 --file "$TMP/shot.png" >/dev/null 2>&1
check "auth: build token as Bearer" "Authorization: Bearer tok" "$(sed -n 1p "$LOG.auth")"

# --- az fallback when no env token ---
reset
printf '#!/usr/bin/env bash\necho aztoken\n' > "$BIN/az"; chmod +x "$BIN/az"
env -u SYSTEM_ACCESSTOKEN -u ADO_PAT bash "$UP" --org https://o --project p --id 1 --file "$TMP/shot.png" >/dev/null 2>&1
check "auth: az token as Bearer" "Authorization: Bearer aztoken" "$(sed -n 1p "$LOG.auth")"
rm -f "$BIN/az"

# --- no credentials ---
reset
env -u SYSTEM_ACCESSTOKEN -u ADO_PAT bash "$UP" --org https://o --project p --id 1 --file "$TMP/shot.png" >/dev/null 2>"$TMP/err"; rc=$?
check "noauth: exit 1" 1 "$rc"
check "noauth: no request sent" 0 "$( [ -f "$LOG" ] && wc -l < "$LOG" | tr -d ' ' || echo 0)"
check "noauth: says how to fix" yes "$(grep -q 'az login' "$TMP/err" && echo yes)"

# --- upload HTTP error stops before linking ---
reset
echo 401 > "$FAKE/POST.code"; echo '{"message":"denied"}' > "$FAKE/POST.json"
run >/dev/null; rc=$?
check "upload 401: exit 1" 1 "$rc"
check "upload 401: one request only" 1 "$(wc -l < "$LOG" | tr -d ' ')"
check "upload 401: reports step and code" yes "$(grep -q 'upload failed (HTTP 401)' "$TMP/err" && echo yes)"

# --- link HTTP error ---
reset
echo 400 > "$FAKE/PATCH.code"
run >/dev/null; rc=$?
check "link 400: exit 1" 1 "$rc"
check "link 400: reports step" yes "$(grep -q 'link failed (HTTP 400)' "$TMP/err" && echo yes)"

# --- usage errors send nothing ---
reset
bash "$UP" --org https://o --project p --id 1 >/dev/null 2>&1; check "usage: missing --file exits 1" 1 "$?"
bash "$UP" --org https://o --project p --id 12a --file "$TMP/shot.png" >/dev/null 2>&1; check "usage: non-numeric id exits 1" 1 "$?"
bash "$UP" --org https://o --project p --id 1 --file "$TMP/missing.png" >/dev/null 2>&1; check "usage: missing file exits 1" 1 "$?"
check "usage: no request sent" 0 "$( [ -f "$LOG" ] && wc -l < "$LOG" | tr -d ' ' || echo 0)"

echo "upload-attachment: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
