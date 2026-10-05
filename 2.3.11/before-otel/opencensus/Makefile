# before-otel / OpenCensus (Google's pre-OTel all-in-one library).
# Same frontend->backend flow as the OTel lab one level up, built the OLD way, reporting
# to the SAME Jaeger as the OTel lab (one backend speaks OTLP + legacy Thrift) — so ot-*/oc-*
# traces show up next to service-a/service-b in the one UI on :16686.
#
#   make          ensure the lab Jaeger (with :14268) is up, deploy frontend/backend, send traffic
#   make traffic  fire a burst of requests at the frontend (generates traces)
#   make watch    tail the logs: context (traceparent) leaves frontend, arrives at backend
#   make verify   prove one trace spans oc-frontend AND oc-backend
#   make ui       print the Jaeger URL (shared with the OTel lab)
#   make destroy  remove this app (the shared Jaeger is left running)
#
IMG := trace-oc:1.0
NS  := ocensus
JNS := tracing          # the 2.3.11 lab's Jaeger (shared; also serves the OTel service-a/b)

.DEFAULT_GOAL := setup
.PHONY: setup image deploy traffic watch verify ui destroy

setup: image deploy traffic ## build + deploy against the lab Jaeger, then send traffic

image: ## build the OpenCensus image and load it into kind
	docker build -t $(IMG) .
	kind load docker-image $(IMG) --name $$(kind get clusters | head -1)

deploy: ## ensure the lab Jaeger (with legacy :14268) is up, then frontend/backend
	kubectl apply -f ../../jaeger.yaml
	kubectl -n $(JNS) rollout status deploy/jaeger --timeout=120s
	kubectl apply -f services.yaml
	kubectl -n $(NS) rollout status deploy/backend --timeout=120s
	kubectl -n $(NS) rollout status deploy/frontend --timeout=120s

traffic: ## fire 20 requests at the frontend to generate traces (uses a port-forward, no extra pod)
	@kubectl -n $(NS) port-forward svc/frontend 8080:8080 >/dev/null 2>&1 & \
	 PF=$$!; sleep 3; \
	 for i in $$(seq 1 20); do curl -s localhost:8080/call >/dev/null 2>&1; sleep 0.3; done; \
	 echo "sent 20 requests to $(NS)/frontend  ->  make watch / make verify / make ui"; \
	 kill $$PF 2>/dev/null

watch: ## context on both sides of the wire
	@echo "-- frontend SENDING --"; kubectl -n $(NS) logs deploy/frontend --tail=3 | grep SENDING || true
	@echo "-- backend RECEIVED --"; kubectl -n $(NS) logs deploy/backend  --tail=3 | grep RECEIVED || true

verify: ## prove one trace spans both services
	@kubectl -n $(JNS) port-forward svc/jaeger-query 16686:16686 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:16686; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

ui: ## the Jaeger UI (shared with the OTel lab — search ot-frontend)
	@echo "Jaeger: http://<box-ip>:16686   (shared with the OTel lab; search Service=oc-frontend)"
	@echo "  the Service dropdown now has service-a/service-b AND oc-frontend/oc-backend"
	@echo "  or: kubectl -n $(JNS) port-forward svc/jaeger-query 16686:16686  ->  http://localhost:16686"

destroy: ## remove this app (the shared Jaeger is left running)
	-kubectl delete -f services.yaml
