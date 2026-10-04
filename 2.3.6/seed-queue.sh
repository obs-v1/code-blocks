#!/usr/bin/env bash
# 2.3.6 — DEMO: trace context through a message queue (Kafka), seeded into Jaeger.
#
# One event — order-service publishes `orders.placed`; notification-service consumes it
# ~0.8s later and emails the customer — rendered two ways so students can compare:
#
#   CONNECTED  the producer INJECTS traceparent into the message headers; the consumer
#              EXTRACTS it. Both sides land in ONE trace, with the queue wait showing as a
#              GAP between the PRODUCER span and the CONSUMER span.
#
#   BROKEN     the hop skips inject/extract. The message carries no context, so the
#              consumer starts a BRAND NEW trace. Result: two disjoint traces, no error.
#
# Every span is tagged demo.scenario=connected|broken and carries messaging.* attributes
# plus the propagation story, so the "why" is visible in each span's Tags.
#
# Usage:  ./seed-queue.sh [OTLP_HTTP_URL]     (DRY=1 ./seed-queue.sh -  to print JSON)
# Deps: curl, jq, openssl.  Assumes Jaeger (from code-blocks/2.3.1) is already running.
set -uo pipefail
OTLP="${1:-http://localhost:4318}"
DRY="${DRY:-0}"

now_s=$(date +%s)
BASE_NS=$(( (now_s - 40) * 1000000000 ))   # recent, within Jaeger's default 1h lookback

# attrs "k=v" ... -> OTLP attribute array JSON (string values)
attrs() {
  local arr="[]" kv k v
  for kv in "$@"; do k="${kv%%=*}"; v="${kv#*=}"
    arr=$(jq -c --arg k "$k" --arg v "$v" '. + [{key:$k, value:{stringValue:$v}}]' <<<"$arr"); done
  printf '%s' "$arr"
}
# span SVC KIND TID SID PARENT NAME OFFSET_MS DUR_MS ATTRS   (kind 1=INTERNAL 2=SERVER 3=CLIENT 4=PRODUCER 5=CONSUMER)
span() {
  local svc="$1" knd="$2" tid="$3" sid="$4" psid="$5" nm="$6" off="$7" dur="$8" at="$9"
  local t0=$(( BASE_NS + off*1000000 )) t1; t1=$(( t0 + dur*1000000 ))
  jq -nc --arg svc "$svc" --argjson knd "$knd" --arg tid "$tid" --arg sid "$sid" \
         --arg psid "$psid" --arg nm "$nm" --arg t0 "$t0" --arg t1 "$t1" --argjson at "$at" '
    { service:$svc, traceId:$tid, spanId:$sid, parentSpanId:$psid, name:$nm,
      kind:$knd, startTimeUnixNano:$t0, endTimeUnixNano:$t1, attributes:$at, status:{code:1} }'
}

MSYS="messaging.system=kafka"; TOPIC="messaging.destination.name=orders.placed"
OFFSET="messaging.kafka.message.offset=42"

# ───────────────────── CONNECTED: inject + extract -> one trace ─────────────────────
T_OK="$(openssl rand -hex 16)"
o_root="$(openssl rand -hex 8)"; o_prod="$(openssl rand -hex 8)"
n_cons="$(openssl rand -hex 8)"; n_cli="$(openssl rand -hex 8)"; e_srv="$(openssl rand -hex 8)"

connected="$(
  span order-service 2 "$T_OK" "$o_root" "" "POST /checkout" 0 60 \
    "$(attrs demo.scenario=connected http.route=/checkout)"
  span order-service 4 "$T_OK" "$o_prod" "$o_root" "orders.placed send" 52 4 \
    "$(attrs demo.scenario=connected "$MSYS" "$TOPIC" messaging.operation=publish "$OFFSET" \
            "propagation=traceparent INJECTED into message headers")"
  # consumer runs ~0.8s later; parent = the producer span (context was extracted)
  span notification-service 5 "$T_OK" "$n_cons" "$o_prod" "orders.placed process" 900 45 \
    "$(attrs demo.scenario=connected "$MSYS" "$TOPIC" messaging.operation=process "$OFFSET" \
            "propagation=traceparent EXTRACTED from message headers" "queue.wait_ms=844")"
  span notification-service 3 "$T_OK" "$n_cli" "$n_cons" "POST email-service/send" 912 28 \
    "$(attrs demo.scenario=connected peer.service=email-service)"
  span email-service 2 "$T_OK" "$e_srv" "$n_cli" "POST /send" 916 22 \
    "$(attrs demo.scenario=connected http.route=/send)"
)"

# ───────────────────── BROKEN: inject/extract skipped -> two traces ─────────────────
T_PROD="$(openssl rand -hex 16)"      # producer side
T_CONS="$(openssl rand -hex 16)"      # consumer starts fresh
bo_root="$(openssl rand -hex 8)"; bo_prod="$(openssl rand -hex 8)"
bn_cons="$(openssl rand -hex 8)"; bn_cli="$(openssl rand -hex 8)"; be_srv="$(openssl rand -hex 8)"

broken="$(
  span order-service 2 "$T_PROD" "$bo_root" "" "POST /checkout" 0 60 \
    "$(attrs demo.scenario=broken http.route=/checkout)"
  span order-service 4 "$T_PROD" "$bo_prod" "$bo_root" "orders.placed send" 52 4 \
    "$(attrs demo.scenario=broken "$MSYS" "$TOPIC" messaging.operation=publish "$OFFSET" \
            "propagation=context NOT injected (the bug)")"
  # no traceparent in the message -> consumer is a NEW root, disconnected
  span notification-service 5 "$T_CONS" "$bn_cons" "" "orders.placed process" 900 45 \
    "$(attrs demo.scenario=broken "$MSYS" "$TOPIC" messaging.operation=process "$OFFSET" \
            "propagation=no traceparent in message - new trace started" \
            "expected.trace_id=$T_PROD" "actual.trace_id=$T_CONS" \
            "trace.status=BROKEN: async boundary not propagated, no error logged")"
  span notification-service 3 "$T_CONS" "$bn_cli" "$bn_cons" "POST email-service/send" 912 28 \
    "$(attrs demo.scenario=broken peer.service=email-service)"
  span email-service 2 "$T_CONS" "$be_srv" "$bn_cli" "POST /send" 916 22 \
    "$(attrs demo.scenario=broken http.route=/send)"
)"

batch="$connected"$'\n'"$broken"

nspans=$(printf '%s' "$batch" | jq -s 'length' 2>/dev/null || echo 0)
if [ "${nspans:-0}" -lt 1 ]; then
  echo "seed ERROR: built 0 spans (jq failed above). Check: jq --version"; exit 1
fi

payload=$(printf '%s' "$batch" | jq -s '
  { resourceSpans: ( group_by(.service) | [ .[] | {
      resource:  { attributes: [ {key:"service.name", value:{stringValue: .[0].service}} ] },
      scopeSpans:[ { scope:{name:"obs-course.queue-demo"}, spans: [ .[] | {
        traceId, spanId, parentSpanId, name, kind,
        startTimeUnixNano, endTimeUnixNano, attributes, status } ] } ]
    } ] ) }')

if [ "$DRY" = "1" ]; then
  echo "$payload"
  echo "# spans: $nspans   connected=$T_OK   broken(producer=$T_PROD, consumer=$T_CONS)" >&2
  exit 0
fi

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$OTLP/v1/traces" \
         -H 'Content-Type: application/json' --data-binary @- <<<"$payload")
if [ "$code" = "200" ]; then
  echo "seeded the queue demo ($nspans spans) -> $OTLP"
  echo "  CONNECTED: one trace $T_OK  (producer -> queue gap -> consumer, both sides joined)"
  echo "  BROKEN   : producer trace $T_PROD  +  orphan consumer trace $T_CONS  (two traces!)"
  echo ">>> make ui   then filter Tags:  demo.scenario=connected   vs   demo.scenario=broken"
else
  echo "seed FAILED: OTLP endpoint returned HTTP $code at $OTLP/v1/traces"; exit 1
fi
