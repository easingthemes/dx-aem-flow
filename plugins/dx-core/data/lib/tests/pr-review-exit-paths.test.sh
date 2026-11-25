#!/usr/bin/env bash
# Hermetic tests for dx-pr-review's mode detection and exit-path contract.
# Runs the Automation Mode bash block straight out of SKILL.md (so the test
# breaks when the documented block does) and checks that the skill documents a
# run result for every non-posting exit. No network, no git.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CORE="$(cd "$HERE/../../.." && pwd)"
SKILL="$CORE/skills/dx-pr-review/SKILL.md"
POST="$CORE/skills/dx-pr-review/references/post-findings.md"
ANSWER="$CORE/skills/dx-pr-answer/SKILL.md"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0 FAIL=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi
}

# First ```bash block after the "## Automation Mode" heading (or the given
# heading/marker) in a markdown file.
extract() { # file heading
  awk -v h="$2" '
    index($0, h) == 1 { seen = 1; next }
    seen && !inb && /^```bash/ { inb = 1; next }
    inb && /^```/ { exit }
    inb { print }
  ' "$1"
}

BLOCK="$TMP/detect.sh"
extract "$SKILL" "## Automation Mode" > "$BLOCK"
check "detect block found" yes "$([ -s "$BLOCK" ] && echo yes)"
check "detect block ends with exit 0" "exit 0" "$(grep -v '^)$' "$BLOCK" | grep -v '^[[:space:]]*$' | tail -1)"

# Run the block in an empty project dir with a clean env. $1 = what Claude Code
# would substitute for $ARGUMENTS.
run() { # args [env...]
  local args="$1"; shift
  local dir; dir="$(mktemp -d "$TMP/p.XXXX")"
  local script="$dir/detect.sh"
  # Same substitution Claude Code performs on the skill text.
  ARGS_SUB="$args" awk '{ gsub(/\$ARGUMENTS/, ENVIRON["ARGS_SUB"]); print }' "$BLOCK" > "$script"
  [ -n "${MKFLAG:-}" ] && { mkdir -p "$dir/.ai/run-context"; touch "$dir/.ai/run-context/orchestrating.flag"; [ "$MKFLAG" = old ] && touch -t 202001010000 "$dir/.ai/run-context/orchestrating.flag"; }
  (cd "$dir" && env -i PATH="$PATH" HOME="$dir" "$@" bash -e "$script" 2>"$dir/err"; echo "rc=$?")
}

out=$(run "12345")
check "no files: exits 0" "rc=0" "$(printf '%s\n' "$out" | tail -1)"
check "no files: interactive/none" "mode=interactive automation_reason=none" "$(printf '%s\n' "$out" | grep '^mode=')"
check "no files: auto_vote defaults false" yes "$(printf '%s\n' "$out" | grep -q 'auto_vote=false' && echo yes)"

out=$(run "12345" DX_PIPELINE_MODE=true)
check "env: automation/env" "mode=automation automation_reason=env" "$(printf '%s\n' "$out" | grep '^mode=')"
check "env: exits 0" "rc=0" "$(printf '%s\n' "$out" | tail -1)"

out=$(MKFLAG=fresh run "12345")
check "fresh flag: automation/flag" "mode=automation automation_reason=flag" "$(printf '%s\n' "$out" | grep '^mode=')"

out=$(MKFLAG=old run "12345")
check "stale flag: interactive" "mode=interactive automation_reason=none" "$(printf '%s\n' "$out" | grep '^mode=')"
check "stale flag: exits 0" "rc=0" "$(printf '%s\n' "$out" | tail -1)"

for word in autopilot autonomous non-interactive AUTOPILOT; do
  out=$(run "12345 $word")
  check "args '$word': automation/args" "mode=automation automation_reason=args" "$(printf '%s\n' "$out" | grep '^mode=')"
done

out=$(run "it's \"quoted\" \$(false) 12345")
check "quoted args: exits 0" "rc=0" "$(printf '%s\n' "$out" | tail -1)"
check "quoted args: interactive" "mode=interactive automation_reason=none" "$(printf '%s\n' "$out" | grep '^mode=')"

# Sibling detect blocks: must never fail either.
for f in "$POST:Detect automation the same way" "$ANSWER:## Automation Mode"; do
  file="${f%%:*}"; head="${f#*:}"
  extract "$file" "$head" > "$TMP/sib.sh"
  name="$(basename "$(dirname "$file")")/$(basename "$file")"
  check "$name: block found" yes "$([ -s "$TMP/sib.sh" ] && echo yes)"
  check "$name: ends with exit 0" "exit 0" "$(grep -v '^)$' "$TMP/sib.sh" | grep -v '^[[:space:]]*$' | tail -1)"
  d="$(mktemp -d "$TMP/s.XXXX")"
  rc=$(cd "$d" && env -i PATH="$PATH" HOME="$d" bash -e "$TMP/sib.sh" >/dev/null 2>&1; echo $?)
  check "$name: exits 0 with no files" 0 "$rc"
done

# Exit-path contract documented in SKILL.md.
section() { awk '/^## Before you stop/{s=1; next} s && /^## /{exit} s' "$SKILL"; }
SEC="$(section)"
check "Before you stop section" yes "$([ -n "$SEC" ] && echo yes)"
check "names run-result.md" yes "$(printf '%s' "$SEC" | grep -q 'shared/run-result.md' && echo yes)"
check "verdict always set" yes "$(printf '%s' "$SEC" | grep -q -- '--verdict. set whenever' && echo yes)"
check "vote only if cast" yes "$(printf '%s' "$SEC" | grep -q -- '--vote. only if' && echo yes)"
for row in 'Analyze-only' 'declined' 'cannot ask'; do
  check "exit table row: $row" yes "$(printf '%s' "$SEC" | grep -i "^|.*$row" | grep -q 'post findings' && echo yes)"
done
check "cannot-ask rule is blocked" yes "$(grep '^\*\*Interactive run that cannot ask' "$SKILL" | grep -q -- '--status blocked --next "/dx-pr-review <id> post findings" --verdict' && echo yes)"
check "analyze-only writes run result" yes "$(awk '/^### 4f\./{s=1;next} s&&/^### /{exit} s' "$SKILL" | grep -q 'run result' && echo yes)"
check "step 12 points back" yes "$(awk '/^### 12\. Run Result/{s=1;next} s&&/^## /{exit} s' "$SKILL" | grep -q '#before-you-stop' && echo yes)"

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
