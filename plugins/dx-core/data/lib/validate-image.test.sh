#!/usr/bin/env bash
# Tests for validate-image.sh. Run with:
#   bash plugins/dx-core/data/lib/validate-image.test.sh
#
# No framework — exits 0 on success, 1 on first failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="$SCRIPT_DIR/validate-image.sh"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0

assert_exit() {
  local desc="$1" expected="$2" actual="$3" stderr="$4"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    echo "  ok: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "    expected exit=$expected, got exit=$actual"
    [[ -n "$stderr" ]] && echo "    stderr: $stderr"
  fi
}

# --- Fixtures: synthesize PNGs via python stdlib (no third-party deps) ---

python3 - "$TMPDIR" <<'PY'
import sys, struct, zlib, os

td = sys.argv[1]

def make_png(width, height):
    """Build a minimal valid PNG (single-color rectangle)."""
    sig = b'\x89PNG\r\n\x1a\n'
    def chunk(ctype, data):
        return struct.pack(">I", len(data)) + ctype + data + struct.pack(">I", zlib.crc32(ctype + data) & 0xffffffff)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    raw = b''
    for _ in range(height):
        raw += b'\x00' + b'\xff\x00\x00' * width  # filter + red pixels
    idat = zlib.compress(raw, 9)
    return sig + chunk(b'IHDR', ihdr) + chunk(b'IDAT', idat) + chunk(b'IEND', b'')

# valid small PNG
valid = make_png(2, 2)
with open(os.path.join(td, "valid.png"), "wb") as f:
    f.write(valid)

# truncated PNG — chop last 12 bytes (removes IEND chunk entirely)
with open(os.path.join(td, "truncated-no-iend.png"), "wb") as f:
    f.write(valid[:-12])

# truncated PNG — chop mid-IDAT (removes 5 bytes from end before IEND)
with open(os.path.join(td, "truncated-mid-idat.png"), "wb") as f:
    f.write(valid[:-17])

# corrupted PNG — flip one byte in IDAT to break CRC
corrupted = bytearray(valid)
# flip byte at offset ~30 (inside IDAT data)
corrupted[30] ^= 0xff
with open(os.path.join(td, "corrupted-crc.png"), "wb") as f:
    f.write(bytes(corrupted))

print("fixtures written")
PY

echo "=== validate-image.sh tests ==="

echo "[1] Valid PNG → exit 0"
OUT=$(bash "$VALIDATOR" "$TMPDIR/valid.png" 2>&1); ST=$?
assert_exit "valid PNG passes" 0 $ST "$OUT"

echo "[2] PNG with no IEND chunk → exit 1 (truncated)"
OUT=$(bash "$VALIDATOR" "$TMPDIR/truncated-no-iend.png" 2>&1); ST=$?
assert_exit "no-IEND PNG rejected" 1 $ST "$OUT"
if [[ "$OUT" != *truncat* ]] && [[ "$OUT" != *IEND* ]]; then
  echo "    NOTE: stderr should mention truncation/IEND, got: $OUT"
fi

echo "[3] PNG with mid-IDAT truncation → exit 1"
OUT=$(bash "$VALIDATOR" "$TMPDIR/truncated-mid-idat.png" 2>&1); ST=$?
assert_exit "mid-IDAT truncation rejected" 1 $ST "$OUT"

echo "[4] PNG with bad chunk CRC → exit 1"
OUT=$(bash "$VALIDATOR" "$TMPDIR/corrupted-crc.png" 2>&1); ST=$?
assert_exit "CRC-corrupt PNG rejected" 1 $ST "$OUT"

echo "[5] Empty file → exit 1"
: > "$TMPDIR/empty.png"
OUT=$(bash "$VALIDATOR" "$TMPDIR/empty.png" 2>&1); ST=$?
assert_exit "empty file rejected" 1 $ST "$OUT"

echo "[6] Non-existent file → exit 2"
OUT=$(bash "$VALIDATOR" "$TMPDIR/nope.png" 2>&1); ST=$?
assert_exit "missing file → usage error" 2 $ST "$OUT"

echo "[7] No argument → exit 2"
OUT=$(bash "$VALIDATOR" 2>&1); ST=$?
assert_exit "no arg → usage error" 2 $ST "$OUT"

echo
echo "=== ${PASS} passed, ${FAIL} failed ==="
exit $(( FAIL > 0 ? 1 : 0 ))
