#!/usr/bin/env bash
# 2.2.14 self-destruct — hammer Loki with high-cardinality + volume. Each round
# is one push carrying STREAMS brand-new streams, each with a ~LINEKB padded
# line. Unprotected + a small memory ceiling, this fills the ingester until it
# OOMs (pushes start timing out / 5xx). Protected, the pushes get 429 and Loki
# stays up.
# Usage: ./hammer.sh [LOKI_URL] [ROUNDS] [STREAMS] [LINEKB]
set -uo pipefail
LOKI="${1:-http://localhost:3100}"
ROUNDS="${2:-80}"
STREAMS="${3:-500}"
LINEKB="${4:-2}"
pad=$(head -c $((LINEKB*1024)) /dev/zero | tr '\0' 'x')
base=$(( $(date +%s) * 1000000000 ))

echo "hammering: $ROUNDS rounds x $STREAMS new streams x ${LINEKB}KB lines ..."
ok=0; rej=0; dead=0
for r in $(seq 1 "$ROUNDS"); do
  ts=$((base + r*100000000))
  payload='{"streams":['
  for i in $(seq 1 "$STREAMS"); do
    [ "$i" -gt 1 ] && payload+=','
    payload+="{\"stream\":{\"app\":\"hammer\",\"round\":\"$r\",\"id\":\"$r-$i\"},\"values\":[[\"$((ts+i))\",\"$pad\"]]}"
  done
  payload+=']}'
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
    -H 'Content-Type: application/json' "$LOKI/loki/api/v1/push" --data-binary "$payload" || echo "000")
  case "$code" in
    204|200) ok=$((ok+1)) ;;
    429)     rej=$((rej+1)) ;;
    *)       dead=$((dead+1)); echo "  round $r: HTTP ${code} — Loki struggling / down" ;;
  esac
done
echo ""
echo "rounds: accepted(204)=$ok   rejected(429)=$rej   failed(5xx/timeout)=$dead"
if [ "$dead" -gt 0 ]; then
  echo "=> Loki stopped answering under the flood (see the pod state next)."
elif [ "$rej" -gt 0 ]; then
  echo "=> limits held: $rej rounds refused with 429, Loki never fell over."
else
  echo "=> everything accepted — increase ROUNDS/STREAMS or lower the memory limit to push it over."
fi
