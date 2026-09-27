output "node_exporter" {
  description = "node_exporter box - metrics on :9100"
  value = {
    public_ip  = aws_instance.node_exporter.public_ip
    private_ip = aws_instance.node_exporter.private_ip
  }
}

output "prom_server_a" {
  description = "Prometheus A (forwarder) - UI on :9090"
  value = {
    public_ip  = aws_instance.prom_a.public_ip
    private_ip = aws_instance.prom_a.private_ip
    ui         = "http://${aws_instance.prom_a.public_ip}:9090"
  }
}

output "prom_server_b" {
  description = "Prometheus B (receiver) - UI on :9090"
  value = {
    public_ip  = aws_instance.prom_b.public_ip
    private_ip = aws_instance.prom_b.private_ip
    ui         = "http://${aws_instance.prom_b.public_ip}:9090"
  }
}
