# 1.5.1 — Grafana datasources & provisioning
#
#   make            # deploy Grafana with a provisioned Prometheus datasource
#   make verify     # prove the datasource is provisioned and reaches Prometheus
#   make destroy    # tear it down
#
NS          ?= monitoring
GRAFANA_URL ?= http://localhost:13000
ADMIN       ?= admin:admin

.DEFAULT_GOAL := setup
.PHONY: setup repo grafana verify destroy

setup: repo grafana ## deploy grafana + provisioned datasource

repo: ## add the grafana-community helm repo (grafana/grafana is deprecated, frozen at v12)
	helm repo add grafana-community https://grafana-community.github.io/helm-charts/
	helm repo update grafana-community

grafana: ## install Grafana with the datasource provisioned from grafana-values.yaml
	helm upgrade -i grafana grafana-community/grafana --version 13.2.5 -n $(NS) --create-namespace -f grafana-values.yaml
	kubectl -n $(NS) rollout status deploy/grafana --timeout=180s

verify: ## confirm the datasource is provisioned and can query Prometheus
	./verify.sh $(GRAFANA_URL) $(ADMIN)

destroy: ## remove Grafana
	-helm -n $(NS) uninstall grafana

datasources:
	helm upgrade -i grafana grafana-community/grafana --version 13.2.5 -n $(NS) --create-namespace -f grafana-values-d.yaml
	kubectl -n $(NS) rollout status deploy/grafana --timeout=180s

