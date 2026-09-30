#!/usr/bin/env bash
# 2.2.13 multi-tenancy: with auth_enabled, the X-Scope-OrgID header isolates
# tenants. Push to team-a and team-b, then prove each tenant sees ONLY its own
# logs, and that a query with no tenant is rejected.
# Usage: ./verify.sh [LOKI_URL]   (default http://localhost:3100)
set -euo pipefail
LOKI="${1:-http://localhost:3100}"
echo "Loki: $LOKI"; echo

BASE=$(( $(date +%s) * 1000000000 )); SEQ=0
push() {   # $1 tenant   $2 line
  SEQ=$((SEQ+1)); ts=$((BASE + SEQ*1000000))
  curl -s -o /dev/null -H "X-Scope-OrgID: $1" -H 'Content-Type: application/json' \
    "$LOKI/loki/api/v1/push" \
    --data-binary "{\"streams\":[{\"stream\":{\"app\":\"tenantdemo\"},\"values\":[[\"$ts\",\"$2\"]]}]}"
}
for i in 1 2 3; do push team-a "order from team-a #$i"; done
for i in 1 2;   do push team-b "order from team-b #$i"; done
sleep 3

cnt() {    # $1 tenant   $2 optional line-filter
  q='sum(count_over_time({app="tenantdemo"}'
  [ -n "${2:-}" ] && q="$q |= \`$2\`"
  q="$q [10m]))"
  curl -s -G -H "X-Scope-OrgID: $1" "$LOKI/loki/api/v1/query" \
    --data-urlencode "query=$q" | jq -r '.data.result[0].value[1] // "0"'
}
a=$(cnt team-a);      b=$(cnt team-b)
a_b=$(cnt team-a team-b); b_a=$(cnt team-b team-a)
noorg=$(curl -s -o /dev/null -w '%{http_code}' -G "$LOKI/loki/api/v1/query" \
        --data-urlencode 'query={app="tenantdemo"}')

printf "  team-a sees (its own):   %s   (should be > 0)\n" "$a"
printf "  team-b sees (its own):   %s   (should be > 0)\n" "$b"
printf "  team-a sees team-b's:    %s   (should be 0 — ISOLATED)\n" "$a_b"
printf "  team-b sees team-a's:    %s   (should be 0 — ISOLATED)\n" "$b_a"
printf "  query with NO tenant:    HTTP %s   (should be 401 — auth required)\n" "$noorg"
echo
if [ "$a" -gt 0 ] && [ "$b" -gt 0 ] && [ "$a_b" -eq 0 ] && [ "$b_a" -eq 0 ] && [ "$noorg" != "200" ]; then
  echo "PASS — tenants are isolated by X-Scope-OrgID; an untenanted query is rejected."
else
  echo "FAIL — see values above."; exit 1
fi
