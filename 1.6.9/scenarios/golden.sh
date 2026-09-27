#!/bin/sh
# Golden Signals scenario — move all four at once on the Golden dashboard:
#   Traffic    — steady request load
#   Errors     — a share of injected 5xx (catch-all route)
#   Latency    — rises as the service saturates under the concurrency
#   Saturation — CPU / threads / pool climb from the concurrency
# It's the RED mix run hot enough to also saturate the service.
#
# env: TARGET service, PORT, DURATION (s), CONCURRENCY (workers), ERROR_PCT (% 5xx)
: "${TARGET:=account-service}"; : "${PORT:=8001}"; : "${DURATION:=300}"
: "${CONCURRENCY:=60}"; : "${ERROR_PCT:=12}"
B="http://${TARGET}:${PORT}"
END=$(( $(date +%s) + DURATION ))
rnd() { od -An -N2 -tu2 /dev/urandom | tr -d ' '; }
echo "[GOLDEN] ${B}  duration=${DURATION}s  concurrency=${CONCURRENCY}  error_pct=${ERROR_PCT}%"

worker() {
  while [ "$(date +%s)" -lt "$END" ]; do
    ACCT=$(( $(rnd) % 200 + 1 ))
    if [ $(( $(rnd) % 100 )) -lt "$ERROR_PCT" ]; then
      curl -s -o /dev/null "${B}/api/v1/accounts/${ACCT}/boom"                            # 5xx
    else
      case $(( $(rnd) % 4 )) in
        0) curl -s -o /dev/null "${B}/api/v1/accounts/${ACCT}/balance" ;;
        1) curl -s -o /dev/null "${B}/api/v1/accounts/${ACCT}" ;;
        2) curl -s -o /dev/null -X POST "${B}/api/v1/accounts/${ACCT}/debit" \
             -H 'content-type: application/json' -d '{"amount":2}' ;;
        3) curl -s -o /dev/null -X POST "${B}/api/v1/accounts/${ACCT}/credit" \
             -H 'content-type: application/json' -d '{"amount":2}' ;;
      esac
    fi
  done
}

i=0; while [ "$i" -lt "$CONCURRENCY" ]; do worker & i=$(( i + 1 )); done
wait
echo "[GOLDEN] done"
