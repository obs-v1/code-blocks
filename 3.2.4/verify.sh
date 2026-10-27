#!/usr/bin/env bash
# PASS/FAIL for the Alertmanager install + wiring. Queries the kind host ports (9090 / 9093).
set -uo pipefail
NS="${NS:-monitoring}"
PROM="${PROM:-http://localhost:9090}"
AM="${AM:-http://localhost:9093}"
pass=0; fail=0
ok(){ echo "  ✓ $1"; pass=$((pass+1)); }
no(){ echo "  ✗ $1"; fail=$((fail+1)); }

echo "== 3.2.4 Alertmanager verification =="

# 1) Prometheus has discovered the Alertmanager (the wiring works)
amcount=$(curl -s --max-time 6 "$PROM/api/v1/alertmanagers" \
  | python3 -c "import sys,json;print(len(json.load(sys.stdin)['data']['activeAlertmanagers']))" 2>/dev/null)
if [ "${amcount:-0}" -ge 1 ] 2>/dev/null; then
  ok "Prometheus is connected to Alertmanager ($amcount active)"
else
  no "Prometheus shows no active Alertmanager (check alerting.alertmanagers in prometheus.yml)"
fi

# 2) the demo alert is firing in Prometheus (retry — it has a 30s 'for')
state=""
for i in $(seq 1 8); do
  state=$(curl -s --max-time 6 "$PROM/api/v1/alerts" \
    | python3 -c "import sys,json;a=[x for x in json.load(sys.stdin)['data']['alerts'] if x['labels'].get('alertname')=='DemoAlwaysFiring'];print(a[0]['state'] if a else 'none')" 2>/dev/null)
  [ "$state" = "firing" ] && break
  sleep 8
done
if [ "$state" = "firing" ]; then
  ok "DemoAlwaysFiring is firing in Prometheus"
else
  no "DemoAlwaysFiring not firing yet (state: ${state:-none}) — give it ~1 min after setup"
fi

# 3) the alert actually reached Alertmanager
got=$(curl -s --max-time 6 "$AM/api/v2/alerts" \
  | python3 -c "import sys,json;a=[x for x in json.load(sys.stdin) if x.get('labels',{}).get('alertname')=='DemoAlwaysFiring'];print('yes' if a else 'no')" 2>/dev/null)
if [ "$got" = "yes" ]; then
  ok "the alert reached Alertmanager (visible in its UI)"
else
  no "Alertmanager has not received the alert yet — wait a few more seconds and re-run"
fi

echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ] && echo "RESULT: PASS" || { echo "RESULT: FAIL"; exit 1; }
