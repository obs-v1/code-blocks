# remote_write demo - one-command orchestration
#
#   make          # same as `make setup`
#   make setup    # init + apply (stand everything up)
#   make destroy  # tear it all down
#
.DEFAULT_GOAL := setup

.PHONY: setup init plan apply destroy output fmt clean

setup: init apply ## stand up the whole demo

init: ## download the provider, prepare the working dir
	terraform init -input=false

plan: init ## preview the changes
	terraform plan

apply: ## create the three instances and provision them
	terraform apply -auto-approve

destroy: ## remove everything this demo created
	terraform destroy -auto-approve

output: ## print the instance IPs and UI URLs
	terraform output

fmt: ## format the terraform files
	terraform fmt -recursive

clean: ## drop local terraform state and cache (does NOT touch AWS)
	rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
