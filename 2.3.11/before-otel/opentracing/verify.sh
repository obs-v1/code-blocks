#!/usr/bin/env bash
# before-otel / OpenTracing — prove propagation worked with the pre-OTel library:
# one trace in the legacy Jaeger spans BOTH ot-frontend and ot-backend.
# Usage: ./verify.sh [JAEGER_URL]   (default http://localhost:16686)
set -uo pipefail
J="${1:-http://localhost:16686}"
echo "Jaeger: $J"; echo

echo "== services Jaeger has seen =="
curl -sf "$J/api/services" | jq -r '.data[]' | sed 's/^/  /'
echo

T=$(curl -sf "$J/api/traces?service=ot-frontend&limit=1" || echo '{}')
n=$(echo "$T" | jq -r '.data[0].spans | length // 0')
svcs=$(echo "$T" | jq -r '[.data[0].processes[].serviceName] | unique | join(", ")')
tid=$(echo "$T" | jq -r '.data[0].traceID // "none"')
echo "== newest ot-frontend trace =="
echo "  trace_id: $tid"
echo "  spans:    $n"
echo "  services: $svcs"
echo
if echo "$svcs" | grep -q "ot-frontend" && echo "$svcs" | grep -q "ot-backend"; then
  echo "PASS — one trace spans ot-frontend AND ot-backend: OpenTracing/jaeger-client propagated the context."
else
  echo "FAIL — a single trace does not contain both services (propagation broken, or spans not yet flushed)."
  exit 1
fi
