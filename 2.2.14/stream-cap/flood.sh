#!/usr/bin/env bash
# 2.2.14 — a runaway producer: push N UNIQUE streams (high cardinality, the
# 2.2.3 trap). Each push either succeeds (HTTP 204) or is rejected by a limit
# (HTTP 429). We count both, so you can see limits_config engage.
# Usage: ./flood.sh [LOKI_URL] [N] [TAG]
set -uo pipefail       # NOT -e: a single curl hiccup must not abort the whole flood
LOKI="${1:-http://localhost:3100}"; N="${2:-200}"; TAG="${3:-x}"
ok=0; rej=0; other=0
base=$(( $(date +%s) * 1000000000 ))
# Loki accepts pushes a few seconds AFTER the pod reports ready — wait for a
# probe push to return 204 before counting, or every push logs a false failure.
for _w in $(seq 1 30); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 4 -H 'Content-Type: application/json' \
      "$LOKI/loki/api/v1/push" \
      --data-binary "{\"streams\":[{\"stream\":{\"app\":\"_probe\"},\"values\":[[\"$base\",\"ready\"]]}]}" 2>/dev/null || echo 000)" = "204" ] && break
  sleep 2
done
for i in $(seq 1 "$N"); do
  ts=$((base + i*1000000))
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H 'Content-Type: application/json' \
    "$LOKI/loki/api/v1/push" \
    --data-binary "{\"streams\":[{\"stream\":{\"app\":\"flood\",\"id\":\"$TAG-$i\"},\"values\":[[\"$ts\",\"line $i\"]]}]}" || echo 000)
  case "$code" in
    204|200) ok=$((ok+1)) ;;
    429)     rej=$((rej+1)) ;;
    *)       other=$((other+1)) ;;
  esac
done
echo "    pushed $N unique streams  ->  accepted(204)=$ok   rejected(429)=$rej   other=$other"
if [ "$rej" -gt 0 ]; then
  echo "    a limit is holding the line: $rej streams were refused, Loki protected."
else
  echo "    every stream was accepted — nothing capped the cardinality."
fi
