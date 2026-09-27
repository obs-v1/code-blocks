# remote_write demo - one-command orchestration
#
#   make          # same as `make setup`
#   make setup    # init + apply (stand everything up)
#   make destroy  # tear it all down
#
.DEFAULT_GOAL := setup

.PHONY: setup tf-install init plan apply destroy output fmt clean

setup: init apply ## stand up the whole demo

tf-install: ## install terraform on the lab box if it is missing
	@command -v terraform >/dev/null 2>&1 || sudo labauto terraform

init: tf-install ## download the provider, prepare the working dir
	terraform init -input=false

plan: init ## preview the changes
	terraform plan

apply: tf-install ## create the three instances and provision them
	terraform apply -auto-approve

destroy: ## remove everything this demo created
	terraform destroy -auto-approve

output: ## print the instance IPs and UI URLs
	terraform output

fmt: ## format the terraform files
	terraform fmt -recursive

clean: ## drop local terraform state and cache (does NOT touch AWS)
	rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
