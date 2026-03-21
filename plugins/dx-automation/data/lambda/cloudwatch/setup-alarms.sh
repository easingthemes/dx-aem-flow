#!/usr/bin/env bash
# Provision CloudWatch Alarms + SNS topic for AI Automation monitoring.
#
# Usage:
#   cd .ai/automation
#   source ../../.ai/lib/audit.sh
#   lambda/cloudwatch/setup-alarms.sh [--email you@example.com]
#
# Reads prefix and region from infra.json. Requires: aws CLI, python3, audit.sh sourced.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA="$SCRIPT_DIR/../../infra.json"
ALARMS_FILE="$SCRIPT_DIR/alarms.json"

# Check prerequisites
if ! command -v aws &>/dev/null; then
  echo "ERROR: aws CLI not found. Install with: brew install awscli"
  exit 1
fi
if ! type aws_resource &>/dev/null 2>&1; then
  echo "ERROR: audit.sh not sourced. Run: source .ai/lib/audit.sh"
  exit 1
fi
if [[ ! -f "$INFRA" ]]; then
  echo "ERROR: infra.json not found at $INFRA. Run /auto-init first."
  exit 1
fi

# Read config from infra.json
REGION=$(python3 -c "import json; print(json.load(open('$INFRA'))['region'])")
RESOURCE_PREFIX=$(python3 -c "import json; print(json.load(open('$INFRA'))['monitoring']['snsTopic']['name'].rsplit('-',1)[0])" 2>/dev/null || \
  python3 -c "import json; d=json.load(open('$INFRA')); print(d['storage']['dynamodb']['dedupe']['tableName'].rsplit('-',1)[0])")
PIPELINE_PREFIX=$(python3 -c "import json; print(json.load(open('$INFRA'))['lambdas']['dor']['functionName'].rsplit('-',2)[0])")
SNS_NAME="${RESOURCE_PREFIX}-alerts"

# Parse email arg
EMAIL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --email) EMAIL="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

echo "=== AI Automation CloudWatch Alarm Setup ==="
echo "Region:  $REGION"
echo "Prefix:  $RESOURCE_PREFIX"
echo "Pipeline prefix: $PIPELINE_PREFIX"
echo ""

# Step 1: Create SNS topic
echo "--- Step 1: Create SNS topic ${SNS_NAME} ---"
TOPIC_ARN=$(aws_resource "sns/${SNS_NAME}" \
  aws sns create-topic --name "$SNS_NAME" --region "$REGION" \
  --query 'TopicArn' --output text)
echo "SNS Topic ARN: $TOPIC_ARN"

# Subscribe email if provided
if [[ -n "$EMAIL" ]]; then
  echo "Subscribing $EMAIL to alerts..."
  aws_resource "sns/${SNS_NAME}/subscription" \
    aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol email --notification-endpoint "$EMAIL" --region "$REGION"
  echo "CHECK YOUR EMAIL to confirm the subscription."
fi

# Step 2: Create alarms
echo ""
echo "--- Step 2: Create CloudWatch Alarms ---"

ALARM_COUNT=$(python3 -c "import json; print(len(json.load(open('$ALARMS_FILE'))['alarms']))")

for i in $(seq 0 $((ALARM_COUNT - 1))); do
  ALARM_JSON=$(python3 -c "import json; print(json.dumps(json.load(open('$ALARMS_FILE'))['alarms'][$i]))")
  NAME_SUFFIX=$(echo "$ALARM_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['nameSuffix'])")
  ALARM_NAME="${RESOURCE_PREFIX}-${NAME_SUFFIX}"
  ALARM_DESC=$(echo "$ALARM_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['description'])")
  NAMESPACE=$(echo "$ALARM_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['namespace'])")
  METRIC=$(echo "$ALARM_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['metricName'])")
  STAT=$(echo "$ALARM_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['statistic'])")
  PERIOD=$(echo "$ALARM_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['period'])")
  EVAL_PERIODS=$(echo "$ALARM_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['evaluationPeriods'])")
  THRESHOLD=$(echo "$ALARM_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['threshold'])")
  COMPARISON=$(echo "$ALARM_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['comparisonOperator'])")
  TREAT_MISSING=$(echo "$ALARM_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['treatMissingData'])")

  # Build dimensions — prefix-aware
  DIM_NAME=$(echo "$ALARM_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('dimensionName',''))" 2>/dev/null || echo "")
  DIM_VALUE_SUFFIX=$(echo "$ALARM_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('dimensionValueSuffix',''))" 2>/dev/null || echo "")
  DIM_CASE=$(echo "$ALARM_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('dimensionValueCase','lower'))" 2>/dev/null || echo "lower")

  DIMENSIONS=""
  if [[ -n "$DIM_NAME" && -n "$DIM_VALUE_SUFFIX" ]]; then
    if [[ "$DIM_CASE" == "upper-prefix" ]]; then
      DIM_VALUE="${PIPELINE_PREFIX}-${DIM_VALUE_SUFFIX}"
    else
      DIM_VALUE="${RESOURCE_PREFIX}-${DIM_VALUE_SUFFIX}"
    fi
    DIMENSIONS="Name=${DIM_NAME},Value=${DIM_VALUE}"
  fi

  echo "Creating alarm: $ALARM_NAME"

  CMD=(aws cloudwatch put-metric-alarm
    --alarm-name "$ALARM_NAME"
    --alarm-description "$ALARM_DESC"
    --namespace "$NAMESPACE"
    --metric-name "$METRIC"
    --statistic "$STAT"
    --period "$PERIOD"
    --evaluation-periods "$EVAL_PERIODS"
    --threshold "$THRESHOLD"
    --comparison-operator "$COMPARISON"
    --treat-missing-data "$TREAT_MISSING"
    --alarm-actions "$TOPIC_ARN"
    --region "$REGION")

  if [[ -n "$DIMENSIONS" ]]; then
    CMD+=(--dimensions "$DIMENSIONS")
  fi

  aws_resource "cloudwatch/$ALARM_NAME" "${CMD[@]}"
  echo "  OK"
done

echo ""
echo "=== Done: ${ALARM_COUNT} alarms created ==="
echo ""
echo "Verify in CloudWatch console:"
echo "  https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#alarmsV2:"
