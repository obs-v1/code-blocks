#!/usr/bin/env bash
# 2.2-1 cross-check: the SIDECAR -> Loki pipeline works, and the same two
# assertions as 2.2 hold — healthchecks DROPPED and the planted password never
# reached the store. Proving what is ABSENT is the skill.
# Usage: ./verify.sh [LOKI_URL]   (default http://localhost:3100)
set -euo pipefail
LOKI="${1:-http://localhost:3100}"
echo "Loki: $LOKI"; echo
q() { curl -sf -G "$LOKI/loki/api/v1/query" --data-urlencode "query=$1" | jq -r '.data.result[0].value[1] // "0"'; }

app=$(q    'sum(count_over_time({service="sidecar-app"}[10m]))')
health=$(q 'sum(count_over_time({service="sidecar-app"} |~ `healthz` [10m]))')
pw=$(q     'sum(count_over_time({service="sidecar-app"} |~ `Sup3rSecret` [10m]))')
red=$(q    'sum(count_over_time({service="sidecar-app"} |~ `REDACTED` [10m]))')

printf "  sidecar-app lines (10m):    %s   (should be > 0 — sidecar is shipping)\n" "$app"
printf "  healthz lines in store:     %s   (should be 0 — DROPPED)\n" "$health"
printf "  'Sup3rSecret' in store:     %s   (should be 0 — SCRUBBED)\n" "$pw"
printf "  'REDACTED' marker present:  %s   (should be > 0 — line kept, secret gone)\n" "$red"
echo
if [ "$app" -gt 0 ] && [ "$health" -eq 0 ] && [ "$pw" -eq 0 ] && [ "$red" -gt 0 ]; then
  echo "PASS — the sidecar ships this app's logs to Loki; healthchecks dropped and the password never reached the store."
else
  echo "FAIL — an assertion did not hold (see values above)."
  exit 1
fi
