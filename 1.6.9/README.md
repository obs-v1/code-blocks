# 1.6.9 — RED · USE · Golden Signals

The Week-1 capstone: the three signal frameworks, one clean dashboard each, for
**bankobserve360**. Loaded in a single `make apply` (Terraform + the
`grafana/grafana` provider), the same "dashboards as code" way as `1.5.6`.

| uid | Dashboard | The framework |
|-----|-----------|---------------|
| `red` | **RED** — Rate · Errors · Duration | For request-serving services: how much traffic, how much fails, how slow. |
| `use` | **USE** — Utilization · Saturation · Errors | For resources (CPU, heap, thread & DB pools): how busy, how backed-up, how many faults. |
| `golden` | **Google Golden Signals** — Latency · Traffic · Errors · Saturation | The four Google-SRE signals, whole fleet at a glance. |

All three carry a `$service` variable so they re-scope to any service (or All).

## Load

Prereqs: Terraform ≥ 1.5 and a reachable Grafana with the `prometheus` datasource.

```bash
make apply   GRAFANA_URL=http://<node-ip>:13000 GRAFANA_AUTH=admin:admin
make destroy GRAFANA_URL=...
```

## Demo scenarios — make the dashboards light up

Each dashboard has a scenario that feeds the bank traffic on purpose, so you can
watch the signals move in real time. They run as a load Job inside the cluster,
so run these where `kubectl` reaches the `bankobs` namespace (e.g. the lab box).

```bash
make scenario-red      # RED / Golden : steady traffic + intentional 5xx errors
make scenario-use      # USE          : saturate CPU, threads and the DB pool
make scenario-golden   # Golden       : latency + traffic + errors + saturation together

make scenario-watch SCEN=red   # tail the generated traffic
make scenario-stop             # stop & remove every scenario
```

- **RED** hits real routes and, `ERROR_PCT`% of the time, the service's catch-all
  path (`…/boom`) which returns **5xx** — so Rate climbs, the Errors panel turns
  red, and Duration ticks up. Validated: the 5xx counter and error-ratio panel
  move as soon as it starts.
- **USE** fires DB-touching calls at high `CONCURRENCY` (120). Validated live:
  CPU **91%**, HikariCP **active 17/20** with **23 connections pending** (the
  saturation signal), p95 latency **~400 ms**, ~100 req/s.
- **Golden** is the RED mix run hot enough to also saturate — all four signals
  move at once.

Everything is tunable:
```bash
make scenario-use TARGET=ledger-service PORT=8002 DURATION=600 CONCURRENCY=200
```
`TARGET` / `PORT` / `DURATION` / `CONCURRENCY` / `ERROR_PCT` all have sane defaults
(see the top of the `Makefile`). Default target is `account-service:8001`.

## Metrics it queries

- **Requests (RED, Golden)** — OpenTelemetry HTTP semconv:
  `http_server_request_duration_seconds_count` / `_bucket`, with a `service`
  label and a `status` class label (`2xx` / `4xx` / `5xx`). Errors are `5xx`
  (widen to `status=~"4xx|5xx"` if you count client errors).
- **Resources (USE, Golden saturation)** — Micrometer / Spring Boot:
  `process_cpu_usage`, `jvm_memory_used_bytes` / `jvm_memory_max_bytes`,
  `tomcat_threads_busy_threads` / `_config_max_threads`,
  `hikaricp_connections_active` / `_max` / `_pending` / `_timeout_total`,
  `logback_events_total{level="error"}`.

## Notes

- **Errors read 0 on a healthy fleet** — `status=~"5xx"` only lights up during
  real failures; panels fall back to 0 (`or vector(0)`) so green shows 0, not
  "No data".
- **USE shows the tiers that exist** — `tomcat_*` only for Tomcat services,
  `hikaricp_*` only for services with a JDBC pool; that's the point of "per
  resource." CPU and heap are on every JVM service.
- On a cold first load a panel can flash empty for a second while its query
  runs; it fills in on the first refresh.
