# 1.5.1 — Grafana datasources & provisioning

Grafana stores **nothing** — it is a query-and-visualisation layer that reads from
*datasources*. This demo stands up Grafana with its Prometheus datasource added the
**production way**: provisioned from a file, with a **stable UID**, so any dashboard
that references `uid: prometheus` works unchanged in every environment.

```
  Grafana  ──queries──►  datasource "Prometheus" (uid: prometheus)  ──►  Prometheus
   (stores nothing)        provisioned from a file, not the UI
```

## What's here

| File | Purpose |
|------|--------|
| `grafana-values.yaml` | Grafana (helm) exposed on a NodePort, with the Prometheus datasource **provisioned** inline |
| `Makefile` | `make` |

## Prereqs

- A Kubernetes cluster with `kubectl` + `helm`, and a **Prometheus already running**
  in the `monitoring` namespace (e.g. from `code-blocks/1.3.15`, or any Prometheus —
  just point the datasource `url` at its service).
- Validated on single-node `kind`, with Grafana on NodePort `31300` → host `:13000`.

## Run

```bash
make setup      # helm-install Grafana with the provisioned datasource
```

## Access

Open **http://&lt;node-ip&gt;:13000** and log in with **admin / admin**
(lab credentials — set in `grafana-values.yaml`). The Prometheus datasource is
already there under **Connections → Data sources**, marked *default* and
*provisioned* — you never clicked to add it.

## The provisioning, explained

The `datasources:` block in `grafana-values.yaml` is the whole lesson:

```yaml
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        uid: prometheus                 # stable UID — dashboards reference THIS
        type: prometheus
        access: proxy
        url: http://prometheus-server.monitoring.svc
        isDefault: true
```

The chart writes that to `/etc/grafana/provisioning/datasources/` inside the pod,
and Grafana loads it on startup. Because the `uid` is fixed and meaningful, a
dashboard exported from here imports cleanly into staging or prod — every
environment exposes a datasource with the same `uid: prometheus`. Random
per-install UIDs are exactly what break exported dashboards.

`datasources.yaml` extends the same pattern to **Loki** (logs) and **Jaeger**
(traces) — uncomment/point them at those backends when you run them, and Grafana
can correlate metrics, logs, and traces on one screen.

