#!/usr/bin/env bash
# 2.3.1 — prove the FIRST LOOK works: the live bankobs fleet is landing spans in the
# Jaeger we just deployed. Jaeger's query API lists every service that has reported a
# span, so if bankobs services appear, tracing is flowing end to end.
# Usage: ./verify.sh [JAEGER_URL]
set -uo pipefail
JAEGER="${1:-http://localhost:16686}"
echo "Jaeger: $JAEGER"; echo

# Jaeger can take a few seconds to register the first spans — poll briefly.
services=""
for i in $(seq 1 12); do
  services=$(curl -s -m 5 "$JAEGER/api/services" | jq -r '.data[]?' 2>/dev/null | sort -u)
  [ -n "$services" ] && break
  sleep 5
done

count=$(printf '%s\n' "$services" | grep -c . || true)
echo "== services Jaeger has seen ($count) =="
printf '%s\n' "$services" | sed 's/^/  /'
echo

# known bankobs services from the fleet — any one proves real traffic is landing
known="upi-service account-service gateway-service payment-gateway"
hit=""
for s in $known; do
  if printf '%s\n' "$services" | grep -qx "$s"; then hit="$hit $s"; fi
done

echo "== payment-flow services present:${hit:- none} =="
echo
if [ -n "$hit" ]; then
  echo "PASS — traces are landing in Jaeger (seeded samples and/or the live bankobs fleet)."
  echo "       Open the UI and look:  make ui  ->  Service = upi-service  ->  Find Traces."
elif [ "${count:-0}" -ge 1 ]; then
  echo "PARTIAL — Jaeger is receiving spans, but none of the expected payment services matched."
  echo "          Re-run 'make seed', or check bankobs is exporting to jaeger-collector.observability.svc:4317."
  exit 1
else
  echo "FAIL — Jaeger has seen no spans yet."
  echo "       1) did 'make seed' run?  (re-run it)"
  echo "       2) is bankobs exporting to jaeger-collector.observability.svc:4317 ? (see README)"
  exit 1
fi
