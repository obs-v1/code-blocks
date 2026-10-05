# 2.3.1 — Stand up the Jaeger backend, seed sample traces, take your FIRST LOOK.
#
#   make          deploy Jaeger all-in-one AND seed sample traces (ready to view)
#   make setup    just deploy Jaeger (no sample data)
#   make seed     load a few sample payment traces straight into Jaeger (OTLP)
#   make verify   prove traces are landing in Jaeger (sample data, or the live fleet)
#   make trace    (optional) force one real request through the bankobs gateway
#   make ui       print the Jaeger URL (or port-forward it)
#   make clean    remove Jaeger (bankobs is left alone)
#
# Assumes the cluster is ALREADY running bankobs. bankobs is instrumented and exports
# OTLP to jaeger-collector.monitoring.svc:4317 — but you don't have to wait on it:
# `make` also SEEDS sample traces so the UI has something to show immediately. The live
# fleet's own traces land alongside them. If the fleet never shows, see the README note.
NS       ?= monitoring
BANKOBS  ?= bankobs
SEED_N   ?= 6
# a service that sees most requests, used only by the optional `make trace`
GW_SVC   ?= gateway-service
GW_PORT  ?= 8080

.DEFAULT_GOAL := all
.PHONY: all setup seed verify trace ui clean

all: setup seed ## deploy Jaeger and load sample traces (the default)
	@echo ""
	@echo ">>> Ready. Sample traces are loaded; the live fleet's traces land here too."
	@echo "    make verify   # confirm traces are landing"
	@echo "    make ui       # open the waterfall"

setup: ## deploy Jaeger all-in-one (OTLP in, UI out)
	kubectl apply -f jaeger.yaml
	kubectl -n $(NS) rollout status deploy/jaeger --timeout=120s

seed: ## load SEED_N sample payment traces into Jaeger over OTLP/HTTP
	@kubectl -n $(NS) port-forward svc/jaeger-collector 4318:4318 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./seed-traces.sh http://localhost:4318 $(SEED_N); RC=$$?; \
	 kill $$PF 2>/dev/null; exit $$RC

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
