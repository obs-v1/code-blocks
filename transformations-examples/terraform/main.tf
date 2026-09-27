# Load every transformation-example dashboard into Grafana, as code.
#
# Same "dashboards as code" idea as 1.5.6, but here one Terraform resource
# fans out over every JSON file in ../dashboards with for_each — drop a new
# dashboard in that folder and the next `terraform apply` loads it too.
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

# One grafana_dashboard per JSON file in ../dashboards.
# fileset() lists them; each dashboard's uid/title come from its own JSON.
resource "grafana_dashboard" "transform" {
  for_each    = fileset("${path.module}/../dashboards", "*.json")
  config_json = file("${path.module}/../dashboards/${each.value}")
  overwrite   = true
}

output "loaded" {
  description = "Number of transformation dashboards Terraform manages"
  value       = length(grafana_dashboard.transform)
}
