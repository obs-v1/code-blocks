```bash

# Upgrde helm chart to monitor with Kubernetes Pushgateway enablement 
helm upgrade --install prometheus prometheus-community/prometheus -n monitoring
  --set server.service.type=NodePort --set server.service.nodePort=30990 -f https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/prom-04/prometheus-values.yaml 


# Let run some jobs 

curl https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/prom-04/setup-pushgateway-seed.sh | bash


```
