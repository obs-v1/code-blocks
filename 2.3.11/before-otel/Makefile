# before-otel — bring up BOTH pre-OTel apps against one shared legacy Jaeger, so you can
# show OpenTracing and OpenCensus traces side by side in a single UI (:31687).
#
#   make          deploy legacy Jaeger + both apps (OpenTracing & OpenCensus), one clean wipe
#   make verify   prove propagation worked for both
#   make ui       print the shared legacy Jaeger URL
#   make destroy  remove both apps (and the shared Jaeger)
#
JNS := tracing-legacy

.DEFAULT_GOAL := all
.PHONY: all jaeger ot oc wipe verify ui destroy

all: jaeger ot oc wipe ## both apps up, one Jaeger, one clean slate
	@echo ""
	@echo ">>> Both apps are running and reporting to the SAME Jaeger."
	@echo "    Give it ~30s, then  make ui  — the Service dropdown has:"
	@echo "      ot-frontend / ot-backend  (OpenTracing + jaeger-client, uber-trace-id)"
	@echo "      oc-frontend / oc-backend  (OpenCensus, traceparent)"

jaeger: ## the shared legacy Jaeger (:14268 ingest, :31687 UI)
	kubectl apply -f jaeger-legacy.yaml
	kubectl -n $(JNS) rollout status deploy/jaeger-legacy --timeout=120s

ot: ## build + deploy the OpenTracing app (no per-app wipe)
	$(MAKE) -C opentracing image deploy

oc: ## build + deploy the OpenCensus app (no per-app wipe)
	$(MAKE) -C opencensus image deploy

wipe: ## one restart of the shared Jaeger, so both apps repopulate a clean store together
	kubectl -n $(JNS) rollout restart deploy/jaeger-legacy
	kubectl -n $(JNS) rollout status deploy/jaeger-legacy --timeout=120s

verify: ## prove propagation for both apps
	@$(MAKE) -C opentracing verify
	@echo ""
	@$(MAKE) -C opencensus verify

ui: ## print the shared legacy Jaeger URL
	@echo "legacy Jaeger: NodePort 31687  ->  http://<box-ip>:31687"
	@echo "  Service dropdown: ot-frontend / ot-backend  and  oc-frontend / oc-backend"
	@echo "  System Architecture tab shows both frontend->backend pairs."
	@echo "  or: kubectl -n $(JNS) port-forward svc/jaeger-legacy-query 16686:16686  ->  http://localhost:16686"

destroy: ## remove both apps and the shared Jaeger
	-kubectl delete -f opentracing/services.yaml
	-kubectl delete -f opencensus/services.yaml
	-kubectl delete -f jaeger-legacy.yaml
