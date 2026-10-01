# 2.2.13 — multi-tenancy.  `make` deploys Loki (auth on) AND proves tenant
# isolation.  `make clean` uninstalls.
NS      ?= loki-tenancy
# unique release name per lab - unique: the chart's ClusterRole is release-named, so two "loki" releases collide across namespaces
RELEASE ?= loki-tenancy

.DEFAULT_GOAL := demo
.PHONY: demo deploy repo verify clean

demo: deploy verify ## deploy + prove two tenants are isolated

deploy: repo ## install Loki with auth_enabled: true
	helm upgrade -i $(RELEASE) grafana/loki -n $(NS) --create-namespace -f values.yaml
	kubectl -n $(NS) rollout status statefulset/$(RELEASE) --timeout=300s

repo: ## add/update the grafana helm repo
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update grafana

verify: ## push to team-a + team-b, prove isolation (needs jq)
	@kubectl -n $(NS) port-forward svc/$(RELEASE)-gateway 3100:80 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:3100; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

clean: ## uninstall the release and remove the namespace
	-helm -n $(NS) uninstall $(RELEASE)
	-kubectl delete ns $(NS) --ignore-not-found
