# 2.2.10 — Promtail -> Loki pipeline, with LogQL drills
#
#   make          # deploy Loki + Promtail + Grafana + the leaky demo app
#   make verify   # LogQL drills + prove healthchecks dropped & password scrubbed
#   make ui       # print the Grafana URL (Explore -> Loki for LogQL by hand)
#   make logql    # port-forward the Loki API directly (curl / a datasource)
#   make destroy  # tear it all down
#
NS ?= monitoring

.DEFAULT_GOAL := setup
.PHONY: setup repo loki promtail grafana app verify ui logql destroy

setup: repo app loki promtail grafana ## deploy everything

repo: ## add the grafana + grafana-community helm repos
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo add grafana-community https://grafana-community.github.io/helm-charts/
	helm repo update grafana grafana-community

app: ## deploy the deliberately-leaky demo (password + healthcheck lines)
	kubectl apply -f leaky-app.yaml
	kubectl -n demo rollout status deploy/leaky-app --timeout=120s

loki: ## single-binary Loki store
	helm upgrade -i loki grafana/loki -n $(NS) --create-namespace -f loki-values.yaml
	kubectl -n $(NS) rollout status statefulset/loki --timeout=240s

promtail: ## Promtail shipper with the parse/drop/scrub/timestamp/promote pipeline
	helm upgrade -i promtail grafana/promtail -n $(NS) -f promtail-values.yaml
	kubectl -n $(NS) rollout status ds/promtail --timeout=120s
	@echo "give logs ~30s to land, then: make verify"

grafana: ## Grafana with the Loki datasource provisioned as code
	helm upgrade -i grafana grafana-community/grafana --version 13.2.5 -n $(NS) --create-namespace -f grafana-values.yaml
	kubectl -n $(NS) rollout status deploy/grafana --timeout=180s
	@$(MAKE) -s ui

verify: ## LogQL drills + the two absence assertions
	@kubectl -n $(NS) port-forward svc/loki-gateway 3100:80 >/dev/null 2>&1 & \
	 PF=$$!; sleep 4; ./verify.sh http://localhost:3100; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

ui: ## print the Grafana URL (admin/admin) — Explore -> Loki to run LogQL
	@TOKEN=$$(curl -s -m 1 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null); \
	 IP=$$(curl -s -m 1 -H "X-aws-ec2-metadata-token: $$TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(curl -s -m 1 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null); \
	 echo "Grafana: http://$$IP:31300   (admin / admin)"; \
	 echo "  if that IP isn't reachable:  kubectl -n $(NS) port-forward svc/grafana 13000:80  ->  http://localhost:13000"; \
	 echo "  then Explore -> Loki datasource -> run LogQL from 2.2.5-2.2.7"

logql: ## port-forward Loki so you can run LogQL (curl or a Grafana Loki datasource)
	@echo "Loki API at http://localhost:3100  (Ctrl-C to stop)"
	kubectl -n $(NS) port-forward svc/loki-gateway 3100:80

destroy: ## remove Grafana, Loki, Promtail, and the demo
	-helm -n $(NS) uninstall grafana
	-helm -n $(NS) uninstall promtail
	-helm -n $(NS) uninstall loki
	-kubectl delete -f leaky-app.yaml
