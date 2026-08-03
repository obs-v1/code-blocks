# 1.5.8 — a fully provisioned Grafana (datasource + every dashboard)
#
#   make            # deploy Grafana, provision datasource + all dashboards
#   make verify     # prove it all loaded and live data flows
#   make destroy    # tear it down
#
NS          ?= monitoring
GRAFANA_URL ?= http://localhost:13000
ADMIN       ?= admin:admin

# every dashboard from the chapter (sibling section folders)
DASH = ../1.5.2/panels.json ../1.5.3/variables.json ../1.5.4/annotations.json \
       ../1.5.5/transformations.json ../1.5.7/red-overview.json

.DEFAULT_GOAL := setup
.PHONY: setup repo dashboards grafana verify destroy

setup: repo dashboards grafana ## deploy the whole thing

repo: ## add the grafana helm repo
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update grafana

dashboards: ## load each dashboard JSON as a labelled ConfigMap (sidecar picks them up)
	kubectl create namespace $(NS) --dry-run=client -o yaml | kubectl apply -f -
	@for f in $(DASH); do \
	  name=dash-$$(basename $$f .json); \
	  echo "  provisioning $$name"; \
	  kubectl create configmap $$name -n $(NS) --from-file=$$f --dry-run=client -o yaml \
	    | kubectl label --local -f - grafana_dashboard=1 -o yaml --dry-run=client \
	    | kubectl apply -f - >/dev/null; \
	done

grafana: ## install Grafana with the datasource + dashboard sidecar
	helm upgrade -i grafana grafana/grafana -n $(NS) --create-namespace -f grafana-values.yaml
	kubectl -n $(NS) rollout status deploy/grafana --timeout=180s

verify: ## check datasource, all dashboards, and live data
	./verify.sh $(GRAFANA_URL) $(ADMIN)

destroy: ## remove Grafana and the dashboard ConfigMaps
	-helm -n $(NS) uninstall grafana
	-kubectl -n $(NS) delete configmap -l grafana_dashboard=1
