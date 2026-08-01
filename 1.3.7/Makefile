# cortex long-term-storage demo - one-command orchestration
#
#   make          # same as `make setup`
#   make setup    # init + apply (stand up the cortex box)
#   make destroy  # tear it down
#
.DEFAULT_GOAL := setup

.PHONY: setup init plan apply destroy output fmt clean

setup: init apply ## stand up cortex

init: ## download providers, prepare the working dir
	terraform init -input=false

plan: init ## preview the changes
	terraform plan

apply: ## create the cortex box and render the prometheus values file
	terraform apply -auto-approve

destroy: ## remove everything this demo created
	terraform destroy -auto-approve

output: ## print the cortex IP, remote_write URL and query URL
	terraform output

fmt: ## format the terraform files
	terraform fmt -recursive

clean: ## drop local terraform state, cache and the rendered values file
	rm -rf .terraform .terraform.lock.hcl terraform.tfstate* prometheus-values-cortex.rendered.yaml
