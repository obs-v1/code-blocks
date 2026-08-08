#!/usr/bin/env bash
# 2.5.4 cross-check, entirely from the logs:
#   A) cross-service navigation WORKS — one payment id spans multiple services.
#   B) the Kafka break is REAL — that id never reaches a downstream consumer.
# Proving what is ABSENT (B) is the skill (same lesson as 2.2.10).
# Usage: ./verify.sh [LOKI_URL]   (default http://localhost:3100)
set -euo pipefail
LOKI="${1:-http://localhost:3100}"
NOW=$(date +%s); START=$(( (NOW-900) * 1000000000 )); END=$(( NOW * 1000000000 ))
qr() { curl -sf -G "$LOKI/loki/api/v1/query_range" \
  --data-urlencode "query=$1" --data-urlencode "limit=${2:-2000}" \
  --data-urlencode "start=$START" --data-urlencode "end=$END"; }
echo "Loki: $LOKI"; echo

# consumers that process the payment event off Kafka — should NOT share its id
CONSUMERS="ledger-service|notification-orchestrator|audit-service|fraud-detection|rules-engine"

CID=$(qr '{service="upi-service"} |= `upi-payment-completed`' 200 \
      | jq -r '[.data.result[].values[][1] | fromjson? | .correlation_id] | map(select(.!=null)) | last')
SVCS=$(qr "{namespace=\"bankobs\"} | json | correlation_id=\`$CID\`" 500 \
      | jq -r '[.data.result[].values[][1] | fromjson? | .service] | unique | join(",")')
n=$(echo "$SVCS" | tr ',' '\n' | grep -c .)
downstream=$(echo "$SVCS" | tr ',' '\n' | grep -cE "$CONSUMERS" || true)

echo "  payment correlation_id: $CID"
echo "  services reached:       $SVCS"
echo "  count:                  $n"
echo "  downstream consumers reached: $downstream   (should be 0 — the Kafka break)"
echo
if [ "$n" -ge 2 ] && [ "$downstream" -eq 0 ]; then
  echo "PASS — the payment id spans the HTTP tier (cross-service nav works),"
  echo "       and reaches NO Kafka consumer: context dies at the queue boundary."
else
  echo "FAIL — expected multi-service reach AND zero downstream consumers."
  exit 1
fi
