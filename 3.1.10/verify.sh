#!/usr/bin/env bash
# PASS/FAIL check for the SLO lab. Run AFTER `make fault` (give it ~2–3 min to burn).
# Queries Prometheus/Alertmanager on the kind host ports (9090 / 9093).
set -uo pipefail
NS="${NS:-monitoring}"
PROM="${PROM:-http://localhost:9090}"
pass=0; fail=0
ok(){ echo "  ✓ $1"; pass=$((pass+1)); }
no(){ echo "  ✗ $1"; fail=$((fail+1)); }

echo "== SLO lab verification =="

# 1) the SLO object exists
if kubectl -n "$NS" get servicelevelobjective demo-app-availability >/dev/null 2>&1; then
  ok "ServiceLevelObjective demo-app-availability exists"
else
  no "ServiceLevelObjective not found (did 'make slo' run?)"
fi

# 2) Pyrra generated a PrometheusRule from it
if kubectl -n "$NS" get prometheusrule 2>/dev/null | grep -qi demo-app; then
  ok "Pyrra generated a PrometheusRule (recording rules + burn-rate alerts)"
else
  no "No generated PrometheusRule yet (Pyrra operator may still be reconciling)"
fi

# 3) the SLI is actually degraded (errors flowing) — retry, metrics lag a little
ratio=""
for i in $(seq 1 10); do
  ratio=$(curl -s --max-time 6 "$PROM/api/v1/query" --data-urlencode \
    'query=sum(rate(http_requests_total{job="demo-app",code=~"5.."}[2m]))/sum(rate(http_requests_total{job="demo-app"}[2m]))' \
    | python3 -c "import sys,json;r=json.load(sys.stdin)['data']['result'];print(r[0]['value'][1] if r else '')" 2>/dev/null)
  awk "BEGIN{exit !($ratio>0.1)}" 2>/dev/null && break
  sleep 10
done
if awk "BEGIN{exit !($ratio>0.1)}" 2>/dev/null; then
  ok "error ratio is elevated (~$(awk "BEGIN{printf \"%.0f\", $ratio*100}")% 5xx) — the incident is real"
else
  no "error ratio not elevated (got '${ratio:-none}') — run 'make fault' and wait ~1 min"
fi

# 4) a burn-rate alert is pending or firing
state=$(curl -s --max-time 6 "$PROM/api/v1/alerts" \
  | python3 -c "import sys,json;a=json.load(sys.stdin)['data']['alerts'];\
hits=[x for x in a if 'demo-app' in json.dumps(x.get('labels',{})) or 'ErrorBudgetBurn' in x.get('labels',{}).get('alertname','')];\
print(','.join(sorted({x['state'] for x in hits})) or 'none')" 2>/dev/null)
if echo "$state" | grep -qE "firing|pending"; then
  ok "burn-rate alert is '$state' — the page the SLO promised"
else
  no "no burn-rate alert pending/firing yet (state: ${state:-none}) — give the fast window ~2–3 min"
fi

echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ] && echo "RESULT: PASS" || { echo "RESULT: FAIL"; exit 1; }
