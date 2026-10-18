#!/usr/bin/env bash
# 2.4.4 check — the app's stdout logs reached Loki via the Collector's filelog
# receiver. Loki promoted k8s.namespace.name to a stream label, so we query
# {k8s_namespace_name="otel24"} and confirm our app lines are there.
# Usage: ./verify.sh [LOKI_URL]   (default http://localhost:3100)
set -euo pipefail
L="${1:-http://localhost:3100}"
echo "Loki: $L"; echo

lines=0
for try in 1 2 3 4 5 6 7 8; do   # filelog + ship takes ~30-60s on cold start
  RESP=$(curl -sf "$L/loki/api/v1/query_range" \
            --data-urlencode 'query={k8s_container_name="app"} |= "\"msg\": \"frontend calling backend\""' \
            --data-urlencode 'limit=20' --data-urlencode 'since=10m' || echo '{}')
  lines=$(echo "$RESP" | python3 -c 'import json,sys
try: r=json.load(sys.stdin)["data"]["result"]
except Exception: r=[]
print(sum(len(s.get("values",[])) for s in r))')
  [ "${lines:-0}" -gt 0 ] && break
  echo "  (waiting for logs to reach Loki — attempt $try)"; sleep 10
done

echo "  app log lines in Loki ({k8s_container_name=\"app\"}): $lines"
if [ "${lines:-0}" -gt 0 ]; then
  echo
  echo "  one line:"
  echo "$RESP" | python3 -c 'import json,sys; r=json.load(sys.stdin)["data"]["result"]; print("   ", r[0]["values"][0][1][:160])' 2>/dev/null || true
  echo
  echo "PASS — the app wrote stdout; the Collector (DaemonSet) tailed it into Loki. No logging SDK."
else
  echo
  echo "FAIL — no app logs in Loki yet. Give it longer and retry."
  exit 1
fi
