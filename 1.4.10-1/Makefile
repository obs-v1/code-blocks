RAW = https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/1.4.10-1

# Install the Prometheus Operator (kube-prometheus-stack), then apply the
# recording rules as a PrometheusRule CRD. The Operator discovers it by its
# `release` label and writes it into Prometheus — no ConfigMap, no reload.
setup:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade -i kube-prometheus-stack prometheus-community/kube-prometheus-stack \
	  -n monitoring --create-namespace -f $(RAW)/values.yaml
	kubectl apply -f $(RAW)/recording-rules.yaml

# Apply just the rules from the local file (after you've edited it)
apply:
	kubectl apply -f recording-rules.yaml

# The PrometheusRule object the Operator sees
crds:
	kubectl -n monitoring get prometheusrules

# The rules Prometheus actually loaded
rules:
	kubectl -n monitoring exec sts/prometheus-kube-prometheus-stack-prometheus -c prometheus -- \
	  wget -qO- http://localhost:9090/api/v1/rules | head -c 1500; echo

# Prove a recorded series now exists
verify:
	kubectl -n monitoring exec sts/prometheus-kube-prometheus-stack-prometheus -c prometheus -- \
	  wget -qO- 'http://localhost:9090/api/v1/query?query=job:prometheus_http_requests:rate5m' ; echo
