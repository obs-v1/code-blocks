# 2.3.15 — CAPSTONE: the full payment traced across the fleet, in Jaeger. One big
#          payment waterfall (8 services) + the deliberate Kafka break. Seeded into the
#          Jaeger you already run from code-blocks/2.3.1.
#
#   make          wipe old traces, then seed the payment journey + Kafka break (clean slate)
#   make seed     just seed, without wiping
#   make verify   prove the 8-service payment trace + the orphan consumer landed
#   make hunt     move 2 — find the slowest span via the Jaeger trace API
#   make ui       print the Jaeger URL
#   make clean    wipe Jaeger's in-memory store
#
NS ?= observability

.DEFAULT_GOAL := all
.PHONY: all wipe seed verify hunt ui clean

all: wipe seed ## clear previous traces, then seed the capstone so only it shows
	@echo ""
	@echo ">>> clean slate: the full payment journey + the Kafka break are in Jaeger."
	@echo "    make verify   # prove it landed"
	@echo "    make hunt     # script the slowest-span hunt (move 2)"
	@echo "    make ui       # open the payment trace (Service=api-gateway)"

wipe: ## restart Jaeger to clear its in-memory store (removes 2.3.1 samples + older traces)
	kubectl -n $(NS) rollout restart deploy/jaeger
	kubectl -n $(NS) rollout status deploy/jaeger --timeout=120s

seed: ## post the capstone traces to Jaeger over OTLP/HTTP (no wipe)
	@kubectl -n $(NS) port-forward svc/jaeger-collector 4318:4318 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./seed-payment.sh http://localhost:4318; RC=$$?; \
	 kill $$PF 2>/dev/null; exit $$RC

verify: ## confirm the payment journey + Kafka break landed
	@kubectl -n $(NS) port-forward svc/jaeger-query 16686:16686 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:16686; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

hunt: ## move 2: find the slowest span in the payment trace, via the Jaeger trace API
	@kubectl -n $(NS) port-forward svc/jaeger-query 16686:16686 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; \
	 end=$$(( $$(date +%s) * 1000000 )); start=$$(( end - 3600*1000000 )); \
	 curl -s "http://localhost:16686/api/traces?service=api-gateway&start=$$start&end=$$end&limit=50" | jq -r '
	   ([ .data[] | select([.processes[].serviceName] | index("bank-network")) ][0]) as $$t
	   | ($$t.spans | map(.references[]? | select(.refType=="CHILD_OF") | .spanID) | unique) as $$parents
	   | [ $$t.spans[] | select(.spanID as $$id | ($$parents | index($$id)) | not) ]
	   | max_by(.duration)
	   | "slowest leaf span:  \(.operationName)   \((.duration/1000) | floor) ms   (page the team that owns it)"'; \
	 kill $$PF 2>/dev/null

ui: ## print the Jaeger URL (NodePort 31686 -> :16686), with a port-forward fallback
	@TOKEN=$$(curl -s -m 1 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null); \
	 IP=$$(curl -s -m 1 -H "X-aws-ec2-metadata-token: $$TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null); \
	 echo "Jaeger: http://$$IP:31686   -> Service=api-gateway -> Find Traces -> the big payment trace"; \
	 echo "  or:   kubectl -n $(NS) port-forward svc/jaeger-query 16686:16686  ->  http://localhost:16686"

clean: wipe ## alias for wipe: clear Jaeger's in-memory store (ALL traces, incl. 2.3.1 samples)
