#!/bin/sh
# RED scenario — drive Rate, Errors, Duration on the RED / Golden dashboards.
# Sends real API traffic to a bank service and injects a controllable share of
# 5xx errors by hitting the service's catch-all route.
#
# env: TARGET service, PORT, DURATION (s), CONCURRENCY (workers), ERROR_PCT (% 5xx)
: "${TARGET:=account-service}"; : "${PORT:=8001}"; : "${DURATION:=300}"
: "${CONCURRENCY:=20}"; : "${ERROR_PCT:=25}"
B="http://${TARGET}:${PORT}"
END=$(( $(date +%s) + DURATION ))
rnd() { od -An -N2 -tu2 /dev/urandom | tr -d ' '; }     # portable 0-65535 (busybox-safe)
echo "[RED] ${B}  duration=${DURATION}s  concurrency=${CONCURRENCY}  error_pct=${ERROR_PCT}%"

worker() {
  while [ "$(date +%s)" -lt "$END" ]; do
    ACCT=$(( $(rnd) % 200 + 1 ))
    if [ $(( $(rnd) % 100 )) -lt "$ERROR_PCT" ]; then
      # unknown path -> the service's catch-all -> 5xx (ERR_INTERNAL)
      curl -s -o /dev/null "${B}/api/v1/accounts/${ACCT}/boom"
    else
      case $(( $(rnd) % 3 )) in
        0) curl -s -o /dev/null "${B}/api/v1/accounts/${ACCT}/balance" ;;                # GET (DB read)
        1) curl -s -o /dev/null "${B}/api/v1/accounts/${ACCT}" ;;                         # GET (DB read)
        2) curl -s -o /dev/null -X POST "${B}/api/v1/accounts/${ACCT}/debit" \
             -H 'content-type: application/json' -d '{"amount":5}' ;;                     # POST (DB write)
      esac
    fi
  done
}

i=0; while [ "$i" -lt "$CONCURRENCY" ]; do worker & i=$(( i + 1 )); done
wait
echo "[RED] done"
