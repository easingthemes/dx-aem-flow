#!/usr/bin/env bash
# Hermetic check that every flow skill records its run (shared/run-result.md).
#
# Every skill in docs/reference/run-result.md § Metrics is a flow skill. For each:
#   Structure
#     - SKILL.md documents a start (`run-result.sh --start --skill <name>`) and a
#       final write (`run-result.sh --skill <name> --id <id> --status`);
#     - it calls the helper from a path its plugin has: dx-core through
#       ${CLAUDE_PLUGIN_ROOT}/data/lib, dx-aem through the project's .ai/lib copy,
#       dx-hub through its scripts/dx-core-lib.sh resolver;
#     - the --progress-file it starts with is the file its progress rows go to;
#     - every terminal node of its flow graph is covered by a run-result write.
#   Execution — the documented start and end, run against a fixture project:
#     - --start writes <skill>-<id>.running.json with run_id = DX_RUN_ID, the
#       progress file and the spec dir;
#     - each documented --status ends the run with exactly one result, removes
#       the marker and appends one history line (skill, id, run_id, status,
#       duration_s, metrics);
#     - a session that ends mid-run is closed by the SessionEnd hook as failed,
#       metrics.interrupted, "interrupted: <step in progress>" — with the hook
#       input of Claude Code and of Copilot CLI;
#     - a nested skill keeps the caller's run_id and never touches the caller's
#       marker or result.
# No network, no git.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CORE="$(cd "$HERE/../../.." && pwd)"
PLUGINS="$(cd "$CORE/.." && pwd)"
REPO="$(cd "$PLUGINS/.." && pwd)"
DOC="$REPO/docs/reference/run-result.md"
RR="$CORE/data/lib/run-result.sh"
UP="$CORE/shared/update-progress.sh"
HOOK="$CORE/hooks/scripts/run-result-close.sh"
RESOLVER="$PLUGINS/dx-hub/skills/dx-hub-dispatch/scripts/dx-core-lib.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The ambient session must not leak into the fixture runs.
unset DX_RUN_ID DX_SESSION_ID CLAUDE_CODE_SESSION_ID COPILOT_AGENT_SESSION_ID COPILOT_CLI \
  CLAUDECODE CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT DX_CORE_ROOT DX_ENGINE

PASS=0 FAIL=0
ok()    { PASS=$((PASS + 1)); }
fail()  { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1"; }
check() { if eval "$2"; then ok; else fail "$1"; fi; }
field() { sed -n "s/^  \"$2\": \"\\(.*\\)\",\\{0,1\\}\$/\\1/p" "$1" 2>/dev/null | head -1; }

# The flow skills a dashboard can start, and the skills they call. Each must be
# in the Metrics table — removing a row must not silently drop its checks.
REQUIRED="dx-agent-all dx-bug-all dx-prep dx-req dx-plan dx-step-all dx-step-verify dx-pr-review
  dx-pr-answer dx-dor dx-estimate dx-post-merge dx-req-dod dx-doc-gen dx-qa-handoff dx-hub-dispatch aem-demo-page"
# Skills that work on a PR: no spec dir, no progress file.
NO_PROGRESS=" dx-pr-review dx-pr-answer "

skills="$(awk '/^## Metrics/{on=1; next} /^## /{on=0} on && /^\| `[a-z0-9-]+` \|/' "$DOC" \
  | sed -E 's/^\| `([a-z0-9-]+)`.*/\1/')"
[ -n "$skills" ] || { echo "FAIL no skills parsed from $DOC § Metrics"; exit 1; }
for s in $REQUIRED; do
  printf '%s\n' "$skills" | grep -qx "$s" && ok || fail "$s: missing from $DOC § Metrics"
done

# Terminal nodes of the flow graph with no run-result write: neither their own
# section, nor the Run Result section, nor any line naming them mentions it.
uncovered_exits() { # SKILL.md
  local f="$1" n sec rr
  grep -oE '"[^"]+" \[shape=doublecircle\]' "$f" | sed 's/" \[.*//; s/^"//' | while IFS= read -r n; do
    sec="$(awk -v h="### $n" '/^```/{fence=!fence} $0==h{on=1;next} on&&!fence&&/^#{1,3} /{exit} on' "$f")"
    printf '%s' "$sec" | grep -qiE 'run.result|run record|run-result' && continue
    rr="$(awk 'tolower($0) ~ /^##+ run (result|record)/{on=1;next} on&&/^## /{exit} on' "$f")"
    printf '%s' "$rr" | grep -qiF -- "$n" && continue
    grep -iF -- "$n" "$f" | grep -qiE 'run.result|run record|run-result' && continue
    echo "$n"
  done
}

# A fixture project: one spec dir for id 12345, the .ai/lib copies a dx-aem skill
# uses, nothing else.
new_project() {
  local p; p="$(mktemp -d "$TMP/proj.XXXXXX")"
  mkdir -p "$p/.ai/specs/12345-fixture" "$p/.ai/lib" "$p/state/12345"
  cp "$RR" "$UP" "$p/.ai/lib/"
  printf '%s' "$p"
}

# The helper as the skill's plugin runs it, from inside a project dir.
helper() { # plugin args...
  local plugin="$1"; shift
  case "$plugin" in
    dx-core) bash "$RR" "$@" ;;
    dx-aem)  bash .ai/lib/run-result.sh "$@" ;;
    dx-hub)  bash "$RESOLVER" run-result.sh "$@" ;;
  esac
}

# RUN_RESULT_SKILLS_ONLY="a b" limits the per-skill checks (a quick local run).
ONLY=" ${RUN_RESULT_SKILLS_ONLY:-} "
for skill in $skills; do
  [ "$ONLY" = "  " ] || [[ "$ONLY" == *" $skill "* ]] || continue
  file="$(ls "$PLUGINS"/*/skills/"$skill"/SKILL.md 2>/dev/null | head -1)"
  if [ -z "$file" ]; then fail "$skill: SKILL.md not found"; continue; fi
  plugin="$(basename "$(dirname "$(dirname "$(dirname "$file")")")")"
  skilldir="$(dirname "$file")"

  # ---- Structure ---------------------------------------------------------
  case "$plugin" in
    dx-core) ;;
    dx-aem)
      grep -qF '${CLAUDE_PLUGIN_ROOT}/data/lib/run-result.sh' "$file" \
        && fail "$skill ($plugin): calls \${CLAUDE_PLUGIN_ROOT}/data/lib/run-result.sh, which only dx-core has" || ok
      grep -qF 'bash .ai/lib/run-result.sh --start' "$file" \
        && ok || fail "$skill ($plugin): does not call the project copy, bash .ai/lib/run-result.sh" ;;
    dx-hub)
      grep -qF 'scripts/dx-core-lib.sh" run-result.sh --start' "$file" \
        && ok || fail "$skill ($plugin): does not call run-result.sh through scripts/dx-core-lib.sh" ;;
  esac

  # Commands continued with a trailing backslash, joined into one line.
  joined="$(sed -e :a -e '/\\$/N; s/\\\n */ /; ta' "$file")"
  start_block="$(printf '%s\n' "$joined" | grep -E -- "run-result\.sh\"? --start --skill $skill( |$)" | head -1)"
  [ -n "$start_block" ] && ok || fail "$skill: no 'run-result.sh --start --skill $skill' in $file"
  end_line="$(printf '%s\n' "$joined" | grep -E -- "run-result\.sh\"? --skill $skill --id (<[^>]+>|[^ ]+) .*--status" | head -1)"
  [ -n "$end_line" ] && ok || fail "$skill: no final 'run-result.sh --skill $skill --id <id> --status' in $file"
  pf="$(printf '%s' "$start_block" | sed -nE 's/.*--progress-file ([A-Za-z0-9._-]+).*/\1/p')"
  if [[ "$NO_PROGRESS" == *" $skill "* ]]; then
    [ -z "$pf" ] && ok || fail "$skill: works on a PR (no spec dir) but starts with --progress-file $pf"
  else
    if [ -z "$pf" ]; then
      fail "$skill: --start has no --progress-file"
    else
      { grep -qF "DX_PROGRESS_FILE=\"$pf\"" "$file" || grep -qsF "DX_PROGRESS_FILE=\"$pf\"" "$skilldir/scripts/update-progress.sh"; } \
        && ok || fail "$skill: starts with --progress-file $pf but writes no rows to it (DX_PROGRESS_FILE=\"$pf\")"
    fi
  fi

  exits="$(uncovered_exits "$file")"
  [ -z "$exits" ] && ok || fail "$skill: terminal node(s) with no run-result write: $(printf '%s' "$exits" | tr '\n' ';')"

  # ---- Execution ---------------------------------------------------------
  # The statuses the end command documents (--status <done|blocked|failed>); a
  # generic placeholder (--status <status>) → every status the file names.
  statuses="$(printf '%s' "$end_line" | sed -nE 's/.*--status <([a-z|]+)>.*/\1/p' | tr '|' ' ')"
  valid=""
  for st in $statuses; do case "$st" in done|blocked|failed) valid="$valid $st" ;; esac; done
  if [ -z "$valid" ]; then
    for st in done blocked failed; do grep -qF "\`$st\`" "$file" && valid="$valid $st"; done
  fi
  statuses="$valid"
  [ -n "$statuses" ] && ok || { fail "$skill: cannot read the documented --status values"; statuses="done"; }

  spec_expect=".ai/specs/12345-fixture"
  extra=()
  if [ "$plugin" = dx-hub ]; then spec_expect="state/12345"; extra=(--spec-dir state/12345); fi
  [ -n "$pf" ] && extra+=(--progress-file "$pf")

  for st in $statuses; do
    P="$(new_project)"; run="kai-$skill-$st"
    ( cd "$P" && DX_RUN_ID="$run" helper "$plugin" --start --skill "$skill" --id 12345 "${extra[@]}" >/dev/null 2>&1 )
    M="$P/.ai/run-results/$skill-12345.running.json"
    check "$skill/$st: --start writes the running marker" '[ -f "$M" ]'
    check "$skill/$st: marker run_id = DX_RUN_ID" '[ "$(field "$M" run_id)" = "$run" ]'
    check "$skill/$st: marker spec_dir" '[ "$(field "$M" spec_dir)" = "$spec_expect" ]'
    [ -n "$pf" ] && check "$skill/$st: marker progress_file" '[ "$(field "$M" progress_file)" = "$pf" ]'
    # The end runs without DX_RUN_ID: the run id must come from the marker.
    ( cd "$P" && helper "$plugin" --skill "$skill" --id 12345 --status "$st" --summary "fixture $st" --metric fail_at=x >/dev/null 2>&1 )
    R="$P/.ai/run-results/$skill-12345.json" H="$P/.ai/run-results/history.jsonl"
    check "$skill/$st: one result file" '[ -f "$R" ] && [ "$(ls "$P/.ai/run-results"/*.json | wc -l | tr -d " ")" = 1 ]'
    check "$skill/$st: result status" '[ "$(field "$R" status)" = "$st" ]'
    check "$skill/$st: result run_id = DX_RUN_ID" '[ "$(field "$R" run_id)" = "$run" ]'
    check "$skill/$st: marker removed" '[ ! -f "$M" ]'
    check "$skill/$st: one history line with skill, id, run_id, status, duration, metrics" \
      '[ "$(wc -l < "$H" | tr -d " ")" = 1 ] && grep -q "\"skill\": *\"$skill\"" "$H" && grep -q "\"id\": *\"12345\"" "$H" && grep -q "\"run_id\": *\"$run\"" "$H" && grep -q "\"status\": *\"$st\"" "$H" && grep -q "\"duration_s\": *[0-9]" "$H" && grep -q "\"metrics\": *{" "$H"'
  done

  # Interrupted, on each engine's SessionEnd input.
  # claude: Claude Code. copilot: Copilot CLI 1.0.116 (session_id + cwd, CLAUDE_PROJECT_DIR
  # set, hook run from the plugin dir). copilot-old: earlier Copilot (sessionId + cwd only).
  for engine in claude copilot copilot-old; do
    P="$(new_project)"; run="kai-$skill-int-$engine"
    ( cd "$P" && DX_RUN_ID="$run" helper "$plugin" --start --skill "$skill" --id 12345 "${extra[@]}" >/dev/null 2>&1 )
    want="interrupted: the session ended before the skill wrote its result"
    if [ -n "$pf" ]; then
      DX_PROGRESS_FILE="$pf" bash "$UP" "$P/$spec_expect" "Step one" done >/dev/null 2>&1
      DX_PROGRESS_FILE="$pf" bash "$UP" "$P/$spec_expect" "Step two" in_progress >/dev/null 2>&1
      want="interrupted: Step two"
    fi
    case "$engine" in
      claude) printf '{"session_id":"cc-1","hook_event_name":"SessionEnd"}' | (cd / && CLAUDE_PROJECT_DIR="$P" DX_RUN_ID="$run" bash "$HOOK") ;;
      copilot) printf '{"hook_event_name":"SessionEnd","session_id":"cp-1","cwd":"%s","reason":"complete"}' "$P" \
        | (cd "$CORE" && CLAUDE_PROJECT_DIR="$P" COPILOT_PROJECT_DIR="$P" COPILOT_CLI=1 DX_RUN_ID="$run" bash "$HOOK") ;;
      copilot-old) printf '{"sessionId":"cp-1","cwd":"%s"}' "$P" | (cd / && DX_RUN_ID="$run" bash "$HOOK") ;;
    esac
    R="$P/.ai/run-results/$skill-12345.json"
    check "$skill/interrupted ($engine): failed" '[ "$(field "$R" status)" = failed ]'
    check "$skill/interrupted ($engine): summary \"$want\"" '[ "$(field "$R" summary)" = "$want" ]'
    check "$skill/interrupted ($engine): metrics.interrupted" 'grep -q "\"interrupted\": *true" "$R"'
    check "$skill/interrupted ($engine): run_id kept" '[ "$(field "$R" run_id)" = "$run" ]'
    check "$skill/interrupted ($engine): marker removed" '[ ! -f "$P/.ai/run-results/$skill-12345.running.json" ]'
  done
done

# A manual Copilot CLI run (no DX_RUN_ID): the hook closes it by the session id.
P="$(new_project)"
( cd "$P" && COPILOT_AGENT_SESSION_ID="Cp-Manual" bash "$RR" --start --skill dx-doc-gen --id 12345 --progress-file doc-gen-progress.md >/dev/null 2>&1 )
printf '{"sessionId":"cp-manual","cwd":"%s"}' "$P" | (cd / && bash "$HOOK")
R="$P/.ai/run-results/dx-doc-gen-12345.json"
check "manual copilot run: closed as failed by session id" '[ "$(field "$R" status)" = failed ] && [ "$(field "$R" run_id)" = "cp-manual.1" ]'

# Nested: the inner skills keep the caller's run_id and never touch its files.
nested() { # caller plugin-of-inner:inner...
  local caller="$1"; shift
  local P run M before spec pi inner plug
  P="$(new_project)"; run="kai-nest-$caller"
  ( cd "$P" && DX_RUN_ID="$run" bash "$RR" --start --skill "$caller" --id 12345 >/dev/null 2>&1 )
  M="$P/.ai/run-results/$caller-12345.running.json"; before="$(cat "$M")"
  for pi in "$@"; do
    plug="${pi%%:*}" inner="${pi#*:}"
    spec=(); [ "$plug" = dx-hub ] && spec=(--spec-dir state/12345)
    ( cd "$P" && DX_RUN_ID="$run" helper "$plug" --start --skill "$inner" --id 12345 "${spec[@]}" >/dev/null 2>&1 \
        && DX_RUN_ID="$run" helper "$plug" --skill "$inner" --id 12345 --status done --summary inner >/dev/null 2>&1 )
    check "nested $caller > $inner: own result with the caller's run_id" \
      '[ "$(field "$P/.ai/run-results/$inner-12345.json" run_id)" = "$run" ]'
  done
  check "nested $caller: caller marker untouched" '[ "$(cat "$M")" = "$before" ]'
  check "nested $caller: no caller result yet" '[ ! -f "$P/.ai/run-results/$caller-12345.json" ]'
  local want=$(( $# + 1 ))
  ( cd "$P" && bash "$RR" --skill "$caller" --id 12345 --status done --summary outer >/dev/null 2>&1 )
  check "nested $caller: caller result is its own" \
    '[ "$(field "$P/.ai/run-results/$caller-12345.json" skill)" = "$caller" ] && [ "$(field "$P/.ai/run-results/$caller-12345.json" summary)" = outer ]'
  check "nested $caller: one history line per run, all with the caller's run_id" \
    '[ "$(grep -c "\"run_id\": *\"$run\"" "$P/.ai/run-results/history.jsonl")" = "$want" ]'
}
[ "$ONLY" = "  " ] && {
nested dx-agent-all dx-core:dx-req dx-core:dx-plan dx-core:dx-step-all dx-core:dx-step-verify
nested dx-prep dx-core:dx-req dx-core:dx-dor dx-core:dx-plan
nested dx-post-merge dx-aem:aem-demo-page dx-core:dx-doc-gen dx-core:dx-qa-handoff
nested dx-req-dod dx-core:dx-post-merge
}

echo "run-result-skills: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
