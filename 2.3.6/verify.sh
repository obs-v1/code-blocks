#!/usr/bin/env bash
# 2.3.6 — prove the queue demo seeded both scenarios into Jaeger:
#   CONNECTED: one trace spanning order-service AND notification-service (producer+consumer joined).
#   BROKEN   : an order-service-only trace (producer side) AND a notification-service trace with
#              NO order-service (the orphan consumer). One event, two disjoint traces.
# Usage: ./verify.sh [JAEGER_URL]
set -uo pipefail
JAEGER="${1:-http://localhost:16686}"
end_us=$(( $(date +%s) * 1000000 )); start_us=$(( end_us - 3600*1000000 ))
echo "Jaeger: $JAEGER"; echo

svc_sets() {  # $1 = service -> JSON array of {id, svcs:[...]}
  curl -s -m 10 "$JAEGER/api/traces?service=$1&start=$start_us&end=$end_us&limit=50" \
    | jq -c '[ .data[] | { id: .traceID, svcs: ([.processes[].serviceName] | unique) } ]'
}

notif=$(svc_sets notification-service)
order=$(svc_sets order-service)

joined=$(printf '%s' "$notif" | jq '[ .[] | select(.svcs|index("order-service")) ]')              # producer+consumer in one trace
orphan=$(printf '%s' "$notif" | jq '[ .[] | select((.svcs|index("order-service"))|not) ]')         # consumer with no producer
prod_only=$(printf '%s' "$order" | jq '[ .[] | select((.svcs|index("notification-service"))|not) ]') # producer with no consumer

nj=$(printf '%s' "$joined"    | jq 'length')
no=$(printf '%s' "$orphan"    | jq 'length')
np=$(printf '%s' "$prod_only" | jq 'length')

echo "CONNECTED  producer+consumer in ONE trace:   $nj   $(printf '%s' "$joined"    | jq -r '[.[].id[0:12]]|join(", ")')"
echo "BROKEN     producer-only trace (no consumer): $np   $(printf '%s' "$prod_only" | jq -r '[.[].id[0:12]]|join(", ")')"
echo "BROKEN     orphan consumer (no producer):     $no   $(printf '%s' "$orphan"    | jq -r '[.[].id[0:12]]|join(", ")')"
echo
if [ "${nj:-0}" -ge 1 ] && [ "${np:-0}" -ge 1 ] && [ "${no:-0}" -ge 1 ]; then
  echo "PASS — the connected producer->consumer trace AND the broken split are both visible."
  echo "       In the UI, filter by tag  demo.scenario=connected  vs  demo.scenario=broken."
else
  echo "FAIL — expected >=1 of each. Did 'make' run against this Jaeger? (re-run it)"
  exit 1
fi
