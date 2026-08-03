# 1.5.5 — Transformations: reshaping data inside Grafana

Sometimes the shape you want isn't the shape PromQL returns. **Transformations**
reshape query results *after* they arrive — join, rename, filter, calculate — with
no change to the query language. `transformations.json` builds a single RED table
out of three separate queries.

## What it does
Three instant queries, each one value per service:
```promql
A:  sum by (service) (rate(http_server_requests_seconds_count[5m]))                       # req/s
B:  sum by (service) (rate(http_server_requests_seconds_count{outcome!="SUCCESS"}[5m]))   # errors/s
C:  histogram_quantile(0.95, sum by (service,le) (rate(http_server_requests_seconds_bucket[5m])))  # p95
```
Then two transformations turn them into one table:
1. **Join by field** on `service` → one row per service, three value columns.
2. **Organize fields** → drop the `Time` columns and rename `Value #A/B/C` to
   `req/s`, `errors/s`, `p95 latency (s)`.

Field overrides then colour the `errors/s` cell red when non-zero and set units.

## Why it matters
You could contort PromQL to produce this, or you could let Grafana join and label —
which is clearer and keeps each query single-purpose. Reshaping is a *presentation*
job; transformations are where it belongs.

## Provision & view
With a Grafana + datasource running (`cd ../1.5.1 && make`), import **only this
dashboard**:
```bash
make apply GRAFANA_URL=http://<node-ip>:13000
```
Open uid `obs-transforms`. (All 1.5 dashboards at once: the **`../1.5.8`** lab.)

**Verified**: the join produces one row per service on the live fleet. (The
`errors/s` column reads 0 while the fleet is healthy — it fills in the moment a
service starts failing.)
