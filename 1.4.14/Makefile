
setup:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade -i prometheus prometheus-community/prometheus -n monitoring -f https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/1.4.14/values.yaml --create-namespace

