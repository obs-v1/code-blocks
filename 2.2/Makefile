# 2.2.10 — Promtail -> Loki pipeline, with LogQL drills
#
#   make          # deploy Loki + Promtail + the leaky demo app
#   make verify   # LogQL drills + prove healthchecks dropped & password scrubbed
#   make logql    # open a port-forward so you can run LogQL by hand / in Grafana
#   make destroy  # tear it all down
#
NS ?= monitoring

.DEFAULT_GOAL := setup
.PHONY: setup repo loki promtail app verify logql destroy

setup: repo app loki promtail ## deploy everything

repo: ## add the grafana helm repo
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update grafana

app: ## deploy the deliberately-leaky demo (password + healthcheck lines)
	kubectl apply -f leaky-app.yaml
	kubectl -n demo rollout status deploy/leaky-app --timeout=120s

loki: ## single-binary Loki store
	helm upgrade -i loki grafana/loki -n $(NS) --create-namespace -f loki-values.yaml
	kubectl -n $(NS) rollout status statefulset/loki --timeout=240s

promtail: ## Promtail shipper with the parse/drop/scrub/timestamp/promote pipeline
	helm upgrade -i promtail grafana/promtail -n $(NS) -f promtail-values.yaml
	kubectl -n $(NS) rollout status ds/promtail --timeout=120s
	@echo "give logs ~30s to land, then: make verify"

verify: ## LogQL drills + the two absence assertions
	@kubectl -n $(NS) port-forward svc/loki-gateway 3100:80 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:3100; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

logql: ## port-forward Loki so you can run LogQL (curl or a Grafana Loki datasource)
	@echo "Loki API at http://localhost:3100  (Ctrl-C to stop)"
	kubectl -n $(NS) port-forward svc/loki-gateway 3100:80

destroy: ## remove Loki, Promtail, and the demo
	-helm -n $(NS) uninstall promtail
	-helm -n $(NS) uninstall loki
	-kubectl delete -f leaky-app.yaml
