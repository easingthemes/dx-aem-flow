#!/usr/bin/env bash
# The SimpleAgent, BugFix and QA pipelines run the agent in TARGET_DIR, whose
# checkout may predate .ai/lib/playwright-basic-auth.cjs. Without it dx-core's
# playwright MCP server exits at startup. Each pipeline copies it from the
# plugin clone and git-excludes it, so an agent commit cannot pick it up.
#
# Hermetic: extracts the step script from the YAML, stubs ADO macros, runs it
# against throwaway git repos. No ADO, no network.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="${PIPELINE_DIR:-$HERE/..}"
PLUGINS="$(cd "$HERE/../../../../.." && pwd)"
STEP="Install Playwright basic-auth init page (if missing)"
FAIL=0; PASS=0
ok()   { PASS=$((PASS+1)); echo "  ok   $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL $1"; }
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

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
# Fake plugin clone at $(Pipeline.Workspace)/dx-aem-flow/plugins
mkdir -p "$T/ws/dx-aem-flow"
ln -s "$PLUGINS" "$T/ws/dx-aem-flow/plugins"
REL=.ai/lib/playwright-basic-auth.cjs

new_target() { # dir
  rm -rf "$1"; git init -q "$1"
  git -C "$1" config user.email bot@example.com; git -C "$1" config user.name bot
  echo x > "$1/README"; git -C "$1" add README; git -C "$1" commit -qm init
}
run_step() { # file, target
  extract "$DIR/$1" "$STEP" \
    | sed -e "s#\$(Pipeline.Workspace)#$T/ws#g" -e "s#\$(TARGET_DIR)#$2#g" > "$T/step.sh"
  [ -s "$T/step.sh" ] || { bad "$1: step not found"; return 1; }
  bash "$T/step.sh" > "$T/out" 2>&1
}

for f in ado-cli-simple.yml ado-cli-bug-fix.yml ado-cli-qa.yml; do
  TGT="$T/target"
  new_target "$TGT"
  if run_step "$f" "$TGT"; then ok "$f: exits 0 (missing)"; else bad "$f: failed: $(tail -3 "$T/out")"; fi
  cmp -s "$PLUGINS/dx-core/data/lib/playwright-basic-auth.cjs" "$TGT/$REL" \
    && ok "$f: copied from plugin clone" || bad "$f: not copied"
  [ -z "$(git -C "$TGT" status --porcelain)" ] && ok "$f: git status clean (excluded)" \
    || bad "$f: shows in git status: $(git -C "$TGT" status --porcelain)"
  run_step "$f" "$TGT" || bad "$f: rerun failed"
  [ "$(grep -cxF "$REL" "$TGT/.git/info/exclude")" = 1 ] && ok "$f: idempotent exclude" \
    || bad "$f: exclude line count != 1"

  # Already present (tracked by the project): left alone, not excluded.
  new_target "$TGT"; mkdir -p "$TGT/.ai/lib"; echo keep > "$TGT/$REL"
  run_step "$f" "$TGT" || bad "$f: failed (present)"
  [ "$(cat "$TGT/$REL")" = keep ] && ok "$f: existing file untouched" || bad "$f: existing file overwritten"
  grep -qxF "$REL" "$TGT/.git/info/exclude" 2>/dev/null && bad "$f: excluded a project-owned file" \
    || ok "$f: no exclude when present"
done

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
