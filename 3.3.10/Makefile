# ─────────────────────────────────────────────────────────────────────────────
#  3.3.10 — Four signals, one run, end to end
#
#  Two sample apps (Python gateway → Go worker), each OTel-instrumented AND
#  Pyroscope-profiled, in front of a full self-contained stack:
#  OTel Collector · Prometheus · Loki · Jaeger · Pyroscope · Grafana.
#
#  make up       # build images, load into kind, deploy the whole stack
#  make fault    # inject latency + errors on the worker (the hot path heats up)
#  make heal     # back to the healthy baseline
#  make verify   # PASS/FAIL: all four signals present + the pivots wired
#  make ui       # print the URLs
#  make destroy
#
#  Prereq: the kind cluster from student-practice/cluster (this adds no cluster of
#  its own). Pyroscope UI needs the 30040→4040 mapping — recreate kind if you want it.
# ─────────────────────────────────────────────────────────────────────────────
CLUSTER ?= lab
NS      ?= monitoring
NODE_IP ?= $(shell curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "<box-ip>")

.PHONY: up all build load deploy fault heal ui verify destroy

all: up

build:
	docker build -t worker:lab  apps/worker
	docker build -t gateway:lab apps/gateway

load: build
	kind load docker-image worker:lab gateway:lab --name $(CLUSTER)

deploy:
	kubectl apply -f k8s/
	kubectl -n $(NS) rollout status deploy/otel-collector --timeout=120s
	kubectl -n $(NS) rollout status deploy/jaeger         --timeout=120s
	kubectl -n $(NS) rollout status deploy/prometheus     --timeout=120s
	kubectl -n $(NS) rollout status deploy/loki           --timeout=180s
	kubectl -n $(NS) rollout status deploy/pyroscope      --timeout=120s
	kubectl -n $(NS) rollout status deploy/grafana        --timeout=120s
	kubectl -n $(NS) rollout status deploy/worker         --timeout=120s
	kubectl -n $(NS) rollout status deploy/gateway        --timeout=120s

up: load deploy
	@echo ""; echo "  ✓ up. Give it ~30s for telemetry to flow, then: make verify"
	@$(MAKE) -s ui

fault:
	kubectl -n $(NS) set env deploy/worker BURN_LOOPS=400000 ERROR_RATE=0.3
	kubectl -n $(NS) rollout status deploy/worker --timeout=120s
	@echo "  🔥 fault on: worker CPU burn ↑ and ~30% of checkouts fail."
	@echo "     Chase it: latency spike (metric) → exemplar → trace → logs, and trace → flame graph."

heal:
	kubectl -n $(NS) set env deploy/worker BURN_LOOPS=20000 ERROR_RATE=0
	kubectl -n $(NS) rollout status deploy/worker --timeout=120s
	@echo "  ✓ healed: back to baseline."

ui:
	@echo "  Grafana (single pane): http://$(NODE_IP):3000   (anonymous Admin)"
	@echo "  Jaeger:                http://$(NODE_IP):16686"
	@echo "  Prometheus:            http://$(NODE_IP):9090"
	@echo "  Pyroscope:             http://$(NODE_IP):4040   (needs the kind 4040 mapping)"

verify:
	@NS=$(NS) bash verify.sh

destroy:
	-kubectl delete -f k8s/ --ignore-not-found
	@echo "  ✓ torn down (namespace $(NS) kept)."
