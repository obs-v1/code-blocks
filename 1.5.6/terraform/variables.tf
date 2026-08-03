variable "grafana_url" {
  description = "Base URL of the Grafana instance, e.g. http://<node-ip>:13000"
  type        = string
}

variable "grafana_auth" {
  description = "Grafana admin auth as user:password (lab default admin:admin)"
  type        = string
  default     = "admin:admin"
  sensitive   = true
}
