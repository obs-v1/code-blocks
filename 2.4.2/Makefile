# 2.4.2 — the OpenTelemetry Collector as a DaemonSet
#
#   make          # build the app image, deploy the Collector (DaemonSet) + the two services
#   make verify   # prove the Collector is RECEIVING telemetry (its own counters)
#   make logs     # watch the Collector print what it receives (the `debug` exporter)
#   make destroy  # tear it down
#
# Assumes a kind cluster already exists. Reach the Collector's UI-less bits with
# port-forward (this lab uses no NodePort, so it won't clash with other labs).
IMG := otel24-app:1.0
NS  := otel24

.DEFAULT_GOAL := setup
.PHONY: setup image deploy verify logs destroy

setup: image deploy ## build + deploy everything

image: ## build the Flask+OTel image and load it into kind
	docker build -t $(IMG) .
	kind load docker-image $(IMG) --name $$(kind get clusters | head -1)

deploy: ## the Collector DaemonSet + the two services + a driver
	kubectl apply -f services.yaml        # creates the namespace
	kubectl apply -f collector.yaml
	kubectl -n $(NS) rollout status daemonset/otel-collector --timeout=120s
	kubectl -n $(NS) rollout status deploy/service-a --timeout=120s
	@echo "  ✓ deployed. Give it ~20s, then: make verify"

verify: ## prove the Collector received spans + metrics (its :8888 self-telemetry)
	@kubectl -n $(NS) port-forward svc/otel-collector 8888:8888 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:8888; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

logs: ## watch the Collector print each batch it receives
	kubectl -n $(NS) logs -f daemonset/otel-collector

destroy: ## remove the lab
	-kubectl delete -f collector.yaml
	-kubectl delete -f services.yaml
