#!/usr/bin/env bash
# 2.3.15 — prove the capstone landed in Jaeger:
#   - the PAYMENT JOURNEY: one api-gateway trace spanning >= 8 services, including
#     bank-network, with a bank-network span >= 300ms (the slowest leaf), and
#   - the KAFKA BREAK: a notification-service trace with NO api-gateway (the orphan consumer).
# Usage: ./verify.sh [JAEGER_URL]
set -uo pipefail
JAEGER="${1:-http://localhost:16686}"
end_us=$(( $(date +%s) * 1000000 )); start_us=$(( end_us - 3600*1000000 ))
echo "Jaeger: $JAEGER"; echo

gw=$(curl -s -m 10 "$JAEGER/api/traces?service=api-gateway&start=$start_us&end=$end_us&limit=50")
nf=$(curl -s -m 10 "$JAEGER/api/traces?service=notification-service&start=$start_us&end=$end_us&limit=50")

journey=$(printf '%s' "$gw" | jq '[ .data[]
  | select([.processes[].serviceName] | index("bank-network"))
  | select(([.processes[].serviceName] | unique | length) >= 8)
  | select(([.spans[] | select(.operationName=="POST /authorize" and .duration >= 300000)] | length) >= 1) ] | length')
services=$(printf '%s' "$gw" | jq '[ .data[]
  | select([.processes[].serviceName] | index("bank-network"))
  | ([.processes[].serviceName] | unique | length) ] | max // 0')
break_orphan=$(printf '%s' "$nf" | jq '[ .data[]
  | select(([.processes[].serviceName] | index("api-gateway")) | not) ] | length')

echo "PAYMENT JOURNEY (>=8 svcs, bank-network >=300ms):  $journey  (expect >= 1)"
echo "services in the payment trace:                     $services (expect >= 8)"
echo "KAFKA BREAK orphan consumer trace:                 $break_orphan (expect >= 1)"
echo
if [ "${journey:-0}" -ge 1 ] && [ "${services:-0}" -ge 8 ] && [ "${break_orphan:-0}" -ge 1 ]; then
  echo "PASS — the full payment journey and the Kafka break are both in Jaeger."
  echo "       make ui -> open the api-gateway payment trace; make hunt -> the slowest span."
else
  echo "FAIL — expected the 8-service payment trace + the orphan consumer. Did 'make' run? (re-run it)"
  exit 1
fi
