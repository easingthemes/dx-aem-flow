#!/usr/bin/env bash
# upload-attachment.sh — Upload a file to Azure DevOps and attach it to a work item.
#
# The ADO MCP upload tool takes the file as base64 in the tool call, which puts the
# whole image into model output. This script sends the bytes with curl instead, so
# a screenshot never passes through the model.
#
# Usage:
#   upload-attachment.sh --org <org-url> --project <project> --id <work-item-id> \
#                        --file <path> [--name <attachment-file-name>]
#
# Re-runs replace: an existing AttachedFile relation with the same name is removed
# before the new one is added, so re-capturing a screenshot does not pile up copies.
#
# Auth (first one set wins):
#   SYSTEM_ACCESSTOKEN  — pipeline build-service token (Bearer)
#   ADO_PAT             — personal access token (Basic)
#   az CLI              — `az account get-access-token` for the Azure DevOps resource (Bearer)
#
# Output: the attachment URL on stdout. Diagnostics on stderr.
# Exit:   0 ok · 1 usage/auth/HTTP error

set -euo pipefail

ORG="" PROJECT="" ID="" FILE="" NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    --org) ORG="${2:-}"; shift 2 ;;
    --project) PROJECT="${2:-}"; shift 2 ;;
    --id) ID="${2:-}"; shift 2 ;;
    --file) FILE="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "upload-attachment: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[ -n "$ORG" ] && [ -n "$PROJECT" ] && [ -n "$ID" ] && [ -n "$FILE" ] || {
  echo "upload-attachment: --org, --project, --id and --file are required" >&2; exit 1; }
case "$ID" in *[!0-9]*) echo "upload-attachment: --id must be numeric" >&2; exit 1 ;; esac
[ -f "$FILE" ] || { echo "upload-attachment: file not found: $FILE" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "upload-attachment: jq is required" >&2; exit 1; }
[ -n "$NAME" ] || NAME="$(basename "$FILE")"

ORG="${ORG%/}"
PROJ_ENC="$(printf '%s' "$PROJECT" | jq -sRr @uri)"
NAME_ENC="$(printf '%s' "$NAME" | jq -sRr @uri)"

# --- auth header -------------------------------------------------------------
if [ -n "${SYSTEM_ACCESSTOKEN:-}" ]; then
  AUTH="Authorization: Bearer ${SYSTEM_ACCESSTOKEN}"
elif [ -n "${ADO_PAT:-}" ]; then
  AUTH="Authorization: Basic $(printf ':%s' "$ADO_PAT" | base64 | tr -d '\n')"
elif command -v az >/dev/null 2>&1 && TOKEN="$(az account get-access-token \
        --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv 2>/dev/null)" \
     && [ -n "$TOKEN" ]; then
  AUTH="Authorization: Bearer ${TOKEN}"
else
  echo "upload-attachment: no credentials — set ADO_PAT (or SYSTEM_ACCESSTOKEN), or run 'az login'" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# call <method> <url> <content-type> <body-arg...>  → sets CODE, body in $TMP/resp
call() {
  local method="$1" url="$2" ctype="$3"; shift 3
  CODE="$(curl -sS -o "$TMP/resp" -w '%{http_code}' -X "$method" "$url" \
    -H "$AUTH" -H "Content-Type: $ctype" "$@")" || CODE=000
}
fail() { # <step>
  echo "upload-attachment: $1 failed (HTTP $CODE)" >&2
  head -c 500 "$TMP/resp" >&2 2>/dev/null || true; echo >&2
  exit 1
}

# --- 1. upload bytes -----------------------------------------------------------
call POST "$ORG/$PROJ_ENC/_apis/wit/attachments?fileName=$NAME_ENC&api-version=7.1" \
  application/octet-stream --data-binary "@$FILE"
[ "$CODE" -ge 200 ] 2>/dev/null && [ "$CODE" -lt 300 ] || fail "upload"
URL="$(jq -r '.url // empty' "$TMP/resp")"
[ -n "$URL" ] || { echo "upload-attachment: upload response has no url" >&2; exit 1; }

# --- 2. find earlier copies with the same name ---------------------------------
WI_URL="$ORG/$PROJ_ENC/_apis/wit/workitems/$ID"
call GET "$WI_URL?\$expand=relations&api-version=7.1" application/json
[ "$CODE" -ge 200 ] 2>/dev/null && [ "$CODE" -lt 300 ] || fail "work item read"

# remove ops go highest index first so earlier indexes stay valid
jq --arg name "$NAME" --arg url "$URL" '
  [ (.relations // []) | to_entries[]
    | select(.value.rel == "AttachedFile" and (.value.attributes.name // "") == $name)
    | .key ] | sort | reverse
  | map({op: "remove", path: "/relations/\(.)"})
  + [{op: "add", path: "/relations/-",
      value: {rel: "AttachedFile", url: $url, attributes: {name: $name}}}]
' "$TMP/resp" > "$TMP/patch.json"

# --- 3. link to the work item --------------------------------------------------
call PATCH "$WI_URL?api-version=7.1" application/json-patch+json --data-binary "@$TMP/patch.json"
[ "$CODE" -ge 200 ] 2>/dev/null && [ "$CODE" -lt 300 ] || fail "link"

REPLACED=$(jq '[.[] | select(.op == "remove")] | length' "$TMP/patch.json")
[ "$REPLACED" -gt 0 ] && echo "upload-attachment: replaced $REPLACED earlier '$NAME'" >&2
printf '%s\n' "$URL"
