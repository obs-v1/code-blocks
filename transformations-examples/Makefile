# transformations-examples — one dashboard per Grafana-13 transformation,
# loaded into Grafana with Terraform (the same "dashboards as code" approach
# as 1.5.6).
#
#   make apply     # load every dashboard in dashboards/ into Grafana
#   make plan      # preview what would change
#   make destroy   # remove them all
#
# Point it at your Grafana (defaults suit the course's kind setup, host :13000):
#   make apply GRAFANA_URL=http://<node-ip>:13000 GRAFANA_AUTH=admin:admin
# GRAFANA_AUTH takes "user:password" or a service-account token.
#
GRAFANA_URL  ?= http://localhost:13000
GRAFANA_AUTH ?= admin:admin
TF = terraform -chdir=terraform

.DEFAULT_GOAL := apply
.PHONY: init apply plan destroy fmt

init: ## download the Grafana provider, prepare the working dir
	$(TF) init -input=false

apply: init ## load every dashboard into Grafana
	$(TF) apply -auto-approve -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

plan: init ## preview the changes
	$(TF) plan -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

destroy: ## remove every dashboard this created
	$(TF) destroy -auto-approve -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

fmt: ## format the terraform files
	$(TF) fmt
