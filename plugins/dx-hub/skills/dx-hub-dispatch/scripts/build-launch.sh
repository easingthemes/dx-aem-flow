#!/usr/bin/env bash
# build-launch.sh — build one repo's CLI command line for /dx-hub-dispatch and
# write it as a small runnable script, so a person (or any launcher) can start
# the session with `bash <script>` and no shell quoting by hand.
#
# Usage: build-launch.sh --engine claude|copilot --cwd <repo-abs-path> \
#          --session <lowercase-uuid> --prompt <delegation prompt> \
#          --out <script path> [--model <model>]
#
# Stdout: the command line (without the cd).
# The script written to --out: cd into --cwd, then exec the command. chmod +x.
# The prompt must be one line with no ", $ or backtick: it goes inside a
# double-quoted shell string.
#
# Exit codes: 0 written, 2 bad or missing argument

set -uo pipefail

engine="" cwd="" session="" prompt="" out="" model=""
while [ $# -gt 0 ]; do
  case "$1" in
    --engine)  engine="${2:-}";  shift 2 ;;
    --cwd)     cwd="${2:-}";     shift 2 ;;
    --session) session="${2:-}"; shift 2 ;;
    --prompt)  prompt="${2:-}";  shift 2 ;;
    --out)     out="${2:-}";     shift 2 ;;
    --model)   model="${2:-}";   shift 2 ;;
    *) echo "error: unknown argument $1" >&2; exit 2 ;;
  esac
done

for v in engine cwd session prompt out; do
  [ -n "${!v}" ] || { echo "error: --$v is required" >&2; exit 2; }
done
case "$engine" in claude|copilot) ;; *) echo "error: --engine must be claude or copilot" >&2; exit 2 ;; esac
printf '%s' "$session" | grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' \
  || { echo "error: --session must be a lowercase uuid" >&2; exit 2; }
case "$prompt" in
  *'"'*|*'$'*|*'`'*) echo "error: prompt contains a double quote, \$ or backtick" >&2; exit 2 ;;
esac
case "$prompt" in *$'\n'*) echo "error: prompt must be one line" >&2; exit 2 ;; esac
case "$model" in *[!A-Za-z0-9._:-]*) echo "error: --model has characters outside [A-Za-z0-9._:-]" >&2; exit 2 ;; esac

model_arg=""
[ -n "$model" ] && model_arg=" --model $model"

if [ "$engine" = copilot ]; then
  cmd="DX_RUN_ID=$session copilot --session-id $session$model_arg -i \"$prompt\""
else
  cmd="DX_RUN_ID=$session claude --session-id $session$model_arg \"$prompt\""
fi

# Single-quote the cwd for the script (escape embedded single quotes).
q_cwd="'${cwd//\'/\'\\\'\'}'"

mkdir -p "$(dirname "$out")" || exit 2
{
  printf '#!/usr/bin/env bash\n'
  printf '# Written by /dx-hub-dispatch — starts one repo session.\n'
  printf 'cd %s || exit 1\n' "$q_cwd"
  printf 'exec env %s\n' "$cmd"
} > "$out" || exit 2
chmod +x "$out"

printf '%s\n' "$cmd"
