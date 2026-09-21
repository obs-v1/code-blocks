# transformations-examples — one dashboard per Grafana-13 transformation
#
#   make load      # import every dashboard into Grafana via the API
#   make list      # list what got loaded
#   make delete    # remove them all
#   make build     # regenerate dashboards/ + README.md from build_dashboards.py
#
# Point it at your Grafana (defaults suit the course's kind setup, host :13000):
#   make load GRAFANA_URL=http://<node-ip>:13000 GRAFANA_AUTH=admin:admin
# GRAFANA_AUTH accepts "user:pass" or "Bearer <service-account-token>".
#
GRAFANA_URL  ?= http://localhost:13000
GRAFANA_AUTH ?= admin:admin
export GRAFANA_URL GRAFANA_AUTH

.DEFAULT_GOAL := load
.PHONY: load list delete build

load: ## import every transformation dashboard
	python3 apply.py load

list: ## list loaded transformation dashboards
	python3 apply.py list

delete: ## remove every transformation dashboard
	python3 apply.py delete

build: ## regenerate dashboards/ and README.md
	python3 build_dashboards.py
