#!/usr/bin/env bash
# Extracts the ```simple``` fenced block from a raw-story.md and writes
# simple-block.yaml. Exits non-zero with a printable error if the block is
# missing or malformed.
#
# Required field: page-url only.
# Optional fields: element, what, brand, platform, scope, activate.
# Anything else is preserved verbatim — the skill's LLM phases use these
# as hints. The kind of change (authoring vs code, what field to edit, etc.)
# is inferred entirely from the natural-language what + story prose
# by classify-work.sh and the Phase 2 subagents.
#
# Usage: parse-simple-block.sh <raw-story.md> <output-yaml-path>
# Exit codes:
#   0  — block parsed successfully
#   2  — block missing (file not found or no fenced block) — skill falls
#         back to LLM extraction from the story prose
#   3  — block malformed (missing page-url, duplicate field, or
#         unterminated fence)
#
# Comment handling: only WHOLE-LINE comments are stripped (lines whose
# first non-whitespace character is `#`). Inline `#` characters inside
# values are preserved verbatim (e.g. `what: "use #FF0000 hex"`).
# If you need a comment, put it on its own line.
#
# Line endings: CRLF input is normalized to LF before parsing.

set -euo pipefail

RAW="${1:?raw-story.md path required}"
OUT="${2:?output yaml path required}"

if [[ ! -f "$RAW" ]]; then
  echo "ERROR: raw-story file not found: $RAW" >&2
  exit 2
fi

# Extract optional ticket from frontmatter (between --- markers at top of file)
TICKET_LINE=$(awk '
  /^---[[:space:]]*$/ { count++; if (count == 2) exit; next }
  count == 1 && /^ticket:/ { print; exit }
' < <(tr -d '\r' < "$RAW"))

# Normalize CRLF -> LF so awk fence patterns match on Windows-authored files.
RAW_CLEAN=$(tr -d '\r' < "$RAW")

# Extract content between ```simple and the next ```.
# awk exits 1 if the opening fence was seen but never closed.
set +e
BLOCK=$(echo "$RAW_CLEAN" | awk '
  /^```simple[[:space:]]*$/ { in_block=1; next }
  in_block && /^```[[:space:]]*$/ { in_block=0; found_close=1; exit }
  in_block { print }
  END { if (in_block && !found_close) exit 1 }
')
AWK_STATUS=$?
set -e

if [[ "$AWK_STATUS" != "0" ]]; then
  echo "ERROR: simple block opened but never closed (missing \`\`\` fence) in $RAW" >&2
  exit 3
fi

if [[ -z "$BLOCK" ]]; then
  echo "ERROR: no \`\`\`simple block found in $RAW" >&2
  exit 2
fi

# Clean:
#  - Drop whole-line comments (first non-whitespace is `#`).
#  - Strip trailing whitespace from every line so downstream enum/value
#    checks aren't confused by stray tabs/spaces.
#  - Drop blank lines.
# Inline `#` is preserved — see header comment.
CLEAN=$(echo "$BLOCK" \
  | sed -E '/^[[:space:]]*#/d' \
  | sed -E 's/[[:space:]]+$//' \
  | sed -E '/^[[:space:]]*$/d')

# Only page-url is strictly required — everything else can be inferred from
# story prose by the LLM phases (element from a Chrome snapshot of
# the page, the kind of change from the what text, etc.).
if ! echo "$CLEAN" | grep -qE '^page-url:'; then
  echo "ERROR: required field 'page-url' missing from simple block" >&2
  exit 3
fi

# Duplicate-field check: every known field must appear at most once.
# Legacy `change-type` is silently tolerated (it's ignored downstream).
for FIELD in page-url element what why brand platform scope activate change-type; do
  COUNT=$(echo "$CLEAN" | grep -cE "^${FIELD}:" || true)
  if [[ "$COUNT" -gt 1 ]]; then
    echo "ERROR: duplicate field '${FIELD}' in simple block" >&2
    exit 3
  fi
done

# Write YAML output (line-by-line, preserve order)
echo "$CLEAN" > "$OUT"

# Prepend frontmatter ticket if present
if [[ -n "$TICKET_LINE" ]]; then
  { echo "$TICKET_LINE"; cat "$OUT"; } > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
fi

echo "OK: parsed simple block to $OUT" >&2
