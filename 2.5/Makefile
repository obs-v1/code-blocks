# 2.5.4 — Project: trace a payment across the fleet (+ find the Kafka break)
#
#   Prereq: the 2.2.10 Loki + Promtail lab is running (this project reads the
#           fleet's logs from Loki). Stand it up with:  (cd ../2.2 && make)
#
#   make investigate   # follow one payment across services — the log waterfall
#   make verify        # prove cross-service nav works AND the Kafka break is real
#
NS ?= monitoring

.DEFAULT_GOAL := verify
.PHONY: investigate verify _pf

investigate: ## follow a live payment correlation_id across the fleet
	@kubectl -n $(NS) port-forward svc/loki-gateway 3100:80 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./trace-payment.sh http://localhost:3100; kill $$PF 2>/dev/null

verify: ## cross-service navigation works + the Kafka break is present
	@kubectl -n $(NS) port-forward svc/loki-gateway 3100:80 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:3100; RC=$$?; kill $$PF 2>/dev/null; exit $$RC
