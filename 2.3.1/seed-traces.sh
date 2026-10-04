#!/usr/bin/env bash
# 2.3.1 — seed a few realistic sample traces straight into Jaeger over OTLP/HTTP,
# so the FIRST LOOK works even if the bankobs fleet isn't exporting yet.
#
# Each trace models one UPI payment across six services and exercises ALL FIVE span
# kinds, so the same traces illustrate 2.3.4 (span kinds) too:
#   SERVER   - a service handling an inbound request        (upi-service /pay, ...)
#   CLIENT   - an outbound call to another service          (upi -> payment-gateway)
#   PRODUCER - publishing a message onto a queue            (upi -> kafka payments.completed)
#   CONSUMER - taking a message off the queue to process it (notification-service)
#   INTERNAL - in-process work, no network                  (compute-fee)
# gateway-service -> upi-service fans out to account-service (-> ledger-service), then the
# SLOW payment-gateway hop, then publishes an event a notification-service consumes.
# One trace in the batch is an error (payment-gateway 500).
#
# Usage:  ./seed-traces.sh [OTLP_HTTP_URL] [COUNT]
#   OTLP_HTTP_URL  default http://localhost:4318   (use "-" with DRY=1 to just print JSON)
#   COUNT          default 6
# Deps: curl, jq, openssl.
set -uo pipefail
OTLP="${1:-http://localhost:4318}"
COUNT="${2:-6}"
DRY="${DRY:-0}"

# span blueprint, one line per span:
#   name | service | kind | parent | offset_ms | dur_ms | http
# kind: 1=INTERNAL 2=SERVER 3=CLIENT 4=PRODUCER 5=CONSUMER ; parent = index, -1 = root
BP=(
 "POST /api/upi/pay|gateway-service|2|-1|0|320|200"
 "POST upi-service/pay|gateway-service|3|0|5|310|200"
 "POST /pay|upi-service|2|1|12|300|200"
 "POST account-service/debit|upi-service|3|2|20|60|200"
 "POST /debit|account-service|2|3|24|50|200"
 "POST ledger-service/post|account-service|3|4|30|28|200"
 "POST /post|ledger-service|2|5|33|20|200"
 "POST payment-gateway/settle|upi-service|3|2|90|180|200"
 "POST /settle|payment-gateway|2|7|95|170|200"
 "compute-fee|upi-service|1|2|275|8|200"
 "publish payments.completed|upi-service|4|2|285|5|200"
 "process payments.completed|notification-service|5|10|292|22|200"
)
# indexes whose http status flips to 500 when a trace is marked an error (payment hop)
ERR_IDX=(7 8)

emit_trace() {  # $1 = base_ns   $2 = is_error(0|1)   $3 = jitter_ms
  local base_ns="$1" is_err="$2" jit="$3"
  local tid; tid=$(openssl rand -hex 16)
  local sids=(); local i
  for ((i=0; i<${#BP[@]}; i++)); do sids+=("$(openssl rand -hex 8)"); done

  for ((i=0; i<${#BP[@]}; i++)); do
    IFS='|' read -r name svc kind parent off dur http <<<"${BP[$i]}"
    # the slow payment hop drifts a little per trace so the list isn't identical
    if [ "$i" = "7" ] || [ "$i" = "8" ]; then dur=$((dur + jit)); fi
    local st_code=1    # STATUS_CODE_OK
    if [ "$is_err" = "1" ]; then
      for e in "${ERR_IDX[@]}"; do [ "$e" = "$i" ] && { http=500; st_code=2; }; done
    fi
    local start_ns=$(( base_ns + off*1000000 ))
    local end_ns=$(( start_ns + dur*1000000 ))
    local psid=""; [ "$parent" != "-1" ] && psid="${sids[$parent]}"

    # attributes fit the kind: messaging for PRODUCER/CONSUMER, a code.function for
    # INTERNAL, http.* for SERVER/CLIENT. Built with jq so the JSON is always valid.
    local attrs
    case "$kind" in
      4|5)
        local op="publish"; [ "$kind" = "5" ] && op="process"
        attrs=$(jq -nc --arg op "$op" '[
          {key:"messaging.system",          value:{stringValue:"kafka"}},
          {key:"messaging.destination.name",value:{stringValue:"payments.completed"}},
          {key:"messaging.operation",       value:{stringValue:$op}}]') ;;
      1)
        attrs=$(jq -nc --arg fn "$name" '[
          {key:"code.function",value:{stringValue:$fn}}]') ;;
      *)
        attrs=$(jq -nc --arg route "$name" --arg http "$http" '[
          {key:"http.request.method",      value:{stringValue:"POST"}},
          {key:"http.route",               value:{stringValue:$route}},
          {key:"http.response.status_code",value:{intValue:$http}}]') ;;
    esac

    # NB: avoid jq-keyword variable names ($end is the keyword `end`, rejected by jq <1.7).
    jq -nc \
      --arg svc "$svc" --arg spanname "$name" --arg tid "$tid" --arg sid "${sids[$i]}" \
      --arg psid "$psid" --argjson knd "$kind" \
      --arg t0 "$start_ns" --arg t1 "$end_ns" \
      --argjson attrs "$attrs" --argjson stc "$st_code" '
      { service: $svc, traceId: $tid, spanId: $sid, parentSpanId: $psid, name: $spanname,
        kind: $knd, startTimeUnixNano: $t0, endTimeUnixNano: $t1,
        attributes: $attrs,
        status: { code: $stc } }'
  done
}

# build the whole batch, then group spans by service into OTLP resourceSpans
now_s=$(date +%s)
batch=""
for ((t=0; t<COUNT; t++)); do
  base_ns=$(( (now_s - 50 + t*3) * 1000000000 ))   # recent + spread across ~20s
  is_err=0; [ "$t" = "$((COUNT-1))" ] && is_err=1   # last one errors
  batch+=$(emit_trace "$base_ns" "$is_err" $((t*4)))$'\n'   # small per-trace drift
done

# guard: if jq failed to build any spans, bail loudly instead of posting an empty batch
nspans=$(printf '%s' "$batch" | jq -s 'length' 2>/dev/null || echo 0)
if [ "${nspans:-0}" -lt 1 ]; then
  echo "seed ERROR: built 0 spans (jq failed above). Check: jq --version"; exit 1
fi

payload=$(printf '%s' "$batch" | jq -s '
  { resourceSpans: ( group_by(.service) | [ .[] | {
      resource:  { attributes: [ {key:"service.name", value:{stringValue: .[0].service}} ] },
      scopeSpans:[ { scope:{name:"obs-course.sample"}, spans: [ .[] | {
        traceId, spanId, parentSpanId, name, kind,
        startTimeUnixNano, endTimeUnixNano, attributes, status } ] } ]
    } ] ) }')

if [ "$DRY" = "1" ]; then
  echo "$payload"
  echo "# services: $(printf '%s' "$batch" | jq -s -r '[.[].service]|unique|join(", ")')" >&2
  echo "# spans: $(printf '%s' "$batch" | jq -s 'length')  traces: $COUNT  (last = error)" >&2
  exit 0
fi

code=$(curl -s -o /tmp/seed-resp.$$ -w '%{http_code}' -X POST "$OTLP/v1/traces" \
         -H 'Content-Type: application/json' --data-binary @- <<<"$payload")
rm -f /tmp/seed-resp.$$
if [ "$code" = "200" ]; then
  echo "seeded $COUNT sample traces ($nspans spans, 6 services, all 5 span kinds, last = error) -> $OTLP"
  echo ">>> make ui  ->  Service = upi-service  ->  Find Traces"
else
  echo "seed FAILED: OTLP endpoint returned HTTP $code at $OTLP/v1/traces"; exit 1
fi
