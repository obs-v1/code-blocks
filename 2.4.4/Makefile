# 2.4.4 — Logs → Loki (the Collector tails node-local pod logs)
#
#   make          # build the app, deploy Loki + the Collector + services
#   make verify   # prove the app's stdout logs reached Loki
#   make ui       # Loki API at http://localhost:3100 (query with curl / Grafana)
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

deploy: ## Loki + the Collector (DaemonSet, tails /var/log/pods) + the services
	kubectl apply -f services.yaml        # creates the namespace
	kubectl apply -f loki.yaml
	kubectl apply -f collector.yaml
	kubectl -n $(NS) rollout status deploy/loki --timeout=120s
	kubectl -n $(NS) rollout status daemonset/otel-collector --timeout=120s
	kubectl -n $(NS) rollout status deploy/service-a --timeout=120s
	@echo "  ✓ deployed. Give it ~30s, then: make verify"

verify: ## prove the app's stdout logs reached Loki
	@kubectl -n $(NS) port-forward svc/loki 3100:3100 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:3100; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

ui: ## Loki HTTP API — e.g. curl '.../loki/api/v1/query_range?query={k8s_namespace_name="otel24"}'
	@echo "Loki API at http://localhost:3100  (Ctrl-C to stop)"
	kubectl -n $(NS) port-forward svc/loki 3100:3100

destroy: ## remove the lab
	-kubectl delete -f collector.yaml
	-kubectl delete -f loki.yaml
	-kubectl delete -f services.yaml
