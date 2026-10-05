# 2.3.6 — DEMO: trace context through a message queue. A producer INJECTS traceparent
#         and a consumer EXTRACTS it -> one trace; skip it -> two. Seeded into the Jaeger
#         you already run from code-blocks/2.3.1.
#
#   make          wipe old traces, then seed the connected + broken scenarios (clean slate)
#   make seed     just seed, without wiping
#   make verify   prove the join (1 trace) and the split (producer-only + orphan consumer)
#   make ui       print the Jaeger URL
#   make clean    wipe Jaeger's in-memory store
#
NS ?= monitoring

.DEFAULT_GOAL := all
.PHONY: all wipe seed verify ui clean

all: wipe seed ## clear previous traces, then seed this demo so only it shows
	@echo ""
	@echo ">>> clean slate: only the queue demo is in Jaeger now."
	@echo "    make verify   # prove connected + broken"
	@echo "    make ui       # filter Tags: demo.scenario=connected  vs  demo.scenario=broken"

wipe: ## restart Jaeger to clear its in-memory store (removes 2.3.1 samples + older traces)
	kubectl -n $(NS) rollout restart deploy/jaeger
	kubectl -n $(NS) rollout status deploy/jaeger --timeout=120s

seed: ## post the demo traces to Jaeger over OTLP/HTTP (no wipe)
	@kubectl -n $(NS) port-forward svc/jaeger-collector 4318:4318 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./seed-queue.sh http://localhost:4318; RC=$$?; \
	 kill $$PF 2>/dev/null; exit $$RC

verify: ## confirm both scenarios landed (joined + split)
	@kubectl -n $(NS) port-forward svc/jaeger-query 16686:16686 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:16686; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

ui: ## print the Jaeger URL (NodePort 31686 -> :16686), with a port-forward fallback
	@TOKEN=$$(curl -s -m 1 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null); \
	 IP=$$(curl -s -m 1 -H "X-aws-ec2-metadata-token: $$TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null); \
	 echo "Jaeger: http://$$IP:31686   -> filter Tags:  demo.scenario=connected   vs   demo.scenario=broken"; \
	 echo "  or:   kubectl -n $(NS) port-forward svc/jaeger-query 16686:16686  ->  http://localhost:16686"

clean: wipe ## alias for wipe: clear Jaeger's in-memory store (ALL traces, incl. 2.3.1 samples)
