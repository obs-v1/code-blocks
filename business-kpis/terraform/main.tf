# business-kpis — a business/KPI dashboard for bankobserve360, as code.
#
# Unlike RED/USE/Golden (which measure the plumbing), this reads the bank's
# OWN business counters emitted by the UPI service:
#   upi_transaction_total          — payments completed
#   upi_transaction_success_total  — payments that succeeded
#   upi_daily_volume_total         — cumulative rupees moved
#   upi_p99_latency_seconds        — payment latency histogram
#
#   terraform init
#   terraform apply -var 'grafana_url=http://<node-ip>:13000' -var 'grafana_auth=admin:admin'
#   terraform destroy ...
#
# (Usually driven through the Makefile: `make apply` / `make destroy`.)

terraform {
  required_version = ">= 1.5"
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 3.0"
    }
  }
}

provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_auth
}

# One dashboard per JSON file in ../dashboards (uid/title come from each JSON).
resource "grafana_dashboard" "biz" {
  for_each    = fileset("${path.module}/../dashboards", "*.json")
  config_json = file("${path.module}/../dashboards/${each.value}")
  overwrite   = true
}

output "loaded" {
  description = "Number of business dashboards Terraform manages"
  value       = length(grafana_dashboard.biz)
}
