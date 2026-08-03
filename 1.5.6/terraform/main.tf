# Dashboards as code with Terraform + the Grafana provider.
#
# Same idea as file provisioning, but managed through Terraform state: the
# datasource and every dashboard become declarative resources. `terraform apply`
# makes Grafana match the code; drift in the UI is corrected on the next apply.
#
#   terraform init
#   terraform apply -var 'grafana_url=http://<node-ip>:13000' -var 'grafana_auth=admin:admin'

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

# The datasource, with the STABLE uid the dashboards reference (see 1.5.1).
resource "grafana_data_source" "prometheus" {
  type       = "prometheus"
  name       = "Prometheus"
  uid        = "prometheus"
  url        = "http://prometheus-server.monitoring.svc"
  is_default = true
}

# Each dashboard is just its JSON, loaded from the sibling section folders.
resource "grafana_dashboard" "red_overview" {
  config_json = file("${path.module}/../../1.5.7/red-overview.json")
  overwrite   = true
}

resource "grafana_dashboard" "panels" {
  config_json = file("${path.module}/../../1.5.2/panels.json")
  overwrite   = true
}

resource "grafana_dashboard" "variables" {
  config_json = file("${path.module}/../../1.5.3/variables.json")
  overwrite   = true
}
