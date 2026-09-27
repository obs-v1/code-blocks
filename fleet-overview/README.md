# Fleet Overview — every bankobserve360 service, not just the Java ones

This dashboard keys off the labels **every** scraped service carries — `up`,
`app`, `domain` — so it shows the whole fleet regardless of language, including
the workers, consumers and databases that serve no HTTP requests at all.

It once existed for a second reason too: the RED dashboards queried
`http_server_requests_seconds`, a **Micrometer (Java/Spring)** metric, so they
only ever showed the ~20 Java services and looked like data was missing. That is
no longer true — every service now emits the canonical
`http_server_request_duration_seconds` with the same labels, so RED covers the
whole fleet. See `docs/operations/metrics-contract.md` in the platform repo.

## Load (one run)

```bash
make apply GRAFANA_URL=http://<node-ip>:13000 GRAFANA_AUTH=admin:admin
make destroy GRAFANA_URL=...
```

Needs Terraform ≥ 1.5 and a Grafana with the `prometheus` datasource.

## What it shows

- **Fleet at a glance** — services scraped / up / down, business domains, and a
  **services-by-language** bar (Java · Go · Python · Node), which is now a
  fleet-composition view rather than an explanation for missing RED data.
- **Service inventory** — a table with **one row per service**, whatever the
  language, coloured up/green / down/red, sorted by domain.
- **Up/down over time** — a state-timeline with every service as a row.
- **Traffic across the fleet** — request rate and 5xx error rate, both from the
  one canonical family, every language in the same panel. These used to be two
  per-language panels; the alignment work made that split unnecessary.
- **Services per domain** — the fleet by business area.

A `$domain` variable scopes everything to one business domain.

## The lesson

A single RED query can only cover a polyglot fleet if every language agrees on
the metric name **and** the label names. Left to their defaults they do not:
Micrometer emits `http_server_requests_seconds{uri,status="200",outcome}`, the
FastAPI instrumentator `http_requests_total{handler}`, and prom-client nothing at
all — which is why this dashboard once needed a panel per language.

The fix was to pin one contract and implement it in each shared library, so the
services themselves emit
`http_server_request_duration_seconds{service,method,path,status}`. Two things
still need this dashboard's `up`/`app`/`domain` approach, though: services with
**no traffic yet** publish no request series at all (a client library emits
nothing for a labelled family before its first observation), and **non-request
workloads** — workers, Kafka consumers, databases — have no RED to describe.
