# 2.3.7 — DEMO: batch processing and span LINKS. One batch span links to many source
#         traces (the many-to-one the parent-child tree can't express). Seeded into the
#         Jaeger you already run from code-blocks/2.3.1.
#
#   make          wipe old traces, then seed the batch + 4 source traces (clean slate)
#   make seed     just seed, without wiping
#   make verify   prove the batch span links to >= 4 separate source traces
#   make ui       print the Jaeger URL
#   make clean    wipe Jaeger's in-memory store
#
NS ?= monitoring

.DEFAULT_GOAL := all
.PHONY: all wipe seed verify ui clean

all: wipe seed ## clear previous traces, then seed this demo so only it shows
	@echo ""
	@echo ">>> clean slate: only the batch/links demo is in Jaeger now."
	@echo "    make verify   # prove the batch span links to 4 source traces"
	@echo "    make ui       # open the batch trace -> batch span -> References/Links"

wipe: ## restart Jaeger to clear its in-memory store (removes 2.3.1 samples + older traces)
	kubectl -n $(NS) rollout restart deploy/jaeger
	kubectl -n $(NS) rollout status deploy/jaeger --timeout=120s

seed: ## post the demo traces to Jaeger over OTLP/HTTP (no wipe)
	@kubectl -n $(NS) port-forward svc/jaeger-collector 4318:4318 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./seed-batch.sh http://localhost:4318; RC=$$?; \
	 kill $$PF 2>/dev/null; exit $$RC

verify: ## confirm the batch span links to >= 4 source traces
	@kubectl -n $(NS) port-forward svc/jaeger-query 16686:16686 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:16686; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

ui: ## print the Jaeger URL (NodePort 31686 -> :16686), with a port-forward fallback
	@TOKEN=$$(curl -s -m 1 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null); \
	 IP=$$(curl -s -m 1 -H "X-aws-ec2-metadata-token: $$TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null); \
	 echo "Jaeger: http://$$IP:31686   -> open the batch-processor trace -> batch span -> References"; \
	 echo "  or:   kubectl -n $(NS) port-forward svc/jaeger-query 16686:16686  ->  http://localhost:16686"

clean: wipe ## alias for wipe: clear Jaeger's in-memory store (ALL traces, incl. 2.3.1 samples)
