#!/usr/bin/env bash
# PASS/FAIL for all four Alertmanager jobs, proven from the mock pager's logs.
set -uo pipefail
NS="${NS:-monitoring}"
export AM="${AM:-http://localhost:9093}"
pass=0; fail=0
ok(){ echo "  ✓ $1"; pass=$((pass+1)); }
no(){ echo "  ✗ $1"; fail=$((fail+1)); }
k(){ kubectl -n "$NS" "$@"; }

echo "== 3.2.10 Alertmanager verification =="

# Start from a clean pager history.
k rollout restart deploy/mock-pager >/dev/null 2>&1
k rollout status deploy/mock-pager --timeout=60s >/dev/null 2>&1
sleep 2

# Fire the scenarios with unique alertnames so the assertions are deterministic.
bash silence.sh VSilenced >/dev/null
bash fire.sh VPage       severity=page     namespace=vtest  >/dev/null
bash fire.sh VTicket     severity=ticket   namespace=vtest  >/dev/null
bash fire.sh ServiceDown severity=critical namespace=vinh   >/dev/null   # inhibition source
bash fire.sh VInhibited  severity=page     namespace=vinh   >/dev/null   # should be muted
bash fire.sh VSilenced   severity=page     namespace=vtest  >/dev/null   # should be suppressed
for i in a b c; do bash fire.sh VGroup severity=page namespace=vtest instance=$i >/dev/null; done

# Wait for notifications. Alertmanager holds back ~10s for gossip to settle after a (re)start,
# then group_wait (5s) + retries — so poll up to ~45s for the first routed page to land.
echo "  fired scenarios; waiting for Alertmanager to notify…"
LOG=""
for i in $(seq 1 15); do
  sleep 3
  LOG=$(k logs deploy/mock-pager --tail=120 2>/dev/null)
  echo "$LOG" | grep -q "via /pagerduty.*VPage" && echo "$LOG" | grep -q "VGroup.*n=3" && break
done

# 1) ROUTING — a page hits PagerDuty AND Slack (continue:true); a ticket hits Jira
if echo "$LOG" | grep -q "via /pagerduty.*VPage" && echo "$LOG" | grep -q "via /slack.*VPage"; then
  ok "routing: a page reached BOTH PagerDuty and Slack (continue:true)"
else
  no "routing: a page did not reach both receivers"
fi
echo "$LOG" | grep -q "via /jira.*VTicket" && ok "routing: a ticket reached Jira" || no "routing: ticket did not reach Jira"

# 2) GROUPING — 3 siblings (same alertname) arrive as ONE notification
if echo "$LOG" | grep "VGroup" | grep -q "n=3"; then
  ok "grouping: 3 siblings batched into one page (n=3)"
else
  no "grouping: siblings not batched ($(echo "$LOG" | grep VGroup | grep -oE 'n=[0-9]+' | sort -u | tr '\n' ' '))"
fi

# 3) INHIBITION — ServiceDown mutes the same-namespace page
if echo "$LOG" | grep -q "VInhibited"; then
  no "inhibition: VInhibited was delivered (should be muted by ServiceDown)"
else
  ok "inhibition: VInhibited muted by ServiceDown (same namespace)"
fi

# 4) SILENCES — the silenced alert is suppressed
if echo "$LOG" | grep -q "VSilenced"; then
  no "silence: VSilenced was delivered (should be suppressed)"
else
  ok "silence: VSilenced suppressed by the time-boxed silence"
fi

echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ] && echo "RESULT: PASS" || { echo "RESULT: FAIL"; exit 1; }
