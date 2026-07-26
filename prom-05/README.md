```bash

# This is the process that actually performs the probes. It ships with the built-in http_2xx module, so no exporter config is needed.

helm install blackbox prometheus-community/prometheus-blackbox-exporter \
    -n monitoring --create-namespace

helm upgrade -i prometheus prometheus-community/prometheus -n monitoring --create-namespace \
    --set server.service.type=NodePort --set server.service.nodePort=30990 \
    -f https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/prom-05/prometheus-values.yaml 

```
