#!/usr/bin/env bash
# status-json.sh — print every hub dispatch status file as one JSON array.
#
# Usage: status-json.sh [state-dir] [ticket-id]
#   state-dir  default: state (relative to the hub directory)
#   ticket-id  only that dispatch (array of 0 or 1 entries)
#
# Each entry is the status.json object as written by /dx-hub-dispatch. A file
# that is empty or not a JSON object (e.g. half-written) becomes
#   {"ticket": "<dir name>", "error": "unreadable status.json"}
# so one bad file never breaks the array. Always exits 0 with valid JSON
# (an empty state dir prints []).

set -uo pipefail

STATE_DIR="${1:-state}"
ONLY="${2:-}"

json_str() { local s="${1//\\/\\\\}"; s="${s//\"/\\\"}"; printf '"%s"' "$s"; }

first=1
printf '['
for f in "$STATE_DIR"/*/status.json; do
  [ -f "$f" ] || continue
  dir="$(basename "$(dirname "$f")")"
  [ -n "$ONLY" ] && [ "$dir" != "$ONLY" ] && continue
  body="$(cat "$f" 2>/dev/null)"
  # Trim surrounding whitespace; accept a single top-level object only.
  trimmed="$(printf '%s' "$body" | tr -d '\r' | sed -e '1s/^[[:space:]]*//' -e '$s/[[:space:]]*$//')"
  case "$trimmed" in
    \{*\}) entry="$trimmed" ;;
    *) entry="{\"ticket\": $(json_str "$dir"), \"error\": \"unreadable status.json\"}" ;;
  esac
  if [ "$first" = 1 ]; then first=0; printf '\n'; else printf ',\n'; fi
  printf '%s' "$entry"
done
[ "$first" = 1 ] && printf ']\n' || printf '\n]\n'
