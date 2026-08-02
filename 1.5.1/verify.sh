#!/usr/bin/env bash
# Cross-check 1.5.1: Grafana is up, the Prometheus datasource is PROVISIONED
# (with uid=prometheus), and Grafana can actually query metrics through it.
# Usage: ./verify.sh [GRAFANA_URL] [admin:password]
set -euo pipefail
G="${1:-http://localhost:13000}"
AUTH="${2:-admin:admin}"
echo "Grafana: $G"
echo

echo "== health =="
curl -sf "$G/api/health" | jq -r '"  db=\(.database)  version=\(.version)"'
echo

echo "== provisioned datasources =="
curl -sf -u "$AUTH" "$G/api/datasources" \
 | jq -r '.[] | "  name=\(.name)  uid=\(.uid)  type=\(.type)  default=\(.isDefault)"'
echo

echo "== query 'up' THROUGH Grafana's datasource proxy (uid: prometheus) =="
q="$G/api/datasources/proxy/uid/prometheus/api/v1/query?query=up"
res=$(curl -sf -u "$AUTH" "$q" | jq -r '.status')
n=$(curl -sf -u "$AUTH" "$q" | jq -r '.data.result | length')
echo "  status=$res   ('up' series returned: $n)"
echo

if [ "$res" = "success" ] && [ "$n" -gt 0 ]; then
  echo "PASS — Grafana is reading metrics from Prometheus via the provisioned datasource."
else
  echo "FAIL — expected status=success with at least one series."
  exit 1
fi
