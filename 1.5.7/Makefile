# 1.5.7 — provision ONLY the RED overview dashboard
#
#   Prereq: a Grafana with the Prometheus datasource (uid: prometheus) running.
#           Stand one up once with:   (cd ../1.5.1 && make)
#
#   make            # import just THIS dashboard into Grafana (nothing else)
#   make verify     # confirm it is present
#   make delete     # remove just THIS dashboard
#
GRAFANA_URL ?= http://localhost:13000
ADMIN       ?= admin:admin
DASH        := red-overview.json
UID         := obs-red

.DEFAULT_GOAL := apply
.PHONY: apply verify delete

apply: ## import ONLY this dashboard (leaves any others untouched)
	@jq '{dashboard: ., overwrite: true}' $(DASH) \
	 | curl -sf -u $(ADMIN) -X POST "$(GRAFANA_URL)/api/dashboards/db" \
	     -H "Content-Type: application/json" -d @- \
	 | jq -r '"  imported \(.uid)  ->  $(GRAFANA_URL)\(.url)"'

verify: ## confirm this dashboard is present
	@curl -sf -u $(ADMIN) "$(GRAFANA_URL)/api/dashboards/uid/$(UID)" \
	 | jq -r '"  \(.dashboard.uid): \(.dashboard.title)"'

delete: ## remove ONLY this dashboard
	@curl -sf -u $(ADMIN) -X DELETE "$(GRAFANA_URL)/api/dashboards/uid/$(UID)" \
	 | jq -r '"  \(.title // .message) deleted"'
