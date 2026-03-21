#!/usr/bin/env bash
# queue-pipeline.sh — Queue an ADO pipeline run via REST API.
# Called by the pipeline YAML delegation step (post-Claude).
#
# Usage:
#   queue-pipeline.sh <org-url> <project> <pipeline-id> <template-params-json>
#
# Auth: Uses SYSTEM_ACCESSTOKEN env var (ADO build service token).
#
# Example:
#   SYSTEM_ACCESSTOKEN="$TOKEN" queue-pipeline.sh \
#     "https://<org>.visualstudio.com" \
#     "<ADO Project>" \
#     "456" \
#     '{"bugId":"12345","eventId":"evt-001"}'

set -euo pipefail

ORG_URL="${1:?Missing org URL}"
PROJECT="${2:?Missing project name}"
PIPELINE_ID="${3:?Missing pipeline ID}"
TEMPLATE_PARAMS="${4:-{}}"

TOKEN="${SYSTEM_ACCESSTOKEN:?Missing SYSTEM_ACCESSTOKEN env var}"

# Build ADO Pipelines REST API URL
API_URL="${ORG_URL}/$(printf '%s' "$PROJECT" | jq -sRr @uri)/_apis/pipelines/${PIPELINE_ID}/runs?api-version=7.1-preview.1"

# Build request body
BODY=$(jq -n --argjson params "$TEMPLATE_PARAMS" '{templateParameters: $params}')

echo "Queuing pipeline $PIPELINE_ID in $PROJECT..."
echo "  URL: $API_URL"
echo "  Parameters: $TEMPLATE_PARAMS"

HTTP_CODE=$(curl -s -o /tmp/queue-response.json -w '%{http_code}' \
  -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$BODY")

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  RUN_ID=$(jq -r '.id // "unknown"' /tmp/queue-response.json)
  echo "Pipeline queued successfully. Run ID: $RUN_ID"
else
  echo "ERROR: Pipeline queue failed with HTTP $HTTP_CODE"
  cat /tmp/queue-response.json 2>/dev/null || true
  exit 1
fi
