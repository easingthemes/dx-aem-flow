#!/usr/bin/env bash
# Extracts the ```simple``` fenced block from a raw-story.md and writes
# simple-block.yaml. Exits non-zero with a printable error if the block is
# missing or malformed.
#
# Usage: parse-simple-block.sh <raw-story.md> <output-yaml-path>
# Exit codes:
#   0  — block parsed successfully
#   2  — block missing
#   3  — block malformed (missing required field)

set -euo pipefail

RAW="${1:?raw-story.md path required}"
OUT="${2:?output yaml path required}"

if [[ ! -f "$RAW" ]]; then
  echo "ERROR: raw-story file not found: $RAW" >&2
  exit 2
fi

# Extract content between ```simple and the next ```
BLOCK=$(awk '
  /^```simple[[:space:]]*$/ { in_block=1; next }
  in_block && /^```[[:space:]]*$/ { in_block=0; exit }
  in_block { print }
' "$RAW")

if [[ -z "$BLOCK" ]]; then
  echo "ERROR: no \`\`\`simple block found in $RAW" >&2
  exit 2
fi

# Strip inline comments (# ...) and blank lines, keep key: value
CLEAN=$(echo "$BLOCK" | sed -E 's/[[:space:]]*#.*$//' | sed -E '/^[[:space:]]*$/d')

# Required fields
for FIELD in page-url component-locator change-type change-value; do
  if ! echo "$CLEAN" | grep -qE "^${FIELD}:"; then
    echo "ERROR: required field '${FIELD}' missing from simple block" >&2
    exit 3
  fi
done

# Validate change-type enum
CHANGE_TYPE=$(echo "$CLEAN" | grep -E '^change-type:' | head -1 | sed -E 's/^change-type:[[:space:]]*//')
case "$CHANGE_TYPE" in
  aria-label|color-token|spacing|copy|css-class|icon) ;;
  *)
    echo "ERROR: change-type '${CHANGE_TYPE}' not in allowed enum (aria-label|color-token|spacing|copy|css-class|icon)" >&2
    exit 3
    ;;
esac

# Write YAML output (line-by-line, preserve order)
echo "$CLEAN" > "$OUT"
echo "OK: parsed simple block to $OUT" >&2
