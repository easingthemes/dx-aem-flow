#!/usr/bin/env bash
# Infrastructure audit log — wraps az pipelines and aws lambda commands.
# Source this file, then use az_pipelines / az_pipelines_variable / aws_lambda_deploy.

AUDIT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.ai/logs"
mkdir -p "$AUDIT_DIR"

_audit_log_file() {
  local mon sun dow prefix
  prefix="${AUDIT_LOG_PREFIX:-infra}"
  if date -v-monday +%Y-%m-%d &>/dev/null; then
    dow=$(date +%u)
    mon=$(date -v-"$(( dow - 1 ))"d +%Y-%m-%d)
    sun=$(date -v+"$(( 7 - dow ))"d +%Y-%m-%d)
  else
    mon=$(date -d "last monday" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
    sun=$(date -d "next sunday" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
  fi
  echo "${AUDIT_DIR}/${prefix}.${mon}--${sun}.jsonl"
}

_audit_append() {
  echo "$1" >> "$(_audit_log_file)"
}

# Extract a named flag value from args (works in both bash and zsh)
_extract_flag() {
  local flag="$1"; shift
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "$flag" ]] && [[ -n "${2:-}" ]]; then
      echo "$2"
      return
    fi
    shift
  done
}

_pipeline_state() {
  local id="$1" org="${2:-}" project="${3:-}"
  local cmd=(az pipelines show --id "$id" -o json)
  [[ -n "$org" ]] && cmd+=(--org "$org")
  [[ -n "$project" ]] && cmd+=(--project "$project")
  "${cmd[@]}" 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
p=d.get('process',{})
print(json.dumps({
  'yamlPath':p.get('yamlFilename',''),
  'queueStatus':d.get('queueStatus',''),
  'defaultBranch':d.get('repository',{}).get('defaultBranch','')
}))" 2>/dev/null || echo '{}'
}

az_pipelines() {
  local subcmd="${1:-}"

  case "$subcmd" in
    show|list|runs)
      az pipelines "$@"
      return $?
      ;;
    update|create|delete)
      local id org project
      id=$(_extract_flag "--id" "$@")
      org=$(_extract_flag "--org" "$@")
      project=$(_extract_flag "--project" "$@")

      local before="{}"
      [[ -n "$id" && "$subcmd" != "create" ]] && before=$(_pipeline_state "$id" "$org" "$project")

      local output rc
      output=$(az pipelines "$@" 2>&1)
      rc=$?
      echo "$output"

      local after="{}"
      [[ -n "$id" && "$subcmd" != "delete" ]] && after=$(_pipeline_state "$id" "$org" "$project")

      _audit_append "$(python3 -c "
import json,datetime,os
print(json.dumps({
  'ts': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
  'user': os.environ.get('USER','unknown'),
  'cmd': 'az pipelines $subcmd',
  'target': 'pipeline/${id:-unknown}',
  'before': json.loads('''$before'''),
  'after': json.loads('''$after'''),
  'exitCode': $rc
}, separators=(',',':')))" 2>/dev/null)"

      return $rc
      ;;
    *)
      az pipelines "$@"
      return $?
      ;;
  esac
}

az_pipelines_variable() {
  local subcmd="${1:-}"

  case "$subcmd" in
    list)
      az pipelines variable "$@"
      return $?
      ;;
    create|update|delete)
      local pipeline_id var_name
      pipeline_id=$(_extract_flag "--pipeline-id" "$@")
      var_name=$(_extract_flag "--name" "$@")

      az pipelines variable "$@"
      local rc=$?

      _audit_append "$(python3 -c "
import json,datetime,os
print(json.dumps({
  'ts': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
  'user': os.environ.get('USER','unknown'),
  'cmd': 'az pipelines variable $subcmd --name $var_name',
  'target': 'pipeline/${pipeline_id:-unknown}/var/${var_name:-unknown}',
  'action': '$subcmd',
  'exitCode': $rc
}, separators=(',',':')))" 2>/dev/null)"

      return $rc
      ;;
    *)
      az pipelines variable "$@"
      return $?
      ;;
  esac
}

aws_lambda_deploy() {
  local func_name="$1" zip_path="$2"
  local code_hash
  code_hash=$(shasum -a 256 "$zip_path" 2>/dev/null | cut -d' ' -f1 || echo "unknown")

  _audit_append "$(python3 -c "
import json,datetime,os
print(json.dumps({
  'ts': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
  'user': os.environ.get('USER','unknown'),
  'cmd': 'aws lambda update-function-code --function-name $func_name',
  'target': 'lambda/$func_name',
  'codeHash': 'sha256:$code_hash'
}, separators=(',',':')))" 2>/dev/null)"
}

# ---------------------------------------------------------------------------
# AWS resource provisioning wrappers
# ---------------------------------------------------------------------------

# Generic wrapper for any AWS CLI mutating command.
# Usage: aws_resource <target-label> <aws-command...>
# Example: aws_resource "dynamodb/myai-dedupe" aws dynamodb create-table --table-name myai-dedupe ...
aws_resource() {
  local target="$1"; shift
  local cmd_str="$*"

  local output rc
  output=$("$@" 2>&1)
  rc=$?
  echo "$output"

  _audit_append "$(python3 -c "
import json,datetime,os
print(json.dumps({
  'ts': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
  'user': os.environ.get('USER','unknown'),
  'cmd': '''$cmd_str''',
  'target': '$target',
  'exitCode': $rc
}, separators=(',',':')))" 2>/dev/null)"

  return $rc
}

# Lambda config update (env vars, memory, timeout, etc.)
aws_lambda_config() {
  local func_name="$1"; shift
  aws_resource "lambda/$func_name/config" aws lambda update-function-configuration --function-name "$func_name" "$@"
}

# IAM inline policy
aws_iam_put_role_policy() {
  local role_name="$1" policy_name="$2"; shift 2
  aws_resource "iam/$role_name/policy/$policy_name" aws iam put-role-policy --role-name "$role_name" --policy-name "$policy_name" "$@"
}

# ---------------------------------------------------------------------------
# Azure generic wrapper (for anything outside az pipelines)
# ---------------------------------------------------------------------------

# Generic wrapper for any Azure CLI mutating command.
# Usage: az_resource <target-label> <az-command...>
# Example: az_resource "keyvault/my-vault" az keyvault create --name my-vault ...
# Example: az_resource "storage/my-account" az storage account create --name my-account ...
az_resource() {
  local target="$1"; shift
  local cmd_str="$*"

  local output rc
  output=$("$@" 2>&1)
  rc=$?
  echo "$output"

  _audit_append "$(python3 -c "
import json,datetime,os
print(json.dumps({
  'ts': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
  'user': os.environ.get('USER','unknown'),
  'cmd': '''$cmd_str''',
  'target': '$target',
  'exitCode': $rc
}, separators=(',',':')))" 2>/dev/null)"

  return $rc
}
