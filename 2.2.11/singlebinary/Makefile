# Loki — SingleBinary mode.  `make` deploys everything, `make clean` uninstalls.
NS      ?= loki-single
# unique release name per lab - unique per mode: the chart's ClusterRole is release-named, so two "loki" releases collide
RELEASE ?= loki-single

.DEFAULT_GOAL := deploy
.PHONY: deploy repo status clean

deploy: repo ## install Loki (SingleBinary) and wait for it to be ready
	helm upgrade -i $(RELEASE) grafana/loki -n $(NS) --create-namespace -f values.yaml
	@sleep 5
	-kubectl -n $(NS) wait --for=condition=ready pod --all --timeout=300s
	@$(MAKE) -s status

repo: ## add/update the grafana helm repo
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update grafana

status: ## show the pods
	@kubectl -n $(NS) get pods

clean: ## uninstall the release and remove the namespace
	-helm -n $(NS) uninstall $(RELEASE)
	-kubectl delete ns $(NS) --ignore-not-found
