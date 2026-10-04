#!/usr/bin/env bash
# 2.3.7 — prove the batch/links demo landed in Jaeger:
#   - >= 4 source traces (order-service), and
#   - a batch-processor span with >= 4 FOLLOWS_FROM references (Jaeger's rendering of
#     OTLP span links) pointing OUT to those separate source traces.
# Usage: ./verify.sh [JAEGER_URL]
set -uo pipefail
JAEGER="${1:-http://localhost:16686}"
end_us=$(( $(date +%s) * 1000000 )); start_us=$(( end_us - 3600*1000000 ))
echo "Jaeger: $JAEGER"; echo

q() { curl -s -m 10 "$JAEGER/api/traces?service=$1&start=$start_us&end=$end_us&limit=50"; }

sources=$(q order-service | jq '[.data[]] | length')
batch=$(q batch-processor)
# most FOLLOWS_FROM references on any single span in the batch trace(s)
maxlinks=$(printf '%s' "$batch" | jq '[ .data[].spans[] | ([.references[]? | select(.refType=="FOLLOWS_FROM")] | length) ] | max // 0')
# the distinct traces those references point to
targets=$(printf '%s' "$batch" | jq '[ .data[].spans[].references[]? | select(.refType=="FOLLOWS_FROM") | .traceID ] | unique | length')

echo "source traces (order-service):                 $sources   (expect >= 4)"
echo "max span LINKS on a batch span (FOLLOWS_FROM):  $maxlinks  (expect >= 4)"
echo "distinct traces those links point to:           $targets   (expect >= 4)"
echo
if [ "${sources:-0}" -ge 4 ] && [ "${maxlinks:-0}" -ge 4 ] && [ "${targets:-0}" -ge 4 ]; then
  echo "PASS — one batch span links to >= 4 separate source traces. Open it in the UI:"
  echo "       the batch span's References point OUT to the four order traces (many-to-one)."
else
  echo "FAIL — expected >=4 sources and a batch span linking to >=4 of them. Did 'make' run? (re-run it)"
  exit 1
fi
