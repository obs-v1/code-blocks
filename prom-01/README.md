```
# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
# helm repo update
# helm upgrade prometheus prometheus-community/prometheus -n monitoring --set server.service.type=NodePort --set server.service.nodePort=30990 -f https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/prom-01/prometheus-values.yaml
```
