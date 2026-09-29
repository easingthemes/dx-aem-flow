#!/usr/bin/env bash
# Webhook payload must reach the listener scripts through env, never through
# ${{ }} expansion inside the script body. ADO expands ${{ }} into the script
# text before bash runs, so a normal comment ("doesn't", `npm run build`, a line
# starting with ##vso[) would otherwise be parsed as shell or as a logging command.
#
# Hermetic: extracts the step script from the YAML, stubs ADO macros, runs it
# with a hostile comment in env. No ADO, no network. PIPELINE_DIR overrides the
# pipeline directory (used to prove the test fails on the old YAML).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="${PIPELINE_DIR:-$HERE/..}"
FAIL=0; PASS=0
ok()   { PASS=$((PASS+1)); echo "  ok   $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL $1"; }

# 1. Structural: every Hook.resource expression sits on a HOOK_* env line.
for f in ado-cli-bug-fix.yml ado-cli-dor.yml ado-cli-hub.yml ado-cli-simple.yml; do
  stray=$(grep -nE '\$\{\{[^}]*Hook\.resource' "$DIR/$f" | grep -v 'contains(' \
          | grep -vE '^[0-9]+:[[:space:]]+HOOK_[A-Z_]+: \$\{\{' || true)
  if [ -z "$stray" ]; then ok "$f: payload only in env"; else bad "$f: payload in script body: $stray"; fi
done

# Print the body of the `- bash: |` step whose displayName is $2, dedented.
extract() {
  awk -v want="$2" '
    /^  - bash: \|$/ { inb=1; buf=""; next }
    inb && /^    displayName: / {
      d=$0; sub(/^    displayName: "/, "", d); sub(/"$/, "", d)
      if (d == want) { printf "%s", buf; exit }
      inb=0; next }
    inb { l=$0; sub(/^      /, "", l); buf = buf l "\n" }
  ' "$1"
}

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/src/.ai/automation/registries"
echo '{"simple":{"workerPipelineId":11,"writes":true}}' > "$T/src/.ai/automation/registries/agents.json"

# Normal comment text that breaks unquoted scripts, plus a logging-command line.
COMMENT="<div>@kai-simple doesn't work, try \`touch $T/pwned1\` or \$(touch $T/pwned2)</div>
##vso[task.setvariable variable=ROUTE_STATUS]hacked"

run_step() { # file, displayName
  # Emulate ADO: ${{ }} is pasted into the script text before bash runs, so a
  # payload expression left in the body receives the raw comment.
  extract "$DIR/$1" "$2" \
    | COMMENT="$COMMENT" perl -pe 's/\$\{\{[^}]*System\.History[^}]*\}\}/$ENV{COMMENT}/g;
                                   s/\$\{\{[^}]*Hook\.resource\.id\s*\}\}/42/g;
                                   s/\$\{\{[^}]*Hook\.resource\.rev\s*\}\}/7/g' \
    | sed -e "s#\$(Build.SourcesDirectory)#$T/src#g" -e "s#\$(Pipeline.Workspace)#$T/ws#g" \
          -e 's/\${{[^}]*}}//g' > "$T/step.sh"
  [ -s "$T/step.sh" ] || { bad "$1: step '$2' not found"; return 1; }
  ( cd "$T" && HOOK_WI_ID=42 HOOK_REV=7 HOOK_COMMENT="$COMMENT" HOOK_COMMENTER="Ann O'Neil" \
      HOOK_PROJECT=p HOOK_STATE=Active HOOK_WI_TYPE=Bug ADO_PAT=x bash "$T/step.sh" ) > "$T/out" 2>&1
}

# 2. Hub: tag still parsed from the comment, nothing executed, no injected variable.
rm -f "$T"/pwned*
if run_step ado-cli-hub.yml "Parse @kai tag + resolve agent"; then ok "hub: step exits 0"; else bad "hub: step failed: $(tail -3 "$T/out")"; fi
grep -q 'ROUTE_STATUS]ok' "$T/out" && grep -q 'AGENT_TAG]simple' "$T/out" \
  && ok "hub: @kai-simple routed" || bad "hub: tag not routed: $(tail -3 "$T/out")"
ls "$T"/pwned* >/dev/null 2>&1 && bad "hub: comment text executed as shell" || ok "hub: comment not executed"
grep -q '^##vso\[task.setvariable variable=ROUTE_STATUS\]hacked' "$T/out" \
  && bad "hub: comment injected a logging command" || ok "hub: no injected logging command"

# 3. Bug-fix: webhook context log prints the comment without executing it.
rm -f "$T"/pwned*
if run_step ado-cli-bug-fix.yml "Resolve bug ID + execution mode (clone target in hub mode)"; then ok "bug-fix: step exits 0"; else bad "bug-fix: step failed: $(tail -3 "$T/out")"; fi
grep -q 'WI_ID\]42' "$T/out" && ok "bug-fix: work item id from webhook" || bad "bug-fix: no WI_ID"
ls "$T"/pwned* >/dev/null 2>&1 && bad "bug-fix: comment text executed as shell" || ok "bug-fix: comment not executed"
grep -q '^##vso\[task.setvariable variable=ROUTE_STATUS\]hacked' "$T/out" \
  && bad "bug-fix: comment injected a logging command" || ok "bug-fix: no injected logging command"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
