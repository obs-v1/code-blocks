#!/bin/sh
# USE scenario — drive Utilization / Saturation / Errors on the USE dashboard.
# Hammers DB-touching endpoints (balance read, debit/credit writes) at high
# concurrency so the app's CPU, Tomcat thread pool and HikariCP connection pool
# all saturate — active connections peg at max and 'pending' (threads waiting
# for a connection) climbs. That queueing is what USE's saturation panels show.
#
# env: TARGET service, PORT, DURATION (s), CONCURRENCY (workers)
: "${TARGET:=account-service}"; : "${PORT:=8001}"; : "${DURATION:=300}"
: "${CONCURRENCY:=120}"
B="http://${TARGET}:${PORT}"
END=$(( $(date +%s) + DURATION ))
rnd() { od -An -N2 -tu2 /dev/urandom | tr -d ' '; }
echo "[USE] saturating ${B}  duration=${DURATION}s  concurrency=${CONCURRENCY}"

worker() {
  while [ "$(date +%s)" -lt "$END" ]; do
    ACCT=$(( $(rnd) % 200 + 1 ))
    case $(( $(rnd) % 3 )) in
      0) curl -s -o /dev/null "${B}/api/v1/accounts/${ACCT}/balance" ;;                   # DB read
      1) curl -s -o /dev/null -X POST "${B}/api/v1/accounts/${ACCT}/debit" \
           -H 'content-type: application/json' -d '{"amount":1}' ;;                       # DB write
      2) curl -s -o /dev/null -X POST "${B}/api/v1/accounts/${ACCT}/credit" \
           -H 'content-type: application/json' -d '{"amount":1}' ;;                       # DB write
    esac
  done
}

i=0; while [ "$i" -lt "$CONCURRENCY" ]; do worker & i=$(( i + 1 )); done
wait
echo "[USE] done"
