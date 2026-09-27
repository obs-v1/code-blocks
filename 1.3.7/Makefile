# mimir long-term-storage demo - one-command orchestration
#
#   make          # same as `make setup`
#   make setup    # init + apply (stand up the mimir box)
#   make destroy  # tear it down
#
.DEFAULT_GOAL := setup

.PHONY: setup tf-install init plan apply destroy output fmt clean

setup: init apply ## stand up mimir

tf-install: ## install terraform on the lab box if it is missing
	@command -v terraform >/dev/null 2>&1 || sudo labauto terraform

init: tf-install ## download providers, prepare the working dir
	terraform init -input=false

plan: init ## preview the changes
	terraform plan

apply: tf-install ## create the mimir box and render the prometheus values file
	terraform apply -auto-approve

destroy: ## remove everything this demo created
	terraform destroy -auto-approve

output: ## print the mimir IP, remote_write URL and query URL
	terraform output

fmt: ## format the terraform files
	terraform fmt -recursive

clean: ## drop local terraform state, cache and the rendered values file
	rm -rf .terraform .terraform.lock.hcl terraform.tfstate* prometheus-values-mimir.rendered.yaml
