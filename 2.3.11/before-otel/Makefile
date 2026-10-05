# before-otel — bring up BOTH pre-OTel apps against one shared legacy Jaeger, so you can
# show OpenTracing and OpenCensus traces side by side in a single UI (:31687).
#
#   make          deploy legacy Jaeger + both apps, one clean wipe, then generate traffic
#   make traffic  fire a burst at both frontends (generates traces)
#   make verify   prove propagation worked for both
#   make ui       print the shared legacy Jaeger URL
#   make destroy  remove both apps (and the shared Jaeger)
#
JNS := tracing-legacy

.DEFAULT_GOAL := all
.PHONY: all jaeger ot oc wipe traffic verify ui destroy

all: jaeger ot oc wipe traffic ## both apps up, one Jaeger, clean slate, traffic sent
	@echo ""
	@echo ">>> Both apps are up and reporting to the SAME Jaeger; traffic sent."
	@echo "    make ui  — the Service dropdown has:"
	@echo "      ot-frontend / ot-backend  (OpenTracing + jaeger-client, uber-trace-id)"
	@echo "      oc-frontend / oc-backend  (OpenCensus, traceparent)"
	@echo "    re-send traffic any time with  make traffic"

jaeger: ## the shared legacy Jaeger (:14268 ingest, :31687 UI)
	kubectl apply -f jaeger-legacy.yaml
	kubectl -n $(JNS) rollout status deploy/jaeger-legacy --timeout=120s

ot: ## build + deploy the OpenTracing app (no per-app wipe)
	$(MAKE) -C opentracing image deploy

oc: ## build + deploy the OpenCensus app (no per-app wipe)
	$(MAKE) -C opencensus image deploy

wipe: ## one restart of the shared Jaeger, so both apps report into a clean store together
	kubectl -n $(JNS) rollout restart deploy/jaeger-legacy
	kubectl -n $(JNS) rollout status deploy/jaeger-legacy --timeout=120s

traffic: ## fire a burst at both frontends (generates traces for both apps)
	@$(MAKE) -C opentracing traffic
	@$(MAKE) -C opencensus traffic

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
