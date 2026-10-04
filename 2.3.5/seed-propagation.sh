#!/usr/bin/env bash
# 2.3.5 — DEMO: what a propagation-format mismatch does to a trace, seeded into Jaeger.
#
# One logical request (checkout -> order-service), rendered two ways so students can
# compare them side by side in the Jaeger UI:
#
#   BROKEN  checkout-service speaks B3 (X-B3-* headers); order-service reads only W3C
#           traceparent. order-service can't read the B3 header, so it starts a BRAND
#           NEW trace. Result: TWO disjoint traces for one request — and no error anywhere.
#
#   FIXED   order-service is configured with a COMPOSITE propagator (tracecontext + b3).
#           It extracts the B3 context, and both services land in ONE trace.
#
# Every span is tagged demo.scenario=broken|fixed, and carries the actual header values
# so the "why" is visible in the span's Tags.
#
# Usage:  ./seed-propagation.sh [OTLP_HTTP_URL]     (DRY=1 ./seed-propagation.sh -  to print JSON)
# Deps: curl, jq, openssl.  Assumes Jaeger (from code-blocks/2.3.1) is already running.
set -uo pipefail
OTLP="${1:-http://localhost:4318}"
DRY="${DRY:-0}"

now_s=$(date +%s)
BASE_NS=$(( (now_s - 40) * 1000000000 ))   # recent, within Jaeger's default 1h lookback

# attrs "k=v" "k=v" ... -> OTLP attribute array JSON (all string values)
attrs() {
  local arr="[]" kv k v
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    arr=$(jq -c --arg k "$k" --arg v "$v" '. + [{key:$k, value:{stringValue:$v}}]' <<<"$arr")
  done
  printf '%s' "$arr"
}

# span SVC KIND TID SID PARENT NAME OFFSET_MS DUR_MS ATTRS_JSON   (kind: 1=INTERNAL 2=SERVER 3=CLIENT)
span() {
  local svc="$1" knd="$2" tid="$3" sid="$4" psid="$5" nm="$6" off="$7" dur="$8" at="$9"
  local t0=$(( BASE_NS + off*1000000 )) t1
  t1=$(( t0 + dur*1000000 ))
  jq -nc --arg svc "$svc" --argjson knd "$knd" --arg tid "$tid" --arg sid "$sid" \
         --arg psid "$psid" --arg nm "$nm" --arg t0 "$t0" --arg t1 "$t1" --argjson at "$at" '
    { service:$svc, traceId:$tid, spanId:$sid, parentSpanId:$psid, name:$nm,
      kind:$knd, startTimeUnixNano:$t0, endTimeUnixNano:$t1, attributes:$at, status:{code:1} }'
}

# ───────────────────────── BROKEN: two disjoint traces ─────────────────────────
T_CHECKOUT="80f198ee56343ba864fe8b2a57d3eff7"      # checkout's trace-id (B3)
T_ORPHAN="$(openssl rand -hex 16)"                 # order-service starts a NEW one
ck_root="$(openssl rand -hex 8)"; ck_cli="$(openssl rand -hex 8)"
ord_root="$(openssl rand -hex 8)"; ord_int="$(openssl rand -hex 8)"
B3="$T_CHECKOUT-$ck_cli-1"                          # the X-B3 header checkout sends

broken="$(
  span checkout-service 2 "$T_CHECKOUT" "$ck_root" "" "POST /checkout [speaks B3 / legacy]" 0 120 \
    "$(attrs demo.scenario=broken http.route=/checkout "propagation.format=B3 (Zipkin, legacy)" note="emits X-B3-* headers only")"
  span checkout-service 3 "$T_CHECKOUT" "$ck_cli" "$ck_root" "call order-service [sends B3 headers]" 12 95 \
    "$(attrs demo.scenario=broken peer.service=order-service "propagation.format=B3 (Zipkin, legacy)" "outgoing.b3.header=$B3" note="context sent as B3 (X-B3-* headers)")"
  # order-service reads only W3C traceparent -> cannot see the B3 header -> NEW trace, no parent
  span order-service 2 "$T_ORPHAN" "$ord_root" "" "POST /place [B3 IGNORED -> new trace]" 30 80 \
    "$(attrs demo.scenario=broken "propagation.format=W3C traceparent only - cannot read B3" "incoming.b3.header=$B3" \
            "extracted.parent=none (B3 header ignored)" "expected.trace_id=$T_CHECKOUT" \
            "actual.trace_id=$T_ORPHAN" "trace.status=BROKEN: new trace started, no error logged")"
  span order-service 1 "$T_ORPHAN" "$ord_int" "$ord_root" "reserve-stock" 42 22 \
    "$(attrs demo.scenario=broken)"
)"

# ───────────────────────── FIXED: one joined trace ─────────────────────────────
T_FIX="$(openssl rand -hex 16)"
fk_root="$(openssl rand -hex 8)"; fk_cli="$(openssl rand -hex 8)"
fo_root="$(openssl rand -hex 8)"; fo_int="$(openssl rand -hex 8)"
B3F="$T_FIX-$fk_cli-1"

fixed="$(
  span checkout-service 2 "$T_FIX" "$fk_root" "" "POST /checkout [speaks B3 / legacy]" 0 125 \
    "$(attrs demo.scenario=fixed http.route=/checkout "propagation.format=B3 (Zipkin, legacy)")"
  span checkout-service 3 "$T_FIX" "$fk_cli" "$fk_root" "call order-service [sends B3 headers]" 12 100 \
    "$(attrs demo.scenario=fixed peer.service=order-service "propagation.format=B3 (Zipkin, legacy)" "outgoing.b3.header=$B3F")"
  # composite propagator extracts the B3 context -> SAME trace, parented under the caller
  span order-service 2 "$T_FIX" "$fo_root" "$fk_cli" "POST /place [B3 extracted via composite]" 22 85 \
    "$(attrs demo.scenario=fixed "propagation.format=composite (W3C + B3)" "incoming.b3.header=$B3F" \
            "extracted.parent=$fk_cli" "trace.status=OK: one trace across both services")"
  span order-service 1 "$T_FIX" "$fo_int" "$fo_root" "reserve-stock" 40 25 \
    "$(attrs demo.scenario=fixed)"
)"

batch="$broken"$'\n'"$fixed"

nspans=$(printf '%s' "$batch" | jq -s 'length' 2>/dev/null || echo 0)
if [ "${nspans:-0}" -lt 1 ]; then
  echo "seed ERROR: built 0 spans (jq failed above). Check: jq --version"; exit 1
fi

payload=$(printf '%s' "$batch" | jq -s '
  { resourceSpans: ( group_by(.service) | [ .[] | {
      resource:  { attributes: [ {key:"service.name", value:{stringValue: .[0].service}} ] },
      scopeSpans:[ { scope:{name:"obs-course.propagation-demo"}, spans: [ .[] | {
        traceId, spanId, parentSpanId, name, kind,
        startTimeUnixNano, endTimeUnixNano, attributes, status } ] } ]
    } ] ) }')

if [ "$DRY" = "1" ]; then
  echo "$payload"
  echo "# spans: $nspans   traces: broken(checkout=$T_CHECKOUT, orphan=$T_ORPHAN)  fixed($T_FIX)" >&2
  exit 0
fi

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$OTLP/v1/traces" \
         -H 'Content-Type: application/json' --data-binary @- <<<"$payload")
if [ "$code" = "200" ]; then
  echo "seeded the propagation demo ($nspans spans) -> $OTLP"
  echo "  BROKEN: checkout trace $T_CHECKOUT  +  orphan order-service trace $T_ORPHAN  (two traces!)"
  echo "  FIXED : one trace $T_FIX  spanning checkout-service AND order-service"
  echo ">>> make ui   then in Jaeger filter by tag:  demo.scenario=broken   vs   demo.scenario=fixed"
else
  echo "seed FAILED: OTLP endpoint returned HTTP $code at $OTLP/v1/traces"; exit 1
fi
