# 1.6.9 — build the full RED dashboard set for bankobserve360 in one run.
#
# One grafana_dashboard resource fans out over every JSON in ../dashboards with
# for_each, so a single `terraform apply` creates all six RED dashboards. Same
# "dashboards as code" approach as 1.5.6 / transformations-examples.
#
#   terraform init
#   terraform apply -var 'grafana_url=http://<node-ip>:13000' -var 'grafana_auth=admin:admin'
#   terraform destroy ...        # removes them all
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
resource "grafana_dashboard" "red" {
  for_each    = fileset("${path.module}/../dashboards", "*.json")
  config_json = file("${path.module}/../dashboards/${each.value}")
  overwrite   = true
}

output "loaded" {
  description = "Number of RED dashboards Terraform manages"
  value       = length(grafana_dashboard.red)
}
