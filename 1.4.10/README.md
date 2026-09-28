# 1.4.10 — Recording rules: naming, and when to materialize

A recording rule computes a query **once, on a schedule**, and stores the result
as a brand-new metric. Everything downstream then reads a small, ready-made
series instead of re-deriving it — the cost moves from **query-time** (paid on
every dashboard refresh, by everyone) to **ingestion-time** (paid once).

## Install

Installs the full `prometheus-community/prometheus` chart with the recording
rules in [`values.yaml`](values.yaml):

```bash
make setup
```

or directly:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade -i prometheus prometheus-community/prometheus -n monitoring \
  -f https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/1.4.10/values.yaml \
  --create-namespace
```

## See it work

```bash
make rules     # the rules Prometheus loaded (health should be "ok")
make verify    # query the recorded series job:prometheus_http_requests:rate5m
```

In the UI (`http://<node>:30990`): **Status → Rules** lists the groups, and a
query for `job:prometheus_http_requests:rate5m` returns the pre-computed series —
compare it to running `sum(rate(prometheus_http_requests_total[5m])) by (job)`
yourself; same numbers, a fraction of the work.

## The naming convention — `level:metric:operation`

Recorded series are self-describing. Read left to right:

```
job:http_requests:rate5m
└─ level      └─ metric        └─ operation
```

At a glance: a **per-job**, **5-minute rate** of **http_requests_total** — no
need to open the rule to know what it holds. The `values.yaml` follows this for
every rule (`instance:prometheus_tsdb_head_series:sum`, `job:up:ratio`, …).

## When to materialize — and when not

| Materialize | Don't materialize |
|---|---|
| Heavy aggregations (scan many series) | Cheap queries (a rule adds series to store) |
| Expressions many dashboards share | One-off explorations |
| Anything an alert evaluates on a tight interval | Anything that saves nothing |
| Rolled-up series kept for long-term storage | |

## The tiered-storage pattern

A recording rule alone makes **queries** cheaper, not **storage**. To shrink
storage too: record the rolled-up series, then **drop the raw high-cardinality
one** underneath it at scrape time. You keep the summary you query and stop
paying for the detail you don't — that pairing is how teams keep months of
history affordable. See the commented `metric_relabel_configs` block at the
bottom of [`values.yaml`](values.yaml).
