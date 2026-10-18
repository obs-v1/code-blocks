#!/usr/bin/env bash
# 2.4.3 check — the app's OTLP metrics reached Prometheus via the Collector's
# remote-write. We ask Prometheus how many series carry each service's name
# (resource_to_telemetry_conversion put service.name on every metric). Both > 0 =
# metrics flowed app → Collector → Prometheus.
# Usage: ./verify.sh [PROM_URL]   (default http://localhost:9090)
set -euo pipefail
P="${1:-http://localhost:9090}"
echo "Prometheus: $P"; echo

q() { curl -sf "$P/api/v1/query" --data-urlencode "query=$1" | python3 -c 'import json,sys; r=json.load(sys.stdin)["data"]["result"]; print(int(float(r[0]["value"][1])) if r else 0)'; }

# metrics take ~40s to appear (app start + 5s export interval + a few requests); retry a few times.
a=0; b=0
for try in 1 2 3 4 5 6 7 8; do   # metrics take ~40-60s on cold start
  a=$(q 'count({service_name="service-a"})'); b=$(q 'count({service_name="service-b"})')
  { [ "${a:-0}" -gt 0 ] && [ "${b:-0}" -gt 0 ]; } && break
  echo "  (waiting for metrics to populate — attempt $try)"; sleep 12
done
echo "  series labelled service-a: $a"
echo "  series labelled service-b: $b"
echo "  sample metric names:"
curl -sf "$P/api/v1/label/__name__/values" | python3 -c 'import json,sys; n=[x for x in json.load(sys.stdin)["data"] if x.startswith("http")]; print("   ",", ".join(n[:6]) or "(none yet)")'
echo
if [ "${a:-0}" -gt 0 ] && [ "${b:-0}" -gt 0 ]; then
  echo "PASS — the app's metrics are in Prometheus, pushed by the Collector (no app-side scrape)."
else
  echo "FAIL — no service metrics yet. Give it ~20s after deploy and retry (metrics push every 5s)."
  exit 1
fi
