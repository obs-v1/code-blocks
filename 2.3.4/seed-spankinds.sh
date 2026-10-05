#!/usr/bin/env bash
# 2.3.4 — DEMO: the five span kinds, seeded into Jaeger as ONE compact payment trace.
#
# Every kind in a single waterfall, each span tagged with what it means:
#   SERVER    upi-service handling POST /api/upi/pay        (a request arrived, I handled it)
#   CLIENT    upi-service calling account-service           (I called out and waited)
#   SERVER    account-service handling /debit               (the callee's own work)
#   INTERNAL  upi-service compute-fee                        (in-process work, no network)
#   PRODUCER  upi-service publishing to Kafka                (put a message on a queue)
#   CONSUMER  notification-service processing the message    (took it off the queue)
#
# The teaching detail: the CLIENT bar (120ms) is longer than the SERVER bar nested inside
# it (105ms). That 15ms gap is pure NETWORK time — a free latency diagnosis.
#
# Usage:  ./seed-spankinds.sh [OTLP_HTTP_URL]     (DRY=1 ./seed-spankinds.sh -  to print JSON)
# Deps: curl, jq, openssl.  Assumes Jaeger (from code-blocks/2.3.1) is already running.
set -uo pipefail
OTLP="${1:-http://localhost:4318}"
DRY="${DRY:-0}"
now_s=$(date +%s)
BASE_NS=$(( (now_s - 20) * 1000000000 ))

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

T=$(openssl rand -hex 16)
r=$(openssl rand -hex 8)     # upi SERVER (root)
c=$(openssl rand -hex 8)     # upi CLIENT -> account
a=$(openssl rand -hex 8)     # account SERVER
i=$(openssl rand -hex 8)     # upi INTERNAL
p=$(openssl rand -hex 8)     # upi PRODUCER
k=$(openssl rand -hex 8)     # notification CONSUMER

all="$(
  span upi-service 2 "$T" "$r" "" "POST /api/upi/pay" 0 200 \
    "$(attrs demo.scenario=span-kinds http.route=/api/upi/pay "note=SERVER - a request arrived and I handled it")"
  span upi-service 3 "$T" "$c" "$r" "POST account-service/debit" 20 120 \
    "$(attrs demo.scenario=span-kinds peer.service=account-service "note=CLIENT - I called account-service and waited" \
            "analysis=this CLIENT bar is 120ms; the SERVER bar inside is 105ms -> the 15ms gap is pure NETWORK time (free latency diagnosis)")"
  span account-service 2 "$T" "$a" "$c" "POST /debit" 28 105 \
    "$(attrs demo.scenario=span-kinds http.route=/debit "note=SERVER - the callee's own work, 105ms")"
  span upi-service 1 "$T" "$i" "$r" "compute-fee" 145 15 \
    "$(attrs demo.scenario=span-kinds code.function=compute-fee "note=INTERNAL - in-process work, no network")"
  span upi-service 4 "$T" "$p" "$r" "payment.completed send" 165 5 \
    "$(attrs demo.scenario=span-kinds messaging.system=kafka messaging.destination.name=payment.completed messaging.operation=publish \
            "note=PRODUCER - put a message on the Kafka queue")"
  span notification-service 5 "$T" "$k" "$p" "payment.completed process" 172 23 \
    "$(attrs demo.scenario=span-kinds messaging.system=kafka messaging.destination.name=payment.completed messaging.operation=process \
            "note=CONSUMER - took the message off the queue to process it")"
)"

nspans=$(printf '%s' "$all" | jq -s 'length' 2>/dev/null || echo 0)
if [ "${nspans:-0}" -lt 1 ]; then echo "seed ERROR: built 0 spans (jq failed). Check: jq --version"; exit 1; fi

payload=$(printf '%s' "$all" | jq -s '
  { resourceSpans: ( group_by(.service) | [ .[] | {
      resource:  { attributes: [ {key:"service.name", value:{stringValue: .[0].service}} ] },
      scopeSpans:[ { scope:{name:"obs-course.span-kinds"}, spans: [ .[] | {
        traceId, spanId, parentSpanId, name, kind,
        startTimeUnixNano, endTimeUnixNano, attributes, status } ] } ]
    } ] ) }')

if [ "$DRY" = "1" ]; then
  echo "$payload"
  echo "# spans: $nspans   trace: $T   kinds: SERVER, CLIENT, SERVER, INTERNAL, PRODUCER, CONSUMER" >&2
  exit 0
fi

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$OTLP/v1/traces" \
         -H 'Content-Type: application/json' --data-binary @- <<<"$payload")
if [ "$code" = "200" ]; then
  echo "seeded the span-kinds demo ($nspans spans) -> $OTLP"
  echo "  one trace $T : all five span kinds in a single payment waterfall"
  echo ">>> make ui  -> Service=upi-service -> open the trace -> click each span -> Tags -> span.kind"
else
  echo "seed FAILED: OTLP endpoint returned HTTP $code at $OTLP/v1/traces"; exit 1
fi
