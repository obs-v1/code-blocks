# 1.6.1 — the RED dashboard set (one run, all dashboards)

**RED** = **R**ate · **E**rrors · **D**uration — the three numbers that tell you
whether a request-serving system is healthy. This folder builds the whole RED
set for **bankobserve360** in a single `make apply`, the same "dashboards as
code" way as `1.5.6` and `transformations-examples` (Terraform + the
`grafana/grafana` provider).

Every dashboard queries the provisioned bank Prometheus (datasource
`uid: prometheus`, e.g. from `1.5.1`), off the Micrometer metric
`http_server_requests_seconds_*`.

## Load — one run creates all six

Prereqs: Terraform ≥ 1.5 and a reachable Grafana with the `prometheus` datasource.

```bash
make apply   GRAFANA_URL=http://<node-ip>:13000 GRAFANA_AUTH=admin:admin
make plan    GRAFANA_URL=...    # preview
make destroy GRAFANA_URL=...    # remove them all
```

`GRAFANA_AUTH` takes `user:password` or a service-account token. Under the hood
it is `terraform apply` fanning out over `dashboards/*.json` with `for_each`
(`terraform/main.tf`) — drop another JSON in `dashboards/` and the next apply
loads it too.

## The six dashboards

RED, cut two ways — **by signal** (Overview + one deep-dive per letter) and
**by scope** (the whole fleet, and one service at a time).

| # | uid | Dashboard | What it answers |
|---|-----|-----------|-----------------|
| 1 | `red-overview` | **RED — Overview** | The three headline numbers + fleet trends. "Is the platform healthy?" |
| 2 | `red-rate` | **RED — Rate** | Throughput deep-dive: total, by service, by method, by endpoint. |
| 3 | `red-errors` | **RED — Errors** | Failing fraction: error rate, error %, success %, by service, by status. |
| 4 | `red-duration` | **RED — Duration** | Tail latency: p50/p95/p99, by service, and the full latency **heatmap**. |
| 5 | `red-fleet` | **RED — Fleet at a glance** | One table, R·E·D **per service** (three queries joined on `service`) + busiest/slowest bars. "Which service is the problem?" |
| 6 | `red-service` | **RED — Per-service** | A `$service` drill-down: RED for one selected service. "Zoom into this one." |

Dashboards 1–4 and 6 carry a `$service` template variable so you can scope them;
`red-fleet` always shows every service.

## Notes

- **Errors panels read low/zero when the fleet is healthy** — that is correct.
  `outcome != "SUCCESS"` (and `status =~ "[45].."`) only light up during real
  failures; an all-green bank shows 0, which is the point of the E signal.
- The **Duration** panels need Micrometer histogram buckets
  (`http_server_requests_seconds_bucket`) — the same series the `1.5.x`
  dashboards use.
- `red-fleet`'s table uses two transformations you met in
  `transformations-examples`: **Join by field** (`service`) to put rate, errors
  and p95 side by side, then **Organize fields** to name the columns.
- On a cold first load a panel can flash empty for a second while its query runs;
  it fills in on the first refresh.
