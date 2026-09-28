RAW = https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/1.4.11-1

# Install the Prometheus Operator (kube-prometheus-stack), then apply the rules
# as PrometheusRule CRDs. The Operator discovers them by their `release` label
# and writes them into Prometheus for you — no ConfigMap, no reload.
setup:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade -i kube-prometheus-stack prometheus-community/kube-prometheus-stack \
	  -n monitoring --create-namespace -f $(RAW)/values.yaml
	kubectl apply -f $(RAW)/recording-rules.yaml
	kubectl apply -f $(RAW)/alerting-rules.yaml

# Apply just the rules from the local files (after you've edited them)
apply:
	kubectl apply -f recording-rules.yaml
	kubectl apply -f alerting-rules.yaml

# The PrometheusRule objects the Operator sees
crds:
	kubectl -n monitoring get prometheusrules

# The rules Prometheus actually loaded (via the Operator)
rules:
	kubectl -n monitoring exec sts/prometheus-kube-prometheus-stack-prometheus -c prometheus -- \
	  wget -qO- http://localhost:9090/api/v1/rules | head -c 1500; echo

# Current alert states (watch PaymentsMetricsMissing go pending -> firing)
alerts:
	kubectl -n monitoring exec sts/prometheus-kube-prometheus-stack-prometheus -c prometheus -- \
	  wget -qO- http://localhost:9090/api/v1/alerts ; echo
