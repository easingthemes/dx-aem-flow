#!/usr/bin/env bash
# Computes pixel similarity between two PNGs. Reports two numbers:
#   - similarity-overall: % identical pixels (0.0–100.0)
#   - similarity-region: % identical pixels INSIDE the bounding box (optional)
#
# Used for confidence gates G5 (non-target ≥99% identical) and G6 (target ≥5% different).
#
# Usage: visual-diff.sh <before.png> <after.png> [x,y,w,h]
# Writes JSON to stdout: {"overall": 99.4, "region-diff": 17.8, "px-total": 4096, "px-changed": 24}

set -euo pipefail

BEFORE="${1:?before.png required}"
AFTER="${2:?after.png required}"
BBOX="${3:-}"

# Use Python with stdlib only (PIL not assumed)
python3 - "$BEFORE" "$AFTER" "$BBOX" <<'PY'
import json, struct, sys, zlib

def read_png(path):
  with open(path, 'rb') as f:
    sig = f.read(8)
    assert sig == b'\x89PNG\r\n\x1a\n', f'not a PNG: {path}'
    w = h = depth = ctype = 0
    idat = b''
    while True:
      length_bytes = f.read(4)
      if len(length_bytes) < 4: break
      length = struct.unpack('>I', length_bytes)[0]
      typ = f.read(4)
      data = f.read(length)
      f.read(4)  # crc
      if typ == b'IHDR':
        w, h, depth, ctype = struct.unpack('>IIBB', data[:10])
      elif typ == b'IDAT':
        idat += data
      elif typ == b'IEND':
        break
  raw = zlib.decompress(idat)
  bpp = 3 if ctype == 2 else 4 if ctype == 6 else None
  assert bpp is not None, f'unsupported color type {ctype}'
  stride = w * bpp + 1
  pixels = []
  for y in range(h):
    line = raw[y*stride : (y+1)*stride]
    pixels.append(line[1:])
  return w, h, bpp, pixels

bp, ap, bb = sys.argv[1], sys.argv[2], sys.argv[3]
bw, bh, bbpp, brows = read_png(bp)
aw, ah, abpp, arows = read_png(ap)
assert (bw, bh) == (aw, ah), 'dimensions mismatch'
assert bbpp == abpp, 'channel count mismatch'

total = bw * bh
changed = 0
region_total = 0
region_changed = 0
rx = ry = rw = rh = 0
if bb:
  rx, ry, rw, rh = (int(x) for x in bb.split(','))

for y in range(bh):
  brow, arow = brows[y], arows[y]
  for x in range(bw):
    off = x * bbpp
    px_b = brow[off:off+bbpp]
    px_a = arow[off:off+bbpp]
    diff = px_b != px_a
    if diff:
      changed += 1
    if bb and (rx <= x < rx + rw) and (ry <= y < ry + rh):
      region_total += 1
      if diff:
        region_changed += 1

overall = 100.0 * (1 - changed / total)
out = {'overall': round(overall, 2), 'px-total': total, 'px-changed': changed}
if bb:
  region_diff_pct = 100.0 * region_changed / region_total if region_total else 0
  non_target_total = total - region_total
  non_target_changed = changed - region_changed
  non_target_pct = 100.0 * (1 - non_target_changed / non_target_total) if non_target_total else 100.0
  out['region-diff'] = round(region_diff_pct, 2)
  out['non-target-identical'] = round(non_target_pct, 2)

print(json.dumps(out))
PY
