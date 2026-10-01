# 2.2.18 — a full per-pod parser for the whole bankobs fleet (json + raw).
#   make          deploy Loki + Promtail + Grafana, then verify all formats parse
#   make verify   prove json AND each raw format landed with the right labels
#   make ui       print the Grafana URL
#   make clean    uninstall everything
#
# Unique release names (own ClusterRoles) + its own namespace, so it does NOT
# collide with the 2.2 / 2.2.19 stacks in `monitoring`.
NS ?= logging

.DEFAULT_GOAL := setup
.PHONY: setup repo loki promtail grafana verify ui clean

setup: repo loki promtail grafana verify ## deploy the stack and verify the parsing

repo:
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo add grafana-community https://grafana-community.github.io/helm-charts/
	helm repo update

loki: ## single-binary Loki
	helm upgrade -i loki-pipeline grafana/loki -n $(NS) --create-namespace -f loki-values.yaml
	kubectl -n $(NS) rollout status statefulset/loki-pipeline --timeout=240s
	kubectl -n $(NS) rollout status deploy/loki-pipeline-gateway --timeout=120s

promtail: ## Promtail with the json/raw per-format pipeline
	helm upgrade -i promtail-pipeline grafana/promtail -n $(NS) -f promtail-values.yaml
	kubectl -n $(NS) rollout status ds/promtail-pipeline --timeout=120s
	@echo "give logs ~30s to land, then: make verify"

grafana: ## Grafana with the Loki datasource (browse what parsed)
	helm upgrade -i grafana-pipeline grafana-community/grafana --version 13.2.5 -n $(NS) --create-namespace -f grafana-values.yaml
	kubectl -n $(NS) rollout status deploy/grafana-pipeline --timeout=180s
	@$(MAKE) -s ui

verify: ## prove json + each raw format parsed with the right labels
	@sleep 25
	@kubectl -n $(NS) port-forward svc/loki-pipeline-gateway 3100:80 >/dev/null 2>&1 & \
	 PF=$$!; sleep 5; ./verify.sh http://localhost:3100; RC=$$?; kill $$PF 2>/dev/null; exit $$RC

ui: ## print the Grafana URL (admin/admin)
	@TOKEN=$$(curl -s -m 1 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null); \
	 IP=$$(curl -s -m 1 -H "X-aws-ec2-metadata-token: $$TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null); \
	 [ -z "$$IP" ] && IP=$$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null); \
	 echo "Grafana: http://$$IP:31301  (admin/admin) -> Explore -> Loki -> {namespace=\"bankobs\"}"

clean: ## uninstall the stack and remove the namespace
	-helm -n $(NS) uninstall grafana-pipeline promtail-pipeline loki-pipeline
	-kubectl delete ns $(NS) --ignore-not-found
