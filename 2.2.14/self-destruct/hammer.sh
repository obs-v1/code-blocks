#!/usr/bin/env bash
# 2.2.14 self-destruct — hammer Loki with high-cardinality + volume. Each round
# is one push carrying STREAMS brand-new streams, each with a ~LINEKB padded
# line. Unprotected + a small memory ceiling, this fills the ingester until it
# OOMs (pushes start timing out / 5xx). Protected, the pushes get 429 and Loki
# stays up.
# Usage: ./hammer.sh [LOKI_URL] [ROUNDS] [STREAMS] [LINEKB] [PARALLEL]
set -uo pipefail
LOKI="${1:-http://localhost:3100}"
ROUNDS="${2:-150}"
STREAMS="${3:-500}"
LINEKB="${4:-2}"
PAR="${5:-8}"                      # concurrent pushes — pile streams on faster
pad=$(head -c $((LINEKB*1024)) /dev/zero | tr '\0' 'x')
base=$(( $(date +%s) * 1000000000 ))

# One round = build a big multi-stream payload with awk (fast; bash string
# concatenation of thousands of streams is O(n^2) and far too slow), pipe it to
# curl via stdin (a payload this size overflows the command-line arg limit), and
# print the HTTP code.
round() {
  local r="$1" ts=$(( base + "$1" * 100000000 ))
  awk -v r="$r" -v n="$STREAMS" -v ts="$ts" -v pad="$pad" 'BEGIN{
    printf "{\"streams\":[";
    for(i=1;i<=n;i++){ if(i>1)printf ",";
      printf "{\"stream\":{\"app\":\"hammer\",\"round\":\"%s\",\"id\":\"%s-%s\"},\"values\":[[\"%d\",\"%s\"]]}", r, r, i, ts+i, pad }
    printf "]}" }' \
  | curl -s -o /dev/null -w '%{http_code}\n' --max-time 20 \
      -H 'Content-Type: application/json' "$LOKI/loki/api/v1/push" --data-binary @- || echo 000
}
export -f round; export LOKI STREAMS base pad

echo "hammering: $ROUNDS rounds x $STREAMS new streams x ${LINEKB}KB lines, $PAR in parallel ..."
codes=$(seq 1 "$ROUNDS" | xargs -P "$PAR" -I{} bash -c 'round "$@"' _ {})
ok=$(grep -c '^20[04]$' <<<"$codes"); rej=$(grep -c '^429$' <<<"$codes")
dead=$(grep -vcE '^(20[04]|429)$' <<<"$codes")
echo ""
echo "rounds: accepted(204)=$ok   rejected(429)=$rej   failed(5xx/timeout)=$dead"
if [ "$dead" -gt 0 ]; then
  echo "=> Loki stopped answering under the flood (see the pod state next)."
elif [ "$rej" -gt 0 ]; then
  echo "=> limits held: $rej pushes refused with 429, Loki never fell over."
else
  echo "=> everything accepted — raise ROUNDS/STREAMS or lower the memory limit to push it over."
fi
