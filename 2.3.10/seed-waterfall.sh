#!/usr/bin/env bash
# 2.3.10 — DEMO: waterfall analysis, seeded into Jaeger. One deliberately-SLOW checkout
# trace that exhibits every reading move the section teaches, plus two fast baselines so
# the slow one stands out in the duration scatter. Key spans carry an `analysis` tag.
#
# The moves, all in the slow trace:
#   1. SEQUENTIAL bars that could be parallel  -> cart / pricing / inventory run in a line
#   2. One LONG bar under a short parent        -> the payment chain (the culprit region)
#   3. SLOW-SELF vs WAITS-ON-CHILDREN           -> bank-gateway (slow in its own code, a leaf)
#                                                  vs payment-service (slow only via its child)
#   4. NEGATIVE SPACE (a gap)                   -> 120ms before the first child = uninstrumented
#                                                  wait (connection pool / queue)
#
# Usage:  ./seed-waterfall.sh [OTLP_HTTP_URL]     (DRY=1 ./seed-waterfall.sh -  to print JSON)
# Deps: curl, jq, openssl.  Assumes Jaeger (from code-blocks/2.3.1) is already running.
set -uo pipefail
OTLP="${1:-http://localhost:4318}"
DRY="${DRY:-0}"
now_s=$(date +%s)
BASE_NS=0   # set per-trace

attrs() {  # "k=v" ... -> OTLP attribute array JSON
  local arr="[]" kv k v
  for kv in "$@"; do k="${kv%%=*}"; v="${kv#*=}"
    arr=$(jq -c --arg k "$k" --arg v "$v" '. + [{key:$k, value:{stringValue:$v}}]' <<<"$arr"); done
  printf '%s' "$arr"
}
# span SVC KIND TID SID PARENT NAME OFF DUR ATTRS   (kind 1=INTERNAL 2=SERVER 3=CLIENT)
span() {
  local svc="$1" knd="$2" tid="$3" sid="$4" psid="$5" nm="$6" off="$7" dur="$8" at="$9"
  local t0=$(( BASE_NS + off*1000000 )) t1; t1=$(( t0 + dur*1000000 ))
  jq -nc --arg svc "$svc" --argjson knd "$knd" --arg tid "$tid" --arg sid "$sid" \
         --arg psid "$psid" --arg nm "$nm" --arg t0 "$t0" --arg t1 "$t1" --argjson at "$at" '
    { service:$svc, traceId:$tid, spanId:$sid, parentSpanId:$psid, name:$nm,
      kind:$knd, startTimeUnixNano:$t0, endTimeUnixNano:$t1, attributes:$at, status:{code:1} }'
}

# ─────────────────────── the SLOW trace (the teaching artifact) ───────────────────────
BASE_NS=$(( (now_s - 30) * 1000000000 ))
T=$(openssl rand -hex 16)
g=$(openssl rand -hex 8)        # api-gateway root
ca=$(openssl rand -hex 8); cas=$(openssl rand -hex 8)   # cart client/server
pr=$(openssl rand -hex 8); prs=$(openssl rand -hex 8)   # pricing
iv=$(openssl rand -hex 8); ivs=$(openssl rand -hex 8)   # inventory
pc=$(openssl rand -hex 8); ps=$(openssl rand -hex 8)    # payment client/server
bc=$(openssl rand -hex 8); bs=$(openssl rand -hex 8)    # payment->bank client / bank server
fr=$(openssl rand -hex 8)                                # fraud-score internal

slow="$(
  span api-gateway 2 "$T" "$g" "" "GET /api/checkout" 0 900 \
    "$(attrs demo.scenario=waterfall demo.trace=slow http.route=/api/checkout \
            "analysis=TOTAL 900ms - slow. 120ms gap before the first child = uninstrumented wait (connection pool / queue)")"
  span api-gateway 3 "$T" "$ca" "$g" "GET cart-service/items" 120 40 \
    "$(attrs demo.scenario=waterfall "analysis=sequential A - could run in parallel")"
  span cart-service 2 "$T" "$cas" "$ca" "GET /items" 124 32 "$(attrs demo.scenario=waterfall)"
  span api-gateway 3 "$T" "$pr" "$g" "GET pricing-service/quote" 165 50 \
    "$(attrs demo.scenario=waterfall "analysis=sequential B - could run in parallel")"
  span pricing-service 2 "$T" "$prs" "$pr" "GET /quote" 169 42 "$(attrs demo.scenario=waterfall)"
  span api-gateway 3 "$T" "$iv" "$g" "GET inventory-service/check" 220 45 \
    "$(attrs demo.scenario=waterfall "analysis=sequential C - A+B+C take ~145ms in a line, ~50ms in parallel")"
  span inventory-service 2 "$T" "$ivs" "$iv" "GET /check" 224 37 "$(attrs demo.scenario=waterfall)"
  span api-gateway 3 "$T" "$pc" "$g" "POST payment-service/charge" 270 560 \
    "$(attrs demo.scenario=waterfall "analysis=THE LONG BAR - start your read here (560 of the 900ms)")"
  span payment-service 2 "$T" "$ps" "$pc" "POST /charge" 274 552 \
    "$(attrs demo.scenario=waterfall "analysis=slow because of its CHILD (bank-gateway), not its own code - do NOT page this team")"
  span payment-service 3 "$T" "$bc" "$ps" "POST bank-gateway/authorize" 300 505 \
    "$(attrs demo.scenario=waterfall "analysis=26ms gap (274-300) before this call = more uninstrumented work")"
  span bank-gateway 2 "$T" "$bs" "$bc" "POST /authorize" 304 492 \
    "$(attrs demo.scenario=waterfall "analysis=SLOW IN ITS OWN CODE - a leaf, no children. THE root cause; page the bank-integration team")"
  span payment-service 1 "$T" "$fr" "$ps" "fraud-score" 806 15 "$(attrs demo.scenario=waterfall)"
)"

# ─────────────────────── two fast baselines (for the scatter) ───────────────────────
baselines=""
for i in 0 1; do
  BASE_NS=$(( (now_s - 50 + i*6) * 1000000000 ))
  bt=$(openssl rand -hex 16); bg=$(openssl rand -hex 8); bpc=$(openssl rand -hex 8); bps=$(openssl rand -hex 8)
  d=$(( 110 + i*12 ))
  baselines+=$(span api-gateway 2 "$bt" "$bg" "" "GET /api/checkout" 0 $d \
                 "$(attrs demo.scenario=waterfall demo.trace=baseline http.route=/api/checkout)")$'\n'
  baselines+=$(span api-gateway 3 "$bt" "$bpc" "$bg" "POST payment-service/charge" 20 $((d-40)) \
                 "$(attrs demo.scenario=waterfall)")$'\n'
  baselines+=$(span payment-service 2 "$bt" "$bps" "$bpc" "POST /charge" 24 $((d-48)) \
                 "$(attrs demo.scenario=waterfall)")$'\n'
done

all="$slow"$'\n'"$baselines"
nspans=$(printf '%s' "$all" | jq -s 'length' 2>/dev/null || echo 0)
if [ "${nspans:-0}" -lt 1 ]; then echo "seed ERROR: built 0 spans (jq failed). Check: jq --version"; exit 1; fi

payload=$(printf '%s' "$all" | jq -s '
  { resourceSpans: ( group_by(.service) | [ .[] | {
      resource:  { attributes: [ {key:"service.name", value:{stringValue: .[0].service}} ] },
      scopeSpans:[ { scope:{name:"obs-course.waterfall-demo"}, spans: [ .[] | {
        traceId, spanId, parentSpanId, name, kind,
        startTimeUnixNano, endTimeUnixNano, attributes, status } ] } ]
    } ] ) }')

if [ "$DRY" = "1" ]; then
  echo "$payload"
  echo "# spans: $nspans   slow trace: $T (900ms, 6 services)   + 2 fast baselines (~115ms)" >&2
  exit 0
fi

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$OTLP/v1/traces" \
         -H 'Content-Type: application/json' --data-binary @- <<<"$payload")
if [ "$code" = "200" ]; then
  echo "seeded the waterfall demo ($nspans spans) -> $OTLP"
  echo "  SLOW trace $T : 900ms checkout across 6 services (the one to analyse)"
  echo "  + 2 fast baselines (~115ms) so the slow one stands out in the duration scatter"
  echo ">>> make ui  -> Service=api-gateway -> Find Traces -> click the 900ms outlier; read the 'analysis' tags"
else
  echo "seed FAILED: OTLP endpoint returned HTTP $code at $OTLP/v1/traces"; exit 1
fi
