#!/usr/bin/env bash
# Tests for scripts/prepared-check.sh. Hermetic: throwaway git repo, per-repo
# user config, no network. Prints PASS/FAIL per test; exits non-zero on failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/../scripts/prepared-check.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
check() {  # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "PASS: $1"; PASS=$((PASS+1))
  else echo "FAIL: $1"; echo "  expected [$2], got [$3]"; FAIL=$((FAIL+1)); fi
}
val() {  # val <key> <output>
  printf '%s\n' "$2" | sed -n "s/^$1=//p"
}

REPO="$TMP/repo"
mkdir -p "$REPO"
cd "$REPO" || exit 1
git init -q
git config user.email dev@example.com
git config user.name Dev
SPEC=".ai/specs/12345-my-story"
mkdir -p "$SPEC/docs"

step() { printf '### Step %s: x\n**Status:** %s\n**Files:** `a`\n\n' "$1" "$2"; }

# --- empty / missing ---
OUT=$(bash "$CHECK" "$TMP/nope")
check "missing dir: REQ none"       "none" "$(val REQ "$OUT")"
check "missing dir: PLAN none"      "none" "$(val PLAN "$OUT")"
check "missing dir: PLAN_WIKI no"   "no"   "$(val PLAN_WIKI "$OUT")"
check "missing dir: REVIEW n/a"     "n/a"  "$(val REVIEW "$OUT")"
check "no args: still all keys"     "5"    "$(bash "$CHECK" | grep -c '=')"

# --- partial requirements ---
printf '# T\n**Tags:** frontend; Plan-Reviewed; misc\n' > "$SPEC/raw-story.md"
OUT=$(bash "$CHECK" "$SPEC")
check "only raw-story: REQ partial" "partial" "$(val REQ "$OUT")"

touch "$SPEC/explain.md" "$SPEC/research.md"
OUT=$(bash "$CHECK" "$SPEC" "plan-reviewed")
check "all three: REQ prepared"     "prepared" "$(val REQ "$OUT")"
check "review tag found (case-insensitive)" "yes" "$(val REVIEW "$OUT")"
check "review tag absent"           "no" "$(val REVIEW "$(bash "$CHECK" "$SPEC" "Other-Tag")")"
check "review tag is not a substring match" "no" "$(val REVIEW "$(bash "$CHECK" "$SPEC" "Plan")")"

# --- plan states ---
{ step 1 pending; step 2 pending; } > "$SPEC/implement.md"
check "all pending: PLAN prepared"  "prepared" "$(val PLAN "$(bash "$CHECK" "$SPEC")")"
check "untracked plan: PLAN_BY unknown" "unknown" "$(val PLAN_BY "$(bash "$CHECK" "$SPEC")")"

{ step 1 done; step 2 pending; } > "$SPEC/implement.md"
check "mixed: PLAN in-progress"     "in-progress" "$(val PLAN "$(bash "$CHECK" "$SPEC")")"

{ step 1 done; step 2 Done; } > "$SPEC/implement.md"
check "all done (any case): PLAN done" "done" "$(val PLAN "$(bash "$CHECK" "$SPEC")")"

{ step 1 blocked; step 2 pending; } > "$SPEC/implement.md"
check "blocked + pending: PLAN in-progress" "in-progress" "$(val PLAN "$(bash "$CHECK" "$SPEC")")"

echo "# no steps" > "$SPEC/implement.md"
check "no status lines: never fresh" "in-progress" "$(val PLAN "$(bash "$CHECK" "$SPEC")")"

# --- who prepared the plan ---
{ step 1 pending; } > "$SPEC/implement.md"
git add -A && git -c user.email=architect@example.com -c user.name=Arch commit -qm prep
check "committed by someone else: PLAN_BY other" "other" "$(val PLAN_BY "$(bash "$CHECK" "$SPEC")")"
echo "" >> "$SPEC/implement.md"
git add -A && git commit -qm tweak
check "committed by me: PLAN_BY self" "self" "$(val PLAN_BY "$(bash "$CHECK" "$SPEC")")"

# --- plan wiki ---
touch "$SPEC/docs/plan-wiki.md"
check "plan-wiki.md: PLAN_WIKI yes" "yes" "$(val PLAN_WIKI "$(bash "$CHECK" "$SPEC")")"

echo "---"
echo "Total: $((PASS+FAIL)), Pass: $PASS, Fail: $FAIL"
[ "$FAIL" -eq 0 ]
