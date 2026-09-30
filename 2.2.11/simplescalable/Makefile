# Loki — SimpleScalable mode.  `make` deploys everything (incl. bundled MinIO),
# `make clean` uninstalls.
NS      ?= loki-scalable
RELEASE ?= loki

.DEFAULT_GOAL := deploy
.PHONY: deploy repo status clean

deploy: repo ## install Loki (SimpleScalable: read/write/backend + MinIO)
	helm upgrade -i $(RELEASE) grafana/loki -n $(NS) --create-namespace -f values.yaml
	@sleep 5
	-kubectl -n $(NS) wait --for=condition=ready pod --all --timeout=420s
	@$(MAKE) -s status

repo: ## add/update the grafana helm repo
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update grafana

status: ## show the pods (note the read / write / backend roles + minio)
	@kubectl -n $(NS) get pods

clean: ## uninstall the release and remove the namespace
	-helm -n $(NS) uninstall $(RELEASE)
	-kubectl delete ns $(NS) --ignore-not-found
