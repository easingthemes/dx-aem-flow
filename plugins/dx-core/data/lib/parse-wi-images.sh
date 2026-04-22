#!/usr/bin/env bash
# parse-wi-images.sh — Extract image references from an ADO work item.
#
# Pure data transformation: no network, no auth, no file writes. Reads the
# JSON body of a wit_get_work_item response (expand=all) on stdin and emits
# one TSV row per unique image reference on stdout.
#
# Used by dx-req (and any skill that ingests ADO work items) to turn the
# raw work item JSON into an actionable fetch list BEFORE calling the MCP
# attachment tool. Separating parse from fetch keeps SKILL.md free of jq
# regexes and makes the extraction unit-testable against fixtures.
#
# Two patterns are extracted and merged:
#
#   1. Formal attachments — relations[].rel == "AttachedFile".
#      resourceSize is known → downstream can size-filter before fetch.
#
#   2. Pasted images — <img src="…/_apis/wit/attachments/{GUID}?fileName=…">
#      inside any field whose multilineFieldsFormat[field] == "html".
#      Size unknown (-1). Filename is typically "image.png" by ADO default.
#
# Dedupe is by GUID; attachment records are emitted first and therefore win
# on conflict (they carry the meaningful filename + size).
#
# Usage:
#   cat work-item.json | bash .ai/lib/parse-wi-images.sh
#   # or
#   bash .ai/lib/parse-wi-images.sh < work-item.json
#
# Stdout (TSV, no header):
#   <source>\t<guid>\t<filename>\t<size-or-minus-1>
#
# where <source> is either the literal "attachment" or the ADO field name
# the embedded reference was found in (e.g. "System.Description").
#
# Requires: jq.

set -euo pipefail

WI_JSON=$(cat)

if [[ -z "$WI_JSON" ]]; then
  echo "ERROR: No input on stdin. Pipe work item JSON to this script." >&2
  exit 2
fi

# 1) AttachedFile relations.
attachments_tsv=$(echo "$WI_JSON" | jq -r '
  (.relations // [])[]
  | select(.rel == "AttachedFile")
  | .url as $u
  | ($u | capture("attachments/(?<g>[0-9a-fA-F-]{36})").g) as $guid
  | ["attachment", $guid, (.attributes.name // "image.bin"), (.attributes.resourceSize // 0)]
  | @tsv
' 2>/dev/null || true)

# 2) Embedded <img> in every HTML field listed in multilineFieldsFormat.
#    scan() with two capture groups returns [[guid, name], …]; the outer [ ][]
#    forces one record per match so @tsv gets a flat row.
embedded_tsv=$(echo "$WI_JSON" | jq -r '
  .multilineFieldsFormat as $fmt
  | .fields as $f
  | ($fmt // {} | to_entries | map(select(.value == "html") | .key)) as $htmlFields
  | $htmlFields[]
  | . as $field
  | ($f[$field] // "") as $html
  | [ $html | scan("_apis/wit/attachments/([0-9a-fA-F-]{36})[?&]fileName=([^\"&<> ]+)") ][]
  | [$field, .[0], .[1], -1]
  | @tsv
' 2>/dev/null || true)

# Dedupe by GUID (column 2). Attachment rows come first, so on tie they win.
printf '%s\n%s\n' "$attachments_tsv" "$embedded_tsv" \
  | awk -F'\t' 'NF>=4 && $2 != "" && !seen[$2]++'
