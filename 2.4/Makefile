# 2.4.8 — SDK + a Collector with tail sampling
#
#   make          # build image, deploy Jaeger + Collector(tail_sampling) + services
#   make burst    # generate ~40 errors + ~200 routine calls
#   make verify   # prove every error survived while routine was thinned
#   make ui       # Jaeger UI at http://localhost:16686
#   make destroy  # tear it down
#
IMG := trace-lab:1.1
NS  := otel

.DEFAULT_GOAL := setup
.PHONY: setup image deploy burst verify ui destroy

setup: image deploy ## build + deploy everything

image: ## build the Flask+OTel image (with a failure path) and load it into kind
	docker build -t $(IMG) .
	kind load docker-image $(IMG) --name $$(kind get clusters | head -1)

deploy: ## Jaeger + the tail-sampling Collector + the two services + driver
	kubectl apply -f services.yaml        # creates the namespace
	kubectl apply -f jaeger.yaml
	kubectl apply -f collector.yaml
	kubectl -n $(NS) rollout status deploy/jaeger --timeout=120s
	kubectl -n $(NS) rollout status deploy/otel-collector --timeout=120s
	kubectl -n $(NS) rollout status deploy/service-a --timeout=120s

burst: ## a measured mix: ~40 errors + ~200 routine
	kubectl -n $(NS) exec deploy/driver -- sh -c \
	  'for i in $$(seq 1 240); do if [ $$((i % 6)) -eq 0 ]; then curl -s "http://service-a.otel.svc:8080/call?fail=1" >/dev/null; else curl -s "http://service-a.otel.svc:8080/call" >/dev/null; fi; done; echo done'
	@echo "waiting for decision_wait + export..."; sleep 12

verify: burst ## generate the burst, then prove tail sampling kept all errors
	@kubectl -n $(NS) port-forward deploy/jaeger 16686:16686 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:16686; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

ui: ## Jaeger UI — compare error vs routine trace counts yourself
	@echo "Jaeger UI at http://localhost:16686  (Ctrl-C to stop)"
	kubectl -n $(NS) port-forward deploy/jaeger 16686:16686

destroy: ## remove the lab
	-kubectl delete -f collector.yaml
	-kubectl delete -f jaeger.yaml
	-kubectl delete -f services.yaml
