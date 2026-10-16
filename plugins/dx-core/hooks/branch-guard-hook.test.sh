#!/usr/bin/env bash
# branch-guard-hook.test.sh — Watch the inline branch guard fire, and not fire.
#
# Covers the PreToolUse guard in hooks/hooks.json (plugin, read by Claude Code
# and Copilot CLI) and templates/hooks/branch-guard-hooks.json.template (the
# Copilot repo-hooks copy /dx-init installs). For each file:
#   1. the matcher selects the Bash tool, evaluated the way Claude Code does
#      (code.claude.com/docs/en/hooks: letters/digits/_/-/space/,/| only →
#      exact list; anything else → unanchored JS regex). `Bash(git commit*)` as
#      a matcher took the regex path and matched nothing, so the guard never ran.
#   2. the command itself filters on "git commit" in the hook's stdin — `if` is
#      best-effort in Claude Code and unknown to Copilot, so the matcher alone
#      would block every Bash call on main.
# Hermetic: throwaway git repos, no global git config, no network.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

PASS=0; FAIL=0
check() { # check <label> <want> <got>
  if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS + 1)); else echo "FAIL $1 (want $2, got $3)"; FAIL=$((FAIL + 1)); fi
}

repo() { # repo <branch> → path
  local d; d="$(mktemp -d "$TMP/r-XXXXXX")"
  git -C "$d" init -q -b "$1" && echo "$d"
}

for f in "$PLUGIN/hooks/hooks.json" "$PLUGIN/templates/hooks/branch-guard-hooks.json.template"; do
  name="${f#"$PLUGIN"/}"
  # Prints: <matches Bash 0|1> TAB <command>
  read -r -d '' info < <(node -e '
    const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const e = (d.hooks.PreToolUse || []).find(x => x.hooks.some(h => /Do not commit on/.test(h.command)));
    if (!e) { console.log("0\t"); process.exit(); }
    const m = e.matcher ?? "";
    const hit = (m === "" || m === "*") ? true
      : /^[A-Za-z0-9_\- ,|]*$/.test(m) ? m.split(/[|,]/).map(s => s.trim()).includes("Bash")
      : new RegExp(m).test("Bash");
    const h = e.hooks.find(h => /Do not commit on/.test(h.command));
    process.stdout.write((hit ? 1 : 0) + "\t" + h.command);
  ' "$f")
  matches="${info%%$'\t'*}"; cmd="${info#*$'\t'}"
  check "$name: matcher selects Bash" 1 "$matches"

  run() { # run <branch> <tool command> → exit code
    local d; d="$(repo "$1")"
    (cd "$d" && printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$2" | bash -c "$cmd" >/dev/null 2>&1); echo $?
  }
  check "$name: git commit on main is blocked" 2 "$(run main 'git commit -m x')"
  check "$name: git commit on develop is blocked" 2 "$(run develop 'git commit -am x')"
  check "$name: other Bash on main is allowed" 0 "$(run main 'ls -la')"
  check "$name: git commit on feature branch is allowed" 0 "$(run feature/x 'git commit -m x')"
  rm -rf "$TMP"/r-*
done

echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
