#!/usr/bin/env bash
# Hermetic tests for data/lib/eval-case-check.sh: the repo's own eval suites
# pass, and each rule fails on a known-bad case. No eval run, no network.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CHK="$HERE/../eval-case-check.sh"
REPO_PLUGINS="$(cd "$HERE/../../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0 FAIL=0
check() { if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi; }

# Every evals/ folder shipped in this repo must pass.
for d in "$REPO_PLUGINS"/*/evals; do
  [ -d "$d" ] || continue
  out=$(bash "$CHK" "$d"); rc=$?
  check "repo suite passes: ${d#$REPO_PLUGINS/}" "0" "$rc"
  [ "$rc" = 0 ] || printf '%s\n' "$out"
done

mkcase() { # name grader-file-content [prompt-body]
  local d="$TMP/$1"; mkdir -p "$d/graders"
  printf -- '---\nmax_turns: 5\n---\n\n%s\n' "${3:-Do the thing.}" > "$d/prompt.md"
  printf '%s\n' "$2" > "$d/graders/g.md"
  echo "$d"
}
fails_with() { # name dir expected-substring
  local out rc; out=$(bash "$CHK" "$2"); rc=$?
  check "$1: exits 1" 1 "$rc"
  check "$1: says why" yes "$(printf '%s' "$out" | grep -qF -- "$3" && echo yes || echo "no ($out)")"
}

ok=$(mkcase ok $'---\ntype: regex\ntarget: { source: file, path: out.md }\npattern: \'2/3\'\nmatch: count:2\nflags: i\nweight: 2\narm: both\n---\nnote')
bash "$CHK" "$ok" >/dev/null; check "valid regex case passes" 0 "$?"
ok2=$(mkcase ok2 $'---\ntype: tool_order\nbefore:\n  tool: Read\nafter: Write\n---')
bash "$CHK" "$ok2" >/dev/null; check "block-style tool_order passes" 0 "$?"
ok3=$(mkcase ok3 $'---\ntype: llm\nfocus: last_message\n---\nPASS if the answer names R3.')
bash "$CHK" "$ok3" >/dev/null; check "llm with body criteria passes" 0 "$?"

# The shapes a hand-written or generated seed tends to get wrong.
fails_with "regex with path/must_match" "$(mkcase b1 $'---\ntype: regex\npath: .ai/run-results/x.json\nmust_match: \'done\'\n---')" "unknown key 'path' for type regex"
fails_with "regex without pattern" "$(mkcase b2 $'---\ntype: regex\ntarget: files\n---')" "regex needs a pattern"
fails_with "tool_used with expect" "$(mkcase b3 $'---\ntype: tool_used\ntool: AskUserQuestion\nexpect: false\n---')" "unknown key 'expect'"
fails_with "unknown type" "$(mkcase b4 $'---\ntype: exit_code\n---')" "type must be"
fails_with "bad match" "$(mkcase b5 $'---\ntype: regex\npattern: x\nmatch: equals\n---')" "match must be"
fails_with "bad target" "$(mkcase b6 $'---\ntype: regex\npattern: x\ntarget: stdout\n---')" "target must be"
fails_with "file_exists without path" "$(mkcase b7 $'---\ntype: file_exists\nexists: true\n---')" "file_exists needs path"
fails_with "tool_used min not int" "$(mkcase b8 $'---\ntype: tool_used\ntool: Skill\nmin: one\n---')" "min must be"
fails_with "llm without criteria" "$(mkcase b9 $'---\ntype: llm\n---')" "llm needs criteria"
fails_with "zero weight" "$(mkcase b10 $'---\ntype: file_exists\npath: a\nweight: 0\n---')" "weight must be"
fails_with "no frontmatter" "$(mkcase b11 'just text')" "frontmatter"
fails_with "blank init template" "$(mkcase b12 $'---\ntype: file_exists\npath: a\n---' 'TODO: describe what the agent should do')" "init' template"
d=$(mkcase b13 $'---\ntype: file_exists\npath: a\n---'); rm "$d/graders/g.md"
fails_with "no graders" "$d" "no graders"
d=$(mkcase b14 $'---\ntype: file_exists\npath: a\n---'); printf 'schema_version: "1.1"\nname: x\ncontext:\n  scaffold_script: resources/missing.sh\n' > "$d/case.yaml"
fails_with "missing scaffold script" "$d" "scaffold_script not found"
mkdir -p "$TMP/empty"; fails_with "no cases" "$TMP/empty" "no eval cases found"
bash "$CHK" "$TMP/does-not-exist" 2>/dev/null; check "missing dir exits 2" 2 "$?"
bash "$CHK" 2>/dev/null; check "no args exits 2" 2 "$?"

echo "eval-case-check: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
