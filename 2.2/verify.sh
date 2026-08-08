#!/usr/bin/env bash
# 2.2.10 lab cross-check: the Promtail -> Loki pipeline works, AND the two
# assertions most courses never make — healthchecks were DROPPED and a planted
# password never reached the store. Proving what is ABSENT is the skill.
# Usage: ./verify.sh [LOKI_URL]   (default http://localhost:3100)
set -euo pipefail
LOKI="${1:-http://localhost:3100}"
echo "Loki: $LOKI"; echo
q() { curl -sf -G "$LOKI/loki/api/v1/query" --data-urlencode "query=$1" | jq -r '.data.result[0].value[1] // "0"'; }

bankobs=$(q 'sum(count_over_time({namespace="bankobs"}[10m]))')
leaky=$(q   'sum(count_over_time({service="leaky-app"}[10m]))')
health=$(q  'sum(count_over_time({service="leaky-app"} |~ `healthz` [10m]))')
pw=$(q      'sum(count_over_time({service="leaky-app"} |~ `Sup3rSecret` [10m]))')
red=$(q     'sum(count_over_time({service="leaky-app"} |~ `REDACTED` [10m]))')

printf "  bankobs fleet lines (10m):  %s   (should be > 0)\n" "$bankobs"
printf "  leaky-app lines (10m):      %s   (should be > 0)\n" "$leaky"
printf "  healthz lines in store:     %s   (should be 0 — DROPPED)\n" "$health"
printf "  'Sup3rSecret' in store:     %s   (should be 0 — SCRUBBED)\n" "$pw"
printf "  'REDACTED' marker present:  %s   (should be > 0 — line kept, secret gone)\n" "$red"
echo
if [ "$bankobs" -gt 0 ] && [ "$leaky" -gt 0 ] && [ "$health" -eq 0 ] && [ "$pw" -eq 0 ] && [ "$red" -gt 0 ]; then
  echo "PASS — logs aggregate to Loki; healthchecks dropped and the password never reached the store."
else
  echo "FAIL — an assertion did not hold (see values above)."
  exit 1
fi
