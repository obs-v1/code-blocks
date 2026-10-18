#!/usr/bin/env bash
# 2.4.2 check — the Collector is RECEIVING telemetry. Every Collector exposes its
# own metrics on :8888; `otelcol_receiver_accepted_*` counts what came in. If spans
# AND metric points are both > 0, the DaemonSet agent is up and the apps reached it.
# Usage: ./verify.sh [COLLECTOR_METRICS_URL]   (default http://localhost:8888)
set -euo pipefail
C="${1:-http://localhost:8888}"
echo "Collector self-telemetry: $C/metrics"; echo

M=$(curl -sf "$C/metrics")
spans=$(echo "$M"   | awk '/^otelcol_receiver_accepted_spans/        {s+=$2} END{printf "%d", s}')
points=$(echo "$M"  | awk '/^otelcol_receiver_accepted_metric_points/{s+=$2} END{printf "%d", s}')

printf "  spans accepted:         %s\n" "$spans"
printf "  metric points accepted: %s\n" "$points"
echo
if [ "${spans:-0}" -gt 0 ] && [ "${points:-0}" -gt 0 ]; then
  echo "PASS — the Collector (DaemonSet) is receiving traces AND metrics over OTLP."
else
  echo "FAIL — nothing received yet. Give it ~20s after deploy (metrics push every 5s), then retry."
  exit 1
fi
