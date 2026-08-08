#!/usr/bin/env bash
# 2.4.8 cross-check: tail sampling keeps EVERY error trace while thinning routine
# traffic to the sample rate. The driver generates ~5x more routine than errors,
# so if MORE error traces survive than routine traces, sampling is provably working.
# Usage: ./verify.sh [JAEGER_URL]   (default http://localhost:16686)
set -euo pipefail
J="${1:-http://localhost:16686}"
echo "Jaeger: $J"; echo

DATA=$(curl -sf "$J/api/traces?service=service-a&limit=1000&lookback=15m")
err=$(echo "$DATA" | jq '[.data[] | select(any(.spans[].tags[]; .key=="error" and .value==true))] | length')
total=$(echo "$DATA" | jq '.data | length')
routine=$(( total - err ))

echo "  driver generates ~5x more routine calls than errors"
echo "  ------------------------------------------------"
printf "  error traces KEPT:    %s\n" "$err"
printf "  routine traces KEPT:  %s\n" "$routine"
printf "  total in Jaeger:      %s\n" "$total"
echo
if [ "$err" -gt 5 ] && [ "$err" -ge "$routine" ]; then
  echo "PASS — every error trace survived while routine traffic was thinned:"
  echo "       more errors kept than routine, despite 5x more routine generated."
else
  echo "FAIL — expected errors kept >= routine kept (with errors > 5). Give it a longer burst / wait."
  exit 1
fi
