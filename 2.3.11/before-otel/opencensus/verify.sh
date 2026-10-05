#!/usr/bin/env bash
# before-otel / OpenCensus — prove propagation: one trace in the legacy Jaeger spans BOTH
# oc-frontend and oc-backend.
# Usage: ./verify.sh [JAEGER_URL]   (default http://localhost:16686)
set -uo pipefail
J="${1:-http://localhost:16686}"
echo "Jaeger: $J"; echo

echo "== services Jaeger has seen =="
curl -sf "$J/api/services" | jq -r '.data[]' | sed 's/^/  /'
echo

T=$(curl -sf "$J/api/traces?service=oc-frontend&limit=1" || echo '{}')
n=$(echo "$T" | jq -r '.data[0].spans | length // 0')
svcs=$(echo "$T" | jq -r '[.data[0].processes[].serviceName] | unique | join(", ")')
tid=$(echo "$T" | jq -r '.data[0].traceID // "none"')
echo "== newest oc-frontend trace =="
echo "  trace_id: $tid"
echo "  spans:    $n"
echo "  services: $svcs"
echo
if echo "$svcs" | grep -q "oc-frontend" && echo "$svcs" | grep -q "oc-backend"; then
  echo "PASS — one trace spans oc-frontend AND oc-backend: OpenCensus propagated the context."
else
  echo "FAIL — a single trace does not contain both services (propagation broken, or spans not yet flushed)."
  exit 1
fi
