#!/usr/bin/env bash
# PASS/FAIL for 3.3.10 — proves all four signals landed AND the pivots are wired.
# Every backend is queried from INSIDE the cluster (curl in the loadgen pod), so
# the result does not depend on which kind host-ports happen to be mapped.
set -uo pipefail
NS="${NS:-monitoring}"
pass=0; fail=0
ok(){ echo "  ✓ $1"; pass=$((pass+1)); }
no(){ echo "  ✗ $1"; fail=$((fail+1)); }
ex(){ kubectl -n "$NS" exec deploy/loadgen -- curl -s --max-time 10 "$@" 2>/dev/null; }

echo "== 3.3.10 four-signal verification =="
echo "  (giving telemetry a moment to flow…)"; sleep 5
S=$(date +%s -d '-15 minutes'); E=$(date +%s)

# 1) METRICS — app RED histograms reached Prometheus
M=$(ex -G http://prometheus:9090/api/v1/query --data-urlencode 'query=count({__name__=~"http_server.*"})')
echo "$M" | grep -q '"value"' && ok "metrics: app http_server series in Prometheus" \
                               || no "metrics: no http_server series in Prometheus"

# 2) METRIC→TRACE — exemplars on the histogram carry a trace_id
EX=$(ex -G http://prometheus:9090/api/v1/query_exemplars \
      --data-urlencode 'query=http_server_duration_milliseconds_bucket' \
      --data-urlencode "start=$S" --data-urlencode "end=$E")
echo "$EX" | grep -q 'trace_id' && ok "metric→trace: exemplars carry a trace_id" \
                                 || no "metric→trace: no exemplars with a trace_id"

# 3) TRACES — both services present, and one trace spans gateway→worker
SVC=$(ex http://jaeger:16686/api/services)
{ echo "$SVC" | grep -q '"gateway"' && echo "$SVC" | grep -q '"worker"'; } \
  && ok "traces: gateway AND worker in Jaeger" || no "traces: gateway/worker missing in Jaeger"
TR=$(ex -G http://jaeger:16686/api/traces --data-urlencode 'service=gateway' --data-urlencode 'limit=10')
echo "$TR" | grep -q '"worker"' && ok "traces: a gateway trace reaches the worker hop" \
                                 || no "traces: no gateway→worker trace found"

# 4) LOGS + LOG→TRACE + LOG→CODE — worker logs in Loki, carrying trace_id and the caller field
LG=$(ex -G http://loki:3100/loki/api/v1/query_range \
      --data-urlencode 'query={service_name="worker"}' \
      --data-urlencode "start=${S}000000000" --data-urlencode "end=${E}000000000")
echo "$LG" | grep -q '"service_name":"worker"' && ok "logs: worker logs in Loki" \
                                                || no "logs: no worker logs in Loki"
echo "$LG" | grep -q '"trace_id"'       && ok "log→trace: log lines carry trace_id" \
                                          || no "log→trace: no trace_id on log lines"
echo "$LG" | grep -q '"code_file_path"' && ok "log→code: log lines carry the caller field (file:line)" \
                                          || no "log→code: no code_file_path on log lines"

# 5) PROFILES — Pyroscope has profiles for the worker
PY=$(ex -X POST http://pyroscope:4040/querier.v1.QuerierService/LabelValues \
      -H 'content-type: application/json' -d '{"name":"service_name"}')
echo "$PY" | grep -q '"worker"' && ok "profiles: worker CPU profiles in Pyroscope" \
                                 || no "profiles: no worker profiles in Pyroscope"

# 6) TRACE→CODE — the worker span carries the pyroscope.profile.id join tag
WT=$(ex -G http://jaeger:16686/api/traces --data-urlencode 'service=worker' --data-urlencode 'limit=1')
echo "$WT" | grep -q 'pyroscope.profile.id' && ok "trace→code: span carries pyroscope.profile.id (→ flame graph)" \
                                             || no "trace→code: no pyroscope.profile.id tag on span"

echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ] && echo "RESULT: PASS" || { echo "RESULT: FAIL"; exit 1; }
