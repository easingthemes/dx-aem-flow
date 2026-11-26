#!/usr/bin/env bash
# hub-config.sh — resolve the settings /dx-hub-dispatch reads from a hub
# .ai/config.yaml, applying documented defaults out loud.
#
# Usage: hub-config.sh [config.yaml]        (default: .ai/config.yaml)
#
# Stdout: one KEY=VALUE line per setting:
#   enabled, engine, model, terminal_delay, launcher, provider, scm_project
# then one line per repo:
#   repo=<name>\t<path>\t<ado-project>\t<capabilities csv>\t<keywords csv>
# Stderr: one "default: ..." line for every value that was missing and got a
# default, and one "warn: ..." line for every value that is present but wrong
# or a repo without capabilities. Nothing is defaulted silently.
#
# Exit codes: 0 resolved, 2 config file missing, 3 hub.enabled is not true,
#             4 an invalid value (engine, launcher, terminal-delay)

set -uo pipefail

CFG="${1:-.ai/config.yaml}"
[ -f "$CFG" ] || { echo "error: config not found: $CFG" >&2; exit 2; }

strip() { sed -e 's/[[:space:]]#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"; }

# Value of <key> directly under top-level <section>: (two-space or deeper indent, first hit).
section_val() {
  awk -v sec="$1" -v key="$2" '
    $0 ~ "^"sec":[[:space:]]*$" { ins=1; next }
    ins && /^[^[:space:]#]/ { ins=0 }
    ins && $0 ~ "^[[:space:]]+"key":" { sub("^[[:space:]]+"key":[[:space:]]*", ""); print; exit }
  ' "$CFG" | strip
}

rc=0
enabled="$(section_val hub enabled)"
if [ "$enabled" != "true" ]; then
  echo "error: hub.enabled is not true in $CFG — run /dx-hub-init" >&2
  exit 3
fi

engine="$(section_val hub engine)"
if [ -z "$engine" ]; then engine=claude; echo "default: hub.engine not set — using claude" >&2
elif [ "$engine" != claude ] && [ "$engine" != copilot ]; then
  echo "warn: hub.engine '$engine' is not claude or copilot" >&2; rc=4
fi

model="$(section_val hub model)"

delay="$(section_val hub terminal-delay)"
if [ -z "$delay" ]; then delay=5; echo "default: hub.terminal-delay not set — using 5" >&2
elif ! printf '%s' "$delay" | grep -Eq '^[0-9]+$'; then
  echo "warn: hub.terminal-delay '$delay' is not a whole number of seconds" >&2; rc=4
fi

launcher="$(section_val hub launcher)"
if [ -z "$launcher" ]; then launcher=auto; echo "default: hub.launcher not set — using auto" >&2
else case "$launcher" in auto|vscode-automator|terminal|none) ;;
  *) echo "warn: hub.launcher '$launcher' is not auto, vscode-automator, terminal or none" >&2; rc=4 ;;
esac; fi

provider="$(section_val tracker provider)"
[ -z "$provider" ] && provider="$(section_val scm provider)"
if [ -z "$provider" ]; then provider=ado; echo "default: tracker.provider not set — using ado" >&2; fi

scm_project="$(section_val scm project)"

printf 'enabled=%s\nengine=%s\nmodel=%s\nterminal_delay=%s\nlauncher=%s\nprovider=%s\nscm_project=%s\n' \
  "$enabled" "$engine" "$model" "$delay" "$launcher" "$provider" "$scm_project"

# repos[]: name, path, ado-project, capabilities, keywords. Lists may be inline
# ([a, b]) or block (- a). Output lists comma-separated, lowercased, no spaces.
repos="$(awk '
  function trim(s) { sub(/[[:space:]]+#.*$/, "", s); gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); gsub(/^["\x27]|["\x27]$/, "", s); return s }
  function inl(s,   out, n, i, a) {
    s=trim(s); if (s == "" ) return ""
    gsub(/^\[|\]$/, "", s); n=split(s, a, ","); out=""
    for (i=1; i<=n; i++) { a[i]=trim(a[i]); if (a[i] != "") out = out (out=="" ? "" : ",") tolower(a[i]) }
    return out
  }
  function flush() {
    if (name != "") printf "repo=%s\t%s\t%s\t%s\t%s\n", name, path, proj, caps, kws
    name=""; path=""; proj=""; caps=""; kws=""; hascaps=0; blk=""
  }
  /^repos:[[:space:]]*$/ { inr=1; next }
  inr && /^[^[:space:]#-]/ { flush(); inr=0; next }
  !inr { next }
  /^[[:space:]]*-[[:space:]]*name:/ { flush(); v=$0; sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", v); name=trim(v); next }
  /^[[:space:]]+path:/        { v=$0; sub(/^[[:space:]]+path:[[:space:]]*/, "", v); path=trim(v); blk=""; next }
  /^[[:space:]]+ado-project:/ { v=$0; sub(/^[[:space:]]+ado-project:[[:space:]]*/, "", v); proj=trim(v); blk=""; next }
  /^[[:space:]]+capabilities:/ { v=$0; sub(/^[[:space:]]+capabilities:[[:space:]]*/, "", v); caps=inl(v); blk="caps"; next }
  /^[[:space:]]+keywords:/    { v=$0; sub(/^[[:space:]]+keywords:[[:space:]]*/, "", v); kws=inl(v); blk="kws"; next }
  /^[[:space:]]+-[[:space:]]*[^[:space:]]/ && blk != "" {
    v=$0; sub(/^[[:space:]]+-[[:space:]]*/, "", v); v=tolower(trim(v))
    if (blk == "caps") caps = caps (caps=="" ? "" : ",") v; else kws = kws (kws=="" ? "" : ",") v
    next
  }
  /^[[:space:]]+[A-Za-z_-]+:/ { blk=""; next }
  END { if (inr) flush() }
' "$CFG")"

if [ -z "$repos" ]; then
  echo "warn: no repos[] entries in $CFG" >&2
else
  printf '%s\n' "$repos"
  while IFS=$'\037' read -r first _path proj caps _kws; do
    name="${first#repo=}"
    [ -z "$caps" ] && echo "warn: repo $name has no capabilities — it can only be matched by name or keywords" >&2
    [ -z "$proj" ] && [ "$provider" = ado ] && [ -z "$scm_project" ] && echo "warn: repo $name has no ado-project and scm.project is not set" >&2
  done < <(printf '%s\n' "$repos" | tr '\t' '\037')
fi

exit "$rc"
