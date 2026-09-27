output "mimir_public_ip" {
  description = "Public IP of the Mimir box"
  value       = aws_instance.mimir.public_ip
}

output "mimir_private_ip" {
  value = aws_instance.mimir.private_ip
}

output "remote_write_url" {
  description = "Point your Prometheus remote_write here"
  value       = "http://${aws_instance.mimir.public_ip}:9009/api/v1/push"
}

output "query_url" {
  description = "Mimir speaks the Prometheus query API (send header X-Scope-OrgID: demo)"
  value       = "http://${aws_instance.mimir.public_ip}:9009/prometheus/api/v1/query?query=up"
}

output "values_file" {
  description = "Ready-to-use prometheus values with the IP filled in"
  value       = local_file.prom_values.filename
}
