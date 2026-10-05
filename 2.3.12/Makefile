# 2.3.12 — Jaeger's PRODUCTION architecture, via Helm: separate collector + query pods,
# backed by Elasticsearch. The real topology the section teaches — not the all-in-one.
#
#   make          deploy single-node Elasticsearch, then the Jaeger Helm chart against it
#   make verify   show the component pods (collector / query / ES) and confirm ingestion
#   make ui       print the Jaeger query URL
#   make clean    uninstall Jaeger + remove Elasticsearch
#
# Assumes the bankobs fleet is deployed and exporting OTLP to jaeger-collector.monitoring.svc:4317
# (same convention as 2.3.1 / the 1.5.1 datasource). This REPLACES the 2.3.1 all-in-one Jaeger
# (same namespace + :16686), so tear that down first if it is running.
NS        ?= monitoring
RELEASE   ?= jaeger
CHART_VER ?= 3.4.1

.DEFAULT_GOAL := up
.PHONY: up repo es jaeger connect-bankobs verify ui clean

up: repo es jaeger ## Elasticsearch + the Jaeger production topology
	@echo ""
	@echo ">>> Jaeger (collector + query) is up on Elasticsearch, in the '$(NS)' namespace."
	@echo "    Collector OTLP: jaeger-collector.$(NS).svc:4317  (where the bankobs fleet exports)"
	@echo "    make verify   # the component pods + whether the fleet is landing"
	@echo "    make ui       # open the query UI"

repo: ## add/update the Jaeger Helm repo
	helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
	helm repo update

es: ## single-node Elasticsearch (lab sizing)
	kubectl create namespace $(NS) --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f es.yaml
	kubectl -n $(NS) rollout status deploy/elasticsearch --timeout=300s

jaeger: ## Helm-install Jaeger (collector + query) pointed at Elasticsearch
	helm upgrade -i $(RELEASE) jaegertracing/jaeger --version $(CHART_VER) \
	  -n $(NS) --create-namespace -f values.yaml
	kubectl -n $(NS) rollout status deploy/$(RELEASE)-collector --timeout=240s
	kubectl -n $(NS) rollout status deploy/$(RELEASE)-query --timeout=240s
	@$(MAKE) -s ui

connect-bankobs: ## route the bankobs fleet's traces into this Jaeger, and light the fleet
	@echo ">>> 1/3  aliasing bankobs' 'jaeger' target to this production collector"
	@# If the obs stack's all-in-one Jaeger owns the name, step aside (it clashes on :31686 too).
	-kubectl -n bankobs delete deploy jaeger --ignore-not-found
	-kubectl -n bankobs delete svc jaeger --ignore-not-found
	kubectl apply -f alias.yaml
	@echo ">>> 2/3  restarting the OTel Collector so it re-resolves 'jaeger'"
	-kubectl -n bankobs rollout restart deploy/otel-collector
	-kubectl -n bankobs rollout status deploy/otel-collector --timeout=120s
	@echo ">>> 3/3  lighting the fleet (dark -> full): emit spans"
	kubectl -n bankobs set env deployment -l domain \
	  OBSERVABILITY_MODE=full OTEL_SDK_DISABLED=false MANAGEMENT_TRACING_ENABLED=true \
	  MANAGEMENT_OTLP_METRICS_EXPORT_ENABLED=true LOGGING_LEVEL_IO_OPENTELEMETRY=INFO
	@echo ""
	@echo "    Fleet is rolling + emitting. Traffic (bankobs loadrunner) fills the UI within ~1-2 min."
	@echo "    make verify   # the bankobs services now reporting here"

verify: ## show the architecture pods and whether traces are landing
	@echo "== Jaeger architecture (separate pods, unlike all-in-one) =="
	@kubectl -n $(NS) get pods -l app.kubernetes.io/instance=$(RELEASE) -o wide
	@kubectl -n $(NS) get pods -l app=elasticsearch -o wide
	@echo ""
	@echo "== services the fleet has reported (empty until bankobs is up + exporting) =="
	@kubectl -n $(NS) port-forward svc/$(RELEASE)-query 16686:80 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; \
	 curl -s http://localhost:16686/api/services | jq -r '.data[]? // "  (none yet)"' | sed 's/^/  /'; \
	 kill $$PF 2>/dev/null || true

ui: ## print the Jaeger query URL (NodePort 31686 -> :16686)
	@TOKEN=$$(curl -s -m 1 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null); \
	 IP=$$(curl -s -m 1 -H "X-aws-ec2-metadata-token: $$TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null); \
	 echo "Jaeger query UI: http://$$IP:16686   (NodePort 31686)"; \
	 echo "  or: kubectl -n $(NS) port-forward svc/$(RELEASE)-query 16686:80  ->  http://localhost:16686"

clean: ## uninstall Jaeger and remove Elasticsearch
	-helm -n $(NS) uninstall $(RELEASE)
	-kubectl delete -f es.yaml
