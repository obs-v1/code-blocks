# 1.5.8 — Lab: a fully provisioned Grafana

The capstone for chapter 1.5. One command stands up a **complete, reproducible
Grafana** — the Prometheus datasource *and* every dashboard from 1.5.2–1.5.7 —
with nothing clicked. This is what "dashboards as code" (1.5.6) looks like end to end.

```
  helm install grafana ──► Grafana ──► datasource "prometheus" (provisioned, 1.5.1)
                             │
       labelled ConfigMaps ──┘  sidecar loads: panels · variables · annotations ·
       (one per dashboard)      transformations · RED overview
```

## What's here

| File | Purpose |
|------|---------|
| `grafana-values.yaml` | Grafana on NodePort, datasource provisioned, dashboard **sidecar** enabled |
| `Makefile` | `make` / `make verify` / `make destroy` |
| `verify.sh` | checks datasource + all 5 dashboards + live data |

## Prereqs
A Kubernetes cluster with `kubectl`/`helm` and **Prometheus running** in the
`monitoring` namespace scraping your workloads (e.g. `../1.3.15`). Validated on
single-node `kind`, Grafana on NodePort `31300` → host `:13000`.

## Run
```bash
make setup      # load every dashboard as a ConfigMap, then install Grafana
```
`make dashboards` creates one **labelled ConfigMap** (`grafana_dashboard=1`) per
dashboard JSON from the sibling folders; Grafana's sidecar watches that label and
loads them into the *Observability Course* folder.

## Access
Open **http://&lt;node-ip&gt;:13000** (admin / admin). Under Dashboards →
*Observability Course* you'll find all five, and the Prometheus datasource is
already there — none of it added by hand.

## Verify
```bash
make verify GRAFANA_URL=http://<node-ip>:13000
```
Expected:
```
== provisioned datasource ==   Prometheus  uid=prometheus  default=true
== provisioned dashboards ==
  obs-panels       -> 1.5.2 — Panels: matching the visual to the question
  obs-variables    -> 1.5.3 — Variables: one dashboard, many contexts
  obs-annotations  -> 1.5.4 — Annotations: marking events on graphs
  obs-transforms   -> 1.5.5 — Transformations: reshaping data inside Grafana
  obs-red          -> 1.5.7 — RED overview (dashboard design done right)
== live data through the datasource proxy (fleet req/s) ==
  fleet request rate = N req/s
PASS — datasource + all 5 dashboards provisioned, and Grafana is reading live fleet metrics.
```

## Tear down
```bash
make destroy
```

---

**Verified 2026-08-03** on single-node kind (k8s v1.36, Grafana 12.3.1): datasource
provisioned, all 5 dashboards loaded, and an `up`/RED query round-tripped through
the datasource proxy (fleet ≈ 5 req/s across 35 services).
