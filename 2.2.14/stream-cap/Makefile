# 2.2.14 — limits_config simulation.  `make` runs the whole before/after:
#   PROBLEM  limits wide open  -> a high-cardinality flood is swallowed whole
#   FIX      set the limits     -> the same flood is capped with HTTP 429
# `make clean` uninstalls.
NS      ?= loki-limits
RELEASE ?= loki
N       ?= 200

.DEFAULT_GOAL := demo
.PHONY: demo problem solve repo clean

demo: problem solve ## show the flood swallowed (problem), then capped (fix)

problem: repo ## limits wide open -> the flood is swallowed
	helm upgrade -i $(RELEASE) grafana/loki -n $(NS) --create-namespace -f values-loose.yaml
	kubectl -n $(NS) rollout status statefulset/$(RELEASE) --timeout=300s
	@echo ""; echo ">>> PROBLEM — limits wide open (max_global_streams_per_user: 100000)"
	@kubectl -n $(NS) port-forward svc/$(RELEASE)-gateway 3100:80 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./flood.sh http://localhost:3100 $(N) a; kill $$PF 2>/dev/null

solve: repo ## set the limits + restart -> the flood is capped (429)
	helm upgrade -i $(RELEASE) grafana/loki -n $(NS) --create-namespace -f values-tight.yaml
	kubectl -n $(NS) rollout restart statefulset/$(RELEASE)
	kubectl -n $(NS) rollout status statefulset/$(RELEASE) --timeout=300s
	@echo ""; echo ">>> FIX — max_global_streams_per_user: 50"
	@kubectl -n $(NS) port-forward svc/$(RELEASE)-gateway 3100:80 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./flood.sh http://localhost:3100 $(N) b; kill $$PF 2>/dev/null
	@echo ""; echo "compare the two runs: same flood, capped once the limit was set."

repo: ## add/update the grafana helm repo
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update grafana

clean: ## uninstall the release and remove the namespace
	-helm -n $(NS) uninstall $(RELEASE)
	-kubectl delete ns $(NS) --ignore-not-found
