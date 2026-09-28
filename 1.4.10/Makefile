
setup:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade -i prometheus prometheus-community/prometheus -n monitoring -f https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/1.4.10/values.yaml --create-namespace

# See the rules Prometheus loaded (state should be "ok" / health "ok")
rules:
	kubectl -n monitoring exec deploy/prometheus-server -c prometheus -- \
	  wget -qO- http://localhost:9090/api/v1/rules | head -c 1200; echo

# Prove a recorded series now exists (should return data once evaluated)
verify:
	kubectl -n monitoring exec deploy/prometheus-server -c prometheus -- \
	  wget -qO- 'http://localhost:9090/api/v1/query?query=job:prometheus_http_requests:rate5m' ; echo
