#!/usr/bin/env bash
# check-agent-hooks.test.sh — Watch check-agent-hooks.sh fail, and run the guard itself.
#
# Part 1 breaks a copy of the agent templates one way per case and expects a
# non-zero exit; the clean copy must pass.
# Part 2 extracts the POSIX `command:` from the canonical guard and feeds it the
# PreToolUse payload Copilot CLI 1.0.98 sends (captured 2026-10-15), in
# throwaway git repos: deny on a protected branch, silent elsewhere, exit 0
# always (Copilot command hooks are fail-closed — a non-zero exit denies).
# The `windows:` variant runs too when pwsh is on PATH.
# Hermetic: no network, no HOME, per-repo git identity.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
CHECK="$HERE/check-agent-hooks.sh"
CANON="$REPO_ROOT/plugins/dx-core/templates/hooks/agent-branch-guard.yaml"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"; mkdir -p "$HOME"

fail=0
fresh() {
  rm -rf "$TMP/r"
  for p in dx-core dx-aem; do
    mkdir -p "$TMP/r/plugins/$p/templates"
    cp -R "$REPO_ROOT/plugins/$p/templates/agents" "$TMP/r/plugins/$p/templates/agents"
  done
  mkdir -p "$TMP/r/plugins/dx-core/templates/hooks"
  cp "$CANON" "$TMP/r/plugins/dx-core/templates/hooks/"
}
expect() { # expect <0|1> <label>
  if bash "$CHECK" "$TMP/r" >"$TMP/out" 2>&1; then got=0; else got=1; fi
  if [ "$got" = "$1" ]; then echo "PASS $2"; else echo "FAIL $2 (exit $got, want $1)"; sed 's/^/    /' "$TMP/out"; fail=1; fi
}
A="$TMP/r/plugins/dx-core/templates/agents"

# --- Part 1: the check ---
fresh; expect 0 "clean templates pass"
fresh; node -e 'const f=process.argv[1],fs=require("fs");let s=fs.readFileSync(f,"utf8");s=s.replace(/\nhooks:\n[\s\S]*?\n---\n/,"\n---\n");fs.writeFileSync(f,s)' "$A/DxCommit.agent.md.template"
expect 1 "shell agent (runCommands) without the guard"
fresh; sed -i 's/main|master|develop|development/main|master/' "$A/DxPRFix.agent.md.template"; expect 1 "guard drifted from the canonical block"
fresh; node -e 'const f=process.argv[1],fs=require("fs");let s=fs.readFileSync(f,"utf8");s=s.replace(/\nhooks:\n[\s\S]*?\n---\n/,"\n---\n");fs.writeFileSync(f,s)' "$A/DxPlanExecutor.agent.md.template"
expect 1 "agent with no tools: key (= every tool) without the guard"
fresh; printf -- "---\nname: X\ndescription: x\ntools:\n  - read\n  - 'execute'\n---\nbody\n" > "$A/X.agent.md.template"; expect 1 "new agent granting 'execute' without the guard"
fresh; printf -- "---\nname: X\ndescription: x\ntools: [read, 'shell']\n---\nbody\n" > "$A/X.agent.md.template"; expect 1 "flow-style tools list with shell, no guard"
fresh; printf -- "---\nname: X\ndescription: x\ntools: ['*']\n---\nbody\n" > "$A/X.agent.md.template"; expect 1 "wildcard tools, no guard"
fresh; printf -- "---\nname: X\ndescription: x\ntools:\n  - read\n  - execute/runInTerminal\n---\nbody\n" > "$A/X.agent.md.template"; expect 1 "execute/runInTerminal, no guard"
fresh; printf -- "---\nname: Y\ndescription: y\ntools: [read, search]\n---\nbody\n" > "$A/Y.agent.md.template"; expect 0 "flow-style read-only list needs no guard"
fresh; printf -- "---\nname: Y\ndescription: y\ntools:\n  - read\n  - search\n---\nbody\n" > "$A/Y.agent.md.template"; expect 0 "read-only agent needs no guard"
fresh; rm "$TMP/r/plugins/dx-core/templates/hooks/agent-branch-guard.yaml"; expect 1 "canonical snippet missing"

# --- Part 2: the guard ---
awk '/^      command: \|$/{f=1;next} /^      windows: \|$/{f=0} f{sub(/^        /,"");print}' "$CANON" > "$TMP/guard.sh"
awk '/^      windows: \|$/{f=1;next} f{sub(/^        /,"");print}' "$CANON" > "$TMP/guard.ps1"
[ -s "$TMP/guard.sh" ] && [ -s "$TMP/guard.ps1" ] || { echo "FAIL could not extract command/windows from $CANON"; exit 1; }

repo() { # repo <branch>
  rm -rf "$TMP/g"; mkdir -p "$TMP/g"
  git -C "$TMP/g" init -q -b main
  git -C "$TMP/g" config user.email t@t; git -C "$TMP/g" config user.name t
  git -C "$TMP/g" commit -q --allow-empty -m init
  [ "$1" = main ] || git -C "$TMP/g" checkout -qb "$1"
}
payload() { printf '{"hook_event_name":"PreToolUse","cwd":"%s","tool_name":"%s","tool_input":{"command":"%s","description":"x"}}' "$TMP/g" "$1" "$2"; }
guard() { # guard <runner> <branch> <tool> <command> <deny|allow> <label>
  repo "$2"
  out="$(cd "$TMP/g" && payload "$3" "$4" | $1 2>"$TMP/err")"; rc=$?
  if [ "$rc" != 0 ]; then echo "FAIL $6 (exit $rc — fail-closed would deny every tool)"; cat "$TMP/err"; fail=1; return; fi
  case "$5:$out" in
    deny:*'"permissionDecision":"deny"'*'BLOCKED: Do not commit on '"$2"*) echo "PASS $6" ;;
    allow:) echo "PASS $6" ;;
    *) echo "FAIL $6 (want $5, got: $out)"; fail=1 ;;
  esac
}
runners=("sh $TMP/guard.sh")
if command -v pwsh >/dev/null 2>&1; then runners+=("pwsh -NoProfile -NonInteractive -File $TMP/guard.ps1")
else echo "SKIP windows: variant (pwsh not on PATH)"; fi
for r in "${runners[@]}"; do
  n="${r%% *}"
  guard "$r" main Bash "git commit -m x" deny "[$n] commit on main denied"
  guard "$r" develop Bash "git add . && git  commit -m x" deny "[$n] chained commit on develop denied"
  guard "$r" feature/x Bash "git commit -m x" allow "[$n] commit on feature branch allowed"
  guard "$r" main Bash 'git add \"my file.txt\" && git commit -m x' deny "[$n] commit after a quoted arg denied"
  guard "$r" main Bash 'cd \"/repo\" && git commit -m x' deny "[$n] commit after a quoted cd denied"
  guard "$r" main Bash "git -C . commit -m x" deny "[$n] git -C . commit denied"
  guard "$r" main Bash "git status" allow "[$n] non-commit command on main allowed"
  guard "$r" main Edit "" allow "[$n] non-shell tool allowed"
done

exit $fail
