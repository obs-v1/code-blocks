# 2.2.19 — metrics → logs drilldown on the bankobs fleet.
#   make        deploy Prometheus + Grafana + Loki + Promtail, then inject errors
#   make stack  just the observability stack (no fault)
#   make fault  bring the injector up and fire an error burst at payment-gateway
#   make reset  heal all faults
#   make ui     print the Grafana URL
#   make clean  uninstall everything
#
# Assumes the cluster is ALREADY running bankobs + the (dormant) fault-injector.
# The fault/load steps reuse the bankobs repo's own tooling — point BANKOBS_DIR
# at it (default below). Override FAULT_SVC/CODE/PCT to fault something else.
NS          ?= monitoring
BANKOBS_DIR ?= $(HOME)/claude/observability/bankobserve360
FAULT_SVC   ?= payment-gateway
FAULT_CODE  ?= 503
FAULT_PCT   ?= 30

.DEFAULT_GOAL := demo
.PHONY: demo stack repo prometheus loki promtail grafana dashboards fault reset load ui clean

demo: stack fault ## deploy the stack, then inject errors to diagnose

stack: repo prometheus loki promtail dashboards grafana ## the observability stack only

repo:
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo add grafana-community https://grafana-community.github.io/helm-charts/
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update

prometheus: ## Prometheus (scrapes the bankobs fleet)
	helm upgrade -i prometheus prometheus-community/prometheus -n $(NS) --create-namespace -f prometheus-values.yaml

loki: ## single-binary Loki
	helm upgrade -i loki grafana/loki -n $(NS) --create-namespace -f loki-values.yaml
	kubectl -n $(NS) rollout status statefulset/loki --timeout=240s

promtail: ## Promtail with the json/raw per-pod parser
	helm upgrade -i promtail grafana/promtail -n $(NS) -f promtail-values.yaml
	kubectl -n $(NS) rollout status ds/promtail --timeout=120s

dashboards: ## load the RED-errors dashboard as a labelled ConfigMap (sidecar picks it up)
	kubectl create namespace $(NS) --dry-run=client -o yaml | kubectl apply -f -
	kubectl create configmap dash-red-errors -n $(NS) --from-file=dashboards/red-errors.json --dry-run=client -o yaml \
	  | kubectl label --local -f - grafana_dashboard=1 -o yaml --dry-run=client | kubectl apply -f -

grafana: ## Grafana with Prometheus + Loki datasources + the dashboard
	helm upgrade -i grafana grafana-community/grafana --version 13.2.5 -n $(NS) --create-namespace -f grafana-values.yaml
	kubectl -n $(NS) rollout status deploy/grafana --timeout=180s
	@$(MAKE) -s ui

fault: ## bring up the injector and fire an error burst (reuses bankobs tooling)
	@if [ ! -d "$(BANKOBS_DIR)" ]; then \
	  echo "BANKOBS_DIR not found ($(BANKOBS_DIR))."; \
	  echo "Run the fault from your bankobs repo instead:"; \
	  echo "  make eks-fault-up && make eks-fault-forward &"; \
	  echo "  make fault-error S=$(FAULT_SVC) CODE=$(FAULT_CODE) PCT=$(FAULT_PCT)"; \
	  exit 1; fi
	$(MAKE) -C "$(BANKOBS_DIR)" eks-fault-up
	@echo "port-forwarding the injector API (:8091) in the background..."
	@kubectl -n bankobs port-forward svc/fault-injector 8091:8091 >/dev/null 2>&1 & echo $$! > /tmp/2219-faultpf.pid; sleep 5
	$(MAKE) -C "$(BANKOBS_DIR)" fault-error S=$(FAULT_SVC) CODE=$(FAULT_CODE) PCT=$(FAULT_PCT)
	@echo ""; echo "errors injected at $(FAULT_SVC). Watch Grafana -> 'Errors: metric -> log', then read {service=\"$(FAULT_SVC)\"} in the logs panel."

reset: ## heal all faults
	-$(MAKE) -C "$(BANKOBS_DIR)" fault-reset
	-kill $$(cat /tmp/2219-faultpf.pid 2>/dev/null) 2>/dev/null || true

load: ## (optional) drive traffic, if the loadrunner isn't already running
	-$(MAKE) -C "$(BANKOBS_DIR)" load

ui: ## print the Grafana URL (admin/admin)
	@TOKEN=$$(curl -s -m 1 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null); \
	 IP=$$(curl -s -m 1 -H "X-aws-ec2-metadata-token: $$TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null); \
	 echo "Grafana: http://$$IP:31300  (admin/admin) -> dashboard 'Errors: metric -> log'"; \
	 echo "  or:    kubectl -n $(NS) port-forward svc/grafana 13000:80  ->  http://localhost:13000"

clean: ## uninstall the stack (bankobs is left alone) and heal faults
	-$(MAKE) -s reset
	-helm -n $(NS) uninstall grafana
	-helm -n $(NS) uninstall promtail
	-helm -n $(NS) uninstall loki
	-helm -n $(NS) uninstall prometheus
	-kubectl -n $(NS) delete configmap dash-red-errors --ignore-not-found
