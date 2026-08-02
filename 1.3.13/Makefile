# 1.3.13 — opt-in annotation pattern demo
#
#   make            # deploy Prometheus + the two demo apps
#   make verify     # prove only the annotated pod is scraped
#   make destroy    # tear it all down
#
NS       ?= monitoring
PROM_URL ?= http://localhost:9090

.DEFAULT_GOAL := setup
.PHONY: setup repo prometheus app verify destroy

setup: repo prometheus app ## deploy everything

repo: ## add the prometheus-community helm repo
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update prometheus-community

prometheus: ## install Prometheus with the annotation scrape job
	helm upgrade -i prometheus prometheus-community/prometheus \
	  -n $(NS) --create-namespace -f prometheus-values.yaml
	kubectl -n $(NS) rollout status deploy/prometheus-server --timeout=180s

app: ## deploy the annotated + plain demo workloads
	kubectl apply -f demo-app.yaml
	kubectl -n demo rollout status deploy/example-annotated --timeout=120s
	kubectl -n demo rollout status deploy/example-plain --timeout=120s

verify: ## cross-check: only the annotated pod is scraped
	./verify.sh $(PROM_URL)

destroy: ## remove the demo apps and Prometheus
	-kubectl delete -f demo-app.yaml
	-helm -n $(NS) uninstall prometheus
