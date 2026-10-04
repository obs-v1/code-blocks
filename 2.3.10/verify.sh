#!/usr/bin/env bash
# 2.3.10 — prove the waterfall demo landed in Jaeger:
#   - one SLOW trace: spans 6 services, includes bank-gateway, with a bank-gateway span
#     >= 400ms (the slow-self leaf / culprit), and
#   - >= 2 fast baseline traces (no bank-gateway) so the slow one is an outlier.
# Usage: ./verify.sh [JAEGER_URL]
set -uo pipefail
JAEGER="${1:-http://localhost:16686}"
end_us=$(( $(date +%s) * 1000000 )); start_us=$(( end_us - 3600*1000000 ))
echo "Jaeger: $JAEGER"; echo

data=$(curl -s -m 10 "$JAEGER/api/traces?service=api-gateway&start=$start_us&end=$end_us&limit=50")

slow=$(printf '%s' "$data" | jq '[ .data[]
  | select([.processes[].serviceName] | index("bank-gateway"))
  | select(([.spans[] | select(.duration >= 400000)] | length) >= 1) ] | length')
svc_in_slow=$(printf '%s' "$data" | jq '[ .data[]
  | select([.processes[].serviceName] | index("bank-gateway"))
  | ([.processes[].serviceName] | unique | length) ] | max // 0')
baselines=$(printf '%s' "$data" | jq '[ .data[]
  | select(([.processes[].serviceName] | index("bank-gateway")) | not) ] | length')

echo "SLOW trace (bank-gateway + a >=400ms span):  $slow        (expect >= 1)"
echo "services in the slow trace:                  $svc_in_slow (expect >= 6)"
echo "fast baseline traces (no bank-gateway):      $baselines   (expect >= 2)"
echo
if [ "${slow:-0}" -ge 1 ] && [ "${svc_in_slow:-0}" -ge 6 ] && [ "${baselines:-0}" -ge 2 ]; then
  echo "PASS — the slow waterfall is present and stands out against the baselines."
  echo "       Service=api-gateway -> Find Traces -> open the ~900ms outlier -> read the 'analysis' tags."
else
  echo "FAIL — expected the slow trace + >=2 baselines. Did 'make' run against this Jaeger? (re-run it)"
  exit 1
fi
