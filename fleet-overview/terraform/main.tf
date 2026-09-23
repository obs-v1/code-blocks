# Fleet Overview — load the whole-fleet dashboard into Grafana in one run.
# Same "dashboards as code" approach as 1.5.6 / 1.6.9 / transformations-examples.
#
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

resource "grafana_dashboard" "fleet" {
  for_each    = fileset("${path.module}/../dashboards", "*.json")
  config_json = file("${path.module}/../dashboards/${each.value}")
  overwrite   = true
}

output "loaded" {
  value = length(grafana_dashboard.fleet)
}
