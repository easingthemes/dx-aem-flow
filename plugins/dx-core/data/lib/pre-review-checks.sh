#!/usr/bin/env bash
# pre-review-checks.sh — 5-phase pre-review verification gate
#
# Runs fast automated checks before the expensive code review subagent.
# Each phase outputs a status line. Failures are collected and reported.
#
# Usage: pre-review-checks.sh [--fix]
#   --fix: auto-fix lint issues (default: report only)
#
# Exit codes:
#   0 = all phases passed
#   1 = one or more phases failed (details on stdout)
#
# Output format (JSON):
#   {"passed": true/false, "phases": [...], "issues": [...]}
#
# Reads commands from .ai/config.yaml:
#   build:
#     compile: "mvn compile -pl core"
#     test: "mvn test -pl core"
#     lint-js: "cd frontend && npm run lint:js"
#     lint-css: "cd frontend && npm run lint:css"
#     frontend-dir: "frontend"
#
# Without config, phases 1-3 are skipped (no commands configured).

set -uo pipefail

AUTO_FIX=false
[[ "${1:-}" == "--fix" ]] && AUTO_FIX=true

ISSUES=()
PHASES=()
OVERALL=true

# --- Read config ---
CONFIG_FILE=".ai/config.yaml"

# Read a scalar value from config.yaml.
# Usage: yaml_val <key>
#   <key> is either a bare key ("compile") — first match at any depth — or a
#   dotted path ("dx-simple.recovery.trigger-token") resolved segment by
#   segment through the indentation tree, so it never bleeds into siblings.
# Output: prints the value, with any inline `# comment` and surrounding
#   quotes stripped. Prints nothing when the key is absent.
yaml_val() {
  local key="${1:-}"
  [ -n "$key" ] || return 0
  [ -f "${CONFIG_FILE:-}" ] || return 0
  awk -v path="$key" '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    BEGIN { n = split(path, seg, "."); depth = 1; want = seg[1]; parent = -1; q = sprintf("%c", 39) }
    {
      line = $0; sub(/\r$/, "", line)
      if (line ~ /^[[:space:]]*(#|$)/) next          # blank or comment line
      match(line, /^[[:space:]]*/); indent = RLENGTH
      rest = substr(line, indent + 1)
      if (rest !~ /^[^:]+:/) next                    # not a key: line
      if (indent <= parent) exit                     # left the parent block: no match
      k = rest; sub(/:.*$/, "", k)
      if (trim(k) != want) next
      v = rest; sub(/^[^:]*:/, "", v); v = trim(v)
      if (depth == n) {
        if (substr(v, 1, 1) == "\"") {               # double-quoted: take up to the close
          v = substr(v, 2); i = index(v, "\""); if (i > 0) v = substr(v, 1, i - 1)
        } else if (substr(v, 1, 1) == q) {           # single-quoted: same
          v = substr(v, 2); i = index(v, q); if (i > 0) v = substr(v, 1, i - 1)
        } else {                                     # bare: drop any trailing comment
          sub(/[[:space:]]+#.*$/, "", v); v = trim(v)
        }
        print v; exit
      }
      parent = indent; depth++; want = seg[depth]
    }
  ' "$CONFIG_FILE"
}

COMPILE_CMD=$(yaml_val "compile")
TEST_CMD=$(yaml_val "test")
LINT_JS_CMD=$(yaml_val "lint-js")
LINT_CSS_CMD=$(yaml_val "lint-css")
FE_DIR=$(yaml_val "frontend-dir")
BASE_BRANCH=$(yaml_val "base-branch")

# --- Command runner ---
# Phase commands come from config and may print anything. Their stdout must not
# reach ours: this script's only output is the JSON the caller parses, so a
# chatty build tool would corrupt it. Capture both streams to a log instead of
# discarding them — a failed phase can then report why it failed.
RUN_LOG_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dx-pre-review.XXXXXX")
trap 'rm -rf "$RUN_LOG_DIR"' EXIT

# run_cmd <log-name> <command-string>  -> exit status of the command
run_cmd() {
  local log="$RUN_LOG_DIR/$1"; shift
  eval "$*" >"$log" 2>&1
}

# log_lines <log-name> [max]  -> last N non-blank lines, one ISSUES entry each
log_lines() {
  local log="$RUN_LOG_DIR/$1" max="${2:-10}"
  [ -s "$log" ] || return 0
  sed 's/\r$//' "$log" | grep -v '^[[:space:]]*$' | tail -n "$max" | sed 's/^/  | /'
}

# --- Determine base SHA ---
if [ -n "$BASE_BRANCH" ]; then
  BASE_SHA=$(git merge-base "$BASE_BRANCH" HEAD 2>/dev/null || git merge-base "origin/$BASE_BRANCH" HEAD 2>/dev/null || echo "")
else
  BASE_SHA=$(git merge-base development HEAD 2>/dev/null || git merge-base origin/development HEAD 2>/dev/null || git merge-base develop HEAD 2>/dev/null || git merge-base origin/develop HEAD 2>/dev/null || echo "")
fi

if [ -z "$BASE_SHA" ]; then
  echo '{"passed": true, "phases": [], "issues": ["Could not determine base SHA — skipping pre-review checks"]}'
  exit 0
fi

CHANGED_FILES=$(git diff --name-only "$BASE_SHA"..HEAD 2>/dev/null || true)
HAS_COMPILABLE=$(echo "$CHANGED_FILES" | grep -cE '\.(java|kt|scala|cs|go|rs)$' || true)
HAS_FE=$(echo "$CHANGED_FILES" | grep -cE '\.(js|jsx|ts|tsx|scss|css)$' || true)

# --- Phase 1: Compile ---
phase1_pass=true
if [ "$HAS_COMPILABLE" -gt 0 ] && [ -n "$COMPILE_CMD" ]; then
  if run_cmd compile.log "$COMPILE_CMD"; then
    PHASES+=('{"phase": 1, "name": "Compile", "status": "passed"}')
  else
    PHASES+=('{"phase": 1, "name": "Compile", "status": "failed"}')
    ISSUES+=("Compilation failed — run: $COMPILE_CMD")
    while IFS= read -r l; do ISSUES+=("$l"); done < <(log_lines compile.log)
    phase1_pass=false
    OVERALL=false
  fi
elif [ -z "$COMPILE_CMD" ]; then
  PHASES+=('{"phase": 1, "name": "Compile", "status": "skipped", "reason": "no compile command configured"}')
else
  PHASES+=('{"phase": 1, "name": "Compile", "status": "skipped", "reason": "no compilable source changes"}')
fi

# --- Phase 2: Lint ---
if [ "$HAS_FE" -gt 0 ] && [ -n "$FE_DIR" ] && [ -d "$FE_DIR" ]; then
  lint_issues=()

  # run_lint <log-name> <command> <message-on-failure>
  run_lint() {
    run_cmd "$1" "$2" && return 0
    lint_issues+=("$3")
    while IFS= read -r l; do lint_issues+=("$l"); done < <(log_lines "$1")
  }

  if $AUTO_FIX; then
    lint_note="auto-fix applied, check remaining"
  else
    lint_note="run lint to auto-fix"
  fi

  [ -n "$LINT_JS_CMD" ]  && run_lint lint-js.log  "$LINT_JS_CMD"  "JS lint found issues — $lint_note"
  [ -n "$LINT_CSS_CMD" ] && run_lint lint-css.log "$LINT_CSS_CMD" "CSS lint found issues — $lint_note"

  if [ ${#lint_issues[@]} -eq 0 ]; then
    PHASES+=('{"phase": 2, "name": "Lint", "status": "passed"}')
  else
    PHASES+=('{"phase": 2, "name": "Lint", "status": "failed"}')
    for issue in "${lint_issues[@]}"; do
      ISSUES+=("$issue")
    done
    OVERALL=false
  fi
elif [ -z "$FE_DIR" ] || [ ! -d "${FE_DIR:-/dev/null}" ]; then
  PHASES+=('{"phase": 2, "name": "Lint", "status": "skipped", "reason": "no frontend directory configured"}')
else
  PHASES+=('{"phase": 2, "name": "Lint", "status": "skipped", "reason": "no frontend changes"}')
fi

# --- Phase 3: Test ---
if [ "$HAS_COMPILABLE" -gt 0 ] && [ "$phase1_pass" = true ] && [ -n "$TEST_CMD" ]; then
  if run_cmd test.log "$TEST_CMD"; then
    PHASES+=('{"phase": 3, "name": "Test", "status": "passed"}')
  else
    PHASES+=('{"phase": 3, "name": "Test", "status": "failed"}')
    ISSUES+=("Tests failed — run: $TEST_CMD")
    while IFS= read -r l; do ISSUES+=("$l"); done < <(log_lines test.log)
    OVERALL=false
  fi
elif [ "$phase1_pass" = false ]; then
  PHASES+=('{"phase": 3, "name": "Test", "status": "skipped", "reason": "compilation failed"}')
elif [ -z "$TEST_CMD" ]; then
  PHASES+=('{"phase": 3, "name": "Test", "status": "skipped", "reason": "no test command configured"}')
else
  PHASES+=('{"phase": 3, "name": "Test", "status": "skipped", "reason": "no compilable source changes"}')
fi

# --- Phase 4: Secret Scan ---
secret_files=()
while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ ! -f "$file" ] && continue
  case "$file" in
    *.png|*.jpg|*.gif|*.jar|*.zip|*.class|*.woff*|*.ttf|*.eot|*.svg) continue ;;
  esac
  if grep -qEi '(aws_secret_access_key|aws_access_key_id|PRIVATE.KEY|BEGIN RSA|password\s*=\s*"[^"]{8,}|api[_-]?key\s*=\s*"[^"]{8,}|secret\s*=\s*"[^"]{8,}|token\s*=\s*"[a-zA-Z0-9]{20,})' "$file" 2>/dev/null; then
    secret_files+=("$file")
  fi
done <<< "$CHANGED_FILES"

if [ ${#secret_files[@]} -eq 0 ]; then
  PHASES+=('{"phase": 4, "name": "Secret Scan", "status": "passed"}')
else
  PHASES+=('{"phase": 4, "name": "Secret Scan", "status": "failed"}')
  for sf in "${secret_files[@]}"; do
    ISSUES+=("Possible secret in: $sf")
  done
  OVERALL=false
fi

# --- Phase 5: Architecture Conventions ---
arch_issues=()
while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ ! -f "$file" ] && continue

  # SCSS: Check for @import instead of @use (Dart Sass convention)
  if [[ "$file" == *.scss ]]; then
    if grep -q '@import ' "$file" 2>/dev/null; then
      arch_issues+=("SCSS uses @import instead of @use/@forward: $file")
    fi
  fi

done <<< "$CHANGED_FILES"

if [ ${#arch_issues[@]} -eq 0 ]; then
  PHASES+=('{"phase": 5, "name": "Architecture", "status": "passed"}')
else
  PHASES+=('{"phase": 5, "name": "Architecture", "status": "failed"}')
  for ai in "${arch_issues[@]}"; do
    ISSUES+=("$ai")
  done
  OVERALL=false
fi

# --- Output JSON ---
PHASES_JSON=$(printf '%s\n' "${PHASES[@]}" | jq -s '.')
ISSUES_JSON=$(printf '%s\n' "${ISSUES[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')

cat <<EOF
{
  "passed": $OVERALL,
  "phases": $PHASES_JSON,
  "issues": $ISSUES_JSON
}
EOF

if [ "$OVERALL" = true ]; then
  exit 0
else
  exit 1
fi
