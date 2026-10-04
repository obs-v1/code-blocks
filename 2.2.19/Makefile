# 2.2.19 — metrics → logs drilldown on the bankobs fleet.
#   make        deploy Prometheus + Grafana + Loki + Promtail, then break a dependency
#   make stack  just the observability stack (no fault)
#   make fault  stop a dependency so its CALLERS error (metrics) and log why (Loki)
#   make reset  heal the fault (revert) and park the injector
#   make ui     print the Grafana URL
#   make clean  uninstall the stack (bankobs is left alone)
#
# Assumes the cluster is ALREADY running bankobs + the (dormant) fault-injector
# Deployment/Service. The fault is driven straight through the injector's REST
# API (no bankobs repo needed on the box).
NS        ?= monitoring
BANKOBS   ?= bankobs
# FAULT_SVC: a dependency many services call; stopping it makes callers fail + log.
# Keep the value clean — an inline comment here would leave trailing spaces in the
# JSON fault payload ("service":"account-service   ") and the injector won't match it.
FAULT_SVC ?= account-service
FAULT_DUR ?= 300

.DEFAULT_GOAL := demo
.PHONY: demo stack repo prometheus loki promtail grafana dashboards fault reset ui clean

demo: stack fault ## deploy the stack, then break a dependency to diagnose

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

fault: ## stop $(FAULT_SVC) for $(FAULT_DUR)s; its callers error + log the reason
	kubectl -n $(BANKOBS) scale deploy/fault-injector --replicas=1
	kubectl -n $(BANKOBS) rollout status deploy/fault-injector --timeout=120s
	@kubectl -n $(BANKOBS) port-forward svc/fault-injector 8091:8091 >/dev/null 2>&1 & echo $$! >/tmp/2219-fpf.pid; sleep 5; \
	 curl -s -X POST http://localhost:8091/api/v1/faults -H 'Content-Type: application/json' \
	   -d '{"type":"container_stop","duration_seconds":$(FAULT_DUR),"target":{"service":"$(FAULT_SVC)"}}' \
	   | jq -r '"injected fault: " + (.data.id // .error // "?")'; \
	 kill $$(cat /tmp/2219-fpf.pid) 2>/dev/null; rm -f /tmp/2219-fpf.pid
	@echo ""
	@echo ">>> $(FAULT_SVC) is down. In Grafana 'Errors: metric -> log':"
	@echo "    top row  — 5xx spikes on its CALLERS (gateway-service, payment-gateway, upi-service)"
	@echo "    log panel — read {service=\"upi-service\"} |= \"payment-failed\": fail_reason names $(FAULT_SVC)"
	@echo "    heal with: make reset"

reset: ## revert all faults and park the injector
	@kubectl -n $(BANKOBS) scale deploy/fault-injector --replicas=1 >/dev/null 2>&1; \
	 kubectl -n $(BANKOBS) rollout status deploy/fault-injector --timeout=60s >/dev/null 2>&1 || true; \
	 kubectl -n $(BANKOBS) port-forward svc/fault-injector 8091:8091 >/dev/null 2>&1 & P=$$!; sleep 4; \
	 curl -s -X DELETE http://localhost:8091/api/v1/faults | jq -r '"reverted: " + (.data.reverted|tostring) 2>/dev/null' 2>/dev/null || true; \
	 kill $$P 2>/dev/null
	-kubectl -n $(BANKOBS) scale deploy/fault-injector --replicas=0

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
