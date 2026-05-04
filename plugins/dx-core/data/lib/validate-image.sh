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
#   * files that fail a structural decode (truncated stream, corrupt
#     chunk CRC, missing terminator) — header-only checks (`file`) miss
#     these because IHDR can be intact while IDAT is incomplete. Observed
#     failure mode: the ADO MCP (`wit_get_work_item_attachment`) silently
#     truncates large attachments, producing a file that passes MIME and
#     dimension checks but trips Anthropic's full-decode pass with
#     `API Error: 400 — Could not process image`.
#
# Uses `file` (always present) for MIME and dimensions, plus python3
# stdlib (always present on macOS/Linux) for the structural decode.
# ImageMagick is not required.
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

# 4. Structural integrity — walk the file's container format end-to-end so
#    truncation or corruption inside the data stream is caught before the
#    file ever reaches the Read tool. `file -b` only inspects the header,
#    so a half-downloaded PNG with a valid IHDR but a missing IEND will
#    pass steps 1-3. Skipped if python3 is unavailable (fail open — match
#    the historical behavior so this script never becomes harder to install).
if command -v python3 >/dev/null 2>&1; then
  # Use `if !` so set -e doesn't kill the script before we report the reason.
  REASON=""
  if ! REASON=$(python3 - "$FILE" "$MIME" 2>&1 <<'PY'
import sys, struct, zlib

path, mime = sys.argv[1], sys.argv[2]
with open(path, 'rb') as f:
    data = f.read()

def fail(msg):
    print(msg)
    sys.exit(1)

if mime == 'image/png':
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        fail("corrupt: PNG signature missing")
    i = 8
    seen_iend = False
    while i < len(data):
        if i + 12 > len(data):
            fail(f"truncated: incomplete chunk header at offset {i}")
        length = struct.unpack(">I", data[i:i+4])[0]
        ctype = data[i+4:i+8]
        ctype_s = ctype.decode('ascii', errors='replace')
        end = i + 8 + length + 4
        if end > len(data):
            fail(f"truncated: {ctype_s} chunk length {length} would overrun file (have {len(data)-i-8} of {length+4} bytes)")
        crc_stored = struct.unpack(">I", data[i+8+length:i+12+length])[0]
        crc_calc = zlib.crc32(data[i+4:i+8+length]) & 0xffffffff
        if crc_stored != crc_calc:
            fail(f"corrupt: bad CRC in {ctype_s} chunk")
        if ctype == b'IEND':
            seen_iend = True
            break
        i = end
    if not seen_iend:
        fail("truncated: no IEND chunk")

elif mime == 'image/jpeg':
    if data[:2] != b'\xff\xd8':
        fail("corrupt: JPEG missing SOI marker")
    if data[-2:] != b'\xff\xd9':
        fail("truncated: JPEG missing EOI marker")

elif mime == 'image/gif':
    if data[:6] not in (b'GIF87a', b'GIF89a'):
        fail("corrupt: GIF header missing")
    if data[-1:] != b'\x3b':
        fail("truncated: GIF missing trailer (0x3B)")

elif mime == 'image/webp':
    if data[:4] != b'RIFF' or data[8:12] != b'WEBP':
        fail("corrupt: WebP RIFF header missing")
    riff_size = struct.unpack("<I", data[4:8])[0]
    if riff_size != len(data) - 8:
        fail(f"truncated: WebP RIFF size {riff_size} vs payload {len(data)-8}")

# unknown MIMEs were filtered upstream; nothing to check here
sys.exit(0)
PY
  ); then
    echo "skip: ${REASON:-integrity check failed}" >&2
    exit 1
  fi
fi

echo "ok: ${MIME}, ${SIZE} bytes${DIMS:+, ${DIMS}}"
exit 0
