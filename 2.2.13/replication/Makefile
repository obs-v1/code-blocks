# 2.2.13 — replication.  `make` deploys Loki (3 ingesters, RF=3) AND proves that
# killing an ingester loses no data.  `make clean` uninstalls.
NS      ?= loki-replication
RELEASE ?= loki

.DEFAULT_GOAL := demo
.PHONY: demo deploy repo verify clean

demo: deploy verify ## deploy + prove no data loss when an ingester dies

deploy: repo ## install Loki (SimpleScalable, write=3, RF=3, MinIO)
	helm upgrade -i $(RELEASE) grafana/loki -n $(NS) --create-namespace -f values.yaml
	kubectl -n $(NS) rollout status statefulset/$(RELEASE)-write --timeout=480s

repo: ## add/update the grafana helm repo
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update grafana

verify: ## push logs, kill an ingester, prove the logs survive (needs jq)
	@kubectl -n $(NS) port-forward svc/$(RELEASE)-gateway 3100:80 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:3100 $(NS); RC=$$?; kill $$PF 2>/dev/null; exit $$RC

clean: ## uninstall the release and remove the namespace
	-helm -n $(NS) uninstall $(RELEASE)
	-kubectl delete ns $(NS) --ignore-not-found
