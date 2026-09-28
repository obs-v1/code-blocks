
setup:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade -i prometheus prometheus-community/prometheus -n monitoring -f https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/1.4.11/values.yaml --create-namespace

# The alerting rules Prometheus loaded (health should be "ok")
rules:
	kubectl -n monitoring exec deploy/prometheus-server -c prometheus -- \
	  wget -qO- http://localhost:9090/api/v1/rules | head -c 1500; echo

# Current alert states (watch PaymentsMetricsMissing go pending -> firing)
alerts:
	kubectl -n monitoring exec deploy/prometheus-server -c prometheus -- \
	  wget -qO- http://localhost:9090/api/v1/alerts ; echo

# Force a config reload if the projected file hasn't synced yet
reload:
	kubectl -n monitoring rollout restart deploy/prometheus-server
