# 2.3.10 — Two services, one trace (watch the traceparent cross the wire)
#
#   make          # build image, deploy Jaeger + service-a -> service-b + driver
#   make watch    # tail the frontend/backend logs: same traceparent, both sides
#   make verify   # prove one trace spans BOTH services
#   make ui       # port-forward the Jaeger UI to http://localhost:16686
#   make destroy  # tear it down
#
IMG := trace-lab:1.0
NS  := tracing

.DEFAULT_GOAL := setup
.PHONY: setup image deploy watch verify ui destroy

setup: image deploy ## build + deploy everything

image: ## build the tiny Flask+OTel image and load it into kind
	docker build -t $(IMG) .
	kind load docker-image $(IMG) --name $$(kind get clusters | head -1)

deploy: ## Jaeger + the two services + a driver
	kubectl apply -f services.yaml       # creates the namespace, services, driver
	kubectl apply -f jaeger.yaml
	kubectl -n $(NS) rollout status deploy/jaeger --timeout=120s
	kubectl -n $(NS) rollout status deploy/service-b --timeout=120s
	kubectl -n $(NS) rollout status deploy/service-a --timeout=120s
	@echo "give it ~30s, then: make watch   and   make verify"

watch: ## see the same traceparent leave the frontend and arrive at the backend
	@echo "-- frontend SENDING --"; kubectl -n $(NS) logs deploy/service-a --tail=3 | grep SENDING || true
	@echo "-- backend RECEIVED --"; kubectl -n $(NS) logs deploy/service-b --tail=3 | grep RECEIVED || true

verify: ## prove one trace spans both services
	@kubectl -n $(NS) port-forward svc/jaeger-query 16686:16686 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:16686; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

ui: ## open the Jaeger UI (search service-a to see the waterfall)
	@echo "Jaeger UI at http://localhost:16686  (Ctrl-C to stop)"
	kubectl -n $(NS) port-forward svc/jaeger-query 16686:16686

destroy: ## remove the lab
	-kubectl delete -f services.yaml
	-kubectl delete -f jaeger.yaml
