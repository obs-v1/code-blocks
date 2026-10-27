# ─────────────────────────────────────────────────────────────────────────────
#  3.2.4 — Install Alertmanager and wire Prometheus to it
#
#  make setup    # Prometheus + Alertmanager, already wired together
#  make ui       # the two URLs
#  make verify   # PASS/FAIL: Prometheus knows AM, the demo alert fires and reaches AM
#  make destroy
#
#  Prereq: a kind cluster whose config maps host ports 9090 and 9093 (see README).
# ─────────────────────────────────────────────────────────────────────────────
NS      ?= monitoring
NODE_IP ?= $(shell curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "<box-ip>")

.PHONY: setup ui verify destroy

setup:
	kubectl create namespace $(NS) --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f prometheus.yaml
	kubectl apply -f alertmanager.yaml
	kubectl -n $(NS) rollout status deploy/alertmanager --timeout=120s
	kubectl -n $(NS) rollout status deploy/prometheus --timeout=120s
	@echo ""
	@echo "  ✓ up. The demo alert fires ~45s after Prometheus starts, then shows in Alertmanager."
	@echo "    Next: make ui   ·   make verify"

ui:
	@echo "  Prometheus:   http://$(NODE_IP):9090"
	@echo "     → Status ▸ Runtime & Build Information shows the discovered Alertmanager (the wiring)."
	@echo "     → Alerts tab shows DemoAlwaysFiring go pending → firing."
	@echo "  Alertmanager: http://$(NODE_IP):9093"
	@echo "     → the firing DemoAlwaysFiring appears here once Prometheus pushes it."

verify:
	@NS=$(NS) bash verify.sh

destroy:
	-kubectl delete -f prometheus.yaml --ignore-not-found
	-kubectl delete -f alertmanager.yaml --ignore-not-found
	@echo "  ✓ torn down."
