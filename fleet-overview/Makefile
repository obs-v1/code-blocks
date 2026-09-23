# fleet-overview — one dashboard showing EVERY bankobserve360 service (all
# languages), loaded into Grafana with Terraform.
#
#   make apply GRAFANA_URL=http://<node-ip>:13000 GRAFANA_AUTH=admin:admin
#   make plan / make destroy
#
GRAFANA_URL  ?= http://localhost:13000
GRAFANA_AUTH ?= admin:admin
TF = terraform -chdir=terraform

.DEFAULT_GOAL := apply
.PHONY: init apply plan destroy fmt

init: ## download the Grafana provider
	$(TF) init -input=false

apply: init ## create the fleet dashboard
	$(TF) apply -auto-approve -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

plan: init ## preview
	$(TF) plan -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

destroy: ## remove it
	$(TF) destroy -auto-approve -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

fmt:
	$(TF) fmt
