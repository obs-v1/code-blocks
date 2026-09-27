#!/usr/bin/env bash
# 2.5.4 — trace a payment across the fleet, from the LOGS (Loki), and find where
# the correlation stops. This fleet propagates a `correlation_id` across HTTP hops
# but each service self-generates its trace_id, so the logs are the honest map of
# how far a request's identity actually travels — and where it dies.
#
# Usage: ./trace-payment.sh [LOKI_URL]   (default http://localhost:3100)
set -euo pipefail
LOKI="${1:-http://localhost:3100}"
NOW=$(date +%s); START=$(( (NOW-900) * 1000000000 )); END=$(( NOW * 1000000000 ))
qr() { curl -sf -G "$LOKI/loki/api/v1/query_range" \
  --data-urlencode "query=$1" --data-urlencode "limit=${2:-2000}" \
  --data-urlencode "start=$START" --data-urlencode "end=$END"; }

echo "== 1) pick a recent completed payment =="
CID=$(qr '{service="upi-service"} |= `upi-payment-completed`' 200 \
      | jq -r '[.data.result[].values[][1] | fromjson? | .correlation_id] | map(select(.!=null)) | last')
echo "   correlation_id = $CID"; echo

echo "== 2) follow it across the fleet — the log-based waterfall =="
qr "{namespace=\"bankobs\"} | json | correlation_id=\`$CID\`" 500 \
 | jq -r '[.data.result[].values[] | {t:(.[0]|tonumber), line:(.[1]|fromjson?)}]
          | sort_by(.t)
          | .[] | "   \(.line.service // "?"|.[0:22])  \(.line.event // .line.message // "" | .[0:40])"' \
 | awk '!seen[$0]++'   # de-dup identical adjacent lines
echo

echo "== 3) how far did it reach? =="
qr "{namespace=\"bankobs\"} | json | correlation_id=\`$CID\`" 500 \
 | jq -r '[.data.result[].values[][1] | fromjson? | .service] | unique
          | "   services reached: \(join(", "))"'
echo "   (the payment then hands off to Kafka — downstream consumers process it"
echo "    under their OWN ids, so the correlation stops here: the Kafka break.)"
