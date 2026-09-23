# 1.6.9 — Lab: a RED dashboard for the 75-service fleet

The Week-1 capstone. RED (**R**ate · **E**rrors · **D**uration) describes anything
that serves requests; this lab applies it to the whole **bankobserve360** fleet —
**and** handles the awkward parts RED can't: saturation, queues and batch jobs.
Everything is built in one `make apply`, the "dashboards as code" way (Terraform +
the `grafana/grafana` provider), the same as `1.5.6` and `transformations-examples`.

Every dashboard queries the provisioned bank Prometheus (`uid: prometheus`, e.g.
from `1.5.1`), off Micrometer's `http_server_requests_seconds_*` plus the JVM /
pool / CPU metrics Spring Boot exports by default.

## Load — one run creates every dashboard

Prereqs: Terraform ≥ 1.5 and a reachable Grafana with the `prometheus` datasource.

```bash
make apply   GRAFANA_URL=http://<node-ip>:13000 GRAFANA_AUTH=admin:admin
make plan    GRAFANA_URL=...    # preview
make destroy GRAFANA_URL=...    # remove them all
```

`GRAFANA_AUTH` takes `user:password` or a service-account token. It's
`terraform apply` fanning out over `dashboards/*.json` with `for_each`
(`terraform/main.tf`) — drop another JSON in `dashboards/` and it loads too.

## The dashboards, mapped to the lab drills

RED cut two ways — **by signal** and **by scope** — plus the "awkward parts."

| uid | Dashboard | Lab drill |
|-----|-----------|-----------|
| `red-overview` | RED — Overview (3 numbers + trends) | 1 · Fleet RED overview |
| `red-fleet` | RED — Fleet at a glance (R·E·D per service, joined table) | 1 · which service is the problem |
| `red-service` | RED — Per-service `$service` drill-down | 1 · zoom into one service |
| `red-rate` | RED — Rate (by service / method / endpoint) | depth for R |
| `red-errors` | RED — Errors (rate, %, success%, by status) | 2 · error definition (5xx / 4xx via `status`, `outcome`) |
| `red-duration` | RED — Duration (p50/95/99, heatmap, **tail-gap p99−p50**) | 4 · percentile-gap, hunt wide tails |
| `red-golden` | **Golden-Signals health strip** (latency · traffic · errors · saturation) | 6 · the four-signal top strip |
| `red-saturation` | **Saturation per service class** (API threads · DB pool · CPU · heap) | 3 · a different formula per tier |
| `red-misfits` | **The misfits** (queue depth · consumer lag · batch time-since-success) | 5 · systems RED can't describe |

Dashboards with a `$service` template variable re-scope to any of the 75;
`red-fleet` always shows the whole fleet.

## Notes on the "awkward parts"

- **Saturation** (`red-saturation`, `red-golden`) uses standard Spring-Boot
  Micrometer metrics: `process_cpu_usage` and `jvm_memory_*` exist on **every**
  service; `tomcat_threads_*` appears only for Tomcat-based services and
  `hikaricp_*` only for services with a JDBC pool — so the API-tier and DB-tier
  panels populate for the services that actually have those tiers, which is the
  point of "saturation per class."
- **Misfits** (`red-misfits`): queue depth, consumer lag and
  batch-time-since-success need their **own exporters** (RabbitMQ/Kafka, or a
  custom success-timestamp gauge). Those panels carry the **canonical queries**
  and light up once the metrics exist; the *uptime* panel
  (`time() - process_start_time_seconds`) is real today. This is exactly the
  lesson: RED describes request-servers, and these systems need signals of
  their own.
- **Errors read 0 on a healthy fleet** — `outcome != "SUCCESS"` (and
  `status =~ "[45].."`) only light up during real failures. Panels fall back to
  0 (via `or vector(0)`) so a green fleet shows 0, not "No data".
- On a cold first load a panel can flash empty for a second while its query
  runs; it fills in on the first refresh.
