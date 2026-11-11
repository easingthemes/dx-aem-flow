#!/usr/bin/env bash
# copilot-bundle-check.sh — does the shipped Copilot CLI still contain what dx relies on?
#
# Downloads the Copilot CLI linux-x64 package from npm (nothing is installed or
# run), decompresses the JS bundle embedded in the binary, and looks for strings
# behind behaviour we verified by hand (docs/testing/copilot-cli-retest.md).
# A MISSING string means that behaviour may have changed: re-run the matching
# interactive check. Needs the network, so it is NOT a test suite (no *.test.sh).
#
# Usage: copilot-bundle-check.sh [version]   (default: latest on npm)
# Exit:  0 all found · 1 something missing · 2 download/extract failed
set -euo pipefail

VERSION="${1:-$(npm view @github/copilot version)}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Copilot CLI $VERSION"
( cd "$WORK" && npm pack "@github/copilot-linux-x64@$VERSION" --silent >/dev/null && tar -xzf ./*.tgz ) \
  || { echo "download failed for @github/copilot-linux-x64@$VERSION"; exit 2; }

# key ⇒ what it stands for (keep in sync with docs/testing/copilot-cli-retest.md)
python3 -I - "$WORK/package/copilot" <<'PY'
import re, sys, zlib
checks = [
    (b'include-custom-instructions', 'agent field: subagents get project instructions (TODO-202)'),
    (b'Preferred agent definition models are unavailable', 'agent model falls back to the session model'),
    (b'GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS==="true"', 'prompt-mode gate compares to "true" (TODO-249)'),
    (b'COPILOT_HOOK_DIR', 'Copilot-only hook env var gating dx progress lines (TODO-270)'),
    (b'hook.progress', 'hook progress lines (TODO-270)'),
    (b'Base directory for this skill', 'skill base dir given to the model: ../../shared/ paths (TODO-20)'),
    (b'Denied by preToolUse hook (hook errored)', 'erroring preToolUse hook denies (branch guard fail-closed)'),
    (b'timed out; allowing the tool call to proceed', 'hook timeout fails open (TODO-262)'),
    (b'stop_hook_active', 'agentStop input carries stop_hook_active (stop guard, TODO-262)'),
]
d = open(sys.argv[1], 'rb').read()
bundle = None
for m in re.finditer(b'\x1f\x8b\x08', d):
    try:
        x = zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(d[m.start():m.start() + 80_000_000])
    except Exception:
        continue
    if len(x) > 10_000_000:
        bundle = x
        break
if bundle is None:
    print('no embedded JS bundle found — the binary layout changed; inspect it by hand')
    sys.exit(2)
missing = 0
for key, why in checks:
    ok = key in bundle
    missing += not ok
    print(f"{'found  ' if ok else 'MISSING'}  {key.decode():50}  {why}")
sys.exit(1 if missing else 0)
PY
