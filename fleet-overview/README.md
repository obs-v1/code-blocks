# Fleet Overview — every bankobserve360 service, not just the Java ones

The RED dashboards (`1.5.7`, `1.6.9`) query **`http_server_requests_seconds`** —
a **Micrometer (Java/Spring) metric**. bankobserve360 is **polyglot**, so those
dashboards only ever show the ~20 Java services and look like data is missing.
It isn't: Prometheus scrapes the whole fleet. This dashboard proves it by keying
off the labels **every** service carries — `up`, `app`, `domain` — instead of a
Java-only metric.

## Load (one run)

```bash
make apply GRAFANA_URL=http://<node-ip>:13000 GRAFANA_AUTH=admin:admin
make destroy GRAFANA_URL=...
```

Needs Terraform ≥ 1.5 and a Grafana with the `prometheus` datasource.

## What it shows

- **Fleet at a glance** — services scraped / up / down, business domains, and a
  **services-by-language** bar (Java · Go · Python · Node) that explains at a
  glance why RED shows 20: only the Java tier speaks Micrometer.
- **Service inventory** — a table with **one row per service**, whatever the
  language, coloured up/green / down/red, sorted by domain.
- **Up/down over time** — a state-timeline with every service as a row.
- **Traffic across the polyglot fleet** — two panels, because the metric names
  differ: Java via `http_server_requests_seconds` (label `service`), and
  Go/Python/OTel via `http_requests_total` / `http_request_duration_seconds`
  (label `app`).
- **Services per domain** — the fleet by business area.

A `$domain` variable scopes everything to one business domain.

## The lesson

A single RED query can't cover a polyglot fleet — the metric names and label
schemes differ per language. To get **one** unified RED across all 61 services
you need **consistent instrumentation** (OpenTelemetry HTTP semconv on every
service). Until then: use `up`/`app`/`domain` for fleet health (this dashboard),
per-language panels for request metrics, and per-workload signals for the
non-request services (workers, consumers, DBs) that RED can't describe at all.
