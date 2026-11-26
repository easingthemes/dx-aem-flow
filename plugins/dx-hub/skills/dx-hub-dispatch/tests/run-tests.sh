#!/usr/bin/env bash
# Hermetic tests for dx-hub-dispatch helper scripts. No network, no git.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
S="$HERE/../scripts"
F="$HERE/fixtures"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0 FAIL=0
check() {
  if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi
}
contains() {
  case "$3" in *"$2"*) PASS=$((PASS + 1)) ;; *) FAIL=$((FAIL + 1)); printf 'FAIL %s\n  expected to contain: %s\n  actual: %s\n' "$1" "$2" "$3" ;; esac
}
val() { printf '%s\n' "$1" | sed -n "s/^$2=//p"; }

# ── hub-config.sh ────────────────────────────────────────────────────────────
out="$(bash "$S/hub-config.sh" "$F/hub-legacy.yaml" 2>"$TMP/err")"; rc=$?
err="$(cat "$TMP/err")"
check "legacy: exit 0" 0 "$rc"
check "legacy: engine default" claude "$(val "$out" engine)"
check "legacy: delay default" 5 "$(val "$out" terminal_delay)"
check "legacy: launcher default" auto "$(val "$out" launcher)"
check "legacy: provider default" ado "$(val "$out" provider)"
check "legacy: model empty" "" "$(val "$out" model)"
contains "legacy: engine default announced" "default: hub.engine not set — using claude" "$err"
contains "legacy: delay default announced" "default: hub.terminal-delay not set — using 5" "$err"
contains "legacy: provider default announced" "default: tracker.provider not set — using ado" "$err"
contains "legacy: missing capabilities warned" "warn: repo site-beta has no capabilities" "$err"
check "legacy: four repos" 4 "$(printf '%s\n' "$out" | grep -c '^repo=')"
check "legacy: repo row" "$(printf 'repo=shared-core\t../shared-core\tProject Two\tfe,be,sling\t')" "$(printf '%s\n' "$out" | grep '^repo=shared-core')"

out="$(bash "$S/hub-config.sh" "$F/hub-current.yaml" 2>"$TMP/err")"; rc=$?
err="$(cat "$TMP/err")"
check "current: exit 0" 0 "$rc"
check "current: no defaults or warnings" "" "$err"
check "current: engine" copilot "$(val "$out" engine)"
check "current: model unquoted" some-model "$(val "$out" model)"
check "current: delay" 8 "$(val "$out" terminal_delay)"
check "current: launcher" none "$(val "$out" launcher)"
check "current: scm project" my-project "$(val "$out" scm_project)"
check "current: block list + inline keywords" "$(printf 'repo=shop-fe\t../shop-fe\tmy-project\tfe\tstorefront,checkout ui')" "$(printf '%s\n' "$out" | grep '^repo=shop-fe')"
check "current: block keywords" "$(printf 'repo=shop-be\t../shop-be\t\tbe\torders')" "$(printf '%s\n' "$out" | grep '^repo=shop-be')"

bash "$S/hub-config.sh" "$F/hub-bad.yaml" >/dev/null 2>"$TMP/err"; rc=$?
err="$(cat "$TMP/err")"
check "bad: exit 4" 4 "$rc"
contains "bad: engine" "hub.engine 'cursor'" "$err"
contains "bad: delay" "hub.terminal-delay 'soon'" "$err"
contains "bad: launcher" "hub.launcher 'tmux'" "$err"

bash "$S/hub-config.sh" "$F/hub-disabled.yaml" >/dev/null 2>&1; check "disabled: exit 3" 3 "$?"
bash "$S/hub-config.sh" "$TMP/nope.yaml" >/dev/null 2>&1; check "missing: exit 2" 2 "$?"

# ── match-repos.sh ───────────────────────────────────────────────────────────
t() { printf '%s\n' "$@" > "$TMP/ticket.txt"; }

t "Alpha: update hero spacing" "Area: Team\\Sites\\Alpha"
out="$(bash "$S/match-repos.sh" "$F/hub-legacy.yaml" "$TMP/ticket.txt")"; rc=$?
check "token: exit 0" 0 "$rc"
check "token: alpha only" "$(printf 'site-alpha-global-2.0\tname-token:alpha')" "$out"

t "Beta and alpha checkout copy" "Area: Web"
out="$(bash "$S/match-repos.sh" "$F/hub-legacy.yaml" "$TMP/ticket.txt")"
check "token: two brands" 2 "$(printf '%s\n' "$out" | grep -c .)"

t "Fix shared core sling model" "Area: Platform"
bash "$S/match-repos.sh" "$F/hub-legacy.yaml" "$TMP/ticket.txt" >/dev/null; rc=$?
check "generic and shared tokens never match: exit 8" 8 "$rc"

t "Global site footer 2.0"
bash "$S/match-repos.sh" "$F/hub-legacy.yaml" "$TMP/ticket.txt" >/dev/null; rc=$?
check "stoplist and digits never match: exit 8" 8 "$rc"

t "Alphabet soup in the footer"
bash "$S/match-repos.sh" "$F/hub-legacy.yaml" "$TMP/ticket.txt" >/dev/null; rc=$?
check "whole words only: exit 8" 8 "$rc"

t "Regression in shared-core after merge"
out="$(bash "$S/match-repos.sh" "$F/hub-legacy.yaml" "$TMP/ticket.txt")"
check "full name match" "$(printf 'shared-core\tname')" "$out"

t "Checkout UI button misaligned"
out="$(bash "$S/match-repos.sh" "$F/hub-current.yaml" "$TMP/ticket.txt")"
check "multi-word keyword" "$(printf 'shop-fe\tkeyword:checkout ui')" "$out"

t "Orders export times out"
out="$(bash "$S/match-repos.sh" "$F/hub-current.yaml" "$TMP/ticket.txt")"
check "block-list keyword" "$(printf 'shop-be\tkeyword:orders')" "$out"

bash "$S/match-repos.sh" "$F/hub-disabled.yaml" "$TMP/ticket.txt" >/dev/null 2>&1; check "match: disabled hub exit 3" 3 "$?"

# ── build-launch.sh ──────────────────────────────────────────────────────────
U="0b1c2d3e-0000-4000-8000-000000000001"
P="Ticket 12345 raw content is pre-seeded. Now run: /dx-core:dx-agent-all 12345"
cmd="$(bash "$S/build-launch.sh" --engine copilot --cwd "$TMP/my repo" --session "$U" --prompt "$P" --out "$TMP/launch/a.sh" --model some-model)"; rc=$?
check "copilot: exit 0" 0 "$rc"
check "copilot: command" "DX_RUN_ID=$U copilot --session-id $U --model some-model -i \"$P\"" "$cmd"
check "copilot: script executable" yes "$([ -x "$TMP/launch/a.sh" ] && echo yes || echo no)"

cmd="$(bash "$S/build-launch.sh" --engine claude --cwd "$TMP/repo" --session "$U" --prompt "$P" --out "$TMP/launch/b.sh")"
check "claude: command" "DX_RUN_ID=$U claude --session-id $U \"$P\"" "$cmd"

# The written script really runs: stub the CLI on PATH, check cwd, env and argv.
mkdir -p "$TMP/bin" "$TMP/my repo"
cat > "$TMP/bin/copilot" <<'EOF'
#!/usr/bin/env bash
printf 'cwd=%s\nrun=%s\n' "$(pwd)" "$DX_RUN_ID"
for a in "$@"; do printf 'arg=%s\n' "$a"; done
EOF
chmod +x "$TMP/bin/copilot"
run="$(PATH="$TMP/bin:$PATH" bash "$TMP/launch/a.sh")"
contains "script: cwd with space" "cwd=$TMP/my repo" "$run"
contains "script: DX_RUN_ID" "run=$U" "$run"
contains "script: prompt is one argv" "arg=$P" "$run"

bash "$S/build-launch.sh" --engine claude --cwd /x --session "$U" --prompt 'say "hi"' --out "$TMP/c.sh" 2>/dev/null; check "rejects double quote" 2 "$?"
bash "$S/build-launch.sh" --engine claude --cwd /x --session "$U" --prompt 'cost $5' --out "$TMP/c.sh" 2>/dev/null; check "rejects dollar" 2 "$?"
bash "$S/build-launch.sh" --engine claude --cwd /x --session "ABC" --prompt 'ok' --out "$TMP/c.sh" 2>/dev/null; check "rejects non-uuid session" 2 "$?"
bash "$S/build-launch.sh" --engine cursor --cwd /x --session "$U" --prompt 'ok' --out "$TMP/c.sh" 2>/dev/null; check "rejects engine" 2 "$?"
bash "$S/build-launch.sh" --engine claude --cwd /x --session "$U" --prompt 'ok' --out "$TMP/c.sh" --model 'a;rm' 2>/dev/null; check "rejects model metachar" 2 "$?"
bash "$S/build-launch.sh" --engine claude --session "$U" --prompt 'ok' --out "$TMP/c.sh" 2>/dev/null; check "requires cwd" 2 "$?"

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
