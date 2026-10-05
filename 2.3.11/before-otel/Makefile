# before-otel — bring up BOTH pre-OTel apps reporting to the SAME Jaeger as the OTel lab
# one level up. A Jaeger backend speaks modern OTLP AND legacy Thrift, so service-a/service-b
# (OTLP) and ot-*/oc-* (Thrift) all land in ONE UI (:16686).
#
#   make          ensure the lab Jaeger (with the legacy agent :6831) is up, deploy both apps, send traffic
#   make traffic  fire a burst at both frontends (generates traces)
#   make verify   prove propagation worked for both
#   make ui       print the Jaeger URL (shared with the OTel lab)
#   make destroy  remove both apps (the shared Jaeger is left running)
#
JNS := tracing

.DEFAULT_GOAL := all
.PHONY: all jaeger ot oc traffic verify ui destroy

all: jaeger ot oc traffic ## both apps up on the shared Jaeger, traffic sent
	@echo ""
	@echo ">>> Both pre-OTel apps report to the SAME Jaeger as the OTel lab."
	@echo "    make ui  ->  http://<box-ip>:16686  — the Service dropdown now has:"
	@echo "      service-a / service-b        (OpenTelemetry, from the lab)"
	@echo "      ot-frontend / ot-backend     (OpenTracing + jaeger-client, uber-trace-id)"
	@echo "      oc-frontend / oc-backend     (OpenCensus, traceparent)"
	@echo "    re-send traffic any time with  make traffic"

jaeger: ## ensure the lab Jaeger (OTLP + legacy agent :6831) is up
	kubectl apply -f ../jaeger.yaml
	kubectl -n $(JNS) rollout status deploy/jaeger --timeout=120s

ot: ## build + deploy the OpenTracing app
	$(MAKE) -C opentracing image deploy

oc: ## build + deploy the OpenCensus app
	$(MAKE) -C opencensus image deploy

traffic: ## fire a burst at both frontends (generates traces for both apps)
	@$(MAKE) -C opentracing traffic
	@$(MAKE) -C opencensus traffic

verify: ## prove propagation for both apps
	@$(MAKE) -C opentracing verify
	@echo ""
	@$(MAKE) -C opencensus verify

ui: ## print the Jaeger URL (shared with the OTel lab)
	@echo "Jaeger: http://<box-ip>:16686   (shared with the OTel lab)"
	@echo "  Service dropdown: service-a/service-b  +  ot-frontend/ot-backend  +  oc-frontend/oc-backend"
	@echo "  Open an ot-* span (uber-trace-id) next to an oc-* / service-a span (traceparent)."
	@echo "  or: kubectl -n $(JNS) port-forward svc/jaeger-query 16686:16686  ->  http://localhost:16686"

destroy: ## remove both apps (the shared Jaeger is left running)
	-kubectl delete -f opentracing/services.yaml
	-kubectl delete -f opencensus/services.yaml
