# 2.3.1 — Stand up the Jaeger backend, then take your FIRST LOOK at a real trace.
#
#   make          deploy Jaeger all-in-one into the `observability` namespace
#   make verify   prove the live bankobs fleet is landing spans in Jaeger
#   make trace    (optional) fire one request at the gateway to force a fresh trace
#   make ui       print the Jaeger URL (or port-forward it)
#   make clean    remove Jaeger (bankobs is left alone)
#
# Assumes the cluster is ALREADY running bankobs. bankobs is already instrumented and
# exports OTLP to jaeger-collector.observability.svc:4317 — this folder just gives those
# spans somewhere to land. If nothing shows up, see the README note on OTEL_EXPORTER.
NS       ?= observability
BANKOBS  ?= bankobs
# a service that sees most requests, used only by the optional `make trace`
GW_SVC   ?= gateway-service
GW_PORT  ?= 8080

.DEFAULT_GOAL := setup
.PHONY: setup verify trace ui clean

setup: ## deploy Jaeger all-in-one (OTLP in, UI out)
	kubectl apply -f jaeger.yaml
	kubectl -n $(NS) rollout status deploy/jaeger --timeout=120s
	@echo ""
	@echo ">>> Jaeger is up. bankobs spans should start landing within ~30s."
	@echo "    make verify   # confirm the fleet is reporting"
	@echo "    make ui       # open the waterfall"

verify: ## prove the live fleet is landing traces in Jaeger
	@kubectl -n $(NS) port-forward svc/jaeger-query 16686:16686 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:16686; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

trace: ## (optional) force one fresh trace through the gateway
	@echo "bankobs usually self-generates traffic; this just forces one request."
	@kubectl -n $(BANKOBS) port-forward svc/$(GW_SVC) $(GW_PORT):$(GW_PORT) >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; \
	 curl -s -m 5 -X POST http://localhost:$(GW_PORT)/api/upi/pay \
	   -H 'Content-Type: application/json' -d '{"amount":12000,"to":"alice"}' \
	   | head -c 300; echo; \
	 kill $$PF 2>/dev/null; \
	 echo ">>> now: make ui -> Service=upi-service -> Find Traces -> newest row"

ui: ## print the Jaeger URL (NodePort 31686 -> :16686), with a port-forward fallback
	@TOKEN=$$(curl -s -m 1 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null); \
	 IP=$$(curl -s -m 1 -H "X-aws-ec2-metadata-token: $$TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null); \
	 echo "Jaeger: http://$$IP:31686   -> pick a Service (e.g. upi-service) -> Find Traces"; \
	 echo "  or:   kubectl -n $(NS) port-forward svc/jaeger-query 16686:16686  ->  http://localhost:16686"

clean: ## uninstall Jaeger (bankobs is left alone)
	-kubectl delete -f jaeger.yaml
