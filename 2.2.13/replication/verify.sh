#!/usr/bin/env bash
# 2.2.13 replication_factor: with RF=3 across 3 ingesters, freshly-pushed logs
# live in three ingesters' memory. Kill one ingester and the logs are STILL
# there — the other two replicas have them. Proves durability from replication
# (not from object storage; the logs haven't flushed yet).
# Usage: ./verify.sh [LOKI_URL] [NAMESPACE]
set -euo pipefail
LOKI="${1:-http://localhost:3100}"
NS="${2:-loki-replication}"
echo "Loki: $LOKI   ns: $NS"; echo

BASE=$(( $(date +%s) * 1000000000 )); SEQ=0
push() {   # $1 line
  SEQ=$((SEQ+1)); ts=$((BASE + SEQ*1000000))
  curl -s -o /dev/null -H 'Content-Type: application/json' "$LOKI/loki/api/v1/push" \
    --data-binary "{\"streams\":[{\"stream\":{\"app\":\"repl\"},\"values\":[[\"$ts\",\"$1\"]]}]}"
}
for i in $(seq 1 10); do push "line $i"; done
sleep 4

cnt() { curl -s -G "$LOKI/loki/api/v1/query" \
  --data-urlencode 'query=sum(count_over_time({app="repl"}[10m]))' \
  | jq -r '.data.result[0].value[1] // "0"'; }

before=$(cnt)
printf "  lines before failure:    %s   (should be 10)\n" "$before"

pod=$(kubectl -n "$NS" get pod -l app.kubernetes.io/component=write \
      -o jsonpath='{.items[0].metadata.name}')
printf "  killing one ingester:    %s\n" "$pod"
kubectl -n "$NS" delete pod "$pod" --wait=false >/dev/null

sleep 10
after=0
for t in 1 2 3 4; do after=$(cnt); [ "$after" = "$before" ] && break; sleep 5; done
printf "  lines after failure:     %s   (should still be %s — REPLICATED)\n" "$after" "$before"
echo
if [ "$before" -ge 10 ] && [ "$after" = "$before" ]; then
  echo "PASS — RF=3 kept every line after an ingester was killed. No loss."
else
  echo "FAIL — data was lost after the ingester loss (see values)."; exit 1
fi
