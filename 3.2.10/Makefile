# ─────────────────────────────────────────────────────────────────────────────
#  3.2.10 — Alertmanager, proven from evidence (routing · grouping · inhibition · silences)
#
#  A mock pager (an HTTP echo whose logs ARE the pager history) sits behind Alertmanager.
#  You fire synthetic alerts at Alertmanager and watch, in the pager's logs, each of the five
#  jobs do exactly what the config says — route, group, inhibit, silence, deduplicate.
#
#  make setup     # Alertmanager (routing tree + inhibition) + the mock pager
#  make route     # 3.2.5: a page → PagerDuty AND Slack; a ticket → Jira
#  make group     # grouping: three siblings arrive as ONE page
#  make inhibit   # 3.2.7: ServiceDown mutes the downstream page in the same namespace
#  make silence   # 3.2.7: a time-boxed silence suppresses a matching alert
#  make verify    # PASS/FAIL: proves all four from the pager logs
#  make destroy
#
#  Prereq: a kind cluster mapping host port 9093 (see README).
# ─────────────────────────────────────────────────────────────────────────────
NS      ?= monitoring
NODE_IP ?= $(shell curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "<box-ip>")
export AM = http://localhost:9093

.PHONY: setup route group inhibit silence _tail ui verify destroy

setup:
	kubectl create namespace $(NS) --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f mock-pager.yaml
	kubectl apply -f alertmanager.yaml
	kubectl -n $(NS) rollout status deploy/mock-pager --timeout=120s
	kubectl -n $(NS) rollout status deploy/alertmanager --timeout=120s
	@echo ""; echo "  ✓ up. Drive it: make route · group · inhibit · silence   (or: make verify)"

route:
	@bash fire.sh PaymentsDown  severity=page   namespace=payments team=payments
	@bash fire.sh CertExpiring  severity=ticket namespace=platform
	@sleep 8; $(MAKE) -s _tail

group:
	@for i in 1 2 3; do bash fire.sh HighLatency severity=page namespace=payments instance=pod-$$i; done
	@echo "  (three siblings, same alertname → group_by batches them)"; sleep 8; $(MAKE) -s _tail

inhibit:
	@bash fire.sh ServiceDown    severity=critical namespace=payments
	@bash fire.sh UpstreamTimeout severity=page     namespace=payments
	@echo "  (ServiceDown should MUTE UpstreamTimeout — same namespace)"; sleep 8; $(MAKE) -s _tail

silence:
	@bash silence.sh NoisyAlert
	@bash fire.sh NoisyAlert severity=page namespace=payments
	@echo "  (NoisyAlert should be SUPPRESSED by the silence)"; sleep 8; $(MAKE) -s _tail

_tail:
	@echo "── mock pager history (last 12) ─────────────────────────────"
	@kubectl -n $(NS) logs deploy/mock-pager --tail=12 2>/dev/null

ui:
	@echo "  Alertmanager: http://$(NODE_IP):9093   (Alerts, Silences, Status)"
	@echo "  Pager log:    kubectl -n $(NS) logs -f deploy/mock-pager"

verify:
	@NS=$(NS) bash verify.sh

destroy:
	-kubectl delete -f alertmanager.yaml --ignore-not-found
	-kubectl delete -f mock-pager.yaml --ignore-not-found
	@echo "  ✓ torn down."
