#!/usr/bin/env bash
# 2.3.15 — CAPSTONE: the full payment, traced across the fleet, seeded into Jaeger.
#
# One flagship UPI payment fanning through the whole bank — api-gateway -> auth -> upi,
# which fans to fraud, account (-> ledger), and the SLOW payment-gateway (-> bank-network),
# then publishes to Kafka. And the deliberate Kafka BREAK: the consumer starts a fresh,
# parentless trace because the producer never injected traceparent into the message.
#
# Covers three of the four capstone moves in Jaeger:
#   1. See the payment whole   -> the big waterfall (8 services)
#   2. Script the hunt         -> `make hunt` finds the slowest leaf via the trace API
#   4. Diagnose the Kafka break -> the orphan consumer trace
# (Move 3, pivot a trace_id into Loki, needs the live stack — see the README.)
#
# Usage:  ./seed-payment.sh [OTLP_HTTP_URL]     (DRY=1 ./seed-payment.sh -  to print JSON)
# Deps: curl, jq, openssl.  Assumes Jaeger (from code-blocks/2.3.1) is already running.
set -uo pipefail
OTLP="${1:-http://localhost:4318}"
DRY="${DRY:-0}"
now_s=$(date +%s)
BASE_NS=0

attrs() {  # "k=v" ... -> OTLP attribute array JSON
  local arr="[]" kv k v
  for kv in "$@"; do k="${kv%%=*}"; v="${kv#*=}"
    arr=$(jq -c --arg k "$k" --arg v "$v" '. + [{key:$k, value:{stringValue:$v}}]' <<<"$arr"); done
  printf '%s' "$arr"
}
# span SVC KIND TID SID PARENT NAME OFF DUR ATTRS  (1=INTERNAL 2=SERVER 3=CLIENT 4=PRODUCER 5=CONSUMER)
span() {
  local svc="$1" knd="$2" tid="$3" sid="$4" psid="$5" nm="$6" off="$7" dur="$8" at="$9"
  local t0=$(( BASE_NS + off*1000000 )) t1; t1=$(( t0 + dur*1000000 ))
  jq -nc --arg svc "$svc" --argjson knd "$knd" --arg tid "$tid" --arg sid "$sid" \
         --arg psid "$psid" --arg nm "$nm" --arg t0 "$t0" --arg t1 "$t1" --argjson at "$at" '
    { service:$svc, traceId:$tid, spanId:$sid, parentSpanId:$psid, name:$nm,
      kind:$knd, startTimeUnixNano:$t0, endTimeUnixNano:$t1, attributes:$at, status:{code:1} }'
}

# ─────────────────── the full payment journey (one big trace) ───────────────────
BASE_NS=$(( (now_s - 30) * 1000000000 ))
T=$(openssl rand -hex 16)
g=$(openssl rand -hex 8)
ac=$(openssl rand -hex 8); as=$(openssl rand -hex 8)                 # auth client/server
uc=$(openssl rand -hex 8); us=$(openssl rand -hex 8)                 # upi client/server
fc=$(openssl rand -hex 8); fs=$(openssl rand -hex 8); fi=$(openssl rand -hex 8)  # fraud + ml
dc=$(openssl rand -hex 8); ds=$(openssl rand -hex 8)                 # account debit
lc=$(openssl rand -hex 8); ls=$(openssl rand -hex 8)                 # ledger
sc=$(openssl rand -hex 8); ss=$(openssl rand -hex 8)                 # payment-gateway settle
nc=$(openssl rand -hex 8); ns=$(openssl rand -hex 8)                 # bank-network authorize
pp=$(openssl rand -hex 8)                                            # kafka producer

journey="$(
  span api-gateway 2 "$T" "$g" "" "POST /api/upi/pay" 0 650 \
    "$(attrs demo.scenario=capstone demo.trace=payment-journey http.route=/api/upi/pay payment.amount=12000 "analysis=the whole payment, one picture")"
  span api-gateway 3 "$T" "$ac" "$g" "GET auth-service/validate" 15 40 "$(attrs demo.scenario=capstone)"
  span auth-service 2 "$T" "$as" "$ac" "GET /validate" 18 34 "$(attrs demo.scenario=capstone)"
  span api-gateway 3 "$T" "$uc" "$g" "POST upi-service/pay" 60 580 "$(attrs demo.scenario=capstone)"
  span upi-service 2 "$T" "$us" "$uc" "POST /pay" 64 574 "$(attrs demo.scenario=capstone)"
  span upi-service 3 "$T" "$fc" "$us" "POST fraud-service/score" 70 90 "$(attrs demo.scenario=capstone)"
  span fraud-service 2 "$T" "$fs" "$fc" "POST /score" 74 84 "$(attrs demo.scenario=capstone)"
  span fraud-service 1 "$T" "$fi" "$fs" "ml-model-infer" 80 70 "$(attrs demo.scenario=capstone)"
  span upi-service 3 "$T" "$dc" "$us" "POST account-service/debit" 165 110 "$(attrs demo.scenario=capstone)"
  span account-service 2 "$T" "$ds" "$dc" "POST /debit" 169 104 "$(attrs demo.scenario=capstone)"
  span account-service 3 "$T" "$lc" "$ds" "POST ledger-service/post" 180 60 "$(attrs demo.scenario=capstone)"
  span ledger-service 2 "$T" "$ls" "$lc" "POST /post" 184 52 "$(attrs demo.scenario=capstone)"
  span upi-service 3 "$T" "$sc" "$us" "POST payment-gateway/settle" 285 340 \
    "$(attrs demo.scenario=capstone "analysis=longest branch - the external settlement")"
  span payment-gateway 2 "$T" "$ss" "$sc" "POST /settle" 289 334 "$(attrs demo.scenario=capstone)"
  span payment-gateway 3 "$T" "$nc" "$ss" "POST bank-network/authorize" 300 318 "$(attrs demo.scenario=capstone)"
  span bank-network 2 "$T" "$ns" "$nc" "POST /authorize" 304 310 \
    "$(attrs demo.scenario=capstone "analysis=SLOWEST LEAF - external bank authorize (310ms) - the real cost; what 'make hunt' finds")"
  span upi-service 4 "$T" "$pp" "$us" "payment.completed send" 632 4 \
    "$(attrs demo.scenario=capstone messaging.system=kafka messaging.destination.name=payment.completed messaging.operation=publish \
            "note=published to Kafka - but traceparent was NOT injected (the deliberate break)")"
)"

# ─────────────────── the Kafka break: a fresh, parentless consumer trace ───────────────────
BASE_NS=$(( (now_s - 28) * 1000000000 ))
TC=$(openssl rand -hex 16)
kc=$(openssl rand -hex 8); kcc=$(openssl rand -hex 8); kss=$(openssl rand -hex 8)
breakt="$(
  span notification-service 5 "$TC" "$kc" "" "payment.completed process" 0 50 \
    "$(attrs demo.scenario=capstone demo.trace=kafka-break messaging.system=kafka messaging.destination.name=payment.completed messaging.operation=process \
            "expected.trace_id=$T" "actual.trace_id=$TC" "trace.status=BROKEN: new parentless trace - producer did not inject traceparent (2.3.6)")"
  span notification-service 3 "$TC" "$kcc" "$kc" "POST sms-service/send" 10 30 "$(attrs demo.scenario=capstone)"
  span sms-service 2 "$TC" "$kss" "$kcc" "POST /send" 14 24 "$(attrs demo.scenario=capstone)"
)"

all="$journey"$'\n'"$breakt"
nspans=$(printf '%s' "$all" | jq -s 'length' 2>/dev/null || echo 0)
if [ "${nspans:-0}" -lt 1 ]; then echo "seed ERROR: built 0 spans (jq failed). Check: jq --version"; exit 1; fi

payload=$(printf '%s' "$all" | jq -s '
  { resourceSpans: ( group_by(.service) | [ .[] | {
      resource:  { attributes: [ {key:"service.name", value:{stringValue: .[0].service}} ] },
      scopeSpans:[ { scope:{name:"obs-course.capstone"}, spans: [ .[] | {
        traceId, spanId, parentSpanId, name, kind,
        startTimeUnixNano, endTimeUnixNano, attributes, status } ] } ]
    } ] ) }')

if [ "$DRY" = "1" ]; then
  echo "$payload"
  echo "# spans: $nspans   payment trace: $T (8 services)   kafka-break orphan: $TC" >&2
  exit 0
fi

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$OTLP/v1/traces" \
         -H 'Content-Type: application/json' --data-binary @- <<<"$payload")
if [ "$code" = "200" ]; then
  echo "seeded the capstone ($nspans spans) -> $OTLP"
  echo "  PAYMENT JOURNEY  $T : one trace across 8 services (api-gateway -> ... -> bank-network)"
  echo "  KAFKA BREAK      $TC : orphan consumer trace (traceparent not injected)"
  echo ">>> make ui   open the payment trace (Service=api-gateway); make hunt finds the slowest span"
else
  echo "seed FAILED: OTLP endpoint returned HTTP $code at $OTLP/v1/traces"; exit 1
fi
