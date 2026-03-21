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

deploy() {
  local name="$1"
  shift
  local files=("$@")
  local region
  region=$(lambda_region)
  local zip="${SCRIPT_DIR}/${name}.zip"

  echo "Packaging ${name}..."
  zip -j "$zip" "${files[@]}"

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

  # Copy shared lib files from agents/lib/ into lambda/ for flat zip
  local copied_libs=()
  if [[ -n "$shared_libs" ]]; then
    for lib in $shared_libs; do
      cp "$SCRIPT_DIR/../agents/lib/$lib" "$SCRIPT_DIR/$lib"
      copied_libs+=("$lib")
    done
    # shellcheck disable=SC2086
    files="$files $shared_libs"
  fi

  # shellcheck disable=SC2086
  deploy "$name" $files

  # Clean up copied lib files
  for lib in "${copied_libs[@]}"; do
    rm -f "$SCRIPT_DIR/$lib"
  done
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
