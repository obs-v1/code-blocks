# 2.2-1 — Loki + a SIDECAR shipper (contrast with 2.2's node DaemonSet).
#
#   make          # deploy Loki + the app-with-sidecar (own namespace)
#   make verify   # LogQL drills + prove healthchecks dropped & password scrubbed
#   make logql    # port-forward Loki for hand LogQL / a Grafana datasource
#   make destroy  # tear it all down
#
# Fully isolated in namespace `sidecar-demo` + its own Loki release — it does
# NOT disturb the 2.2 lab (Loki/Promtail in `monitoring`, app in `demo`).
NS ?= sidecar-demo

.DEFAULT_GOAL := setup
.PHONY: setup repo loki app verify logql destroy

setup: repo loki app ## deploy everything

repo: ## add the grafana helm repo
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update grafana

loki: ## single-binary Loki store in its own namespace
	helm upgrade -i loki grafana/loki -n $(NS) --create-namespace -f loki-values.yaml
	kubectl -n $(NS) rollout status statefulset/loki --timeout=240s

app: ## the app + Promtail sidecar (shared-volume shipping)
	kubectl apply -f app-with-sidecar.yaml
	kubectl -n $(NS) rollout status deploy/sidecar-app --timeout=120s
	@echo "give logs ~30s to land, then: make verify"

verify: ## LogQL drills + the two absence assertions
	@kubectl -n $(NS) port-forward svc/loki-gateway 3100:80 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:3100; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

logql: ## port-forward Loki so you can run LogQL by hand
	@echo "Loki API at http://localhost:3100  (Ctrl-C to stop)"
	kubectl -n $(NS) port-forward svc/loki-gateway 3100:80

destroy: ## remove Loki and the app
	-helm -n $(NS) uninstall loki
	-kubectl delete -f app-with-sidecar.yaml
