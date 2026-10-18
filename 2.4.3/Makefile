# 2.4.3 — Metrics → Prometheus (via the Collector's remote-write)
#
#   make          # build the app, deploy Prometheus + the Collector + services
#   make verify   # prove the app's metrics landed in Prometheus
#   make ui       # Prometheus UI at http://localhost:9090
#   make destroy  # tear it down
#
IMG := otel24-app:1.0
NS  := otel24

.DEFAULT_GOAL := setup
.PHONY: setup image deploy verify ui destroy

setup: image deploy ## build + deploy everything

image: ## build the app image and load it into kind
	docker build -t $(IMG) .
	kind load docker-image $(IMG) --name $$(kind get clusters | head -1)

deploy: ## Prometheus (remote-write on) + the Collector (DaemonSet) + the services
	kubectl apply -f services.yaml        # creates the namespace
	kubectl apply -f prometheus.yaml
	kubectl apply -f collector.yaml
	kubectl -n $(NS) rollout status deploy/prometheus --timeout=120s
	kubectl -n $(NS) rollout status daemonset/otel-collector --timeout=120s
	kubectl -n $(NS) rollout status deploy/service-a --timeout=120s
	@echo "  ✓ deployed. Metrics take ~40s to populate; 'make verify' retries until they do."

verify: ## prove the app's OTLP metrics reached Prometheus
	@kubectl -n $(NS) port-forward svc/prometheus 9090:9090 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:9090; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

ui: ## Prometheus UI — try the query  {service_name="service-a"}
	@echo "Prometheus UI at http://localhost:9090  (Ctrl-C to stop)"
	kubectl -n $(NS) port-forward svc/prometheus 9090:9090

destroy: ## remove the lab
	-kubectl delete -f collector.yaml
	-kubectl delete -f prometheus.yaml
	-kubectl delete -f services.yaml
