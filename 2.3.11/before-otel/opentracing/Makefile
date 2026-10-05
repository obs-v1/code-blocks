# before-otel / OpenTracing + jaeger-client (the pre-OTel "API + vendor tracer" era).
# Same frontend->backend flow as the OTel lab one level up, built the OLD way.
#
#   make          build image, deploy legacy Jaeger + both services, wipe, generate traffic
#   make traffic  fire a burst of requests at the frontend (generates traces)
#   make watch    tail the logs: same uber-trace-id leaves frontend, arrives at backend
#   make verify   prove one trace spans ot-frontend AND ot-backend
#   make ui       print the legacy Jaeger URL
#   make wipe     clear the legacy Jaeger (traces from a previous run)
#   make destroy  remove this app (legacy Jaeger is left for the sibling demo)
#
IMG := trace-ot:1.0
NS  := otracing
JNS := tracing-legacy

.DEFAULT_GOAL := setup
.PHONY: setup image deploy wipe traffic watch verify ui destroy

setup: image deploy wipe traffic ## build + deploy on a clean Jaeger, then send traffic

image: ## build the OpenTracing/jaeger-client image and load it into kind
	docker build -t $(IMG) .
	kind load docker-image $(IMG) --name $$(kind get clusters | head -1)

deploy: ## legacy Jaeger (:14268) + frontend/backend (no standing driver pod)
	kubectl apply -f ../jaeger-legacy.yaml
	kubectl -n $(JNS) rollout status deploy/jaeger-legacy --timeout=120s
	kubectl apply -f services.yaml
	kubectl -n $(NS) rollout status deploy/backend --timeout=120s
	kubectl -n $(NS) rollout status deploy/frontend --timeout=120s

wipe: ## restart the legacy Jaeger to clear its in-memory store (traces from a prior run)
	kubectl -n $(JNS) rollout restart deploy/jaeger-legacy
	kubectl -n $(JNS) rollout status deploy/jaeger-legacy --timeout=120s

traffic: ## fire 20 requests at the frontend to generate traces (uses a port-forward, no extra pod)
	@kubectl -n $(NS) port-forward svc/frontend 8080:8080 >/dev/null 2>&1 & \
	 PF=$$!; sleep 3; \
	 for i in $$(seq 1 20); do curl -s localhost:8080/call >/dev/null 2>&1; sleep 0.3; done; \
	 echo "sent 20 requests to $(NS)/frontend  ->  make watch / make verify / make ui"; \
	 kill $$PF 2>/dev/null

watch: ## same uber-trace-id on both sides of the wire
	@echo "-- frontend SENDING --"; kubectl -n $(NS) logs deploy/frontend --tail=3 | grep SENDING || true
	@echo "-- backend RECEIVED --"; kubectl -n $(NS) logs deploy/backend  --tail=3 | grep RECEIVED || true

verify: ## prove one trace spans both services
	@kubectl -n $(JNS) port-forward svc/jaeger-legacy-query 16686:16686 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:16686; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

ui: ## the legacy Jaeger UI (search ot-frontend)
	@echo "legacy Jaeger: NodePort 31687  ->  http://<box-ip>:31687   (search Service=ot-frontend)"
	@echo "  or: kubectl -n $(JNS) port-forward svc/jaeger-legacy-query 16686:16686  ->  http://localhost:16686"

destroy: ## remove this app (leaves the shared legacy Jaeger)
	-kubectl delete -f services.yaml
