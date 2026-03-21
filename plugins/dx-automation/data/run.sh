#!/usr/bin/env bash
#
# AI Automation local runner — wraps eval and capture scripts with .env loading.
#
# Usage:
#   ./run.sh cycle-time [--weeks=12] [--repo=My-Repo]
#   ./run.sh eval [--all | --agent dor | --fixture dor/story-001]
#   ./run.sh capture <agent> <id> <name> [--repo=RepoName]
#   ./run.sh retro [--week latest | --all]
#
# Reads AZURE_DEVOPS_PAT and ANTHROPIC_API_KEY from repo root .env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found. Create it with AZURE_DEVOPS_PAT=<your-pat>"
  exit 1
fi

INFRA_FILE="$SCRIPT_DIR/infra.json"
ORG_URL=$(python3 -c "import json; print(json.load(open('$INFRA_FILE'))['adoOrg'])" 2>/dev/null || echo "")
if [ -z "$ORG_URL" ]; then
  echo "ERROR: Could not read adoOrg from $INFRA_FILE"
  exit 1
fi
ORG_URL="${ORG_URL%/}/"  # ensure trailing slash

CMD="${1:-help}"
shift || true

case "$CMD" in
  cycle-time)
    SYSTEM_COLLECTIONURI="$ORG_URL" \
    node --env-file="$ENV_FILE" "$SCRIPT_DIR/eval/metrics/measure-cycle-time.js" "$@"
    ;;

  eval)
    node "$SCRIPT_DIR/eval/run.js" "$@"
    ;;

  capture)
    AGENT="${1:?Usage: run.sh capture <agent> <id> <name>}"
    ID="${2:?Usage: run.sh capture <agent> <id> <name>}"
    NAME="${3:?Usage: run.sh capture <agent> <id> <name>}"
    shift 3
    SYSTEM_COLLECTIONURI="$ORG_URL" \
    node --env-file="$ENV_FILE" "$SCRIPT_DIR/eval/capture-fixture.js" \
      --agent="$AGENT" --id="$ID" --name="$NAME" "$@"
    ;;

  retro)
    node "$SCRIPT_DIR/eval/retro.js" "$@"
    ;;

  help|*)
    echo "AI Automation local runner"
    echo ""
    echo "Usage: ./run.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  cycle-time  [--weeks=N] [--repo=Name]     Measure PR cycle time baseline"
    echo "  eval        [--all | --agent X]            Run eval fixtures"
    echo "  capture     <agent> <id> <name>            Capture fixture from live ADO"
    echo "  retro       [--week latest | --all]        Weekly retro summary"
    echo ""
    echo "Config: $ENV_FILE (AZURE_DEVOPS_PAT, ANTHROPIC_API_KEY)"
    ;;
esac
