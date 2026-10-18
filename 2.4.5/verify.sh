#!/usr/bin/env bash
# 2.4.5 check — a single trace spans BOTH services. The app sent OTLP to the Collector,
# the Collector forwarded to Jaeger. If any service-a trace also contains a service-b
# span, context propagated end-to-end and the Collector's trace pipeline works.
# Usage: ./verify.sh [JAEGER_URL]   (default http://localhost:16686)
set -euo pipefail
J="${1:-http://localhost:16686}"
echo "Jaeger: $J"; echo

both=0; total=0
for try in 1 2 3 4 5 6 7 8; do   # apps take ~60-90s to warm up + batch-export on cold start
  DATA=$(curl -sf "$J/api/traces?service=service-a&limit=50&lookback=10m" || echo '{"data":[]}')
  total=$(echo "$DATA" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["data"]))')
  both=$(echo "$DATA" | python3 -c '
import json,sys
d=json.load(sys.stdin)["data"]; n=0
for t in d:
    svcs={p["serviceName"] for p in t.get("processes",{}).values()}
    if "service-a" in svcs and "service-b" in svcs: n+=1
print(n)')
  [ "${both:-0}" -gt 0 ] && break
  echo "  (waiting for traces — attempt $try)"; sleep 10
done

echo "  service-a traces in Jaeger: $total"
echo "  traces that span service-a AND service-b: $both"
echo
if [ "${both:-0}" -gt 0 ]; then
  echo "PASS — a trace reached Jaeger spanning both services, via the Collector (no direct app→Jaeger)."
else
  echo "FAIL — no cross-service trace yet. Give it longer and retry."
  exit 1
fi
