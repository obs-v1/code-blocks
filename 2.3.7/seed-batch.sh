#!/usr/bin/env bash
# 2.3.7 — DEMO: batch processing and span LINKS, seeded into Jaeger.
#
# Parent-child assumes one cause per span. A batch consumer breaks that: one span
# processes N messages drawn from N DIFFERENT traces. Which one is the parent? None,
# and all. Span LINKS express that many-to-one relationship the tree cannot.
#
# This seeds FOUR independent source traces (each an order that published to a queue),
# then ONE batch-processor span that consumes all four and carries a span LINK to each
# origin. In Jaeger the batch span shows "References" (FOLLOWS_FROM) out to the four
# separate source traces — one span, four source traces.
#
# Usage:  ./seed-batch.sh [OTLP_HTTP_URL]     (DRY=1 ./seed-batch.sh -  to print JSON)
# Deps: curl, jq, openssl.  Assumes Jaeger (from code-blocks/2.3.1) is already running.
set -uo pipefail
OTLP="${1:-http://localhost:4318}"
DRY="${DRY:-0}"
now_s=$(date +%s)
BASE_NS=0   # set per-trace below

attrs() {  # "k=v" ... -> OTLP attribute array JSON
  local arr="[]" kv k v
  for kv in "$@"; do k="${kv%%=*}"; v="${kv#*=}"
    arr=$(jq -c --arg k "$k" --arg v "$v" '. + [{key:$k, value:{stringValue:$v}}]' <<<"$arr"); done
  printf '%s' "$arr"
}
linkobj() {  # TRACEID SPANID [k=v ...] -> one OTLP span-link object
  local t="$1" s="$2"; shift 2
  jq -nc --arg t "$t" --arg s "$s" --argjson a "$(attrs "$@")" '{traceId:$t, spanId:$s, attributes:$a}'
}
# span SVC KIND TID SID PARENT NAME OFF DUR ATTRS [LINKS]  (kind 1=INTERNAL 2=SERVER 3=CLIENT 4=PRODUCER 5=CONSUMER)
span() {
  local svc="$1" knd="$2" tid="$3" sid="$4" psid="$5" nm="$6" off="$7" dur="$8" at="$9" lnk="${10:-[]}"
  local t0=$(( BASE_NS + off*1000000 )) t1; t1=$(( t0 + dur*1000000 ))
  jq -nc --arg svc "$svc" --argjson knd "$knd" --arg tid "$tid" --arg sid "$sid" \
         --arg psid "$psid" --arg nm "$nm" --arg t0 "$t0" --arg t1 "$t1" \
         --argjson at "$at" --argjson lnk "$lnk" '
    { service:$svc, traceId:$tid, spanId:$sid, parentSpanId:$psid, name:$nm, kind:$knd,
      startTimeUnixNano:$t0, endTimeUnixNano:$t1, attributes:$at, status:{code:1}, links:$lnk }'
}

# ── four independent source traces: each order published a message to the queue ──
STIDS=(); SPRODS=(); src=""
for i in 0 1 2 3; do
  BASE_NS=$(( (now_s - 70 + i*8) * 1000000000 ))   # each happened at a different time
  tid=$(openssl rand -hex 16); sr=$(openssl rand -hex 8); sp=$(openssl rand -hex 8)
  STIDS+=("$tid"); SPRODS+=("$sp")
  mid="order-$((1001+i))"
  src+=$(span order-service 2 "$tid" "$sr" "" "POST /checkout" 0 50 \
           "$(attrs demo.scenario=batch "order.id=$mid")")$'\n'
  src+=$(span order-service 4 "$tid" "$sp" "$sr" "orders.placed send" 40 4 \
           "$(attrs demo.scenario=batch messaging.system=kafka messaging.destination.name=orders.placed \
                   messaging.operation=publish "messaging.message.id=$mid")")$'\n'
done

# ── the batch trace: one consumer span LINKS to all four source producer spans ──
BASE_NS=$(( (now_s - 8) * 1000000000 ))
tb=$(openssl rand -hex 16); bc=$(openssl rand -hex 8); bl=$(openssl rand -hex 8); ls=$(openssl rand -hex 8)
LNK=$( for i in 0 1 2 3; do linkobj "${STIDS[$i]}" "${SPRODS[$i]}" "messaging.message.id=order-$((1001+i))"; done | jq -s '.' )

batch=""
batch+=$(span batch-processor 5 "$tb" "$bc" "" "settle-batch process [4 msgs]" 0 120 \
           "$(attrs demo.scenario=batch messaging.system=kafka messaging.destination.name=orders.placed \
                   messaging.operation=process messaging.batch.message_count=4 \
                   note="one span, FOUR source traces - see References/Links")" \
           "$LNK")$'\n'
batch+=$(span batch-processor 3 "$tb" "$bl" "$bc" "POST ledger/post-batch" 10 95 \
           "$(attrs demo.scenario=batch peer.service=ledger-service)")$'\n'
batch+=$(span ledger-service 2 "$tb" "$ls" "$bl" "POST /post-batch" 14 85 \
           "$(attrs demo.scenario=batch http.route=/post-batch)")$'\n'

all="$src$batch"
nspans=$(printf '%s' "$all" | jq -s 'length' 2>/dev/null || echo 0)
if [ "${nspans:-0}" -lt 1 ]; then echo "seed ERROR: built 0 spans (jq failed). Check: jq --version"; exit 1; fi

payload=$(printf '%s' "$all" | jq -s '
  { resourceSpans: ( group_by(.service) | [ .[] | {
      resource:  { attributes: [ {key:"service.name", value:{stringValue: .[0].service}} ] },
      scopeSpans:[ { scope:{name:"obs-course.batch-demo"}, spans: [ .[] | {
        traceId, spanId, parentSpanId, name, kind,
        startTimeUnixNano, endTimeUnixNano, attributes, status, links } ] } ]
    } ] ) }')

if [ "$DRY" = "1" ]; then
  echo "$payload"
  echo "# spans: $nspans   source traces: ${STIDS[*]:0:1}...(4)   batch trace: $tb   links on batch span: 4" >&2
  exit 0
fi

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$OTLP/v1/traces" \
         -H 'Content-Type: application/json' --data-binary @- <<<"$payload")
if [ "$code" = "200" ]; then
  echo "seeded the batch/links demo ($nspans spans) -> $OTLP"
  echo "  4 source traces (order-service), each with a PRODUCER span"
  echo "  1 batch trace $tb : batch-processor span LINKS to all four source spans"
  echo ">>> make ui  -> open the batch trace -> the batch span's References/Links point to 4 OTHER traces"
else
  echo "seed FAILED: OTLP endpoint returned HTTP $code at $OTLP/v1/traces"; exit 1
fi
