#!/usr/bin/env bash
# 2.3.4 — prove the span-kinds demo landed in Jaeger. Jaeger records the OTLP span kind as a
# `span.kind` tag for SERVER/CLIENT/PRODUCER/CONSUMER; INTERNAL is the implicit default and
# carries NO span.kind tag, so we check the four explicit kinds + the full 6-span trace.
# Usage: ./verify.sh [JAEGER_URL]
set -uo pipefail
JAEGER="${1:-http://localhost:16686}"
end_us=$(( $(date +%s) * 1000000 )); start_us=$(( end_us - 3600*1000000 ))
echo "Jaeger: $JAEGER"; echo

data=$(curl -s -m 10 "$JAEGER/api/traces?service=upi-service&start=$start_us&end=$end_us&limit=50")
# the span-kinds trace: the one that spans all three demo services
tr=$(printf '%s' "$data" | jq -c '[ .data[]
  | select(([.processes[].serviceName] | index("account-service")) and ([.processes[].serviceName] | index("notification-service"))) ][0]')

[ "$tr" = "null" ] || [ -z "$tr" ] && { echo "FAIL — span-kinds trace not found. Did 'make' run? (re-run it)"; exit 1; }

kinds=$(printf '%s' "$tr" | jq -r '[.spans[].tags[] | select(.key=="span.kind") | .value] | unique | sort | join(",")')
nspans=$(printf '%s' "$tr" | jq '.spans | length')

echo "span.kind tags present: ${kinds:-<none>}   (expect client,consumer,producer,server)"
echo "spans in the trace:     $nspans           (expect 6 — the 6th is INTERNAL, no span.kind tag)"
echo
have() { printf '%s' "$kinds" | tr ',' '\n' | grep -qx "$1"; }
if have client && have server && have producer && have consumer && [ "${nspans:-0}" -ge 6 ]; then
  echo "PASS — SERVER, CLIENT, PRODUCER, CONSUMER all present as span.kind; INTERNAL is the 6th span."
  echo "       Open the trace and click each span -> Tags -> span.kind (and the 'note' tag)."
else
  echo "FAIL — expected the four explicit kinds + a 6-span trace. Re-run 'make'."
  exit 1
fi
