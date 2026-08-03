# 1.5.6 — Dashboards as code

A dashboard is just a **JSON document**. Once you accept that, "clicking to build
dashboards" stops being the workflow and *provisioning JSON* takes over — versioned,
reviewed, and identical in every environment. This folder shows the three common
ways to do it.

## 1) File provisioning (the backbone)
`dashboard-provider.yaml` tells Grafana to watch a directory of dashboard JSON on
startup. Drop a `*.json` in the folder → the dashboard appears. No UI, no API.
```yaml
apiVersion: 1
providers:
  - name: obs-course
    type: file
    options: { path: /var/lib/grafana/dashboards/obs-course }
```
This is exactly what the **`../1.5.8`** capstone uses (via labelled ConfigMaps and
the Grafana dashboard sidecar) to load every dashboard in the chapter.

## 2) Terraform (`terraform/`)
Manage the datasource and each dashboard as declarative resources with the
`grafana/grafana` provider. `apply` makes Grafana match the code; UI drift is
corrected on the next run.
```bash
cd terraform
terraform init
terraform apply -var 'grafana_url=http://<node-ip>:13000' -var 'grafana_auth=admin:admin'
```
`main.tf` provisions the `uid: prometheus` datasource and loads the sibling
dashboard JSONs with `grafana_dashboard`.

## 3) Grafonnet (`red.jsonnet`)
Don't hand-write JSON — **generate** it. Grafonnet is a typed Jsonnet library; a
single function can stamp out a panel (or a whole RED row) for every service in a
loop.
```bash
jb install github.com/grafana/grafonnet/gen/grafonnet-latest@main
jsonnet -J vendor red.jsonnet > red-generated.json    # then provision the JSON
```

## The through-line
All three end at the same place: **JSON is the source of truth.** Give datasources
stable UIDs (1.5.1), keep dashboards in git, and the whole observability UI becomes
reproducible.

> The Terraform and Grafonnet examples are illustrative references (they need their
> own provider/toolchain to run). The file-provisioning path is the one the 1.5.8
> lab actually deploys and verifies.
