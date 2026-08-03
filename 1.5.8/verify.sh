#!/usr/bin/env bash
# Cross-check the fully-provisioned Grafana:
#   datasource provisioned, all 5 dashboards loaded, and live data flowing.
# Usage: ./verify.sh [GRAFANA_URL] [admin:password]
set -euo pipefail
G="${1:-http://localhost:13000}"
AUTH="${2:-admin:admin}"
echo "Grafana: $G"
echo

echo "== health =="
curl -sf "$G/api/health" | jq -r '"  db=\(.database)  version=\(.version)"'
echo

echo "== provisioned datasource =="
curl -sf -u "$AUTH" "$G/api/datasources" | jq -r '.[] | "  \(.name)  uid=\(.uid)  default=\(.isDefault)"'
echo

echo "== provisioned dashboards =="
UIDS="obs-panels obs-variables obs-annotations obs-transforms obs-red"
miss=0
for uid in $UIDS; do
  t=$(curl -sf -u "$AUTH" "$G/api/dashboards/uid/$uid" 2>/dev/null | jq -r '.dashboard.title // "MISSING"')
  printf "  %-16s -> %s\n" "$uid" "$t"
  [ "$t" = "MISSING" ] && miss=1
done
echo

echo "== live data through the datasource proxy (fleet req/s) =="
q="$G/api/datasources/proxy/uid/prometheus/api/v1/query?query=sum(rate(http_server_requests_seconds_count%5B5m%5D))"
val=$(curl -sf -u "$AUTH" "$q" | jq -r '.data.result[0].value[1] // "none"')
echo "  fleet request rate = $val req/s"
echo

if [ "$miss" = 0 ] && [ "$val" != "none" ]; then
  echo "PASS — datasource + all 5 dashboards provisioned, and Grafana is reading live fleet metrics."
else
  echo "FAIL — a dashboard is missing or no data came back."
  exit 1
fi
