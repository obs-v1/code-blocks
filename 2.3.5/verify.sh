#!/usr/bin/env bash
# 2.3.5 — prove the demo seeded both scenarios into Jaeger:
#   BROKEN: a checkout-service-only trace AND an order-service-only trace (one request,
#           two disjoint traces — the silent split).
#   FIXED : one trace that spans BOTH checkout-service and order-service.
# Jaeger's query API returns each trace's processes, so we just inspect the service sets.
# Usage: ./verify.sh [JAEGER_URL]
set -uo pipefail
JAEGER="${1:-http://localhost:16686}"
end_us=$(( $(date +%s) * 1000000 ))
start_us=$(( end_us - 3600*1000000 ))     # last hour, in microseconds
echo "Jaeger: $JAEGER"; echo

svc_sets() {  # $1 = service to query -> JSON array of {id, svcs:[...]}
  curl -s -m 10 "$JAEGER/api/traces?service=$1&start=$start_us&end=$end_us&limit=50" \
    | jq -c '[ .data[] | { id: .traceID, svcs: ([.processes[].serviceName] | unique) } ]'
}

ord=$(svc_sets order-service)
ck=$(svc_sets checkout-service)

joined=$(printf '%s' "$ord" | jq '[ .[] | select((.svcs|index("checkout-service")) and (.svcs|index("order-service"))) ]')
orphan=$(printf '%s' "$ord" | jq '[ .[] | select(.svcs == ["order-service"]) ]')
ck_only=$(printf '%s' "$ck" | jq '[ .[] | select(.svcs == ["checkout-service"]) ]')

nj=$(printf '%s' "$joined"  | jq 'length')
no=$(printf '%s' "$orphan"  | jq 'length')
nc=$(printf '%s' "$ck_only" | jq 'length')

echo "BROKEN  checkout-service-only traces: $nc   $(printf '%s' "$ck_only" | jq -r '[.[].id[0:12]]|join(", ")')"
echo "BROKEN  order-service-only traces:    $no   $(printf '%s' "$orphan"  | jq -r '[.[].id[0:12]]|join(", ")')"
echo "FIXED   checkout+order joined traces: $nj   $(printf '%s' "$joined"  | jq -r '[.[].id[0:12]]|join(", ")')"
echo
if [ "${nc:-0}" -ge 1 ] && [ "${no:-0}" -ge 1 ] && [ "${nj:-0}" -ge 1 ]; then
  echo "PASS — the split is visible (two one-service traces) AND the fix is visible (one joined trace)."
  echo "       In the UI, filter by tag  demo.scenario=broken  vs  demo.scenario=fixed."
else
  echo "FAIL — expected >=1 of each. Did 'make seed' run against this Jaeger? (re-run it)"
  exit 1
fi
