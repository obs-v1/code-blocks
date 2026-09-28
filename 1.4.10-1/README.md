# 1.4.10-1 — Recording rules the Operator way: a PrometheusRule CRD

Same recording rules as 1.4.10, but delivered as a **`PrometheusRule` custom
resource** instead of a chart's `serverFiles`. This is how you manage rules under
the **Prometheus Operator** (kube-prometheus-stack): you `kubectl apply` a CRD,
the Operator discovers it by a **label**, and writes it into Prometheus — no
ConfigMap edit, no manual reload.

| serverFiles way (1.4.10) | Operator way (here) |
|---|---|
| Rules live in Helm `values.yaml` | Rules are a `PrometheusRule` object you `kubectl apply` |
| Reload after a ConfigMap sync (can lag) | Operator reconciles in seconds |
| One chart owns the rules | Any team can ship rules from their own namespace |

## How discovery works

The Prometheus CR has a `ruleSelector`. kube-prometheus-stack's default selects
`PrometheusRule` objects labelled **`release: <helm-release-name>`**, so the file
here carries:

```yaml
metadata:
  labels:
    release: kube-prometheus-stack   # <-- matched by the Prometheus ruleSelector
```

## Install

```bash
make setup
```

Installs the Operator + Prometheus (NodePort 30990 via [`values.yaml`](values.yaml))
and applies [`recording-rules.yaml`](recording-rules.yaml). Iterating later:

```bash
make apply     # kubectl apply the local recording-rules.yaml
```

## See it work

```bash
make crds      # the PrometheusRule object the Operator sees
make rules     # the rules Prometheus actually loaded
make verify    # query the recorded series job:prometheus_http_requests:rate5m
```

In the UI (`http://<node>:30990` → **Status → Rules**) the group appears, and a
query for `job:prometheus_http_requests:rate5m` returns the pre-computed series —
compare it to `sum(rate(prometheus_http_requests_total[5m])) by (job)`; same
numbers, a fraction of the work.

## The naming convention — `level:metric:operation`

```
job:http_requests:rate5m
└─ level      └─ metric        └─ operation
```

Read at a glance: a **per-job**, **5-minute rate** of **http_requests_total**.
Every rule in this file follows it (`instance:prometheus_tsdb_head_series:sum`,
`job:up:ratio`, …).

## When to materialize — and when not

| Materialize | Don't materialize |
|---|---|
| Heavy aggregations (scan many series) | Cheap queries (a rule adds series to store) |
| Expressions many dashboards share | One-off explorations |
| Anything an alert evaluates on a tight interval | Anything that saves nothing |
| Rolled-up series kept for long-term storage | |

## The tiered-storage pattern (Operator flavour)

A recording rule alone makes **queries** cheaper, not **storage**. To shrink
storage too: record the rolled-up series (here), then **drop the raw
high-cardinality one** at scrape time. Under the Operator the drop lives on the
scrape object, not a global `prometheus.yml` — add `metricRelabelings` to the
`ServiceMonitor`/`PodMonitor` that scrapes the raw metric:

```yaml
# in the ServiceMonitor for the app that exposes http_requests_total
spec:
  endpoints:
    - port: web
      metricRelabelings:
        - sourceLabels: [__name__]
          regex: http_requests_total       # the raw series, now rolled up
          action: drop
```

You keep the summary you query and stop paying for the detail you don't.
