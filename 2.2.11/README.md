# 2.2.11 — Loki deployment modes: the same Loki, three topologies

One subfolder per `deploymentMode` from section 2.2.11. Each installs the **same
`grafana/loki` Helm chart**, differing only in how the components are split
across pods. In each folder, **`make` deploys everything** and **`make clean`
uninstalls** (release + namespace).

| Folder | `deploymentMode` | What runs | When |
|--------|------------------|-----------|------|
| [`singlebinary/`](singlebinary/) | `SingleBinary` | one `loki` pod (filesystem) | the lab; fine into a few GB/day |
| [`simplescalable/`](simplescalable/) | `SimpleScalable` | **write** (distributor+ingester), **read** (querier+query-frontend), **backend** (compactor·ruler·index-gateway) + MinIO | the production default for most shops |
| [`distributed/`](distributed/) | `Distributed` | every component its own deployment + MinIO | only at very large scale |

## Run one

```bash
cd singlebinary      # or simplescalable / distributed
make                 # add repo, install the chart, wait, show pods
make status          # re-show the pods
make clean           # uninstall + delete the namespace
```

Each mode uses its **own namespace** (`loki-single` / `loki-scalable` /
`loki-distributed`), so you can run them side by side and compare `make status`.

## Why SimpleScalable and Distributed enable MinIO

SingleBinary keeps chunks on a local PVC — fine for one pod. The moment Loki is
split across pods (SimpleScalable, Distributed) the roles must share **one**
object store, or a read pod can't find what a write pod flushed. These two
folders enable the chart's **bundled MinIO** (`minio.enabled: true`) so the lab
works without a real S3/GCS bucket. In production you'd point `loki.storage` at
actual object storage instead.

## Notes

- Same chart everywhere (`grafana/loki`); only `deploymentMode` + the per-role
  replica counts change. Compare the three `values.yaml` files side by side —
  that diff *is* the lesson.
- Replica counts are lab-sized (1-2). Production scales `write`/`read`/`backend`
  (SimpleScalable) or the individual microservices (Distributed), and sets
  `replication_factor: 3`.
- Reach the API with `kubectl -n <ns> port-forward svc/loki-gateway 3100:80`.
- Distributed brings up the most pods — give a small box a minute, and watch
  with `kubectl -n loki-distributed get pods -w`.
