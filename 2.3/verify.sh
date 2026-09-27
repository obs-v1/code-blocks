#!/usr/bin/env bash
# 2.3.10 cross-check: propagation verified end to end — one trace contains BOTH
# services, and the traceparent that leaves the frontend is the one the backend
# receives (same trace id, different span id).
# Usage: ./verify.sh [JAEGER_URL]   (default http://localhost:16686)
set -euo pipefail
J="${1:-http://localhost:16686}"
echo "Jaeger: $J"; echo

echo "== services Jaeger has seen =="
curl -sf "$J/api/services" | jq -r '.data[]' | sed 's/^/  /'
echo

echo "== newest service-a trace: which services does it span? =="
T=$(curl -sf "$J/api/traces?service=service-a&limit=1")
n=$(echo "$T" | jq -r '.data[0].spans | length // 0')
svcs=$(echo "$T" | jq -r '[.data[0].processes[].serviceName] | unique | join(", ")')
tid=$(echo "$T" | jq -r '.data[0].traceID // "none"')
echo "  trace_id: $tid"
echo "  spans:    $n"
echo "  services: $svcs"
echo

if echo "$svcs" | grep -q "service-a" && echo "$svcs" | grep -q "service-b"; then
  echo "PASS — one trace spans service-a AND service-b: traceparent propagated across the wire."
else
  echo "FAIL — a single trace does not contain both services (propagation broken)."
  exit 1
fi
