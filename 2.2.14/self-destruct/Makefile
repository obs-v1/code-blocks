# 2.2.14 self-destruct — make Loki fail under its OWN load, then survive.
#   PROBLEM  limits OFF + small memory ceiling -> the flood OOMs Loki (CrashLoop)
#   FIX      limits ON  + same ceiling          -> the flood is rejected, Loki lives
# `make clean` uninstalls. Tune ROUNDS/STREAMS/MEM to your node (see README).
NS      ?= loki-oom
RELEASE ?= loki
ROUNDS  ?= 80
STREAMS ?= 500

.DEFAULT_GOAL := demo
.PHONY: demo problem solve repo podstate clean

demo: problem solve ## crash it (problem), then survive the same flood (fix)

problem: repo ## no limits + 350Mi -> flood OOMs Loki
	helm upgrade -i $(RELEASE) grafana/loki -n $(NS) --create-namespace -f values-unprotected.yaml
	kubectl -n $(NS) rollout status statefulset/$(RELEASE) --timeout=300s
	@echo ""; echo ">>> PROBLEM — all limits OFF, memory capped at 350Mi. Hammering..."
	@kubectl -n $(NS) port-forward svc/$(RELEASE)-gateway 3100:80 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./hammer.sh http://localhost:3100 $(ROUNDS) $(STREAMS); kill $$PF 2>/dev/null
	@sleep 6; $(MAKE) -s podstate

solve: repo ## same flood, but limits ON -> Loki survives
	helm upgrade -i $(RELEASE) grafana/loki -n $(NS) --create-namespace -f values-protected.yaml
	kubectl -n $(NS) rollout restart statefulset/$(RELEASE)
	kubectl -n $(NS) rollout status statefulset/$(RELEASE) --timeout=300s
	@echo ""; echo ">>> FIX — limits ON, same 350Mi ceiling. Hammering the same flood..."
	@kubectl -n $(NS) port-forward svc/$(RELEASE)-gateway 3100:80 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./hammer.sh http://localhost:3100 $(ROUNDS) $(STREAMS); kill $$PF 2>/dev/null
	@sleep 4; $(MAKE) -s podstate

podstate: ## show the Loki pod: restarts + last-termination reason (OOMKilled?)
	@echo "Loki pod state:"
	@kubectl -n $(NS) get pods -l app.kubernetes.io/component=single-binary
	@kubectl -n $(NS) get pod -l app.kubernetes.io/component=single-binary \
	  -o jsonpath='{range .items[*]}  restarts={.status.containerStatuses[0].restartCount}  lastReason={.status.containerStatuses[0].lastState.terminated.reason}{"\n"}{end}' 2>/dev/null; echo

repo:
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update grafana

clean: ## uninstall the release and remove the namespace
	-helm -n $(NS) uninstall $(RELEASE)
	-kubectl delete ns $(NS) --ignore-not-found
