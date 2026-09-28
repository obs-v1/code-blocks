# business-kpis — deploy the UPI Payments business dashboard to Grafana as code.
#
#   make apply GRAFANA_URL=http://<node-ip>:13000 GRAFANA_AUTH=admin:admin
#   make destroy GRAFANA_URL=...
#
# Same Terraform + grafana/grafana provider approach as 1.6.9. The dashboard
# reads bankobserve360's OWN business counters (upi_transaction_total,
# upi_daily_volume_total, ...) — bring up the app, `make seed`, then `make load`
# in the bankobserve360 repo to make it move.
#
GRAFANA_URL  ?= http://localhost:13000
GRAFANA_AUTH ?= admin:admin
TF = terraform -chdir=terraform

.DEFAULT_GOAL := apply
.PHONY: init apply plan destroy fmt

init: ## download the Grafana provider, prepare the working dir
	$(TF) init -input=false

apply: init ## create/update the business dashboard
	$(TF) apply -auto-approve -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

plan: init ## preview the changes
	$(TF) plan -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

destroy: ## remove the business dashboard this created
	$(TF) destroy -auto-approve -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

fmt: ## format the terraform files
	$(TF) fmt
