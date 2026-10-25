# ─────────────────────────────────────────────────────────────────────────────
#  3.1.10 — an SLO with burn-rate alerts, demoed with Pyrra
#
#  read the idea (3.1.5–3.1.9) → run this → watch the error budget burn → know what it means
#
#  make setup   # kube-prometheus-stack + Pyrra + the demo app (one node, kind)
#  make slo     # apply the 12-line SLO; Pyrra generates the rules + burn-rate alerts
#  make ui      # the URLs: Pyrra (budget), Prometheus, Alertmanager, Grafana
#  make fault   # inject ~30% errors — the incident
#  make verify  # PASS/FAIL: budget burning + fast-burn alert firing
#  make fault-stop / make destroy
# ─────────────────────────────────────────────────────────────────────────────
NS        ?= monitoring
IMG       ?= demo-slo-app:1.0
CLUSTER   ?= lab
PYRRA_VER ?= v0.10.2
KPS_VER   ?= 65.5.1          # kube-prometheus-stack; bump if the kind k8s version needs it
PYRRA_CRD  = https://raw.githubusercontent.com/pyrra-dev/pyrra/$(PYRRA_VER)/examples/kubernetes/manifests/setup/pyrra-slo-CustomResourceDefinition.yaml
# host ports published by the kind config (student-practice/cluster/kind-config.yaml)
NODE_IP   ?= $(shell curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "<box-ip>")

.PHONY: setup slo ui fault fault-stop verify destroy image

setup: image
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
	helm repo update prometheus-community >/dev/null
	helm upgrade --install kps prometheus-community/kube-prometheus-stack \
	  --version $(KPS_VER) -n $(NS) --create-namespace -f values-kps.yaml
	kubectl -n $(NS) rollout status deploy/kps-operator --timeout=240s
	kubectl apply -f app.yaml
	kubectl apply -f grafana-dashboard.yaml
	kubectl -n $(NS) rollout status deploy/demo-app --timeout=120s
	kubectl apply --server-side -f $(PYRRA_CRD)
	kubectl apply -f pyrra.yaml
	kubectl -n $(NS) rollout status deploy/pyrra-kubernetes --timeout=120s
	kubectl -n $(NS) rollout status deploy/pyrra-api --timeout=120s
	@echo ""; echo "  ✓ setup done. Next: make slo   then   make ui"

image:
	docker build -t $(IMG) .
	kind load docker-image $(IMG) --name $(CLUSTER)

slo:
	kubectl apply -f slo.yaml
	@echo "  → waiting for Pyrra to generate the PrometheusRule…"; sleep 8
	@kubectl -n $(NS) get prometheusrule -l pyrra.dev/team=payments 2>/dev/null || \
	 kubectl -n $(NS) get prometheusrule | grep -i demo-app || echo "  (rule not visible yet — give it a few more seconds)"
	@echo "  ✓ SLO applied. Open the Pyrra UI (make ui) and watch the budget."

ui:
	@echo "  Pyrra (error budget + burn rate):  http://$(NODE_IP):9099"
	@echo "  Prometheus (rules + alerts):       http://$(NODE_IP):9090"
	@echo "  Alertmanager (fired alerts):       http://$(NODE_IP):9093"
	@echo "  Grafana SLO dashboard (admin/admin): http://$(NODE_IP):3000/d/slo-demo-app"

fault:
	kubectl -n $(NS) exec deploy/demo-app -- \
	  python -c "import urllib.request as u; print(u.urlopen(u.Request('http://localhost:8080/admin/error-rate?rate=0.3', method='POST')).read())"
	@echo "  ✓ injecting ~30% errors. Watch the budget fall in Pyrra; the fast-burn alert fires in ~2–3 min."

fault-stop:
	kubectl -n $(NS) exec deploy/demo-app -- \
	  python -c "import urllib.request as u; print(u.urlopen(u.Request('http://localhost:8080/admin/error-rate?rate=0', method='POST')).read())"
	@echo "  ✓ errors back to 0. The budget stops burning (it recovers slowly as the window rolls)."

verify:
	@NS=$(NS) bash verify.sh

destroy:
	-kubectl delete -f slo.yaml --ignore-not-found
	-kubectl delete -f pyrra.yaml --ignore-not-found
	-kubectl delete -f grafana-dashboard.yaml --ignore-not-found
	-kubectl delete -f app.yaml --ignore-not-found
	-helm uninstall kps -n $(NS)
	-kubectl delete -f $(PYRRA_CRD) --ignore-not-found
	-kubectl delete ns $(NS) --ignore-not-found
	@echo "  ✓ torn down."
