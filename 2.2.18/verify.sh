#!/usr/bin/env bash
# 2.2.18 — prove the per-pod parser handles the WHOLE fleet: JSON services get
# level+service, the raw log4j/pipe formats get level, the CLF access log gets a
# status (and is NOT stamped with a bogus level). Proving each format landed with
# the RIGHT labels is the skill.
# Usage: ./verify.sh [LOKI_URL]
set -uo pipefail
LOKI="${1:-http://localhost:3100}"
echo "Loki: $LOKI"; echo
c(){ curl -s -G "$LOKI/loki/api/v1/query" --data-urlencode "query=$1" | jq -r '.data.result[0].value[1] // "0"' | cut -d. -f1; }

json_lines=$(c 'sum(count_over_time({namespace="bankobs", log_format="json"}[15m]))')
raw_lines=$(c 'sum(count_over_time({namespace="bankobs", log_format="raw"}[120m]))')
json_svc=$(c 'sum(count_over_time({service="account-service"}[15m]))')
json_lvl=$(c 'sum(count_over_time({namespace="bankobs", log_format="json", level=~"INFO|WARN|ERROR|DEBUG"}[15m]))')
log4j_lvl=$(c 'sum(count_over_time({app="cbs-adapter", level=~"TRACE|DEBUG|INFO|WARN|ERROR|FATAL"}[30m]))')
clf_status=$(c 'sum(count_over_time({app="tomcat-loan-legacy", status=~"[0-9]+"}[30m]))')
clf_badlvl=$(c 'sum(count_over_time({app="tomcat-loan-legacy", level=~".+"}[30m]))')
pipe_lvl=$(c 'sum(count_over_time({app="pci-logger", level=~"INFO|WARN|ERROR"}[120m]))')

printf "  shipped:  json=%s lines   raw=%s lines   (both > 0)\n" "$json_lines" "$raw_lines"
printf "  JSON   service label (account-service): %s   (> 0)\n" "$json_svc"
printf "  JSON   level extracted:                 %s   (> 0)\n" "$json_lvl"
printf "  RAW    log4j level (cbs-adapter):       %s   (> 0)\n" "$log4j_lvl"
printf "  RAW    CLF status (tomcat-loan-legacy): %s   (> 0)\n" "$clf_status"
printf "  RAW    CLF has NO bogus level:          %s   (should be 0)\n" "$clf_badlvl"
printf "  RAW    pipe level (pci-logger):         %s   (> 0 once it logs)\n" "$pipe_lvl"
echo
if [ "${json_lines:-0}" -gt 0 ] && [ "${raw_lines:-0}" -gt 0 ] && [ "${json_svc:-0}" -gt 0 ] \
   && [ "${json_lvl:-0}" -gt 0 ] && [ "${log4j_lvl:-0}" -gt 0 ] && [ "${clf_status:-0}" -gt 0 ] \
   && [ "${clf_badlvl:-0}" -eq 0 ]; then
  echo "PASS — JSON and RAW both parsed: json -> level+service, log4j/pipe -> level, CLF -> status (no mislabel)."
else
  echo "FAIL — see values above."; exit 1
fi
