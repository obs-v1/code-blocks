# 2.4.5 — Traces → Jaeger (via the Collector)
#
#   make          # build the app, deploy Jaeger + the Collector + services
#   make verify   # prove one trace spans BOTH services (service-a → service-b)
#   make ui       # Jaeger UI at http://localhost:16686
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

deploy: ## Jaeger + the Collector (DaemonSet) + the two services
	kubectl apply -f services.yaml        # creates the namespace
	kubectl apply -f jaeger.yaml
	kubectl apply -f collector.yaml
	kubectl -n $(NS) rollout status deploy/jaeger --timeout=120s
	kubectl -n $(NS) rollout status daemonset/otel-collector --timeout=120s
	kubectl -n $(NS) rollout status deploy/service-a --timeout=120s
	@echo "  ✓ deployed. Give it ~20s, then: make verify"

verify: ## prove one trace spans service-a AND service-b
	@kubectl -n $(NS) port-forward svc/jaeger-query 16686:16686 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:16686; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

ui: ## Jaeger UI — find a service-a trace, see the service-b child span
	@echo "Jaeger UI at http://localhost:16686  (Ctrl-C to stop)"
	kubectl -n $(NS) port-forward svc/jaeger-query 16686:16686

destroy: ## remove the lab
	-kubectl delete -f collector.yaml
	-kubectl delete -f jaeger.yaml
	-kubectl delete -f services.yaml
