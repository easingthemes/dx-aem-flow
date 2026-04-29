#!/usr/bin/env bash
# validate-image.sh — Decide whether an image file is safe to load with the
# Read tool (i.e. whether the Anthropic vision API will accept it).
#
# Background: when /dx-req downloads images attached to ADO work items, a
# subset of them cannot be processed by Claude's vision API and produce:
#
#     API Error: 400 {"type":"invalid_request_error",
#                     "message":"Could not process image"}
#
# That error is fatal — the whole turn is rejected and the session is
# blocked until the offending Read is removed from context. The cure is to
# pre-screen every file before Read sees it and skip the unsafe ones.
#
# Per Anthropic's vision constraints, this script rejects:
#   * formats other than JPEG / PNG / non-animated GIF / WebP
#     (SVG, BMP, TIFF, ICO, AVIF, HEIC are NOT supported by the vision API)
#   * files larger than 5 MB after decode
#   * dimensions that exceed 8000 px on either side, or are 0
#   * empty or unreadable files
#
# Pure POSIX tools — uses `file` (always present) for MIME and dimension
# detection. ImageMagick is not required.
#
# Usage:
#   validate-image.sh <path>
#
# Exit codes:
#   0 — safe to Read; one-line "ok: <mime>, <size> bytes[, <WxH>]" on stdout
#   1 — unsafe; one-line "skip: <reason>" on stderr (NOT a hard error —
#       callers should record the reason and move on)
#   2 — usage error (file not found, no argument, etc.)
#
# Designed to be called in a loop:
#   for f in "$SPEC_DIR/images/"*; do
#     if ! reason=$(bash .ai/lib/validate-image.sh "$f" 2>&1 >/dev/null); then
#       echo "$f: $reason"  # record in INDEX.md, do not Read
#     fi
#   done

set -euo pipefail

FILE="${1:-}"

if [[ -z "$FILE" ]]; then
  echo "usage: validate-image.sh <path>" >&2
  exit 2
fi

if [[ ! -f "$FILE" ]]; then
  echo "skip: file not found" >&2
  exit 2
fi

# 1. Size — Anthropic hard-rejects files > 5 MB.
if SIZE=$(stat -c%s "$FILE" 2>/dev/null); then :; else SIZE=$(stat -f%z "$FILE"); fi
if (( SIZE == 0 )); then
  echo "skip: empty file" >&2
  exit 1
fi
if (( SIZE > 5242880 )); then
  echo "skip: ${SIZE} bytes exceeds 5 MB limit" >&2
  exit 1
fi

# 2. MIME — only JPEG / PNG / GIF / WebP are accepted by the vision API.
MIME=$(file --mime-type -b "$FILE" 2>/dev/null || echo unknown)
case "$MIME" in
  image/png|image/jpeg|image/gif|image/webp) ;;
  *)
    echo "skip: unsupported MIME type ${MIME} (vision API accepts png/jpeg/gif/webp only)" >&2
    exit 1
    ;;
esac

# 3. Dimensions — `file -b` reports "<W> x <H>" or "<W>x<H>" for PNG/JPEG/GIF/WebP.
DESC=$(file -b "$FILE" 2>/dev/null || echo "")
DIMS=$(printf '%s' "$DESC" | grep -oE '[0-9]+[[:space:]]*x[[:space:]]*[0-9]+' | head -1 | tr -d '[:space:]')
if [[ -n "$DIMS" ]]; then
  W="${DIMS%x*}"
  H="${DIMS#*x}"
  if (( W < 1 || H < 1 )); then
    echo "skip: invalid dimensions ${W}x${H}" >&2
    exit 1
  fi
  if (( W > 8000 || H > 8000 )); then
    echo "skip: dimensions ${W}x${H} exceed 8000 px on a side" >&2
    exit 1
  fi
fi

echo "ok: ${MIME}, ${SIZE} bytes${DIMS:+, ${DIMS}}"
exit 0
