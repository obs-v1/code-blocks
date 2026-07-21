1. Create a EC2 Server 
2. Login to server and execute this to install exporters.

```bash
curl https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/prom-02/install-exporters.sh | sudo bash 
```

3. Validate the exporters running status. 

```bash
ss -lntp
```

4. On the K8S ec2 node.

```bash
# Download the prometheus input file 
curl -L -O https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/prom-01/prometheus-values.yaml

# Update the IP address of static config

# Update the helm chart 
helm upgrade -i prometheus prometheus-community/prometheus -n monitoring --set server.service.type=NodePort --set server.service.nodePort=30990 -f prometheus-values.yaml
```

