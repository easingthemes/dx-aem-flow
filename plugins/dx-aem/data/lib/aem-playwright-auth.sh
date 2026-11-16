#!/usr/bin/env bash
# aem-playwright-auth.sh — produce Playwright auth artifacts for AEM browser agents.
#
# WHY: keeps AEM credentials OUT of the model/transcript. The password is read
# from AEM_INSTANCES (the same single source the AEM MCP server uses) INSIDE this
# script and exchanged server-side for a session cookie. The model only ever
# references the produced file path (via browser_set_storage_state) — it never
# sees the secret. This is the Playwright analog of how the AEM MCP server
# receives `-I ${AEM_INSTANCES}` and authenticates server-side.
#
# Scope: AEM author login only (login-token cookie -> storageState JSON). Basic Auth
# on QA/stage sites is a separate layer handled by dx-core: BASIC_AUTH_SITES and
# the `basic-auth` rule (applied inside the browser by the playwright init-page).
#
# Usage:
#   aem-playwright-auth.sh author <local|qa>   # AEM author login  -> .ai/playwright/aem-author-state.json
#
# Author flow (runtime, decoupled from MCP launch):
#   1) bash .ai/lib/aem-playwright-auth.sh author qa
#   2) browser_set_storage_state  path: ".ai/playwright/aem-author-state.json"   (needs --caps=storage)
#   3) browser_navigate  url: "<author-url>..."   -> already authenticated
#
# Exit: 0 ok, 1 usage/cred error, 2 login failed.

set -euo pipefail

OUT_DIR=".ai/playwright"
STATE_FILE="$OUT_DIR/aem-author-state.json"

# jq is used to emit valid JSON regardless of special chars in tokens/passwords.
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required (brew install jq / apt-get install jq)" >&2; exit 1; }

# Locate dx-common.sh (consumer .ai/lib, or alongside this script in the plugin).
_common() {
  local c
  for c in ".ai/lib/dx-common.sh" "$(dirname "$0")/dx-common.sh" "$(dirname "$0")/../../../dx-core/data/lib/dx-common.sh"; do
    [ -f "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

aem_author_login() {
  local instance="${1:-local}" common
  common="$(_common)" || { echo "ERROR: dx-common.sh not found (run /dx-init)" >&2; return 1; }

  # Resolve URL/user/pass from AEM_INSTANCES (sets $AEM_URL $AEM_USER $AEM_PASS).
  eval "$(bash "$common" aem-instance "$instance" 2>/dev/null)" || {
    echo "ERROR: cannot resolve instance '$instance' from AEM_INSTANCES" >&2; return 1; }
  [ -n "${AEM_URL:-}" ] && [ -n "${AEM_USER:-}" ] && [ -n "${AEM_PASS:-}" ] || {
    echo "ERROR: AEM_INSTANCES missing url/user/pass for '$instance'" >&2; return 1; }

  local scheme host secure
  scheme="${AEM_URL%%://*}"
  host="$(printf '%s' "$AEM_URL" | sed -E 's#^[a-z]+://##; s#/.*$##; s#:.*$##')"
  [ "$scheme" = "https" ] && secure="true" || secure="false"

  # AEM form login over HTTP. _charset_=utf-8 is REQUIRED or the 302 carries no cookie.
  local headers token
  headers="$(curl -sS -i -o - -X POST \
      --data-urlencode "_charset_=utf-8" \
      --data-urlencode "j_username=$AEM_USER" \
      --data-urlencode "j_password=$AEM_PASS" \
      "$AEM_URL/libs/granite/core/content/login.html/j_security_check" 2>/dev/null || true)"
  # Extract the login-token value; strip the trailing CR (CRLF headers) and any
  # "; Path=..." suffix. tr handles the bare "login-token=x\r" case too.
  token="$(printf '%s' "$headers" | grep -i '^set-cookie:[[:space:]]*login-token=' | head -1 \
            | sed -E 's/^[^=]*=//; s/;.*$//' | tr -d '\r\n' || true)"

  if [ -z "$token" ]; then
    echo "ERROR: AEM author login failed (no login-token returned) for $AEM_URL" >&2
    echo "  Check AEM_INSTANCES creds for '$instance' and that the author is reachable." >&2
    return 2
  fi

  mkdir -p "$OUT_DIR"
  # Playwright storageState. expires:-1 = session cookie; httpOnly so only CDP/Playwright can set it.
  # jq encodes the token/host safely (a stray " or \ would otherwise corrupt the JSON).
  jq -n --arg tok "$token" --arg host "$host" --argjson secure "$secure" \
    '{cookies:[{name:"login-token",value:$tok,domain:$host,path:"/",expires:-1,httpOnly:true,secure:$secure,sameSite:"Lax"}],origins:[]}' \
    > "$STATE_FILE"
  echo "wrote $STATE_FILE  (author=$instance host=$host)"
}

cmd="${1:-}"; [ $# -gt 0 ] && shift || true
case "$cmd" in
  author) aem_author_login "${1:-local}" ;;
  *) echo "Usage: aem-playwright-auth.sh author <local|qa>" >&2; exit 1 ;;
esac
