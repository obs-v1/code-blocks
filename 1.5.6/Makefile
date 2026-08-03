# 1.5.6 — dashboards as code (Terraform path)
#
#   Prereq: a Grafana running (e.g. `cd ../1.5.1 && make`). Terraform then manages
#   the datasource + dashboards declaratively via the grafana/grafana provider.
#
#   make            # terraform init + apply
#   make plan       # preview
#   make fmt        # format the HCL
#   make destroy    # remove what Terraform created
#
GRAFANA_URL  ?= http://localhost:13000
GRAFANA_AUTH ?= admin:admin

.DEFAULT_GOAL := apply
.PHONY: apply plan fmt destroy

apply: ## provision datasource + dashboards with Terraform
	cd terraform && terraform init -input=false && \
	  terraform apply -auto-approve -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

plan: ## preview the changes
	cd terraform && terraform init -input=false && \
	  terraform plan -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'

fmt: ## format the terraform
	cd terraform && terraform fmt -recursive

destroy: ## remove what Terraform created
	cd terraform && terraform destroy -auto-approve -var 'grafana_url=$(GRAFANA_URL)' -var 'grafana_auth=$(GRAFANA_AUTH)'
