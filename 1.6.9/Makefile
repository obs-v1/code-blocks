# 1.6.1 — the full RED dashboard set, loaded into Grafana with Terraform.
# One `make apply` creates all six RED dashboards at once.
#
#   make apply     # create every RED dashboard in dashboards/
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

apply: init ## create all six RED dashboards
	$(TF) apply -auto-approve -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

plan: init ## preview the changes
	$(TF) plan -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

destroy: ## remove every RED dashboard this created
	$(TF) destroy -auto-approve -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

fmt: ## format the terraform files
	$(TF) fmt
