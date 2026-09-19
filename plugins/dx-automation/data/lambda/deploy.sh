#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
INFRA="$SCRIPT_DIR/../infra.json"
cd "$SCRIPT_DIR"

# shellcheck source=../../lib/audit.sh
export AUDIT_LOG_PREFIX=infra
source "$REPO_ROOT/.ai/lib/audit.sh"

# Read Lambda config from infra.json
lambda_name() {
  python3 -c "import json; print(json.load(open('$INFRA'))['lambdas']['$1']['functionName'])"
}
lambda_files() {
  python3 -c "import json; print(' '.join(json.load(open('$INFRA'))['lambdas']['$1']['files']))"
}
lambda_region() {
  python3 -c "import json; print(json.load(open('$INFRA'))['region'])"
}
lambda_shared_libs() {
  python3 -c "import json; libs=json.load(open('$INFRA'))['lambdas']['$1'].get('sharedLibs',[]); print(' '.join(libs))" 2>/dev/null || true
}

# deploy <function-name> <entry-files...> -- <shared-libs...>
#
# Entry files are zipped flat at the root; shared libs keep their lib/ prefix so the
# deployed layout matches the repo layout and the routers' `./lib/x.js` imports resolve
# in both. (They used to be copied flat and imported as `./x.js`, which meant the
# handlers could not be imported or unit-tested outside a deploy.)
deploy() {
  local name="$1"
  shift
  local files=()
  local libs=()
  local in_libs=0
  for arg in "$@"; do
    if [[ "$arg" == "--" ]]; then in_libs=1; continue; fi
    if [[ $in_libs -eq 1 ]]; then libs+=("lib/$arg"); else files+=("$arg"); fi
  done
  local region
  region=$(lambda_region)
  local zip="${SCRIPT_DIR}/${name}.zip"

  echo "Packaging ${name}..."
  rm -f "$zip"
  zip -j "$zip" "${files[@]}"
  if [[ ${#libs[@]} -gt 0 ]]; then
    ( cd "$SCRIPT_DIR" && zip "$zip" "${libs[@]}" )
  fi

  aws_lambda_deploy "$name" "$zip"

  echo "Deploying ${name} to AWS Lambda (${region})..."
  aws lambda update-function-code \
    --function-name "$name" \
    --zip-file "fileb://${zip}" \
    --region "$region" \
    --output text --query 'LastModified'

  rm "$zip"
  echo "${name} deployed."
}

deploy_agent() {
  local agent="$1"
  local name files shared_libs
  name=$(lambda_name "$agent")
  files=$(lambda_files "$agent")
  shared_libs=$(lambda_shared_libs "$agent")

  # shellcheck disable=SC2086
  deploy "$name" $files -- $shared_libs
}

TARGET="${1:-all}"

case "$TARGET" in
  wi-router)
    deploy_agent wi-router
    ;;
  pr-router)
    deploy_agent pr-router
    ;;
  all)
    deploy_agent wi-router
    echo ""
    deploy_agent pr-router
    ;;
  *)
    echo "Usage: deploy.sh [wi-router|pr-router|all]"
    echo "  wi-router   Deploy Work Item Router Lambda (handles dor/dod/bugfix/qa/devagent/docagent)"
    echo "  pr-router   Deploy PR Router Lambda (handles pr-answer)"
    echo "  all         Deploy both (default)"
    echo ""
    echo "Lambda names are read from infra.json"
    exit 1
    ;;
esac

echo ""
echo "Done."
